using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text;

namespace VibeProxy.Services;

/// <summary>
/// Manages the cli-proxy-api backend process lifecycle.
/// Equivalent to ServerManager.swift in the macOS version.
/// </summary>
public class ServerManager : INotifyPropertyChanged
{
    private const int BackendPort = 8318;
    private const int GracefulShutdownTimeoutMs = 2000;
    private const int MaxLogLines = 1000;

    private Process? _process;
    private readonly object _lock = new();
    private readonly RingBuffer<string> _logBuffer = new(MaxLogLines);
    private CancellationTokenSource? _outputCancellation;

    public event PropertyChangedEventHandler? PropertyChanged;
    public event Action<string>? OnLogUpdate;

    private bool _isRunning;
    public bool IsRunning
    {
        get => _isRunning;
        private set
        {
            if (_isRunning != value)
            {
                _isRunning = value;
                OnPropertyChanged();
            }
        }
    }

    public int Port => BackendPort;

    public IReadOnlyList<string> Logs => _logBuffer.ToList();

    /// <summary>
    /// Adds an external log message (e.g., from ThinkingProxy).
    /// </summary>
    public void AddExternalLog(string message)
    {
        AppendLog(message);
    }

    /// <summary>
    /// Starts the cli-proxy-api backend process.
    /// </summary>
    public async Task<bool> StartAsync()
    {
        if (IsRunning) return true;

        // Kill any orphaned processes first
        await KillOrphanedProcessesAsync();

        var executablePath = GetExecutablePath();
        var configPath = GetConfigPath();

        if (!File.Exists(executablePath))
        {
            AppendLog($"ERROR: Backend executable not found at: {executablePath}");
            return false;
        }

        if (!File.Exists(configPath))
        {
            AppendLog($"ERROR: Config file not found at: {configPath}");
            return false;
        }

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = executablePath,
                Arguments = $"-config \"{configPath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(executablePath)
            };

            _process = new Process { StartInfo = startInfo };
            _process.EnableRaisingEvents = true;
            _process.Exited += OnProcessExited;

            _outputCancellation = new CancellationTokenSource();

            _process.Start();

            // Start reading output streams
            _ = ReadOutputAsync(_process.StandardOutput, _outputCancellation.Token);
            _ = ReadOutputAsync(_process.StandardError, _outputCancellation.Token);

            AppendLog($"Started cli-proxy-api on port {BackendPort}");

            // Wait briefly to check if process started successfully
            await Task.Delay(1000);

            if (_process.HasExited)
            {
                AppendLog($"ERROR: Process exited immediately with code {_process.ExitCode}");
                return false;
            }

            IsRunning = true;
            return true;
        }
        catch (Exception ex)
        {
            AppendLog($"ERROR: Failed to start process: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Stops the cli-proxy-api backend process gracefully.
    /// </summary>
    public async Task StopAsync()
    {
        if (!IsRunning || _process == null) return;

        AppendLog("Stopping server...");

        try
        {
            _outputCancellation?.Cancel();

            // Try graceful shutdown first
            if (!_process.HasExited)
            {
                // On Windows, CloseMainWindow() won't work for console apps
                // We'll use taskkill with /T to kill the process tree
                try
                {
                    using var killer = new Process();
                    killer.StartInfo = new ProcessStartInfo
                    {
                        FileName = "taskkill",
                        Arguments = $"/PID {_process.Id} /T",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };
                    killer.Start();
                    await killer.WaitForExitAsync();
                }
                catch
                {
                    // Fallback: direct kill
                }

                // Wait for graceful exit
                var exited = await WaitForExitAsync(_process, GracefulShutdownTimeoutMs);

                if (!exited)
                {
                    AppendLog("Graceful shutdown timed out, forcing kill...");
                    _process.Kill(entireProcessTree: true);
                    await WaitForExitAsync(_process, 1000);
                }
            }

            AppendLog("Server stopped");
        }
        catch (Exception ex)
        {
            AppendLog($"Error during shutdown: {ex.Message}");
        }
        finally
        {
            CleanupProcess();
            IsRunning = false;
        }
    }

    /// <summary>
    /// Restarts the server.
    /// </summary>
    public async Task RestartAsync()
    {
        await StopAsync();
        await Task.Delay(500);
        await StartAsync();
    }

    /// <summary>
    /// Runs an authentication command for a specific service.
    /// </summary>
    public async Task<bool> RunAuthCommandAsync(AuthCommand command)
    {
        var executablePath = GetExecutablePath();
        var configPath = GetConfigPath();

        if (!File.Exists(executablePath)) return false;

        string? args = null;

        if (command == AuthCommand.ClaudeLogin)
            args = $"-config \"{configPath}\" -claude-login";
        else if (command == AuthCommand.CodexLogin)
            args = $"-config \"{configPath}\" -codex-login";
        else if (command == AuthCommand.CopilotLogin)
            args = $"-config \"{configPath}\" -copilot-login";
        else if (command == AuthCommand.GeminiLogin)
            args = $"-config \"{configPath}\" -gemini-login";
        else if (command == AuthCommand.AntigravityLogin)
            args = $"-config \"{configPath}\" -antigravity-login";
        else if (command is QwenLoginCommand qwen)
            args = $"-config \"{configPath}\" -qwen-login -qwen-email \"{qwen.Email}\"";

        if (args == null) return false;

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = executablePath,
                Arguments = args,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                RedirectStandardInput = true,
                CreateNoWindow = true
            };

            using var authProcess = new Process { StartInfo = startInfo };
            var output = new StringBuilder();

            authProcess.OutputDataReceived += (s, e) =>
            {
                if (e.Data != null)
                {
                    output.AppendLine(e.Data);
                    AppendLog($"[Auth] {e.Data}");
                }
            };

            authProcess.ErrorDataReceived += (s, e) =>
            {
                if (e.Data != null)
                {
                    output.AppendLine(e.Data);
                    AppendLog($"[Auth] {e.Data}");
                }
            };

            authProcess.Start();
            authProcess.BeginOutputReadLine();
            authProcess.BeginErrorReadLine();

            // Service-specific handling
            if (command == AuthCommand.GeminiLogin)
            {
                // Auto-send newline after 3 seconds to accept default project
                await Task.Delay(3000);
                if (!authProcess.HasExited)
                {
                    await authProcess.StandardInput.WriteLineAsync();
                }
            }
            else if (command == AuthCommand.CodexLogin)
            {
                // Auto-send newline after 12 seconds
                await Task.Delay(12000);
                if (!authProcess.HasExited)
                {
                    await authProcess.StandardInput.WriteLineAsync();
                }
            }
            else if (command is QwenLoginCommand qwen)
            {
                // Auto-send email after 10 seconds
                await Task.Delay(10000);
                if (!authProcess.HasExited)
                {
                    await authProcess.StandardInput.WriteLineAsync(qwen.Email);
                }
            }

            // Wait for process to complete (with timeout)
            var completed = await WaitForExitAsync(authProcess, 120000);

            if (!completed)
            {
                authProcess.Kill();
                return false;
            }

            return authProcess.ExitCode == 0;
        }
        catch (Exception ex)
        {
            AppendLog($"Auth error: {ex.Message}");
            return false;
        }
    }

    private async Task KillOrphanedProcessesAsync()
    {
        try
        {
            var processes = Process.GetProcessesByName("cli-proxy-api-plus");
            foreach (var p in processes)
            {
                try
                {
                    AppendLog($"Killing orphaned process {p.Id}");
                    p.Kill(entireProcessTree: true);
                    await WaitForExitAsync(p, 1000);
                }
                catch { }
                finally
                {
                    p.Dispose();
                }
            }
        }
        catch { }
    }

    private string GetExecutablePath()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;
        return Path.Combine(baseDir, "Resources", "cli-proxy-api-plus.exe");
    }

    private string GetConfigPath()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;
        return Path.Combine(baseDir, "Resources", "config.yaml");
    }

    private async Task ReadOutputAsync(StreamReader reader, CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync();
                if (line == null) break;
                if (cancellationToken.IsCancellationRequested) break;
                AppendLog(line);
            }
        }
        catch (OperationCanceledException) { }
        catch { }
    }

    private void AppendLog(string message)
    {
        var timestamped = $"[{DateTime.Now:HH:mm:ss}] {message}";
        _logBuffer.Add(timestamped);
        OnLogUpdate?.Invoke(timestamped);
    }

    private void OnProcessExited(object? sender, EventArgs e)
    {
        if (_isRunning)
        {
            AppendLog("Process exited unexpectedly");
            IsRunning = false;
        }
    }

    private static async Task<bool> WaitForExitAsync(Process process, int timeoutMs)
    {
        using var cts = new CancellationTokenSource(timeoutMs);
        try
        {
            await process.WaitForExitAsync(cts.Token);
            return true;
        }
        catch (OperationCanceledException)
        {
            return false;
        }
    }

    private void CleanupProcess()
    {
        lock (_lock)
        {
            _outputCancellation?.Cancel();
            _outputCancellation?.Dispose();
            _outputCancellation = null;

            if (_process != null)
            {
                _process.Exited -= OnProcessExited;
                _process.Dispose();
                _process = null;
            }
        }
    }

    protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}

/// <summary>
/// Authentication command types matching macOS AuthCommand enum.
/// </summary>
public class AuthCommand
{
    public static readonly AuthCommand ClaudeLogin = new();
    public static readonly AuthCommand CodexLogin = new();
    public static readonly AuthCommand CopilotLogin = new();
    public static readonly AuthCommand GeminiLogin = new();
    public static readonly AuthCommand AntigravityLogin = new();

    public static AuthCommand QwenLogin(string email) => new QwenLoginCommand(email);

    protected AuthCommand() { }
}

public sealed class QwenLoginCommand : AuthCommand
{
    public string Email { get; }
    public QwenLoginCommand(string email) => Email = email;
}

/// <summary>
/// Simple circular buffer for log storage.
/// </summary>
internal class RingBuffer<T>
{
    private readonly T[] _buffer;
    private readonly object _lock = new();
    private int _start;
    private int _count;

    public RingBuffer(int capacity)
    {
        _buffer = new T[capacity];
    }

    public void Add(T item)
    {
        lock (_lock)
        {
            var index = (_start + _count) % _buffer.Length;
            _buffer[index] = item;

            if (_count < _buffer.Length)
            {
                _count++;
            }
            else
            {
                _start = (_start + 1) % _buffer.Length;
            }
        }
    }

    public List<T> ToList()
    {
        lock (_lock)
        {
            var result = new List<T>(_count);
            for (int i = 0; i < _count; i++)
            {
                result.Add(_buffer[(_start + i) % _buffer.Length]);
            }
            return result;
        }
    }
}
