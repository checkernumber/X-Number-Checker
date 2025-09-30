package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type TwitterTaskResponse struct {
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	TaskID    string `json:"task_id"`
	UserID    string `json:"user_id"`
	Status    string `json:"status"`
	Total     int    `json:"total"`
	Success   int    `json:"success"`
	Failure   int    `json:"failure"`
	ResultURL string `json:"result_url,omitempty"`
}

type TwitterChecker struct {
	apiKey     string
	httpClient *http.Client
}

func NewTwitterChecker(apiKey string) *TwitterChecker {
	return &TwitterChecker{
		apiKey:     apiKey,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// UploadFile uploads a file for Twitter account checking
func (tc *TwitterChecker) UploadFile(filePath string) (*TwitterTaskResponse, error) {
	url := "https://api.checknumber.ai/x/api/simple/tasks"

	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

	var requestBody bytes.Buffer
	writer := multipart.NewWriter(&requestBody)

	part, err := writer.CreateFormFile("file", filepath.Base(filePath))
	if err != nil {
		return nil, fmt.Errorf("failed to create form file: %v", err)
	}

	_, err = io.Copy(part, file)
	if err != nil {
		return nil, fmt.Errorf("failed to copy file: %v", err)
	}

	writer.Close()

	req, err := http.NewRequest("POST", url, &requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("X-API-Key", tc.apiKey)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := tc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var response TwitterTaskResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

	return &response, nil
}

// CheckTaskStatus checks the status of a task
func (tc *TwitterChecker) CheckTaskStatus(taskID, userID string) (*TwitterTaskResponse, error) {
	url := fmt.Sprintf("https://api.checknumber.ai/x/api/simple/tasks/%s?user_id=%s", taskID, userID)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("X-API-Key", tc.apiKey)

	resp, err := tc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var response TwitterTaskResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

	return &response, nil
}

func main() {
	apiKey := "YOUR_API_KEY"
	checker := NewTwitterChecker(apiKey)

	// Upload file
	uploadResponse, err := checker.UploadFile("input.txt")
	if err != nil {
		fmt.Printf("Error uploading file: %v\n", err)
		return
	}

	fmt.Printf("Task ID: %s\n", uploadResponse.TaskID)
	fmt.Printf("Status: %s\n", uploadResponse.Status)

	// Check status periodically
	for {
		time.Sleep(5 * time.Second)

		statusResponse, err := checker.CheckTaskStatus(uploadResponse.TaskID, "test")
		if err != nil {
			fmt.Printf("Error checking status: %v\n", err)
			continue
		}

		fmt.Printf("Status: %s, Success: %d, Total: %d\n", 
			statusResponse.Status, statusResponse.Success, statusResponse.Total)

		if statusResponse.Status == "exported" {
			fmt.Printf("Results available at: %s\n", statusResponse.ResultURL)
			break
		} else if statusResponse.Status == "failed" {
			fmt.Println("Task failed")
			break
		}
	}
}
