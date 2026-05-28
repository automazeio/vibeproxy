using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using VibeProxyCore;

namespace VibeProxy;

/// <summary>
/// Manages the bifrost server process lifecycle
/// </summary>
public class ServerManager : IDisposable
{
    private Process? _serverProcess;
    private readonly RustCoreManager _coreManager;
    private readonly BackendClient? _backendClient;
    private bool _isRunning = false;
    private bool _disposed = false;

    public event EventHandler<bool>? StatusChanged;
    public event EventHandler<string>? ErrorOccurred;

    public bool IsRunning => _isRunning && _serverProcess != null && !_serverProcess.HasExited;

    public ServerManager(RustCoreManager coreManager)
    {
        _coreManager = coreManager;
        
        // Initialize backend client if config is available
        try
        {
            var config = _coreManager.GetConfig();
            _backendClient = new BackendClient(config.Backend);
        }
        catch
        {
            // Backend client will be null if config unavailable
        }
    }

    /// <summary>
    /// Starts the bifrost server
    /// </summary>
    public async Task<bool> StartServerAsync()
    {
        if (IsRunning)
        {
            ErrorOccurred?.Invoke(this, "Server is already running");
            return false;
        }

        try
        {
            var config = _coreManager.GetConfig();
            
            // Find the bifrost CLI executable
            string? bifrostPath = FindBifrostExecutable();
            if (string.IsNullOrEmpty(bifrostPath))
            {
                ErrorOccurred?.Invoke(this, "Bifrost executable not found. Please ensure it's installed.");
                return false;
            }

            // Prepare server start arguments
            var startInfo = new ProcessStartInfo
            {
                FileName = bifrostPath,
                Arguments = $"server --host {config.Backend.Url} --port {config.Backend.Port}",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                WorkingDirectory = Path.GetDirectoryName(bifrostPath) ?? Environment.CurrentDirectory
            };

            // Start the process
            _serverProcess = new Process
            {
                StartInfo = startInfo,
                EnableRaisingEvents = true
            };

            _serverProcess.Exited += (s, e) =>
            {
                _isRunning = false;
                StatusChanged?.Invoke(this, false);
            };

            _serverProcess.OutputDataReceived += (s, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    System.Diagnostics.Debug.WriteLine($"[Bifrost] {e.Data}");
                }
            };

            _serverProcess.ErrorDataReceived += (s, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    System.Diagnostics.Debug.WriteLine($"[Bifrost Error] {e.Data}");
                    ErrorOccurred?.Invoke(this, e.Data);
                }
            };

            if (!_serverProcess.Start())
            {
                ErrorOccurred?.Invoke(this, "Failed to start server process");
                return false;
            }

            _serverProcess.BeginOutputReadLine();
            _serverProcess.BeginErrorReadLine();

            _isRunning = true;
            StatusChanged?.Invoke(this, true);

            // Wait a moment for server to start, then verify
            await Task.Delay(2000);
            
            if (_backendClient != null)
            {
                bool healthy = await _backendClient.HealthCheckAsync();
                if (!healthy)
                {
                    System.Diagnostics.Debug.WriteLine("[ServerManager] Server started but health check failed");
                }
            }

            return true;
        }
        catch (Exception ex)
        {
            ErrorOccurred?.Invoke(this, $"Failed to start server: {ex.Message}");
            _isRunning = false;
            return false;
        }
    }

    /// <summary>
    /// Stops the bifrost server
    /// </summary>
    public async Task<bool> StopServerAsync()
    {
        if (!IsRunning || _serverProcess == null)
        {
            return true; // Already stopped
        }

        try
        {
            // Try graceful shutdown first
            if (!_serverProcess.HasExited)
            {
                _serverProcess.Kill();
                
                // Wait for process to exit (max 5 seconds)
                if (!_serverProcess.WaitForExit(5000))
                {
                    // Force kill if still running
                    _serverProcess.Kill();
                    _serverProcess.WaitForExit();
                }
            }

            _serverProcess.Dispose();
            _serverProcess = null;
            _isRunning = false;
            StatusChanged?.Invoke(this, false);

            return true;
        }
        catch (Exception ex)
        {
            ErrorOccurred?.Invoke(this, $"Failed to stop server: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Restarts the server
    /// </summary>
    public async Task<bool> RestartServerAsync()
    {
        await StopServerAsync();
        await Task.Delay(1000); // Brief pause between stop and start
        return await StartServerAsync();
    }

    /// <summary>
    /// Checks server health
    /// </summary>
    public async Task<bool> CheckHealthAsync()
    {
        if (_backendClient == null)
        {
            return IsRunning; // Fallback to process status
        }

        try
        {
            return await _backendClient.HealthCheckAsync();
        }
        catch
        {
            return IsRunning; // Fallback to process status
        }
    }

    /// <summary>
    /// Gets server status information
    /// </summary>
    public async Task<ServerStatus> GetStatusAsync()
    {
        var status = new ServerStatus
        {
            IsRunning = IsRunning,
            ProcessId = _serverProcess?.Id,
            HasExited = _serverProcess?.HasExited ?? true
        };

        if (_backendClient != null && IsRunning)
        {
            try
            {
                status.IsHealthy = await _backendClient.HealthCheckAsync();
                
                // Try to get detailed status
                try
                {
                    var detailedStatus = await _backendClient.GetStatusAsync();
                    if (detailedStatus.TryGetProperty("uptime", out var uptime))
                    {
                        status.Uptime = uptime.GetString();
                    }
                }
                catch
                {
                    // Detailed status unavailable, that's okay
                }
            }
            catch
            {
                status.IsHealthy = false;
            }
        }

        return status;
    }

    private string? FindBifrostExecutable()
    {
        // Check common locations
        var possiblePaths = new[]
        {
            Path.Combine(Environment.CurrentDirectory, "bifrost.exe"),
            Path.Combine(Environment.CurrentDirectory, "bifrost"),
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bifrost.exe"),
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bifrost"),
            "bifrost.exe", // In PATH
            "bifrost" // In PATH
        };

        foreach (var path in possiblePaths)
        {
            if (File.Exists(path))
            {
                return Path.GetFullPath(path);
            }

            // Try to find in PATH
            try
            {
                var whichResult = Process.Start(new ProcessStartInfo
                {
                    FileName = "where",
                    Arguments = path,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                });
                
                if (whichResult != null)
                {
                    var output = whichResult.StandardOutput.ReadToEnd();
                    whichResult.WaitForExit();
                    
                    if (!string.IsNullOrWhiteSpace(output))
                    {
                        var foundPath = output.Split('\n')[0].Trim();
                        if (File.Exists(foundPath))
                        {
                            return foundPath;
                        }
                    }
                }
            }
            catch
            {
                // Continue searching
            }
        }

        return null;
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            StopServerAsync().Wait(5000);
            _serverProcess?.Dispose();
            _disposed = true;
        }
    }
}

/// <summary>
/// Server status information
/// </summary>
public class ServerStatus
{
    public bool IsRunning { get; set; }
    public bool IsHealthy { get; set; }
    public int? ProcessId { get; set; }
    public bool HasExited { get; set; }
    public string? Uptime { get; set; }
}
