using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using Microsoft.Win32;
using VibeProxy.Models;
using VibeProxy.Services;
using Button = System.Windows.Controls.Button;
using Color = System.Windows.Media.Color;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using Image = System.Windows.Controls.Image;
using MessageBox = System.Windows.MessageBox;
using Orientation = System.Windows.Controls.Orientation;
using Path = System.IO.Path;
using TextBox = System.Windows.Controls.TextBox;

namespace VibeProxy.Views;

public partial class SettingsWindow : Window
{
    private const string StartupRegistryKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "VibeProxy";

    private readonly ServerManager _serverManager;
    private readonly AuthManager _authManager;
    private readonly Dictionary<ServiceType, bool> _connectingServices = new();

    public SettingsWindow(ServerManager serverManager)
    {
        InitializeComponent();
        _serverManager = serverManager;
        _authManager = new AuthManager();

        // Subscribe to events
        _serverManager.PropertyChanged += ServerManager_PropertyChanged;
        _serverManager.OnLogUpdate += ServerManager_OnLogUpdate;
        _authManager.OnAuthStatusChanged += AuthManager_OnStatusChanged;

        // Initialize UI state
        UpdateServerStatus();
        LoadLaunchAtLoginState();
        LoadExistingLogs();
        BuildServiceRows();
    }

    private void ServerManager_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ServerManager.IsRunning))
        {
            Dispatcher.Invoke(UpdateServerStatus);
        }
    }

    private void ServerManager_OnLogUpdate(string log)
    {
        Dispatcher.Invoke(() =>
        {
            var currentText = LogTextBlock.Text;
            if (currentText == "No logs yet...")
            {
                LogTextBlock.Text = log;
            }
            else
            {
                LogTextBlock.Text = currentText + Environment.NewLine + log;
            }

            // Auto-scroll to bottom
            LogScrollViewer.ScrollToEnd();
        });
    }

    private void AuthManager_OnStatusChanged()
    {
        Dispatcher.Invoke(BuildServiceRows);
    }

    private void LoadExistingLogs()
    {
        var logs = _serverManager.Logs;
        if (logs.Count > 0)
        {
            LogTextBlock.Text = string.Join(Environment.NewLine, logs);
            LogScrollViewer.ScrollToEnd();
        }
    }

    private void UpdateServerStatus()
    {
        if (_serverManager.IsRunning)
        {
            StatusIndicator.Fill = new SolidColorBrush(Color.FromRgb(34, 197, 94)); // Green
            StatusText.Text = $"Running on port {_serverManager.Port}";
            ToggleServerButton.Content = "Stop Server";
        }
        else
        {
            StatusIndicator.Fill = new SolidColorBrush(Color.FromRgb(239, 68, 68)); // Red
            StatusText.Text = "Stopped";
            ToggleServerButton.Content = "Start Server";
        }
    }

    private void BuildServiceRows()
    {
        ServicesPanel.Children.Clear();

        foreach (ServiceType service in Enum.GetValues<ServiceType>())
        {
            var row = CreateServiceRow(service);
            ServicesPanel.Children.Add(row);
        }
    }

    private Border CreateServiceRow(ServiceType service)
    {
        var accounts = _authManager.GetAccounts(service);
        var isConnecting = _connectingServices.TryGetValue(service, out var connecting) && connecting;

        var border = new Border
        {
            Background = new SolidColorBrush(Color.FromRgb(37, 37, 37)),
            CornerRadius = new CornerRadius(6),
            Padding = new Thickness(12, 10, 12, 10),
            Margin = new Thickness(0, 4, 0, 0)
        };

        var mainGrid = new Grid();
        mainGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        mainGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        mainGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        // Service icon
        var icon = new Image
        {
            Width = 24,
            Height = 24,
            Margin = new Thickness(0, 0, 10, 0)
        };

        try
        {
            var iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", service.GetIconName());
            if (File.Exists(iconPath))
            {
                icon.Source = new BitmapImage(new Uri(iconPath));
            }
        }
        catch { }

        Grid.SetColumn(icon, 0);
        mainGrid.Children.Add(icon);

        // Service name and account info
        var infoPanel = new StackPanel { VerticalAlignment = VerticalAlignment.Center };

        var nameText = new TextBlock
        {
            Text = service.GetDisplayName(),
            Foreground = new SolidColorBrush(Color.FromRgb(224, 224, 224)),
            FontWeight = FontWeights.SemiBold,
            FontSize = 13
        };
        infoPanel.Children.Add(nameText);

        if (accounts.HasAccounts)
        {
            foreach (var account in accounts.Accounts)
            {
                var accountRow = CreateAccountRow(account);
                infoPanel.Children.Add(accountRow);
            }
        }
        else
        {
            var noAccountText = new TextBlock
            {
                Text = "Not connected",
                Foreground = new SolidColorBrush(Color.FromRgb(156, 163, 175)),
                FontSize = 11
            };
            infoPanel.Children.Add(noAccountText);
        }

        Grid.SetColumn(infoPanel, 1);
        mainGrid.Children.Add(infoPanel);

        // Connect button or spinner
        var actionPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Center
        };

        if (isConnecting)
        {
            var spinner = new TextBlock
            {
                Text = "Connecting...",
                Foreground = new SolidColorBrush(Color.FromRgb(156, 163, 175)),
                FontSize = 11,
                VerticalAlignment = VerticalAlignment.Center
            };
            actionPanel.Children.Add(spinner);
        }
        else
        {
            var connectButton = new Button
            {
                Content = accounts.HasAccounts ? "Add Account" : "Connect",
                Padding = new Thickness(10, 5, 10, 5),
                Background = new SolidColorBrush(Color.FromRgb(55, 65, 81)),
                Foreground = new SolidColorBrush(Color.FromRgb(224, 224, 224)),
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand,
                FontSize = 11
            };
            connectButton.Click += (s, e) => ConnectService(service);
            actionPanel.Children.Add(connectButton);
        }

        Grid.SetColumn(actionPanel, 2);
        mainGrid.Children.Add(actionPanel);

        border.Child = mainGrid;
        return border;
    }

    private StackPanel CreateAccountRow(AuthAccount account)
    {
        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 4, 0, 0)
        };

        // Status indicator
        var statusColor = account.IsExpired
            ? Color.FromRgb(251, 146, 60) // Orange
            : Color.FromRgb(34, 197, 94);  // Green

        var statusDot = new Ellipse
        {
            Width = 8,
            Height = 8,
            Fill = new SolidColorBrush(statusColor),
            Margin = new Thickness(0, 0, 6, 0),
            VerticalAlignment = VerticalAlignment.Center
        };
        panel.Children.Add(statusDot);

        // Account name
        var nameText = new TextBlock
        {
            Text = account.DisplayName,
            Foreground = new SolidColorBrush(Color.FromRgb(156, 163, 175)),
            FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center
        };
        panel.Children.Add(nameText);

        // Expiry indicator
        if (account.IsExpired)
        {
            var expiredText = new TextBlock
            {
                Text = " (expired)",
                Foreground = new SolidColorBrush(Color.FromRgb(251, 146, 60)),
                FontSize = 11,
                VerticalAlignment = VerticalAlignment.Center
            };
            panel.Children.Add(expiredText);
        }

        // Remove button
        var removeButton = new Button
        {
            Content = "Remove",
            Padding = new Thickness(6, 2, 6, 2),
            Background = new SolidColorBrush(Color.FromRgb(127, 29, 29)),
            Foreground = new SolidColorBrush(Colors.White),
            BorderThickness = new Thickness(0),
            FontSize = 10,
            Margin = new Thickness(10, 0, 0, 0),
            Cursor = System.Windows.Input.Cursors.Hand
        };
        removeButton.Click += (s, e) => RemoveAccount(account);
        panel.Children.Add(removeButton);

        return panel;
    }

    private async void ConnectService(ServiceType service)
    {
        _connectingServices[service] = true;
        BuildServiceRows();

        try
        {
            AuthCommand command;

            if (service == ServiceType.Qwen)
            {
                // Qwen needs email input first
                var email = PromptForEmail();
                if (string.IsNullOrEmpty(email))
                {
                    _connectingServices[service] = false;
                    BuildServiceRows();
                    return;
                }
                command = AuthCommand.QwenLogin(email);
            }
            else
            {
                command = service switch
                {
                    ServiceType.Claude => AuthCommand.ClaudeLogin,
                    ServiceType.Codex => AuthCommand.CodexLogin,
                    ServiceType.Copilot => AuthCommand.CopilotLogin,
                    ServiceType.Gemini => AuthCommand.GeminiLogin,
                    ServiceType.Antigravity => AuthCommand.AntigravityLogin,
                    _ => throw new ArgumentException($"Unknown service: {service}")
                };
            }

            var success = await _serverManager.RunAuthCommandAsync(command);

            if (success)
            {
                // Refresh auth status
                _authManager.RefreshAuthStatus();
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to connect: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            _connectingServices[service] = false;
            BuildServiceRows();
        }
    }

    private string? PromptForEmail()
    {
        var dialog = new Window
        {
            Title = "Qwen Login",
            Width = 350,
            Height = 150,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Owner = this,
            Background = new SolidColorBrush(Color.FromRgb(30, 30, 30)),
            ResizeMode = ResizeMode.NoResize
        };

        var panel = new StackPanel { Margin = new Thickness(20) };

        var label = new TextBlock
        {
            Text = "Enter your email for Qwen authentication:",
            Foreground = new SolidColorBrush(Color.FromRgb(224, 224, 224)),
            Margin = new Thickness(0, 0, 0, 10)
        };
        panel.Children.Add(label);

        var textBox = new TextBox
        {
            Margin = new Thickness(0, 0, 0, 15),
            Padding = new Thickness(8, 6, 8, 6)
        };
        panel.Children.Add(textBox);

        var buttonPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };

        var okButton = new Button
        {
            Content = "Connect",
            Padding = new Thickness(15, 6, 15, 6),
            Margin = new Thickness(0, 0, 8, 0),
            IsDefault = true
        };
        okButton.Click += (s, e) => { dialog.DialogResult = true; dialog.Close(); };
        buttonPanel.Children.Add(okButton);

        var cancelButton = new Button
        {
            Content = "Cancel",
            Padding = new Thickness(15, 6, 15, 6),
            IsCancel = true
        };
        buttonPanel.Children.Add(cancelButton);

        panel.Children.Add(buttonPanel);
        dialog.Content = panel;

        return dialog.ShowDialog() == true ? textBox.Text : null;
    }

    private void RemoveAccount(AuthAccount account)
    {
        var result = MessageBox.Show(
            $"Remove {account.DisplayName} from {account.Type.GetDisplayName()}?",
            "Confirm Removal",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (result == MessageBoxResult.Yes)
        {
            _authManager.DeleteAccount(account);
        }
    }

    private async void ToggleServer_Click(object sender, RoutedEventArgs e)
    {
        ToggleServerButton.IsEnabled = false;

        try
        {
            if (_serverManager.IsRunning)
            {
                await _serverManager.StopAsync();
            }
            else
            {
                await _serverManager.StartAsync();
            }
        }
        finally
        {
            ToggleServerButton.IsEnabled = true;
        }
    }

    private void OpenAuthFolder_Click(object sender, RoutedEventArgs e)
    {
        _authManager.OpenAuthDirectory();
    }

    private void LoadLaunchAtLoginState()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(StartupRegistryKey, false);
            var value = key?.GetValue(AppName);
            LaunchAtLoginCheckBox.IsChecked = value != null;
        }
        catch
        {
            LaunchAtLoginCheckBox.IsChecked = false;
        }
    }

    private void LaunchAtLogin_Changed(object sender, RoutedEventArgs e)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(StartupRegistryKey, true);
            if (key == null) return;

            if (LaunchAtLoginCheckBox.IsChecked == true)
            {
                var exePath = Process.GetCurrentProcess().MainModule?.FileName;
                if (exePath != null)
                {
                    key.SetValue(AppName, $"\"{exePath}\"");
                }
            }
            else
            {
                key.DeleteValue(AppName, false);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to update startup setting: {ex.Message}",
                "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Hyperlink_RequestNavigate(object sender, RequestNavigateEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = e.Uri.AbsoluteUri,
            UseShellExecute = true
        });
        e.Handled = true;
    }

    protected override void OnClosed(EventArgs e)
    {
        _serverManager.PropertyChanged -= ServerManager_PropertyChanged;
        _serverManager.OnLogUpdate -= ServerManager_OnLogUpdate;
        _authManager.OnAuthStatusChanged -= AuthManager_OnStatusChanged;
        _authManager.Dispose();
        base.OnClosed(e);
    }
}
