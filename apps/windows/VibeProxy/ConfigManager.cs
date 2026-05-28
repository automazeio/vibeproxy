using System;
using System.IO;
using System.Text.Json;
using VibeProxyCore;

namespace VibeProxy;

/// <summary>
/// Manages application configuration using shared core
/// </summary>
public class ConfigManager
{
    private static ConfigManager? _instance;
    public static ConfigManager Instance => _instance ??= new ConfigManager();
    
    private AppConfig? _appConfig;
    private readonly string _configPath;
    
    private ConfigManager()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var configDir = Path.Combine(appData, "VibeProxy");
        Directory.CreateDirectory(configDir);
        _configPath = Path.Combine(configDir, "config.json");
    }
    
    /// <summary>
    /// Load configuration from file or shared core default
    /// </summary>
    public AppConfig LoadConfig()
    {
        // Try to load from file first
        if (File.Exists(_configPath))
        {
            try
            {
                var json = File.ReadAllText(_configPath);
                _appConfig = JsonSerializer.Deserialize<AppConfig>(json);
                if (_appConfig != null)
                {
                    return _appConfig;
                }
            }
            catch
            {
                // Fall through to default
            }
        }
        
        // Fall back to shared core default
        try
        {
            _appConfig = VibeProxyCore.VibeProxyCore.GetDefaultConfig();
            return _appConfig;
        }
        catch
        {
            // Last resort: create default manually
            _appConfig = new AppConfig();
            return _appConfig;
        }
    }
    
    /// <summary>
    /// Save configuration to file
    /// </summary>
    public void SaveConfig(AppConfig config)
    {
        var options = new JsonSerializerOptions { WriteIndented = true };
        var json = JsonSerializer.Serialize(config, options);
        File.WriteAllText(_configPath, json);
        _appConfig = config;
    }
    
    /// <summary>
    /// Get current configuration
    /// </summary>
    public AppConfig GetConfig()
    {
        return _appConfig ?? LoadConfig();
    }
}
