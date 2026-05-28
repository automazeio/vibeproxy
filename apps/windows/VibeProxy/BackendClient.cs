using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using VibeProxyCore;

namespace VibeProxy;

/// <summary>
/// HTTP client for communicating with bifrost-enhanced backend
/// </summary>
public class BackendClient
{
    private readonly BackendConfig _config;
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    
    public BackendClient(BackendConfig config)
    {
        _config = config;
        _baseUrl = $"{config.Url}:{config.Port}";
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(_baseUrl),
            Timeout = TimeSpan.FromSeconds(30)
        };
        
        if (!string.IsNullOrEmpty(config.ApiKey))
        {
            _httpClient.DefaultRequestHeaders.Authorization = 
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", config.ApiKey);
        }
    }
    
    /// <summary>
    /// Check if the backend server is healthy
    /// </summary>
    public async Task<bool> HealthCheckAsync()
    {
        try
        {
            var response = await _httpClient.GetAsync("/health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
    
    /// <summary>
    /// Get backend status
    /// </summary>
    public async Task<JsonElement> GetStatusAsync()
    {
        var response = await _httpClient.GetAsync("/api/v1/status");
        response.EnsureSuccessStatusCode();
        
        var json = await response.Content.ReadAsStringAsync();
        return JsonDocument.Parse(json).RootElement;
    }
    
    /// <summary>
    /// Make a generic API request
    /// </summary>
    public async Task<JsonElement> RequestAsync(string path, string method = "GET", object? body = null)
    {
        HttpRequestMessage request = new(new HttpMethod(method), path);
        
        if (body != null)
        {
            var json = JsonSerializer.Serialize(body);
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
        }
        
        var response = await _httpClient.SendAsync(request);
        response.EnsureSuccessStatusCode();
        
        var responseJson = await response.Content.ReadAsStringAsync();
        return JsonDocument.Parse(responseJson).RootElement;
    }
}
