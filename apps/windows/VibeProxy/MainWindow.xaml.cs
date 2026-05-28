using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Windows.Graphics;
using VibeProxyCore;

namespace VibeProxy;

public sealed partial class MainWindow : Window
{
    private readonly RustCoreManager _coreManager;
    private readonly ServerManager _serverManager;
    private AppWindow? _appWindow;
    private bool _isServerRunning = false;
    private TrayIcon? _trayIcon;

    public MainWindow()
    {
        this.InitializeComponent();

        // Initialize Rust core
        _coreManager = new RustCoreManager();
        
        // Initialize server manager
        _serverManager = new ServerManager(_coreManager);
        _serverManager.StatusChanged += OnServerStatusChanged;
        _serverManager.ErrorOccurred += OnServerError;

        // Get AppWindow for customization
        _appWindow = GetAppWindowForCurrentWindow();
        if (_appWindow != null)
        {
            _appWindow.Title = "VibeProxy";
            _appWindow.Resize(new SizeInt32(500, 600));
        }

        // Initialize system tray
        InitializeTray();

        // Load initial state
        LoadConfiguration();
        
        // Create tray icon
        _trayIcon = new TrayIcon(this);
        
        // Wire up tray icon events
        _trayIcon.ShowWindowRequested += (s, e) => ShowWindow();
        _trayIcon.SettingsRequested += (s, e) => Settings_Click(s, new RoutedEventArgs());
        _trayIcon.QuitRequested += (s, e) => Quit_Click(s, new RoutedEventArgs());
    }
    
    private void ShowWindow()
    {
        if (_appWindow != null)
        {
            _appWindow.Show();
            _appWindow.MoveInZOrderAtTop();
        }
    }

    private AppWindow? GetAppWindowForCurrentWindow()
    {
        try
        {
            IntPtr hWnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            WindowId windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hWnd);
            return AppWindow.GetFromWindowId(windowId);
        }
        catch
        {
            return null;
        }
    }

    private void InitializeTray()
    {
        if (_appWindow != null)
        {
            _appWindow.Closing += (s, e) =>
            {
                // Hide instead of close when clicking X
                e.Cancel = true;
                _appWindow.Hide();
                
                // Show notification
                _trayIcon?.ShowNotification("VibeProxy", "Running in system tray. Right-click the icon to show window.");
            };
        }
    }

    private void LoadConfiguration()
    {
        var config = _coreManager.GetConfig();

        // Update UI with config values
        DispatcherQueue.TryEnqueue(() =>
        {
            // Update status indicators
            UpdateServerStatus();
        });
    }

    private void UpdateServerStatus()
    {
        // Update UI based on server status
        DispatcherQueue.TryEnqueue(() =>
        {
            if (StatusText != null)
            {
                StatusText.Text = _isServerRunning ? "Running" : "Stopped";
            }

            if (StatusIndicator != null)
            {
                StatusIndicator.Fill = _isServerRunning
                    ? new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Green)
                    : new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Red);
            }
            
            // Update button states
            if (StartServerButton != null)
            {
                StartServerButton.IsEnabled = !_isServerRunning;
            }
            if (StopServerButton != null)
            {
                StopServerButton.IsEnabled = _isServerRunning;
            }
            if (RestartServerButton != null)
            {
                RestartServerButton.IsEnabled = _isServerRunning;
            }
        });
    }
    
    private void OnServerStatusChanged(object? sender, bool isRunning)
    {
        _isServerRunning = isRunning;
        UpdateServerStatus();
        
        // Update tray icon tooltip
        _trayIcon?.UpdateTooltip(isRunning 
            ? "VibeProxy - Running" 
            : "VibeProxy - Stopped");
        
        // Show notification
        _trayIcon?.ShowNotification(
            "VibeProxy",
            isRunning ? "Server started" : "Server stopped");
    }
    
    private void OnServerError(object? sender, string error)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            // Show error in UI (you can add an error text block)
            System.Diagnostics.Debug.WriteLine($"[Server Error] {error}");
            
            // Show toast notification
            _trayIcon?.ShowNotification("VibeProxy Error", error);
        });
    }
    
    // Add menu item for visual rules editor
    private void ShowRulesEditor_Click(object sender, RoutedEventArgs e)
    {
        var rulesWindow = new VisualRulesEditor();
        rulesWindow.Activate();
    }

    private async void StartServer_Click(object sender, RoutedEventArgs e)
    {
        if (StartServerButton != null)
        {
            StartServerButton.IsEnabled = false;
        }
        
        bool success = await _serverManager.StartServerAsync();
        
        if (!success && StartServerButton != null)
        {
            StartServerButton.IsEnabled = true;
        }
        
        // Start health monitoring
        if (success)
        {
            StartHealthMonitoring();
        }
    }

    private async void StopServer_Click(object sender, RoutedEventArgs e)
    {
        if (StopServerButton != null)
        {
            StopServerButton.IsEnabled = false;
        }
        
        await _serverManager.StopServerAsync();
        
        // Stop health monitoring
        StopHealthMonitoring();
    }
    
    private async void RestartServer_Click(object sender, RoutedEventArgs e)
    {
        if (RestartServerButton != null)
        {
            RestartServerButton.IsEnabled = false;
        }
        
        bool success = await _serverManager.RestartServerAsync();
        
        if (success)
        {
            StartHealthMonitoring();
        }
        
        if (RestartServerButton != null)
        {
            RestartServerButton.IsEnabled = _isServerRunning;
        }
    }
    
    private System.Threading.CancellationTokenSource? _healthMonitoringCts;
    
    private void StartHealthMonitoring()
    {
        StopHealthMonitoring(); // Stop any existing monitoring
        
        _healthMonitoringCts = new System.Threading.CancellationTokenSource();
        
        Task.Run(async () =>
        {
            while (!_healthMonitoringCts.Token.IsCancellationRequested)
            {
                try
                {
                    var status = await _serverManager.GetStatusAsync();
                    
                    DispatcherQueue.TryEnqueue(() =>
                    {
                        // Update health status
                        if (StatusText != null)
                        {
                            StatusText.Text = status.IsRunning 
                                ? (status.IsHealthy ? "Running (Healthy)" : "Running (Unhealthy)")
                                : "Stopped";
                        }
                        
                        // Update backend latency if available
                        var health = _coreManager.GetBackendHealth();
                        if (health != null && BackendLatency != null)
                        {
                            BackendLatency.Text = $"{health.LatencyMs}ms";
                        }
                    });
                }
                catch
                {
                    // Ignore monitoring errors
                }
                
                await Task.Delay(5000, _healthMonitoringCts.Token); // Check every 5 seconds
            }
        });
    }
    
    private void StopHealthMonitoring()
    {
        _healthMonitoringCts?.Cancel();
        _healthMonitoringCts?.Dispose();
        _healthMonitoringCts = null;
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        var settingsWindow = new SettingsWindow();
        settingsWindow.Activate();
    }

    private async void Quit_Click(object sender, RoutedEventArgs e)
    {
        // Stop server if running
        if (_isServerRunning)
        {
            await _serverManager.StopServerAsync();
        }
        
        // Stop health monitoring
        StopHealthMonitoring();
        
        // Dispose resources
        _serverManager.Dispose();
        _trayIcon?.Dispose();
        
        // Actually close the app
        if (_appWindow != null)
        {
            _appWindow.Destroy();
        }
        Application.Current.Exit();
    }
}

/// <summary>
/// Manager for Rust core library integration
/// </summary>
public class RustCoreManager
{
    private bool _isInitialized = false;

    public RustCoreManager()
    {
        Initialize();
    }

    public void Initialize()
    {
        if (_isInitialized) return;

        try
        {
            _isInitialized = VibeProxyCore.VibeProxyCore.Initialize();
            if (_isInitialized)
            {
                System.Diagnostics.Debug.WriteLine($"[RustCore] Initialized, version: {VibeProxyCore.VibeProxyCore.Version}");
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[RustCore] Failed to initialize: {ex.Message}");
        }
    }

    public VibeProxyCore.AppConfig GetConfig()
    {
        if (!_isInitialized) return new VibeProxyCore.AppConfig();

        try
        {
            return VibeProxyCore.VibeProxyCore.LoadConfig();
        }
        catch
        {
            return VibeProxyCore.VibeProxyCore.GetDefaultConfig();
        }
    }

    public bool SaveConfig(VibeProxyCore.AppConfig config)
    {
        if (!_isInitialized) return false;

        try
        {
            VibeProxyCore.VibeProxyCore.SaveConfig(config);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public void CheckBackendHealth()
    {
        if (!_isInitialized) return;

        try
        {
            var config = GetConfig();
            var status = VibeProxyCore.VibeProxyCore.CheckBackendHealth(config.Backend);
            System.Diagnostics.Debug.WriteLine($"[RustCore] Backend health: {status.Healthy}, latency: {status.LatencyMs}ms");
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[RustCore] Health check failed: {ex.Message}");
        }
    }
    
    public VibeProxyCore.HealthStatus? GetBackendHealth()
    {
        if (!_isInitialized) return null;
        
        try
        {
            var config = GetConfig();
            return VibeProxyCore.VibeProxyCore.CheckBackendHealth(config.Backend);
        }
        catch
        {
            return null;
        }
    }
}
