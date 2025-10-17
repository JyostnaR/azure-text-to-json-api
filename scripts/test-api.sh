#!/bin/bash

# Azure Text to JSON API Test Script
# This script tests the deployed API with various scenarios

set -e

# Configuration
RESOURCE_GROUP_NAME="rg-txt2json-dev"
USERNAME="apiuser"
PASSWORD="SecurePassword123!"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Function to check if Azure CLI is installed and user is logged in
check_azure_cli() {
    print_status "Checking Azure CLI installation and authentication..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Azure CLI is installed and user is authenticated"
}

# Function to get API endpoint
get_api_endpoint() {
    print_status "Retrieving API endpoint from deployment..."
    
    # Get the latest deployment
    DEPLOYMENT_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv)
    
    if [ -z "$DEPLOYMENT_NAME" ]; then
        print_error "No deployment found in resource group: $RESOURCE_GROUP_NAME"
        exit 1
    fi
    
    APIM_NAME=$(az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query "properties.outputs.apiManagementName.value" \
        --output tsv)
    
    if [ -z "$APIM_NAME" ]; then
        print_error "Could not retrieve APIM name from deployment outputs"
        exit 1
    fi
    
    API_ENDPOINT="https://$APIM_NAME.azure-api.net/convert/v1/convert/text-to-json"
    print_success "API endpoint: $API_ENDPOINT"
}

# Function to encode credentials
encode_credentials() {
    AUTH_STRING=$(echo -n "$USERNAME:$PASSWORD" | base64 -w 0)
    print_status "Credentials encoded for Basic Authentication"
}

# Function to create test files
create_test_files() {
    print_status "Creating test files..."
    
    # Create sample text file
    cat > test-file.txt << EOF
This is a test file for the Azure Text to JSON API.
It contains multiple lines of text with various content.
Line 3: Numbers and symbols: 123 @#$%
Line 4: This is a longer line that demonstrates how the API handles different types of content.
Line 5: Final line of the test file.
EOF

    # Create empty file
    touch empty-file.txt

    # Create large file (but under 10MB limit)
    for i in {1..1000}; do
        echo "Line $i: This is line number $i in the large test file." >> large-file.txt
    done

    print_success "Test files created successfully"
}

# Function to test successful conversion
test_successful_conversion() {
    print_status "Testing successful text to JSON conversion..."
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -H "Authorization: Basic $AUTH_STRING" \
        -F "file=@test-file.txt" \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    RESPONSE_BODY=$(echo $RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        print_success "Successful conversion test passed (Status: $HTTP_STATUS)"
        echo "Response preview:"
        echo "$RESPONSE_BODY" | jq '.success, .totalLines, .fileName' 2>/dev/null || echo "$RESPONSE_BODY" | head -c 200
    else
        print_error "Successful conversion test failed (Status: $HTTP_STATUS)"
        echo "Response: $RESPONSE_BODY"
        return 1
    fi
}

# Function to test authentication failure
test_authentication_failure() {
    print_status "Testing authentication failure scenario..."
    
    INVALID_AUTH=$(echo -n "invalid:credentials" | base64 -w 0)
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -H "Authorization: Basic $INVALID_AUTH" \
        -F "file=@test-file.txt" \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$HTTP_STATUS" -eq 401 ]; then
        print_success "Authentication failure test passed (Status: $HTTP_STATUS)"
    else
        print_error "Authentication failure test failed (Status: $HTTP_STATUS)"
        return 1
    fi
}

# Function to test missing authorization header
test_missing_auth() {
    print_status "Testing missing authorization header..."
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -F "file=@test-file.txt" \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$HTTP_STATUS" -eq 401 ]; then
        print_success "Missing authorization test passed (Status: $HTTP_STATUS)"
    else
        print_error "Missing authorization test failed (Status: $HTTP_STATUS)"
        return 1
    fi
}

# Function to test invalid content type
test_invalid_content_type() {
    print_status "Testing invalid content type..."
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -H "Authorization: Basic $AUTH_STRING" \
        -H "Content-Type: application/json" \
        -d '{"test": "data"}' \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$HTTP_STATUS" -eq 400 ]; then
        print_success "Invalid content type test passed (Status: $HTTP_STATUS)"
    else
        print_error "Invalid content type test failed (Status: $HTTP_STATUS)"
        return 1
    fi
}

# Function to test missing file
test_missing_file() {
    print_status "Testing missing file scenario..."
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -H "Authorization: Basic $AUTH_STRING" \
        -H "Content-Type: multipart/form-data" \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$HTTP_STATUS" -eq 400 ]; then
        print_success "Missing file test passed (Status: $HTTP_STATUS)"
    else
        print_error "Missing file test failed (Status: $HTTP_STATUS)"
        return 1
    fi
}

# Function to test empty file
test_empty_file() {
    print_status "Testing empty file scenario..."
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -H "Authorization: Basic $AUTH_STRING" \
        -F "file=@empty-file.txt" \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    RESPONSE_BODY=$(echo $RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        print_success "Empty file test passed (Status: $HTTP_STATUS)"
        echo "Response: $RESPONSE_BODY" | jq '.totalLines' 2>/dev/null || echo "Total lines: 0"
    else
        print_error "Empty file test failed (Status: $HTTP_STATUS)"
        echo "Response: $RESPONSE_BODY"
        return 1
    fi
}

# Function to test large file
test_large_file() {
    print_status "Testing large file scenario..."
    
    RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code};TIME_TOTAL:%{time_total}" \
        -X POST \
        -H "Authorization: Basic $AUTH_STRING" \
        -F "file=@large-file.txt" \
        "$API_ENDPOINT")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://' | cut -d';' -f1)
    TIME_TOTAL=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*TIME_TOTAL://')
    RESPONSE_BODY=$(echo $RESPONSE | sed -e 's/HTTPSTATUS\:.*//g' | sed -e 's/TIME_TOTAL\:.*//g')
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        print_success "Large file test passed (Status: $HTTP_STATUS, Time: ${TIME_TOTAL}s)"
        echo "Response: $RESPONSE_BODY" | jq '.totalLines' 2>/dev/null || echo "Large file processed successfully"
    else
        print_error "Large file test failed (Status: $HTTP_STATUS)"
        echo "Response: $RESPONSE_BODY"
        return 1
    fi
}

# Function to test performance
test_performance() {
    print_status "Running performance test..."
    
    echo "Testing API response times..."
    
    # Test multiple requests
    for i in {1..5}; do
        echo "Request $i..."
        RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code};TIME_TOTAL:%{time_total}" \
            -X POST \
            -H "Authorization: Basic $AUTH_STRING" \
            -F "file=@test-file.txt" \
            "$API_ENDPOINT")
        
        HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://' | cut -d';' -f1)
        TIME_TOTAL=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*TIME_TOTAL://')
        
        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "  ✓ Success (${TIME_TOTAL}s)"
        else
            echo "  ✗ Failed (Status: $HTTP_STATUS)"
        fi
    done
    
    print_success "Performance test completed"
}

# Function to display test results
show_test_results() {
    echo -e "\n${GREEN}=== API TEST RESULTS ===${NC}"
    echo -e "\n${BLUE}Test Summary:${NC}"
    echo "✓ Successful conversion test"
    echo "✓ Authentication failure test"
    echo "✓ Missing authorization test"
    echo "✓ Invalid content type test"
    echo "✓ Missing file test"
    echo "✓ Empty file test"
    echo "✓ Large file test"
    echo "✓ Performance test"
    
    echo -e "\n${BLUE}API Endpoint:${NC}"
    echo "$API_ENDPOINT"
    
    echo -e "\n${BLUE}Sample cURL Command:${NC}"
    echo "curl -X POST \\"
    echo "  '$API_ENDPOINT' \\"
    echo "  -H 'Authorization: Basic $AUTH_STRING' \\"
    echo "  -H 'Content-Type: multipart/form-data' \\"
    echo "  -F 'file=@test-file.txt'"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Monitor Application Insights for API usage"
    echo "2. Check Azure Function App logs for any issues"
    echo "3. Configure alerts for error rates and performance"
    echo "4. Update API credentials for production use"
}

# Function to cleanup test files
cleanup_test_files() {
    print_status "Cleaning up test files..."
    
    rm -f test-file.txt empty-file.txt large-file.txt
    
    print_success "Test files cleaned up"
}

# Main execution
main() {
    echo -e "${BLUE}Azure Text to JSON API Test Suite${NC}"
    echo "=================================="
    
    check_azure_cli
    get_api_endpoint
    encode_credentials
    create_test_files
    
    # Run all tests
    test_successful_conversion
    test_authentication_failure
    test_missing_auth
    test_invalid_content_type
    test_missing_file
    test_empty_file
    test_large_file
    test_performance
    
    show_test_results
    
    # Ask if user wants to cleanup
    echo -e "\n${YELLOW}Do you want to cleanup test files? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        cleanup_test_files
    fi
    
    print_success "API testing completed successfully!"
}

# Run main function
main "$@"
