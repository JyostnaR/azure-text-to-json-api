# Azure Key Vault Secrets Setup Script (PowerShell)
# This script populates Azure Key Vault with sample credentials and configuration

param(
    [Parameter(HelpMessage="Resource group name")]
    [string]$ResourceGroupName = "rg-txt2json-dev",
    
    [Parameter(HelpMessage="Environment name")]
    [string]$Environment = "dev",
    
    [Parameter(HelpMessage="Show help")]
    [switch]$Help
)

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if Azure CLI is installed and user is logged in
function Test-AzureCLI {
    Write-Status "Checking Azure CLI installation and authentication..."
    
    try {
        $null = Get-Command az -ErrorAction Stop
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install it first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
    
    try {
        $null = az account show 2>$null
    }
    catch {
        Write-Error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    }
    
    Write-Success "Azure CLI is installed and user is authenticated"
}

# Function to get Key Vault name from deployment
function Get-KeyVaultName {
    Write-Status "Retrieving Key Vault name from deployment..."
    
    try {
        $DeploymentName = az deployment group list --resource-group $ResourceGroupName --query "[0].name" --output tsv
        if (-not $DeploymentName) {
            throw "No deployment found"
        }
        
        $KeyVaultName = az deployment group show --resource-group $ResourceGroupName --name $DeploymentName --query "properties.outputs.keyVaultName.value" --output tsv
        
        if (-not $KeyVaultName) {
            throw "Could not retrieve Key Vault name"
        }
        
        Write-Success "Found Key Vault: $KeyVaultName"
        return $KeyVaultName
    }
    catch {
        Write-Error "Failed to retrieve Key Vault name: $_"
        Write-Error "Please run the infrastructure deployment first using: ./infrastructure/deploy.sh"
        exit 1
    }
}

# Function to create sample API credentials
function New-ApiCredentials {
    param([string]$KeyVaultName)
    
    Write-Status "Creating sample API credentials..."
    
    # Create API username
    az keyvault secret set --vault-name $KeyVaultName --name "api-username" --value "apiuser" --description "API Username for Basic Authentication" --output none
    
    # Create API password
    az keyvault secret set --vault-name $KeyVaultName --name "api-password" --value "SecurePassword123!" --description "API Password for Basic Authentication" --output none
    
    Write-Success "API credentials created successfully"
    Write-Warning "Remember to update these credentials with secure values for production!"
}

# Function to create configuration secrets
function New-ConfigurationSecrets {
    param([string]$KeyVaultName, [string]$ResourceGroupName)
    
    Write-Status "Creating configuration secrets..."
    
    try {
        $DeploymentName = az deployment group list --resource-group $ResourceGroupName --query "[0].name" --output tsv
        
        # Create Application Insights connection string
        $AppInsightsConnection = az deployment group show --resource-group $ResourceGroupName --name $DeploymentName --query "properties.outputs.applicationInsightsConnectionString.value" --output tsv
        
        if ($AppInsightsConnection) {
            az keyvault secret set --vault-name $KeyVaultName --name "app-insights-connection-string" --value $AppInsightsConnection --description "Application Insights Connection String" --output none
            Write-Success "Application Insights connection string stored"
        }
        else {
            Write-Warning "Could not retrieve Application Insights connection string"
        }
        
        # Create Blob Storage connection string
        $BlobStorageConnection = az deployment group show --resource-group $ResourceGroupName --name $DeploymentName --query "properties.outputs.blobStorageConnectionString.value" --output tsv
        
        if ($BlobStorageConnection) {
            az keyvault secret set --vault-name $KeyVaultName --name "blob-storage-connection-string" --value $BlobStorageConnection --description "Blob Storage Connection String" --output none
            Write-Success "Blob Storage connection string stored"
        }
        else {
            Write-Warning "Could not retrieve Blob Storage connection string"
        }
    }
    catch {
        Write-Warning "Error retrieving configuration secrets: $_"
    }
}

# Function to create additional secrets for different environments
function New-EnvironmentSecrets {
    param([string]$KeyVaultName, [string]$Environment, [string]$ResourceGroupName)
    
    Write-Status "Creating environment-specific secrets..."
    
    # Create environment name
    az keyvault secret set --vault-name $KeyVaultName --name "environment-name" --value $Environment --description "Environment name (dev, staging, prod)" --output none
    
    # Create resource group name
    az keyvault secret set --vault-name $KeyVaultName --name "resource-group-name" --value $ResourceGroupName --description "Azure Resource Group Name" --output none
    
    # Create deployment timestamp
    $DeploymentTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    az keyvault secret set --vault-name $KeyVaultName --name "deployment-timestamp" --value $DeploymentTime --description "Deployment timestamp" --output none
    
    Write-Success "Environment secrets created successfully"
}

# Function to create security secrets
function New-SecuritySecrets {
    param([string]$KeyVaultName)
    
    Write-Status "Creating security-related secrets..."
    
    # Create JWT secret (for future use if implementing JWT authentication)
    $JwtSecret = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    az keyvault secret set --vault-name $KeyVaultName --name "jwt-secret" --value $JwtSecret --description "JWT signing secret (for future use)" --output none
    
    # Create API rate limit configuration
    az keyvault secret set --vault-name $KeyVaultName --name "rate-limit-per-minute" --value "60" --description "API rate limit per minute" --output none
    az keyvault secret set --vault-name $KeyVaultName --name "rate-limit-per-hour" --value "1000" --description "API rate limit per hour" --output none
    
    Write-Success "Security secrets created successfully"
}

# Function to create monitoring secrets
function New-MonitoringSecrets {
    param([string]$KeyVaultName)
    
    Write-Status "Creating monitoring configuration secrets..."
    
    # Create log level configuration
    az keyvault secret set --vault-name $KeyVaultName --name "log-level" --value "Information" --description "Application log level" --output none
    
    # Create alert email configuration (placeholder)
    az keyvault secret set --vault-name $KeyVaultName --name "alert-email" --value "admin@contoso.com" --description "Email address for alerts" --output none
    
    # Create retention period configuration
    az keyvault secret set --vault-name $KeyVaultName --name "log-retention-days" --value "90" --description "Log retention period in days" --output none
    
    Write-Success "Monitoring secrets created successfully"
}

# Function to verify secrets were created
function Test-Secrets {
    param([string]$KeyVaultName)
    
    Write-Status "Verifying created secrets..."
    
    # List all secrets in the Key Vault
    $Secrets = az keyvault secret list --vault-name $KeyVaultName --query "[].name" --output tsv
    
    Write-Host "`nCreated secrets:" -ForegroundColor Blue
    foreach ($Secret in $Secrets) {
        Write-Host "  - $Secret"
    }
    
    # Count secrets
    $SecretCount = ($Secrets | Measure-Object).Count
    Write-Success "Total secrets created: $SecretCount"
}

# Function to display usage information
function Show-UsageInfo {
    param([string]$KeyVaultName, [string]$ResourceGroupName, [string]$Environment)
    
    Write-Host "`n=== KEY VAULT SECRETS SETUP COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
    Write-Host "`nKey Vault Information:" -ForegroundColor Blue
    Write-Host "Key Vault Name: $KeyVaultName"
    Write-Host "Resource Group: $ResourceGroupName"
    Write-Host "Environment: $Environment"
    
    Write-Host "`nSample API Credentials:" -ForegroundColor Blue
    Write-Host "Username: apiuser"
    Write-Host "Password: SecurePassword123!"
    $AuthString = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("apiuser:SecurePassword123!"))
    Write-Host "Base64 Encoded: $AuthString"
    
    Write-Host "`nImportant Security Notes:" -ForegroundColor Blue
    Write-Host "1. Update the API credentials with secure values for production"
    Write-Host "2. Enable Key Vault soft delete and purge protection"
    Write-Host "3. Configure proper access policies for production environments"
    Write-Host "4. Consider using Azure Key Vault certificates for enhanced security"
    Write-Host "5. Regularly rotate secrets and monitor access"
    
    Write-Host "`nNext Steps:" -ForegroundColor Blue
    Write-Host "1. Test the API with the sample credentials"
    Write-Host "2. Configure Application Insights alerts"
    Write-Host "3. Set up monitoring and logging"
    Write-Host "4. Implement proper secret rotation policies"
    
    $SubscriptionId = az account show --query id --output tsv
    Write-Host "`nKey Vault Portal URL:" -ForegroundColor Blue
    Write-Host "https://portal.azure.com/#@/resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"
}

# Function to create production-ready secrets template
function New-ProductionTemplate {
    Write-Status "Creating production secrets template..."
    
    $Template = @"
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
"@
    
    $Template | Out-File -FilePath "production-secrets-template.json" -Encoding UTF8
    
    Write-Success "Production secrets template created: production-secrets-template.json"
    Write-Warning "Update this template with production values before deploying to production environment"
}

# Main execution
function Main {
    if ($Help) {
        Write-Host "Usage: .\setup-keyvault-secrets.ps1 [OPTIONS]"
        Write-Host "Options:"
        Write-Host "  -ResourceGroupName NAME    Resource group name (default: rg-txt2json-dev)"
        Write-Host "  -Environment ENV          Environment name (default: dev)"
        Write-Host "  -Help                     Show this help message"
        return
    }
    
    Write-Host "Azure Key Vault Secrets Setup" -ForegroundColor Blue
    Write-Host "============================="
    
    Test-AzureCLI
    $KeyVaultName = Get-KeyVaultName
    New-ApiCredentials -KeyVaultName $KeyVaultName
    New-ConfigurationSecrets -KeyVaultName $KeyVaultName -ResourceGroupName $ResourceGroupName
    New-EnvironmentSecrets -KeyVaultName $KeyVaultName -Environment $Environment -ResourceGroupName $ResourceGroupName
    New-SecuritySecrets -KeyVaultName $KeyVaultName
    New-MonitoringSecrets -KeyVaultName $KeyVaultName
    Test-Secrets -KeyVaultName $KeyVaultName
    New-ProductionTemplate
    Show-UsageInfo -KeyVaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -Environment $Environment
    
    Write-Success "Key Vault secrets setup completed successfully!"
}

# Run main function
Main
