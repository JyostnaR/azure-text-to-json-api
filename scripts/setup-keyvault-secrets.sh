#!/bin/bash

# Azure Key Vault Secrets Setup Script
# This script populates Azure Key Vault with sample credentials and configuration

set -e

# Configuration
RESOURCE_GROUP_NAME="rg-txt2json-dev"
ENVIRONMENT="dev"

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
        print_error "Azure CLI is not installed. Please install it first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if user is logged in
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Azure CLI is installed and user is authenticated"
}

# Function to get Key Vault name from deployment
get_keyvault_name() {
    print_status "Retrieving Key Vault name from deployment..."
    
    # Get the latest deployment
    DEPLOYMENT_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv)
    
    if [ -z "$DEPLOYMENT_NAME" ]; then
        print_error "No deployment found in resource group: $RESOURCE_GROUP_NAME"
        print_error "Please run the infrastructure deployment first using: ./infrastructure/deploy.sh"
        exit 1
    fi
    
    KEY_VAULT_NAME=$(az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query "properties.outputs.keyVaultName.value" \
        --output tsv)
    
    if [ -z "$KEY_VAULT_NAME" ]; then
        print_error "Could not retrieve Key Vault name from deployment outputs"
        exit 1
    fi
    
    print_success "Found Key Vault: $KEY_VAULT_NAME"
}

# Function to create sample API credentials
create_api_credentials() {
    print_status "Creating sample API credentials..."
    
    # Create API username
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "api-username" \
        --value "apiuser" \
        --description "API Username for Basic Authentication" \
        --output none
    
    # Create API password (in production, use a secure password generator)
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "api-password" \
        --value "SecurePassword123!" \
        --description "API Password for Basic Authentication" \
        --output none
    
    print_success "API credentials created successfully"
    print_warning "Remember to update these credentials with secure values for production!"
}

# Function to create configuration secrets
create_configuration_secrets() {
    print_status "Creating configuration secrets..."
    
    # Create Application Insights connection string
    APP_INSIGHTS_CONNECTION=$(az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query "properties.outputs.applicationInsightsConnectionString.value" \
        --output tsv)
    
    if [ -n "$APP_INSIGHTS_CONNECTION" ]; then
        az keyvault secret set \
            --vault-name $KEY_VAULT_NAME \
            --name "app-insights-connection-string" \
            --value "$APP_INSIGHTS_CONNECTION" \
            --description "Application Insights Connection String" \
            --output none
        
        print_success "Application Insights connection string stored"
    else
        print_warning "Could not retrieve Application Insights connection string"
    fi
    
    # Create Blob Storage connection string
    BLOB_STORAGE_CONNECTION=$(az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query "properties.outputs.blobStorageConnectionString.value" \
        --output tsv)
    
    if [ -n "$BLOB_STORAGE_CONNECTION" ]; then
        az keyvault secret set \
            --vault-name $KEY_VAULT_NAME \
            --name "blob-storage-connection-string" \
            --value "$BLOB_STORAGE_CONNECTION" \
            --description "Blob Storage Connection String" \
            --output none
        
        print_success "Blob Storage connection string stored"
    else
        print_warning "Could not retrieve Blob Storage connection string"
    fi
}

# Function to create additional secrets for different environments
create_environment_secrets() {
    print_status "Creating environment-specific secrets..."
    
    # Create environment name
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "environment-name" \
        --value "$ENVIRONMENT" \
        --description "Environment name (dev, staging, prod)" \
        --output none
    
    # Create resource group name
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "resource-group-name" \
        --value "$RESOURCE_GROUP_NAME" \
        --description "Azure Resource Group Name" \
        --output none
    
    # Create deployment timestamp
    DEPLOYMENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "deployment-timestamp" \
        --value "$DEPLOYMENT_TIME" \
        --description "Deployment timestamp" \
        --output none
    
    print_success "Environment secrets created successfully"
}

# Function to create security secrets
create_security_secrets() {
    print_status "Creating security-related secrets..."
    
    # Create JWT secret (for future use if implementing JWT authentication)
    JWT_SECRET=$(openssl rand -base64 32)
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "jwt-secret" \
        --value "$JWT_SECRET" \
        --description "JWT signing secret (for future use)" \
        --output none
    
    # Create API rate limit configuration
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "rate-limit-per-minute" \
        --value "60" \
        --description "API rate limit per minute" \
        --output none
    
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "rate-limit-per-hour" \
        --value "1000" \
        --description "API rate limit per hour" \
        --output none
    
    print_success "Security secrets created successfully"
}

# Function to create monitoring secrets
create_monitoring_secrets() {
    print_status "Creating monitoring configuration secrets..."
    
    # Create log level configuration
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "log-level" \
        --value "Information" \
        --description "Application log level" \
        --output none
    
    # Create alert email configuration (placeholder)
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "alert-email" \
        --value "admin@contoso.com" \
        --description "Email address for alerts" \
        --output none
    
    # Create retention period configuration
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "log-retention-days" \
        --value "90" \
        --description "Log retention period in days" \
        --output none
    
    print_success "Monitoring secrets created successfully"
}

# Function to verify secrets were created
verify_secrets() {
    print_status "Verifying created secrets..."
    
    # List all secrets in the Key Vault
    SECRETS=$(az keyvault secret list --vault-name $KEY_VAULT_NAME --query "[].name" --output tsv)
    
    echo -e "\n${BLUE}Created secrets:${NC}"
    for secret in $SECRETS; do
        echo "  - $secret"
    done
    
    # Count secrets
    SECRET_COUNT=$(echo "$SECRETS" | wc -l)
    print_success "Total secrets created: $SECRET_COUNT"
}

# Function to display usage information
show_usage_info() {
    echo -e "\n${GREEN}=== KEY VAULT SECRETS SETUP COMPLETED SUCCESSFULLY ===${NC}"
    echo -e "\n${BLUE}Key Vault Information:${NC}"
    echo "Key Vault Name: $KEY_VAULT_NAME"
    echo "Resource Group: $RESOURCE_GROUP_NAME"
    echo "Environment: $ENVIRONMENT"
    
    echo -e "\n${BLUE}Sample API Credentials:${NC}"
    echo "Username: apiuser"
    echo "Password: SecurePassword123!"
    echo "Base64 Encoded: $(echo -n 'apiuser:SecurePassword123!' | base64)"
    
    echo -e "\n${BLUE}Important Security Notes:${NC}"
    echo "1. Update the API credentials with secure values for production"
    echo "2. Enable Key Vault soft delete and purge protection"
    echo "3. Configure proper access policies for production environments"
    echo "4. Consider using Azure Key Vault certificates for enhanced security"
    echo "5. Regularly rotate secrets and monitor access"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Test the API with the sample credentials"
    echo "2. Configure Application Insights alerts"
    echo "3. Set up monitoring and logging"
    echo "4. Implement proper secret rotation policies"
    
    echo -e "\n${BLUE}Key Vault Portal URL:${NC}"
    echo "https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME"
}

# Function to create production-ready secrets template
create_production_template() {
    print_status "Creating production secrets template..."
    
    cat > production-secrets-template.json << EOF
{
  "api-username": "REPLACE_WITH_SECURE_USERNAME",
  "api-password": "REPLACE_WITH_SECURE_PASSWORD",
  "jwt-secret": "REPLACE_WITH_SECURE_JWT_SECRET",
  "alert-email": "REPLACE_WITH_ALERT_EMAIL",
  "log-level": "Warning",
  "rate-limit-per-minute": "30",
  "rate-limit-per-hour": "500",
  "log-retention-days": "365"
}
EOF
    
    print_success "Production secrets template created: production-secrets-template.json"
    print_warning "Update this template with production values before deploying to production environment"
}

# Main execution
main() {
    echo -e "${BLUE}Azure Key Vault Secrets Setup${NC}"
    echo "=================================="
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--resource-group)
                RESOURCE_GROUP_NAME="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -g, --resource-group NAME    Resource group name (default: rg-txt2json-dev)"
                echo "  -e, --environment ENV        Environment name (default: dev)"
                echo "  -h, --help                   Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_azure_cli
    get_keyvault_name
    create_api_credentials
    create_configuration_secrets
    create_environment_secrets
    create_security_secrets
    create_monitoring_secrets
    verify_secrets
    create_production_template
    show_usage_info
    
    print_success "Key Vault secrets setup completed successfully!"
}

# Run main function
main "$@"
