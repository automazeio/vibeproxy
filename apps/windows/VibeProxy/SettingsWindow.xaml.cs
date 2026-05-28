using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using VibeProxyCore;

namespace VibeProxy;

public sealed partial class SettingsWindow : Window
{
    private readonly RustCoreManager _coreManager;
    private VibeProxyCore.AppConfig _config;

    public SettingsWindow()
    {
        this.InitializeComponent();
        _coreManager = new RustCoreManager();
        LoadSettings();
    }

    private void LoadSettings()
    {
        _config = _coreManager.GetConfig();

        // Backend
        BackendUrl.Text = _config.Backend.Url;
        BackendPort.Value = _config.Backend.Port;
        
        // Load API key from credential manager if available
        string? savedApiKey = CredentialManager.GetApiKey("backend");
        if (savedApiKey != null)
        {
            BackendApiKey.Password = savedApiKey;
        }
        else if (!string.IsNullOrEmpty(_config.Backend.ApiKey))
        {
            BackendApiKey.Password = _config.Backend.ApiKey;
            // Save to credential manager for future use
            CredentialManager.SaveApiKey("backend", _config.Backend.ApiKey);
        }

        // SLM
        SLMUrl.Text = _config.SLM.Url;
        SLMPort.Value = _config.SLM.Port;
        // Select backend in combo box
        for (int i = 0; i < SLMBackend.Items.Count; i++)
        {
            if (SLMBackend.Items[i] is ComboBoxItem item && 
                item.Content?.ToString()?.ToLower() == _config.SLM.Backend.ToLower())
            {
                SLMBackend.SelectedIndex = i;
                break;
            }
        }

        // Tunnel
        TunnelEnabled.IsOn = _config.Tunnel.Enabled;
        TunnelId.Text = _config.Tunnel.TunnelId ?? "";
        TunnelCredentials.Text = _config.Tunnel.CredentialsPath ?? "";
        
        // Clear any previous validation errors
        ClearValidationErrors();
    }
    
    private void ClearValidationErrors()
    {
        // Clear any error indicators
        if (BackendUrl != null) BackendUrl.BorderBrush = null;
        if (BackendPort != null) BackendPort.BorderBrush = null;
        if (SLMUrl != null) SLMUrl.BorderBrush = null;
        if (SLMPort != null) SLMPort.BorderBrush = null;
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        // Validate inputs
        if (!ValidateInputs())
        {
            return;
        }

        // Update config
        _config.Backend.Url = BackendUrl.Text.Trim();
        _config.Backend.Port = (ushort)BackendPort.Value;
        
        // Save API key to credential manager if provided
        if (!string.IsNullOrEmpty(BackendApiKey.Password))
        {
            if (CredentialManager.SaveApiKey("backend", BackendApiKey.Password))
            {
                // Also store in config (for backward compatibility)
                _config.Backend.ApiKey = BackendApiKey.Password;
            }
            else
            {
                ShowError("Failed to save API key securely. Please try again.");
                return;
            }
        }
        else
        {
            // Check if there's a saved key
            string? savedKey = CredentialManager.GetApiKey("backend");
            if (savedKey != null)
            {
                _config.Backend.ApiKey = savedKey;
            }
            else
            {
                _config.Backend.ApiKey = null;
            }
        }

        _config.SLM.Url = SLMUrl.Text.Trim();
        _config.SLM.Port = (ushort)SLMPort.Value;
        var backendCombo = SLMBackend.SelectedItem as ComboBoxItem;
        _config.SLM.Backend = backendCombo?.Content?.ToString()?.ToLower() ?? "vllm";

        _config.Tunnel.Enabled = TunnelEnabled.IsOn;
        _config.Tunnel.TunnelId = string.IsNullOrEmpty(TunnelId.Text) ? null : TunnelId.Text.Trim();
        _config.Tunnel.CredentialsPath = string.IsNullOrEmpty(TunnelCredentials.Text) ? null : TunnelCredentials.Text.Trim();

        // Save
        if (_coreManager.SaveConfig(_config))
        {
            // Show success message
            var successDialog = new ContentDialog
            {
                Title = "Success",
                Content = "Settings saved successfully",
                CloseButtonText = "OK",
                XamlRoot = this.Content.XamlRoot
            };
            await successDialog.ShowAsync();
            
            // Close window
            this.Close();
        }
        else
        {
            ShowError("Failed to save settings. Please check your configuration and try again.");
        }
    }
    
    private bool ValidateInputs()
    {
        bool isValid = true;
        ClearValidationErrors();
        
        // Validate Backend URL
        if (string.IsNullOrWhiteSpace(BackendUrl.Text))
        {
            MarkError(BackendUrl, "Backend URL is required");
            isValid = false;
        }
        else if (!Uri.TryCreate(BackendUrl.Text, UriKind.Absolute, out _))
        {
            MarkError(BackendUrl, "Invalid URL format");
            isValid = false;
        }
        
        // Validate Backend Port
        if (BackendPort.Value < 1 || BackendPort.Value > 65535)
        {
            MarkError(BackendPort, "Port must be between 1 and 65535");
            isValid = false;
        }
        
        // Validate SLM URL
        if (string.IsNullOrWhiteSpace(SLMUrl.Text))
        {
            MarkError(SLMUrl, "SLM URL is required");
            isValid = false;
        }
        else if (!Uri.TryCreate(SLMUrl.Text, UriKind.Absolute, out _))
        {
            MarkError(SLMUrl, "Invalid URL format");
            isValid = false;
        }
        
        // Validate SLM Port
        if (SLMPort.Value < 1 || SLMPort.Value > 65535)
        {
            MarkError(SLMPort, "Port must be between 1 and 65535");
            isValid = false;
        }
        
        // Validate Tunnel ID if tunnel is enabled
        if (TunnelEnabled.IsOn && string.IsNullOrWhiteSpace(TunnelId.Text))
        {
            MarkError(TunnelId, "Tunnel ID is required when tunnel is enabled");
            isValid = false;
        }
        
        if (!isValid)
        {
            ShowError("Please fix the validation errors before saving.");
        }
        
        return isValid;
    }
    
    private void MarkError(Control control, string message)
    {
        // Set red border to indicate error
        control.BorderBrush = new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Red);
        control.BorderThickness = new Microsoft.UI.Xaml.Thickness(2);
        
        // You could also add a tooltip or error message below the control
        System.Diagnostics.Debug.WriteLine($"Validation error: {message}");
    }
    
    private async void ShowError(string message)
    {
        var dialog = new ContentDialog
        {
            Title = "Error",
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = this.Content.XamlRoot
        };
        await dialog.ShowAsync();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        this.Close();
    }
}
