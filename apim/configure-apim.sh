#!/bin/bash

# Azure API Management Configuration Script
# This script configures APIM with the Convert Text to JSON API

set -e

# Configuration
RESOURCE_GROUP_NAME="rg-txt2json-dev"
APIM_NAME="txt2json-dev-{unique-suffix}-apim"
FUNCTION_APP_URL="https://txt2json-dev-{unique-suffix}-func.azurewebsites.net"
API_NAME="convert-text-to-json"
API_DISPLAY_NAME="Convert Text to JSON API"
API_DESCRIPTION="REST API that converts text files to JSON format with Basic Authentication"

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

# Function to get APIM name from deployment
get_apim_name() {
    print_status "Retrieving APIM instance name from deployment..."
    
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
    
    print_success "Found APIM instance: $APIM_NAME"
}

# Function to get Function App URL from deployment
get_function_app_url() {
    print_status "Retrieving Function App URL from deployment..."
    
    DEPLOYMENT_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv)
    
    FUNCTION_APP_URL=$(az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query "properties.outputs.functionAppUrl.value" \
        --output tsv)
    
    if [ -z "$FUNCTION_APP_URL" ]; then
        print_error "Could not retrieve Function App URL from deployment outputs"
        exit 1
    fi
    
    print_success "Found Function App URL: $FUNCTION_APP_URL"
}

# Function to create the API
create_api() {
    print_status "Creating API in APIM..."
    
    az apim api create \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --api-id $API_NAME \
        --display-name "$API_DISPLAY_NAME" \
        --description "$API_DESCRIPTION" \
        --path "convert" \
        --service-url $FUNCTION_APP_URL \
        --protocols https \
        --subscription-required true \
        --output table
    
    print_success "API created successfully"
}

# Function to add the operation
add_operation() {
    print_status "Adding POST operation to API..."
    
    az apim api operation create \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --api-id $API_NAME \
        --operation-id "convert-text-to-json" \
        --display-name "Convert Text to JSON" \
        --method POST \
        --url-template "/v1/convert/text-to-json" \
        --description "Converts uploaded text file to structured JSON format" \
        --output table
    
    print_success "Operation added successfully"
}

# Function to configure operation policy
configure_operation_policy() {
    print_status "Configuring operation policy..."
    
    # Apply the convert API policy to the operation
    az apim api operation policy create \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --api-id $API_NAME \
        --operation-id "convert-text-to-json" \
        --policy-file "./policies/convert-api-policy.xml" \
        --output table
    
    print_success "Operation policy configured successfully"
}

# Function to configure API policy
configure_api_policy() {
    print_status "Configuring API-level policy..."
    
    # Apply rate limiting policy at API level
    az apim api policy create \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --api-id $API_NAME \
        --policy-file "./policies/rate-limit-policy.xml" \
        --output table
    
    print_success "API policy configured successfully"
}

# Function to configure global policy
configure_global_policy() {
    print_status "Configuring global policy..."
    
    # Apply global policy
    az apim policy create \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --policy-file "./policies/global-policy.xml" \
        --output table
    
    print_success "Global policy configured successfully"
}

# Function to create a subscription
create_subscription() {
    print_status "Creating subscription for the API..."
    
    SUBSCRIPTION_NAME="txt2json-subscription"
    
    az apim subscription create \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --subscription-id $SUBSCRIPTION_NAME \
        --display-name "Text to JSON API Subscription" \
        --scope "/apis/$API_NAME" \
        --output table
    
    print_success "Subscription created successfully"
    
    # Get subscription keys
    print_status "Retrieving subscription keys..."
    
    PRIMARY_KEY=$(az apim subscription show \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --subscription-id $SUBSCRIPTION_NAME \
        --query "primaryKey" \
        --output tsv)
    
    SECONDARY_KEY=$(az apim subscription show \
        --resource-group $RESOURCE_GROUP_NAME \
        --service-name $APIM_NAME \
        --subscription-id $SUBSCRIPTION_NAME \
        --query "secondaryKey" \
        --output tsv)
    
    print_success "Subscription keys retrieved"
    echo -e "\n${BLUE}Subscription Information:${NC}"
    echo "Subscription ID: $SUBSCRIPTION_NAME"
    echo "Primary Key: $PRIMARY_KEY"
    echo "Secondary Key: $SECONDARY_KEY"
}

# Function to test the API
test_api() {
    print_status "Testing the API configuration..."
    
    APIM_URL="https://$APIM_NAME.azure-api.net"
    TEST_URL="$APIM_URL/convert/v1/convert/text-to-json"
    
    echo -e "\n${BLUE}API Endpoint Information:${NC}"
    echo "API URL: $TEST_URL"
    echo "Method: POST"
    echo "Content-Type: multipart/form-data"
    echo "Authorization: Basic <base64(username:password)>"
    
    print_success "API configuration completed"
}

# Function to display next steps
show_next_steps() {
    echo -e "\n${GREEN}=== APIM CONFIGURATION COMPLETED SUCCESSFULLY ===${NC}"
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Test the API using the endpoint information above"
    echo "2. Create a sample .txt file for testing"
    echo "3. Use the Basic Auth credentials stored in Key Vault:"
    echo "   - Username: apiuser"
    echo "   - Password: SecurePassword123!"
    echo "4. Encode credentials in Base64: echo -n 'apiuser:SecurePassword123!' | base64"
    echo "5. Send a POST request with the Authorization header"
    
    echo -e "\n${BLUE}Example cURL command:${NC}"
    echo "curl -X POST \\"
    echo "  '$APIM_URL/convert/v1/convert/text-to-json' \\"
    echo "  -H 'Authorization: Basic <base64-encoded-credentials>' \\"
    echo "  -H 'Content-Type: multipart/form-data' \\"
    echo "  -F 'file=@sample.txt'"
    
    echo -e "\n${BLUE}API Management Portal:${NC}"
    echo "https://$APIM_NAME.portal.azure-api.net"
}

# Main execution
main() {
    echo -e "${BLUE}Azure API Management Configuration${NC}"
    echo "====================================="
    
    # Check if Azure CLI is installed and user is logged in
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    get_apim_name
    get_function_app_url
    create_api
    add_operation
    configure_operation_policy
    configure_api_policy
    configure_global_policy
    create_subscription
    test_api
    show_next_steps
    
    print_success "APIM configuration script completed successfully!"
}

# Run main function
main "$@"
