using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows;
using Hardcodet.Wpf.TaskbarNotification;
using VibeProxy.Services;
using VibeProxy.Views;
using Application = System.Windows.Application;
using Clipboard = System.Windows.Clipboard;
using MessageBox = System.Windows.MessageBox;

namespace VibeProxy;

public partial class App : Application
{
    private const string MutexName = "VibeProxy_SingleInstance_Mutex";

    private Mutex? _mutex;
    private TaskbarIcon? _taskbarIcon;
    private ServerManager? _serverManager;
    private ThinkingProxy? _thinkingProxy;
    private SettingsWindow? _settingsWindow;
    private Icon? _activeIcon;
    private Icon? _inactiveIcon;

    protected override void OnStartup(StartupEventArgs e)
    {
        // Enforce single instance
        _mutex = new Mutex(true, MutexName, out bool createdNew);

        if (!createdNew)
        {
            MessageBox.Show(
                "VibeProxy is already running.\n\nCheck your system tray for the VibeProxy icon.",
                "VibeProxy Already Running",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            Shutdown();
            return;
        }

        base.OnStartup(e);

        // Load icons
        _activeIcon = LoadIconFromResource("icon-active.png");
        _inactiveIcon = LoadIconFromResource("icon-inactive.png");

        // Initialize services
        _serverManager = new ServerManager();
        _thinkingProxy = new ThinkingProxy();

        // Connect ThinkingProxy logs to ServerManager for unified logging
        _thinkingProxy.OnLog += message => _serverManager.AddExternalLog(message);

        // Setup system tray
        SetupTaskbarIcon();

        // Check for backend binary
        if (!CheckBackendBinary())
        {
            ShowNotification("Setup Required", "Backend binary not found. Click here to open settings.");
            OpenSettings();
            return;
        }

        // Auto-start server
        StartServer();
    }

    private bool CheckBackendBinary()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;
        var executablePath = Path.Combine(baseDir, "Resources", "cli-proxy-api-plus.exe");
        return File.Exists(executablePath);
    }

    private Icon? LoadIconFromResource(string resourceName)
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            var resourcePath = $"VibeProxy.Resources.{resourceName}";

            using var stream = assembly.GetManifestResourceStream(resourcePath);
            if (stream != null)
            {
                using var bitmap = new Bitmap(stream);
                var hIcon = bitmap.GetHicon();
                return Icon.FromHandle(hIcon);
            }

            // Fallback: try loading from file
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            var filePath = Path.Combine(baseDir, "Resources", resourceName);
            if (File.Exists(filePath))
            {
                using var bitmap = new Bitmap(filePath);
                var hIcon = bitmap.GetHicon();
                return Icon.FromHandle(hIcon);
            }

            return SystemIcons.Application;
        }
        catch
        {
            return SystemIcons.Application;
        }
    }

    private void SetupTaskbarIcon()
    {
        _taskbarIcon = new TaskbarIcon
        {
            ToolTipText = "VibeProxy - Stopped",
            Icon = _inactiveIcon ?? SystemIcons.Application,
            ContextMenu = CreateContextMenu()
        };

        _taskbarIcon.TrayMouseDoubleClick += (s, e) => OpenSettings();
        _taskbarIcon.TrayBalloonTipClicked += (s, e) => OpenSettings();
    }

    private System.Windows.Controls.ContextMenu CreateContextMenu()
    {
        var menu = new System.Windows.Controls.ContextMenu();

        var statusItem = new System.Windows.Controls.MenuItem
        {
            Header = "Server: Stopped",
            IsEnabled = false
        };
        menu.Items.Add(statusItem);

        menu.Items.Add(new System.Windows.Controls.Separator());

        var settingsItem = new System.Windows.Controls.MenuItem { Header = "Open Settings" };
        settingsItem.Click += (s, e) => OpenSettings();
        menu.Items.Add(settingsItem);

        menu.Items.Add(new System.Windows.Controls.Separator());

        var toggleItem = new System.Windows.Controls.MenuItem { Header = "Start Server" };
        toggleItem.Click += (s, e) => ToggleServer();
        menu.Items.Add(toggleItem);

        menu.Items.Add(new System.Windows.Controls.Separator());

        var copyUrlItem = new System.Windows.Controls.MenuItem
        {
            Header = "Copy Server URL",
            IsEnabled = false
        };
        copyUrlItem.Click += (s, e) => CopyServerUrl();
        menu.Items.Add(copyUrlItem);

        menu.Items.Add(new System.Windows.Controls.Separator());

        var quitItem = new System.Windows.Controls.MenuItem { Header = "Quit" };
        quitItem.Click += (s, e) => QuitApplication();
        menu.Items.Add(quitItem);

        return menu;
    }

    private async void StartServer()
    {
        if (_serverManager == null || _thinkingProxy == null) return;

        // Check for backend binary first
        if (!CheckBackendBinary())
        {
            ShowNotification("Setup Required", "Backend binary (cli-proxy-api-plus.exe) not found. Please copy it to Resources folder.");
            return;
        }

        // Start ThinkingProxy first (port 8317)
        var proxyStarted = await _thinkingProxy.StartAsync();
        if (!proxyStarted)
        {
            ShowNotification("Server Error", "Failed to start ThinkingProxy on port 8317");
            return;
        }

        // Wait briefly for proxy to be ready
        await Task.Delay(100);

        // Then start the backend (port 8318)
        var backendStarted = await _serverManager.StartAsync();
        if (backendStarted)
        {
            UpdateTrayStatus(true);
            ShowNotification("Server Started", "VibeProxy is now running on port 8317");
        }
        else
        {
            // Backend failed, stop the proxy too
            _thinkingProxy.Stop();
            ShowNotification("Server Error", "Failed to start backend server. Check logs for details.");
        }
    }

    private async void StopServer()
    {
        if (_serverManager == null || _thinkingProxy == null) return;

        // Stop proxy first (stop accepting new requests)
        _thinkingProxy.Stop();

        // Then stop backend
        await _serverManager.StopAsync();

        UpdateTrayStatus(false);
    }

    private void ToggleServer()
    {
        if (_serverManager?.IsRunning == true)
        {
            StopServer();
        }
        else
        {
            StartServer();
        }
    }

    private void UpdateTrayStatus(bool running)
    {
        if (_taskbarIcon == null) return;

        _taskbarIcon.ToolTipText = running ? "VibeProxy - Running (port 8317)" : "VibeProxy - Stopped";
        _taskbarIcon.Icon = running ? (_activeIcon ?? SystemIcons.Application) : (_inactiveIcon ?? SystemIcons.Application);

        if (_taskbarIcon.ContextMenu != null)
        {
            var items = _taskbarIcon.ContextMenu.Items;

            // Update status text (first item)
            if (items[0] is System.Windows.Controls.MenuItem statusItem)
            {
                statusItem.Header = running ? "Server: Running (port 8317)" : "Server: Stopped";
            }

            // Update toggle button (5th item, after separator)
            if (items[4] is System.Windows.Controls.MenuItem toggleItem)
            {
                toggleItem.Header = running ? "Stop Server" : "Start Server";
            }

            // Update copy URL enabled state (7th item)
            if (items[6] is System.Windows.Controls.MenuItem copyUrlItem)
            {
                copyUrlItem.IsEnabled = running;
            }
        }
    }

    private void OpenSettings()
    {
        if (_settingsWindow == null || !_settingsWindow.IsVisible)
        {
            _settingsWindow = new SettingsWindow(_serverManager!);
            _settingsWindow.Closed += (s, e) => _settingsWindow = null;
            _settingsWindow.Show();
        }
        else
        {
            _settingsWindow.Activate();
        }
    }

    private void CopyServerUrl()
    {
        Clipboard.SetText("http://localhost:8317");
        ShowNotification("Copied", "Server URL copied to clipboard");
    }

    private void ShowNotification(string title, string message)
    {
        _taskbarIcon?.ShowBalloonTip(title, message, BalloonIcon.Info);
    }

    private async void QuitApplication()
    {
        // Stop proxy first
        _thinkingProxy?.Stop();

        // Then stop backend
        if (_serverManager?.IsRunning == true)
        {
            await _serverManager.StopAsync();
        }

        _thinkingProxy?.Dispose();
        _taskbarIcon?.Dispose();
        _mutex?.ReleaseMutex();
        _mutex?.Dispose();
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _thinkingProxy?.Dispose();
        _taskbarIcon?.Dispose();
        _mutex?.ReleaseMutex();
        _mutex?.Dispose();
        base.OnExit(e);
    }
}
