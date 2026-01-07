using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace VibeProxy.Services;

/// <summary>
/// HTTP proxy that intercepts requests and adds extended thinking parameters
/// for Claude models with "-thinking-NUMBER" suffix in the model name.
/// Equivalent to ThinkingProxy.swift in the macOS version.
/// </summary>
public class ThinkingProxy : IDisposable
{
    private const int ProxyPort = 8317;
    private const int TargetPort = 8318;
    private const string TargetHost = "127.0.0.1";
    private const int MaxBudgetTokens = 32000;
    private const string BetaHeader = "interleaved-thinking-2025-05-14";

    // Pattern: model-name-thinking-NUMBER or model-name-thinking
    private static readonly Regex ThinkingPattern = new(@"-thinking(?:-(\d+))?$", RegexOptions.Compiled);
    private static readonly Regex GeminiClaudePattern = new(@"^gemini-claude-.*-thinking", RegexOptions.Compiled);

    private TcpListener? _listener;
    private CancellationTokenSource? _cts;
    private bool _isRunning;
    private readonly object _lock = new();

    public bool IsRunning => _isRunning;
    public int Port => ProxyPort;

    public event Action<string>? OnLog;

    /// <summary>
    /// Starts the thinking proxy listener on port 8317.
    /// </summary>
    public Task<bool> StartAsync()
    {
        if (_isRunning) return Task.FromResult(true);

        try
        {
            _cts = new CancellationTokenSource();
            _listener = new TcpListener(IPAddress.Loopback, ProxyPort);
            _listener.Start();
            _isRunning = true;

            Log($"ThinkingProxy started on port {ProxyPort}");

            // Start accepting connections in background
            _ = AcceptConnectionsAsync(_cts.Token);

            return Task.FromResult(true);
        }
        catch (Exception ex)
        {
            Log($"Failed to start ThinkingProxy: {ex.Message}");
            return Task.FromResult(false);
        }
    }

    /// <summary>
    /// Stops the thinking proxy.
    /// </summary>
    public void Stop()
    {
        lock (_lock)
        {
            if (!_isRunning) return;

            _cts?.Cancel();
            _listener?.Stop();
            _isRunning = false;
            Log("ThinkingProxy stopped");
        }
    }

    private async Task AcceptConnectionsAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested && _listener != null)
        {
            try
            {
                var client = await _listener.AcceptTcpClientAsync();
                _ = HandleConnectionAsync(client, cancellationToken);
            }
            catch (SocketException) when (cancellationToken.IsCancellationRequested)
            {
                // Normal shutdown
                break;
            }
            catch (ObjectDisposedException)
            {
                // Listener was disposed
                break;
            }
            catch (Exception ex)
            {
                Log($"Accept error: {ex.Message}");
            }
        }
    }

    private async Task HandleConnectionAsync(TcpClient client, CancellationToken cancellationToken)
    {
        using (client)
        {
            try
            {
                client.ReceiveTimeout = 30000;
                client.SendTimeout = 30000;

                using var stream = client.GetStream();

                // Read the HTTP request
                var request = await ReadHttpRequestAsync(stream, cancellationToken);
                if (request == null)
                {
                    await SendErrorResponseAsync(stream, 400, "Bad Request");
                    return;
                }

                // Process and forward the request
                await ProcessRequestAsync(client, stream, request, cancellationToken);
            }
            catch (Exception ex)
            {
                Log($"Connection error: {ex.Message}");
            }
        }
    }

    private async Task<HttpRequest?> ReadHttpRequestAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        var buffer = new byte[65536];
        var requestData = new MemoryStream();
        int totalRead = 0;
        int headerEndIndex = -1;
        int contentLength = 0;

        // Read until we have complete headers
        while (headerEndIndex < 0)
        {
            var bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, cancellationToken);
            if (bytesRead == 0) return null;

            requestData.Write(buffer, 0, bytesRead);
            totalRead += bytesRead;

            // Check for header end
            var data = requestData.ToArray();
            headerEndIndex = FindHeaderEnd(data);
        }

        // Parse headers to get Content-Length
        var headerBytes = requestData.ToArray().Take(headerEndIndex).ToArray();
        var headerText = Encoding.UTF8.GetString(headerBytes);
        var request = ParseHttpRequest(headerText);
        if (request == null) return null;

        // Get Content-Length
        if (request.Headers.TryGetValue("content-length", out var contentLengthStr))
        {
            int.TryParse(contentLengthStr, out contentLength);
        }

        // Calculate how much body we already have
        var bodyStart = headerEndIndex + 4; // Skip \r\n\r\n
        var bodyBytesRead = (int)requestData.Length - bodyStart;
        var remainingBody = contentLength - bodyBytesRead;

        // Read remaining body if needed
        while (remainingBody > 0)
        {
            var bytesRead = await stream.ReadAsync(buffer, 0, Math.Min(buffer.Length, remainingBody), cancellationToken);
            if (bytesRead == 0) break;
            requestData.Write(buffer, 0, bytesRead);
            remainingBody -= bytesRead;
        }

        // Extract body
        var allData = requestData.ToArray();
        if (bodyStart < allData.Length)
        {
            request.Body = allData.Skip(bodyStart).Take(contentLength).ToArray();
        }

        return request;
    }

    private static int FindHeaderEnd(byte[] data)
    {
        for (int i = 0; i < data.Length - 3; i++)
        {
            if (data[i] == '\r' && data[i + 1] == '\n' && data[i + 2] == '\r' && data[i + 3] == '\n')
            {
                return i;
            }
        }
        return -1;
    }

    private static HttpRequest? ParseHttpRequest(string headerText)
    {
        var lines = headerText.Split(new[] { "\r\n" }, StringSplitOptions.None);
        if (lines.Length == 0) return null;

        var requestLine = lines[0].Split(' ');
        if (requestLine.Length < 3) return null;

        var request = new HttpRequest
        {
            Method = requestLine[0],
            Path = requestLine[1],
            Version = requestLine[2]
        };

        for (int i = 1; i < lines.Length; i++)
        {
            var colonIndex = lines[i].IndexOf(':');
            if (colonIndex > 0)
            {
                var key = lines[i].Substring(0, colonIndex).Trim().ToLowerInvariant();
                var value = lines[i].Substring(colonIndex + 1).Trim();
                request.Headers[key] = value;
                request.OriginalHeaders.Add((lines[i].Substring(0, colonIndex).Trim(), value));
            }
        }

        return request;
    }

    private async Task ProcessRequestAsync(TcpClient client, NetworkStream clientStream, HttpRequest request, CancellationToken cancellationToken)
    {
        var path = request.Path;
        var addBetaHeader = false;

        // Check for path rewrites (Amp management API)
        if (path.StartsWith("/auth/cli-login"))
        {
            path = "/api" + path;
        }
        else if (path.StartsWith("/provider/"))
        {
            path = "/api" + path;
        }

        // Process JSON body for thinking parameters
        if (request.Body != null && request.Body.Length > 0 &&
            request.Headers.TryGetValue("content-type", out var contentType) &&
            contentType.Contains("application/json"))
        {
            try
            {
                var bodyText = Encoding.UTF8.GetString(request.Body);
                var (modifiedBody, wasModified, needsBeta) = ProcessThinkingParameter(bodyText);

                if (wasModified)
                {
                    request.Body = Encoding.UTF8.GetBytes(modifiedBody);
                    addBetaHeader = needsBeta;
                }
            }
            catch (Exception ex)
            {
                Log($"JSON processing error: {ex.Message}");
            }
        }

        // Forward to backend
        await ForwardToBackendAsync(client, clientStream, request, path, addBetaHeader, cancellationToken);
    }

    /// <summary>
    /// Processes the thinking parameter in the model name.
    /// Returns (modifiedJson, wasModified, needsBetaHeader)
    /// </summary>
    private (string, bool, bool) ProcessThinkingParameter(string jsonBody)
    {
        try
        {
            var jsonNode = JsonNode.Parse(jsonBody);
            if (jsonNode == null) return (jsonBody, false, false);

            var modelNode = jsonNode["model"];
            if (modelNode == null) return (jsonBody, false, false);

            var model = modelNode.GetValue<string>();
            if (string.IsNullOrEmpty(model)) return (jsonBody, false, false);

            // Check for thinking pattern
            var match = ThinkingPattern.Match(model);
            if (!match.Success) return (jsonBody, false, false);

            // Check if it's a Gemini-Claude special case
            var isGeminiClaude = GeminiClaudePattern.IsMatch(model);

            // Extract budget tokens
            int? budgetTokens = null;
            if (match.Groups[1].Success && int.TryParse(match.Groups[1].Value, out var parsed))
            {
                budgetTokens = Math.Min(parsed, MaxBudgetTokens);
            }

            // Strip the thinking suffix from model name (unless it's gemini-claude pattern)
            string cleanModel;
            if (isGeminiClaude)
            {
                // Keep "-thinking" for gemini-claude models, just strip the number
                cleanModel = model;
                if (budgetTokens.HasValue)
                {
                    cleanModel = model.Substring(0, model.LastIndexOf($"-{budgetTokens}"));
                }
            }
            else
            {
                cleanModel = ThinkingPattern.Replace(model, "");
            }

            jsonNode["model"] = cleanModel;

            // Add thinking object if we have a budget
            if (budgetTokens.HasValue)
            {
                var thinkingObj = new JsonObject
                {
                    ["type"] = "enabled",
                    ["budget_tokens"] = budgetTokens.Value
                };
                jsonNode["thinking"] = thinkingObj;

                // Calculate headroom (10% of budget, min 1024)
                var headroom = Math.Max(budgetTokens.Value / 10, 1024);
                var minMaxTokens = budgetTokens.Value + headroom;

                // Ensure max_tokens is sufficient
                var maxTokensNode = jsonNode["max_tokens"];
                var maxOutputTokensNode = jsonNode["max_output_tokens"];

                if (maxTokensNode != null)
                {
                    var currentMax = maxTokensNode.GetValue<int>();
                    if (currentMax < minMaxTokens)
                    {
                        jsonNode["max_tokens"] = minMaxTokens;
                    }
                }
                else if (maxOutputTokensNode != null)
                {
                    var currentMax = maxOutputTokensNode.GetValue<int>();
                    if (currentMax < minMaxTokens)
                    {
                        jsonNode["max_output_tokens"] = minMaxTokens;
                    }
                }
                else
                {
                    // Add max_tokens if neither exists
                    jsonNode["max_tokens"] = minMaxTokens;
                }

                Log($"Added thinking: budget={budgetTokens}, model={cleanModel}");
            }
            else
            {
                // Enable thinking without specific budget
                var thinkingObj = new JsonObject
                {
                    ["type"] = "enabled"
                };
                jsonNode["thinking"] = thinkingObj;
                Log($"Enabled thinking for model={cleanModel}");
            }

            var options = new JsonSerializerOptions { WriteIndented = false };
            return (jsonNode.ToJsonString(options), true, true);
        }
        catch (Exception ex)
        {
            Log($"Thinking parameter error: {ex.Message}");
            return (jsonBody, false, false);
        }
    }

    private async Task ForwardToBackendAsync(TcpClient client, NetworkStream clientStream, HttpRequest request,
        string path, bool addBetaHeader, CancellationToken cancellationToken)
    {
        try
        {
            using var backendClient = new TcpClient();

            // Add connection timeout (5 seconds to connect to localhost backend)
            using var connectCts = new CancellationTokenSource(5000);
            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(connectCts.Token, cancellationToken);
            await backendClient.ConnectAsync(TargetHost, TargetPort, linkedCts.Token);

            // Set socket timeouts for backend connection (matching client timeouts)
            backendClient.ReceiveTimeout = 30000;
            backendClient.SendTimeout = 30000;

            using var backendStream = backendClient.GetStream();

            // Build the request to send to backend
            var requestBuilder = new StringBuilder();
            requestBuilder.Append($"{request.Method} {path} {request.Version}\r\n");

            // Add headers (excluding ones we override)
            foreach (var (key, value) in request.OriginalHeaders)
            {
                var lowerKey = key.ToLowerInvariant();

                // Skip headers we override
                if (lowerKey == "connection" || lowerKey == "transfer-encoding")
                {
                    continue;
                }

                // Update Content-Length if body was modified
                if (lowerKey == "content-length" && request.Body != null)
                {
                    requestBuilder.Append($"Content-Length: {request.Body.Length}\r\n");
                }
                // Update Host header
                else if (lowerKey == "host")
                {
                    requestBuilder.Append($"Host: {TargetHost}:{TargetPort}\r\n");
                }
                // Handle anthropic-beta header
                else if (lowerKey == "anthropic-beta" && addBetaHeader)
                {
                    // Merge beta headers
                    if (!value.Contains(BetaHeader))
                    {
                        requestBuilder.Append($"anthropic-beta: {value},{BetaHeader}\r\n");
                    }
                    else
                    {
                        requestBuilder.Append($"{key}: {value}\r\n");
                    }
                    addBetaHeader = false; // Already added
                }
                else
                {
                    requestBuilder.Append($"{key}: {value}\r\n");
                }
            }

            // Add beta header if needed and not already added
            if (addBetaHeader)
            {
                requestBuilder.Append($"anthropic-beta: {BetaHeader}\r\n");
            }

            // CRITICAL: Add Connection: close to ensure backend closes connection after response
            // Without this, HTTP/1.1 keep-alive causes StreamResponseAsync to hang waiting for more data
            requestBuilder.Append("Connection: close\r\n");

            requestBuilder.Append("\r\n");

            // Send headers
            var headerBytes = Encoding.UTF8.GetBytes(requestBuilder.ToString());
            await backendStream.WriteAsync(headerBytes, 0, headerBytes.Length, cancellationToken);

            // Send body
            if (request.Body != null && request.Body.Length > 0)
            {
                await backendStream.WriteAsync(request.Body, 0, request.Body.Length, cancellationToken);
            }

            await backendStream.FlushAsync(cancellationToken);

            // Stream response back to client
            await StreamResponseAsync(backendStream, clientStream, client, cancellationToken);
        }
        catch (Exception ex)
        {
            Log($"Backend forward error: {ex.Message}");
            await SendErrorResponseAsync(clientStream, 502, "Bad Gateway");
        }
    }

    private async Task StreamResponseAsync(NetworkStream source, NetworkStream destination,
        TcpClient destinationClient, CancellationToken cancellationToken)
    {
        // Use 64KB buffer to match Swift implementation (was 8KB - too small for large SSE chunks)
        var buffer = new byte[65536];
        try
        {
            int bytesRead;
            while ((bytesRead = await source.ReadAsync(buffer, 0, buffer.Length, cancellationToken)) > 0)
            {
                await destination.WriteAsync(buffer, 0, bytesRead, cancellationToken);
                await destination.FlushAsync(cancellationToken);
            }

            // Explicit EOF signaling - shutdown the send side to signal client we're done
            // This matches Swift's `isComplete: true` behavior
            try
            {
                destinationClient.Client.Shutdown(System.Net.Sockets.SocketShutdown.Send);
            }
            catch { }
        }
        catch (IOException)
        {
            // Connection closed by remote - this is normal for SSE streams
        }
        catch (SocketException)
        {
            // Socket error - connection likely closed
        }
        catch (Exception ex)
        {
            Log($"Stream error: {ex.Message}");
        }
    }

    private async Task SendErrorResponseAsync(NetworkStream stream, int statusCode, string message)
    {
        var response = $"HTTP/1.1 {statusCode} {message}\r\n" +
                      $"Content-Type: text/plain\r\n" +
                      $"Content-Length: {message.Length}\r\n" +
                      $"Connection: close\r\n" +
                      $"\r\n" +
                      message;

        var bytes = Encoding.UTF8.GetBytes(response);
        try
        {
            await stream.WriteAsync(bytes, 0, bytes.Length);
        }
        catch { }
    }

    private void Log(string message)
    {
        OnLog?.Invoke($"[ThinkingProxy] {message}");
    }

    public void Dispose()
    {
        Stop();
        _cts?.Dispose();
    }
}

internal class HttpRequest
{
    public string Method { get; set; } = "";
    public string Path { get; set; } = "";
    public string Version { get; set; } = "";
    public Dictionary<string, string> Headers { get; } = new(StringComparer.OrdinalIgnoreCase);
    public List<(string Key, string Value)> OriginalHeaders { get; } = new();
    public byte[]? Body { get; set; }
}
