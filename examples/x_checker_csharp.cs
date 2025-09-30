using System;
using System.Net.Http;
using System.IO;
using System.Threading.Tasks;
using Newtonsoft.Json;

public class TwitterChecker
{
    private readonly HttpClient _client;
    private readonly string _apiKey;

    public TwitterChecker(string apiKey)
    {
        _apiKey = apiKey;
        _client = new HttpClient();
        _client.DefaultRequestHeaders.Add("X-API-Key", _apiKey);
    }

    // Upload file for checking
    public async Task<TwitterTaskResponse> UploadFileAsync(string filePath)
    {
        var url = "https://api.checknumber.ai/x/api/simple/tasks";
        
        using var form = new MultipartFormDataContent();
        using var fileStream = File.OpenRead(filePath);
        using var streamContent = new StreamContent(fileStream);
        
        form.Add(streamContent, "file", Path.GetFileName(filePath));

        using var response = await _client.PostAsync(url, form);
        response.EnsureSuccessStatusCode();
        
        var jsonResponse = await response.Content.ReadAsStringAsync();
        return JsonConvert.DeserializeObject<TwitterTaskResponse>(jsonResponse);
    }

    // Check task status
    public async Task<TwitterTaskResponse> CheckTaskStatusAsync(string taskId, string userId)
    {
        var url = $"https://api.checknumber.ai/x/api/simple/tasks/{taskId}?user_id={userId}";
        
        using var response = await _client.GetAsync(url);
        response.EnsureSuccessStatusCode();
        
        var jsonResponse = await response.Content.ReadAsStringAsync();
        return JsonConvert.DeserializeObject<TwitterTaskResponse>(jsonResponse);
    }

    public void Dispose()
    {
        _client?.Dispose();
    }
}

public class TwitterTaskResponse
{
    [JsonProperty("created_at")]
    public DateTime CreatedAt { get; set; }
    
    [JsonProperty("updated_at")]
    public DateTime UpdatedAt { get; set; }
    
    [JsonProperty("task_id")]
    public string TaskId { get; set; }
    
    [JsonProperty("user_id")]
    public string UserId { get; set; }
    
    [JsonProperty("status")]
    public string Status { get; set; }
    
    [JsonProperty("total")]
    public int Total { get; set; }
    
    [JsonProperty("success")]
    public int Success { get; set; }
    
    [JsonProperty("failure")]
    public int Failure { get; set; }
    
    [JsonProperty("result_url")]
    public string ResultUrl { get; set; }
}

// Usage Example
class Program
{
    static async Task Main(string[] args)
    {
        var checker = new TwitterChecker("YOUR_API_KEY");
        
        try
        {
            // Upload file
            var uploadResponse = await checker.UploadFileAsync("input.txt");
            Console.WriteLine($"Task ID: {uploadResponse.TaskId}");
            Console.WriteLine($"Status: {uploadResponse.Status}");
            
            // Check status periodically
            TwitterTaskResponse statusResponse;
            do
            {
                await Task.Delay(5000); // Wait 5 seconds
                statusResponse = await checker.CheckTaskStatusAsync(uploadResponse.TaskId, "test");
                Console.WriteLine($"Status: {statusResponse.Status}, Success: {statusResponse.Success}, Total: {statusResponse.Total}");
            }
            while (statusResponse.Status != "exported" && statusResponse.Status != "failed");
            
            if (statusResponse.Status == "exported")
            {
                Console.WriteLine($"Results available at: {statusResponse.ResultUrl}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
        finally
        {
            checker.Dispose();
        }
    }
}
