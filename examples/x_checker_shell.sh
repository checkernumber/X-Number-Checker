#!/bin/bash

# X/Twitter Account Checker Shell Script
# Usage: ./x_twitter_shell.sh [API_KEY] [INPUT_FILE] [USER_ID]

set -e  # Exit on any error

# Configuration
API_KEY="${1:-YOUR_API_KEY}"
INPUT_FILE="${2:-input.txt}"
USER_ID="${3:-test}"
BASE_URL="https://api.checknumber.ai/x/api/simple/tasks"
POLL_INTERVAL=5  # seconds
MAX_POLLS=720    # 1 hour maximum (720 * 5 seconds)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed. Please install curl."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. JSON parsing will be limited."
    fi
}

# Function to create sample input file
create_sample_input() {
    local file="${1:-input.txt}"
    cat > "$file" << EOF
+1234567890
+9876543210
+1122334455
+5556667777
+9998887777
EOF
    print_info "Created sample input file: $file"
}

# Function to upload file
upload_file() {
    local file="$1"
    local api_key="$2"
    
    if [[ ! -f "$file" ]]; then
        print_error "Input file not found: $file"
        return 1
    fi
    
    print_info "Uploading file: $file"
    
    local response
    response=$(curl --silent --show-error --fail \
        --location "$BASE_URL" \
        --header "X-API-Key: $api_key" \
        --form "file=@$file" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to upload file"
        return 1
    fi
    
    echo "$response"
}

# Function to check task status
check_task_status() {
    local task_id="$1"
    local user_id="$2"
    local api_key="$3"
    
    local url="${BASE_URL}/${task_id}?user_id=${user_id}"
    
    local response
    response=$(curl --silent --show-error --fail \
        --location "$url" \
        --header "X-API-Key: $api_key" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to check task status"
        return 1
    fi
    
    echo "$response"
}

# Function to extract JSON field (fallback if jq is not available)
extract_json_field() {
    local json="$1"
    local field="$2"
    
    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".$field // empty"
    else
        # Simple grep-based extraction (less reliable but works without jq)
        echo "$json" | grep -o "\"$field\"[^,}]*" | cut -d'"' -f4 | head -1
    fi
}

# Function to poll task status until completion
poll_task_status() {
    local task_id="$1"
    local user_id="$2"
    local api_key="$3"
    local polls=0
    
    print_info "Polling task status (Task ID: $task_id)"
    
    while [[ $polls -lt $MAX_POLLS ]]; do
        local response
        response=$(check_task_status "$task_id" "$user_id" "$api_key")
        
        if [[ $? -ne 0 ]]; then
            print_error "Failed to check task status"
            return 1
        fi
        
        local status
        local success
        local total
        local result_url
        
        status=$(extract_json_field "$response" "status")
        success=$(extract_json_field "$response" "success")
        total=$(extract_json_field "$response" "total")
        result_url=$(extract_json_field "$response" "result_url")
        
        print_info "Status: $status, Success: $success, Total: $total"
        
        case "$status" in
            "exported")
                print_success "Task completed successfully!"
                if [[ -n "$result_url" && "$result_url" != "null" ]]; then
                    print_success "Results available at: $result_url"
                    return 0
                else
                    print_warning "Task completed but no result URL provided"
                    return 0
                fi
                ;;
            "failed")
                print_error "Task failed"
                return 1
                ;;
            "pending"|"processing")
                print_info "Task in progress... (poll $((polls + 1))/$MAX_POLLS)"
                ;;
            *)
                print_warning "Unknown status: $status"
                ;;
        esac
        
        sleep $POLL_INTERVAL
        ((polls++))
    done
    
    print_error "Maximum polling attempts reached. Task may still be processing."
    return 1
}

# Function to download results
download_results() {
    local url="$1"
    local output_file="${2:-twitter_results.xlsx}"
    
    print_info "Downloading results to: $output_file"
    
    if curl --silent --show-error --fail \
        --location "$url" \
        --output "$output_file"; then
        print_success "Results downloaded successfully: $output_file"
        return 0
    else
        print_error "Failed to download results"
        return 1
    fi
}

# Main function
main() {
    print_info "X/Twitter Account Checker"
    print_info "=========================="
    
    # Check dependencies
    check_dependencies
    
    # Validate inputs
    if [[ "$API_KEY" == "YOUR_API_KEY" ]]; then
        print_error "Please provide a valid API key"
        print_info "Usage: $0 <API_KEY> [INPUT_FILE] [USER_ID]"
        exit 1
    fi
    
    # Create sample input file if it doesn't exist
    if [[ ! -f "$INPUT_FILE" ]]; then
        print_warning "Input file not found: $INPUT_FILE"
        read -p "Create sample input file? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_sample_input "$INPUT_FILE"
        else
            print_error "Input file is required"
            exit 1
        fi
    fi
    
    # Upload file
    local upload_response
    upload_response=$(upload_file "$INPUT_FILE" "$API_KEY")
    
    if [[ $? -ne 0 ]]; then
        print_error "Upload failed"
        exit 1
    fi
    
    # Extract task ID
    local task_id
    task_id=$(extract_json_field "$upload_response" "task_id")
    
    if [[ -z "$task_id" || "$task_id" == "null" ]]; then
        print_error "Failed to extract task ID from response"
        print_error "Response: $upload_response"
        exit 1
    fi
    
    print_success "File uploaded successfully!"
    print_info "Task ID: $task_id"
    
    # Poll for completion
    if poll_task_status "$task_id" "$USER_ID" "$API_KEY"; then
        print_success "Process completed successfully!"
        
        # Get final status to extract result URL
        local final_response
        final_response=$(check_task_status "$task_id" "$USER_ID" "$API_KEY")
        local result_url
        result_url=$(extract_json_field "$final_response" "result_url")
        
        if [[ -n "$result_url" && "$result_url" != "null" ]]; then
            read -p "Download results? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                download_results "$result_url"
            fi
        fi
    else
        print_error "Task failed or timed out"
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
X/Twitter Account Checker Shell Script

Usage: $0 [API_KEY] [INPUT_FILE] [USER_ID]

Arguments:
    API_KEY     Your API key for the service
    INPUT_FILE  Path to input file containing phone numbers (default: input.txt)
    USER_ID     User ID for the API (default: test)

Options:
    -h, --help  Show this help message

Examples:
    $0 your_api_key_here input.txt test
    $0 your_api_key_here numbers.txt
    $0 your_api_key_here

Environment Variables:
    TWITTER_API_KEY  API key (alternative to first argument)

The input file should contain one phone number per line.
EOF
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        if [[ -n "${TWITTER_API_KEY:-}" ]]; then
            API_KEY="$TWITTER_API_KEY"
        fi
        ;;
esac

# Run main function
main "$@"
