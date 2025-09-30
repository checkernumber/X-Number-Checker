// Browser-compatible JavaScript for X/Twitter account checking

class TwitterChecker {
    constructor(apiKey) {
        this.apiKey = apiKey;
        this.baseUrl = 'https://api.checknumber.ai/x/api/simple/tasks';
    }

    // Upload file for checking
    async uploadFile(file) {
        const formData = new FormData();
        formData.append('file', file);

        try {
            const response = await fetch(this.baseUrl, {
                method: 'POST',
                headers: {
                    'X-API-Key': this.apiKey
                },
                body: formData
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error uploading file:', error);
            throw error;
        }
    }

    // Check task status
    async checkTaskStatus(taskId, userId) {
        const url = `${this.baseUrl}/${taskId}?user_id=${userId}`;

        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'X-API-Key': this.apiKey
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error checking task status:', error);
            throw error;
        }
    }

    // Poll task status until completion
    async pollTaskStatus(taskId, userId, interval = 5000) {
        return new Promise((resolve, reject) => {
            const poll = async () => {
                try {
                    const response = await this.checkTaskStatus(taskId, userId);
                    console.log(`Status: ${response.status}, Success: ${response.success}, Total: ${response.total}`);

                    if (response.status === 'exported') {
                        console.log(`Results available at: ${response.result_url}`);
                        resolve(response);
                    } else if (response.status === 'failed') {
                        reject(new Error('Task failed'));
                    } else {
                        setTimeout(poll, interval);
                    }
                } catch (error) {
                    reject(error);
                }
            };
            poll();
        });
    }
}

// Usage Example
async function main() {
    const apiKey = 'YOUR_API_KEY';
    const checker = new TwitterChecker(apiKey);

    try {
        // For file input from HTML form
        const fileInput = document.getElementById('file-input'); // Assuming you have a file input
        const file = fileInput.files[0];
        
        if (!file) {
            console.error('Please select a file');
            return;
        }

        // Upload file
        console.log('Uploading file...');
        const uploadResponse = await checker.uploadFile(file);
        console.log('Task ID:', uploadResponse.task_id);
        console.log('Initial Status:', uploadResponse.status);

        // Poll for completion
        console.log('Polling for task completion...');
        const finalResponse = await checker.pollTaskStatus(uploadResponse.task_id, 'test');
        
        console.log('Task completed successfully!');
        console.log('Final response:', finalResponse);

    } catch (error) {
        console.error('Error:', error.message);
    }
}

// Alternative: Create file from text content
function createFileFromText(content, filename = 'input.txt') {
    const blob = new Blob([content], { type: 'text/plain' });
    return new File([blob], filename, { type: 'text/plain' });
}

// Example usage with text content
async function checkNumbersFromText() {
    const apiKey = 'YOUR_API_KEY';
    const checker = new TwitterChecker(apiKey);

    // Example phone numbers
    const phoneNumbers = `+1234567890
+9876543210
+1122334455`;

    try {
        const file = createFileFromText(phoneNumbers);
        
        const uploadResponse = await checker.uploadFile(file);
        console.log('Upload response:', uploadResponse);
        
        const finalResponse = await checker.pollTaskStatus(uploadResponse.task_id, 'test');
        console.log('Final response:', finalResponse);
        
    } catch (error) {
        console.error('Error:', error);
    }
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { TwitterChecker, createFileFromText };
}
