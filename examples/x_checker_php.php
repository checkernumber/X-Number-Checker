<?php

class TwitterChecker {
    private $apiKey;
    private $baseUrl = 'https://api.checknumber.ai/x/api/simple/tasks';
    
    public function __construct($apiKey) {
        $this->apiKey = $apiKey;
    }
    
    // Upload file for checking
    public function uploadFile($filePath) {
        if (!file_exists($filePath)) {
            throw new Exception("File not found: " . $filePath);
        }
        
        $curl = curl_init();
        
        $postData = [
            'file' => new CURLFile($filePath, 'text/plain', basename($filePath))
        ];
        
        curl_setopt_array($curl, [
            CURLOPT_URL => $this->baseUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $postData,
            CURLOPT_HTTPHEADER => [
                'X-API-Key: ' . $this->apiKey
            ],
            CURLOPT_TIMEOUT => 30
        ]);
        
        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $error = curl_error($curl);
        curl_close($curl);
        
        if ($error) {
            throw new Exception("cURL error: " . $error);
        }
        
        if ($httpCode !== 200) {
            throw new Exception("HTTP error! status: " . $httpCode . ", response: " . $response);
        }
        
        $result = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("JSON decode error: " . json_last_error_msg());
        }
        
        return $result;
    }
    
    // Check task status
    public function checkTaskStatus($taskId, $userId) {
        $url = $this->baseUrl . '/' . $taskId . '?user_id=' . urlencode($userId);
        
        $curl = curl_init();
        
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'X-API-Key: ' . $this->apiKey
            ],
            CURLOPT_TIMEOUT => 30
        ]);
        
        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $error = curl_error($curl);
        curl_close($curl);
        
        if ($error) {
            throw new Exception("cURL error: " . $error);
        }
        
        if ($httpCode !== 200) {
            throw new Exception("HTTP error! status: " . $httpCode . ", response: " . $response);
        }
        
        $result = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("JSON decode error: " . json_last_error_msg());
        }
        
        return $result;
    }
    
    // Poll task status until completion
    public function pollTaskStatus($taskId, $userId, $interval = 5) {
        do {
            $response = $this->checkTaskStatus($taskId, $userId);
            echo "Status: {$response['status']}, Success: {$response['success']}, Total: {$response['total']}\n";
            
            if ($response['status'] === 'exported') {
                echo "Results available at: {$response['result_url']}\n";
                return $response;
            } elseif ($response['status'] === 'failed') {
                throw new Exception('Task failed');
            }
            
            sleep($interval);
        } while (true);
    }
    
    // Create input file from array of phone numbers
    public function createInputFile($phoneNumbers, $filePath = 'input.txt') {
        if (is_array($phoneNumbers)) {
            $content = implode("\n", $phoneNumbers);
        } else {
            $content = $phoneNumbers;
        }
        
        $result = file_put_contents($filePath, $content);
        if ($result === false) {
            throw new Exception("Failed to create file: " . $filePath);
        }
        
        return $filePath;
    }
    
    // Download results file
    public function downloadResults($resultUrl, $outputPath = 'results.xlsx') {
        $curl = curl_init();
        $file = fopen($outputPath, 'w');
        
        curl_setopt_array($curl, [
            CURLOPT_URL => $resultUrl,
            CURLOPT_FILE => $file,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT => 300
        ]);
        
        $success = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        fclose($file);
        
        if (!$success || $httpCode !== 200) {
            unlink($outputPath);
            throw new Exception("Failed to download results file");
        }
        
        return $outputPath;
    }
}

// Usage Example
try {
    $apiKey = 'YOUR_API_KEY';
    $checker = new TwitterChecker($apiKey);
    
    // Example phone numbers
    $phoneNumbers = [
        '+1234567890',
        '+9876543210',
        '+1122334455'
    ];
    
    // Create input file
    $inputFile = $checker->createInputFile($phoneNumbers, 'input.txt');
    echo "Created input file: $inputFile\n";
    
    // Upload file
    echo "Uploading file...\n";
    $uploadResponse = $checker->uploadFile($inputFile);
    echo "Task ID: {$uploadResponse['task_id']}\n";
    echo "Initial Status: {$uploadResponse['status']}\n";
    
    // Poll for completion
    echo "Polling for task completion...\n";
    $finalResponse = $checker->pollTaskStatus($uploadResponse['task_id'], 'test');
    
    echo "Task completed successfully!\n";
    
    // Download results if available
    if (!empty($finalResponse['result_url'])) {
        echo "Downloading results...\n";
        $resultsFile = $checker->downloadResults($finalResponse['result_url'], 'twitter_results.xlsx');
        echo "Results saved to: $resultsFile\n";
    }
    
    // Clean up input file
    unlink($inputFile);
    echo "Cleaned up temporary files\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}

?>
