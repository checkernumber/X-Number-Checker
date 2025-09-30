import java.io.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;

public class TwitterChecker {
    private final HttpClient httpClient;
    private final String apiKey;
    private final ObjectMapper objectMapper;

    public TwitterChecker(String apiKey) {
        this.apiKey = apiKey;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(30))
                .build();
        this.objectMapper = new ObjectMapper();
    }

    // Upload file for checking
    public TwitterTaskResponse uploadFile(String filePath) throws Exception {
        String url = "https://api.checknumber.ai/x/api/simple/tasks";
        
        Path path = Path.of(filePath);
        String boundary = "----WebKitFormBoundary" + System.currentTimeMillis();
        
        StringBuilder body = new StringBuilder();
        body.append("--").append(boundary).append("\r\n");
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"")
            .append(path.getFileName().toString()).append("\"\r\n");
        body.append("Content-Type: text/plain\r\n\r\n");
        body.append(Files.readString(path));
        body.append("\r\n--").append(boundary).append("--\r\n");

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("X-API-Key", apiKey)
                .header("Content-Type", "multipart/form-data; boundary=" + boundary)
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();

        HttpResponse<String> response = httpClient.send(request, 
                HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new RuntimeException("HTTP error! status: " + response.statusCode());
        }

        return objectMapper.readValue(response.body(), TwitterTaskResponse.class);
    }

    // Check task status
    public TwitterTaskResponse checkTaskStatus(String taskId, String userId) throws Exception {
        String url = String.format("https://api.checknumber.ai/x/api/simple/tasks/%s?user_id=%s", 
                taskId, userId);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("X-API-Key", apiKey)
                .GET()
                .build();

        HttpResponse<String> response = httpClient.send(request, 
                HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new RuntimeException("HTTP error! status: " + response.statusCode());
        }

        return objectMapper.readValue(response.body(), TwitterTaskResponse.class);
    }

    public static class TwitterTaskResponse {
        @JsonProperty("created_at")
        public String createdAt;
        
        @JsonProperty("updated_at")
        public String updatedAt;
        
        @JsonProperty("task_id")
        public String taskId;
        
        @JsonProperty("user_id")
        public String userId;
        
        @JsonProperty("status")
        public String status;
        
        @JsonProperty("total")
        public int total;
        
        @JsonProperty("success")
        public int success;
        
        @JsonProperty("failure")
        public int failure;
        
        @JsonProperty("result_url")
        public String resultUrl;
    }

    public static void main(String[] args) {
        TwitterChecker checker = new TwitterChecker("YOUR_API_KEY");
        
        try {
            // Upload file
            TwitterTaskResponse uploadResponse = checker.uploadFile("input.txt");
            System.out.println("Task ID: " + uploadResponse.taskId);
            System.out.println("Status: " + uploadResponse.status);
            
            // Check status periodically
            TwitterTaskResponse statusResponse;
            do {
                TimeUnit.SECONDS.sleep(5); // Wait 5 seconds
                statusResponse = checker.checkTaskStatus(uploadResponse.taskId, "test");
                System.out.printf("Status: %s, Success: %d, Total: %d%n", 
                    statusResponse.status, statusResponse.success, statusResponse.total);
            }
            while (!statusResponse.status.equals("exported") && 
                   !statusResponse.status.equals("failed"));
            
            if (statusResponse.status.equals("exported")) {
                System.out.println("Results available at: " + statusResponse.resultUrl);
            } else if (statusResponse.status.equals("failed")) {
                System.out.println("Task failed");
            }
            
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
