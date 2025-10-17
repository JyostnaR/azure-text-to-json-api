#!/bin/bash

# Azure Text to JSON API - Infrastructure Deployment Script
# This script deploys the complete Azure infrastructure using Bicep templates

set -e

# Configuration
RESOURCE_GROUP_NAME="rg-txt2json-dev"
LOCATION="East US"
DEPLOYMENT_NAME="txt2json-deployment-$(date +%Y%m%d-%H%M%S)"
PARAMETERS_FILE="parameters.json"
TEMPLATE_FILE="main.bicep"

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

# Function to create resource group if it doesn't exist
create_resource_group() {
    print_status "Creating resource group: $RESOURCE_GROUP_NAME"
    
    if az group exists --name $RESOURCE_GROUP_NAME --output tsv | grep -q "true"; then
        print_warning "Resource group $RESOURCE_GROUP_NAME already exists"
    else
        az group create \
            --name $RESOURCE_GROUP_NAME \
            --location "$LOCATION" \
            --output table
        print_success "Resource group created successfully"
    fi
}

# Function to deploy the Bicep template
deploy_infrastructure() {
    print_status "Deploying infrastructure with Bicep template..."
    
    az deployment group create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --template-file $TEMPLATE_FILE \
        --parameters @$PARAMETERS_FILE \
        --output table
    
    if [ $? -eq 0 ]; then
        print_success "Infrastructure deployment completed successfully"
    else
        print_error "Infrastructure deployment failed"
        exit 1
    fi
}

# Function to display deployment outputs
show_outputs() {
    print_status "Retrieving deployment outputs..."
    
    echo -e "\n${BLUE}=== DEPLOYMENT OUTPUTS ===${NC}"
    az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query properties.outputs \
        --output table
}

# Function to create sample secrets in Key Vault
create_sample_secrets() {
    print_status "Creating sample secrets in Key Vault..."
    
    # Get Key Vault name from deployment outputs
    KEY_VAULT_NAME=$(az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $DEPLOYMENT_NAME \
        --query properties.outputs.keyVaultName.value \
        --output tsv)
    
    if [ -n "$KEY_VAULT_NAME" ]; then
        # Create sample API credentials
        az keyvault secret set \
            --vault-name $KEY_VAULT_NAME \
            --name "api-username" \
            --value "apiuser" \
            --output none
        
        az keyvault secret set \
            --vault-name $KEY_VAULT_NAME \
            --name "api-password" \
            --value "SecurePassword123!" \
            --output none
        
        print_success "Sample secrets created in Key Vault: $KEY_VAULT_NAME"
        print_warning "Remember to update the API credentials with secure values!"
    else
        print_warning "Could not retrieve Key Vault name from deployment outputs"
    fi
}

# Function to display next steps
show_next_steps() {
    echo -e "\n${GREEN}=== DEPLOYMENT COMPLETED SUCCESSFULLY ===${NC}"
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Deploy the Azure Function code using the GitHub Actions workflow"
    echo "2. Configure API Management policies for Basic Authentication"
    echo "3. Test the API endpoint with the sample credentials:"
    echo "   - Username: apiuser"
    echo "   - Password: SecurePassword123!"
    echo "4. Update Key Vault secrets with production credentials"
    echo "5. Configure Application Insights alerts and monitoring"
    
    echo -e "\n${BLUE}Key Resources Created:${NC}"
    echo "- Resource Group: $RESOURCE_GROUP_NAME"
    echo "- Function App: Check deployment outputs for name"
    echo "- API Management: Check deployment outputs for name"
    echo "- Key Vault: Check deployment outputs for name"
    echo "- Application Insights: Check deployment outputs for name"
}

# Main execution
main() {
    echo -e "${BLUE}Azure Text to JSON API - Infrastructure Deployment${NC}"
    echo "=================================================="
    
    check_azure_cli
    create_resource_group
    deploy_infrastructure
    show_outputs
    create_sample_secrets
    show_next_steps
    
    print_success "Deployment script completed successfully!"
}

# Run main function
main "$@"
