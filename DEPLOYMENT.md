# Deployment Guide

This guide provides detailed instructions for deploying the Azure Text to JSON REST API across different environments.

## 🏗️ Architecture Overview

The solution consists of the following Azure resources:

- **Resource Group**: Container for all resources
- **Function App**: Serverless backend for file processing
- **API Management**: API gateway with authentication and rate limiting
- **Key Vault**: Secure storage for credentials and secrets
- **Application Insights**: Monitoring and logging
- **Storage Account**: Required for Function App runtime
- **Blob Storage**: Optional audit storage for files

## 🚀 Deployment Methods

### Method 1: Automated Deployment (Recommended)

Use the provided scripts for automated deployment:

```bash
# 1. Deploy infrastructure
cd infrastructure
./deploy.sh

# 2. Setup Key Vault secrets
cd ../scripts
./setup-keyvault-secrets.sh

# 3. Configure API Management
cd ../apim
./configure-apim.sh
```

### Method 2: Manual Deployment

Follow the step-by-step manual deployment process below.

### Method 3: GitHub Actions CI/CD

Use the GitHub Actions workflow for automated CI/CD:

1. Configure GitHub secrets
2. Push code to trigger deployment
3. Monitor deployment progress in GitHub Actions

## 📋 Prerequisites

### Required Tools

- **Azure CLI** (v2.40.0 or later)
- **Bicep CLI** (included with Azure CLI)
- **.NET 8.0 SDK** (for local development)
- **Git** (for version control)

### Azure Permissions

Your Azure account needs the following permissions:

- **Contributor** role on the target subscription
- **Key Vault Administrator** role (for secret management)
- **API Management Service Contributor** role

### GitHub Setup (for CI/CD)

- GitHub repository with Actions enabled
- Service Principal with appropriate Azure permissions
- GitHub secrets configured

## 🔧 Step-by-Step Deployment

### Step 1: Prepare Environment

1. **Login to Azure CLI**:
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **Set environment variables**:
   ```bash
   export RESOURCE_GROUP_NAME="rg-txt2json-dev"
   export LOCATION="eastus"
   export ENVIRONMENT="dev"
   ```

3. **Clone repository**:
   ```bash
   git clone <repository-url>
   cd cursor_convertTxt2Json_vibeCoding
   ```

### Step 2: Deploy Infrastructure

1. **Review Bicep template**:
   ```bash
   cd infrastructure
   cat main.bicep
   ```

2. **Customize parameters** (optional):
   ```bash
   # Edit parameters.json
   nano parameters.json
   ```

3. **Deploy infrastructure**:
   ```bash
   # Make script executable
   chmod +x deploy.sh
   
   # Run deployment
   ./deploy.sh
   ```

4. **Verify deployment**:
   ```bash
   az group show --name $RESOURCE_GROUP_NAME
   ```

### Step 3: Configure Key Vault

1. **Setup secrets**:
   ```bash
   cd ../scripts
   chmod +x setup-keyvault-secrets.sh
   ./setup-keyvault-secrets.sh
   ```

2. **Verify secrets**:
   ```bash
   # Get Key Vault name
   KEY_VAULT_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv | xargs -I {} az deployment group show --resource-group $RESOURCE_GROUP_NAME --name {} --query "properties.outputs.keyVaultName.value" --output tsv)
   
   # List secrets
   az keyvault secret list --vault-name $KEY_VAULT_NAME --query "[].name" --output table
   ```

### Step 4: Deploy Function App

#### Option A: Using Azure Functions Core Tools

1. **Build the project**:
   ```bash
   cd src/Txt2JsonFunction
   dotnet build --configuration Release
   ```

2. **Deploy to Azure**:
   ```bash
   # Get Function App name
   FUNCTION_APP_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv | xargs -I {} az deployment group show --resource-group $RESOURCE_GROUP_NAME --name {} --query "properties.outputs.functionAppName.value" --output tsv)
   
   # Deploy
   func azure functionapp publish $FUNCTION_APP_NAME
   ```

#### Option B: Using Azure CLI

1. **Create deployment package**:
   ```bash
   cd src/Txt2JsonFunction
   dotnet publish --configuration Release --output ./publish
   cd publish
   zip -r function-app.zip .
   ```

2. **Deploy using Azure CLI**:
   ```bash
   az functionapp deployment source config-zip \
     --resource-group $RESOURCE_GROUP_NAME \
     --name $FUNCTION_APP_NAME \
     --src function-app.zip
   ```

### Step 5: Configure API Management

1. **Run APIM configuration**:
   ```bash
   cd ../../apim
   chmod +x configure-apim.sh
   ./configure-apim.sh
   ```

2. **Verify API configuration**:
   ```bash
   # Get APIM name
   APIM_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv | xargs -I {} az deployment group show --resource-group $RESOURCE_GROUP_NAME --name {} --query "properties.outputs.apiManagementName.value" --output tsv)
   
   # List APIs
   az apim api list --resource-group $RESOURCE_GROUP_NAME --service-name $APIM_NAME --query "[].name" --output table
   ```

### Step 6: Test Deployment

1. **Get API endpoint**:
   ```bash
   APIM_URL="https://$APIM_NAME.azure-api.net"
   API_ENDPOINT="$APIM_URL/convert/v1/convert/text-to-json"
   echo "API Endpoint: $API_ENDPOINT"
   ```

2. **Create test file**:
   ```bash
   echo "Line 1: Test content" > test.txt
   echo "Line 2: More test content" >> test.txt
   ```

3. **Test API**:
   ```bash
   # Encode credentials
   AUTH_STRING=$(echo -n "apiuser:SecurePassword123!" | base64 -w 0)
   
   # Test API
   curl -X POST \
     "$API_ENDPOINT" \
     -H "Authorization: Basic $AUTH_STRING" \
     -H "Content-Type: multipart/form-data" \
     -F "file=@test.txt"
   ```

## 🌍 Environment-Specific Deployments

### Development Environment

```bash
# Deploy to dev environment
./infrastructure/deploy.sh -e dev -g rg-txt2json-dev -l eastus
```

### Staging Environment

```bash
# Deploy to staging environment
./infrastructure/deploy.sh -e staging -g rg-txt2json-staging -l eastus
```

### Production Environment

```bash
# Deploy to production environment
./infrastructure/deploy.sh -e prod -g rg-txt2json-prod -l eastus

# Update production secrets
./scripts/setup-keyvault-secrets.sh -e prod -g rg-txt2json-prod
```

## 🔄 CI/CD Pipeline Deployment

### GitHub Actions Setup

1. **Configure GitHub Secrets**:
   - `AZURE_CREDENTIALS`: Service Principal JSON
   - `AZURE_FUNCTIONAPP_PUBLISH_PROFILE`: Function App publish profile

2. **Trigger Deployment**:
   ```bash
   # Push to main branch for production deployment
   git push origin main
   
   # Or trigger manually
   gh workflow run deploy.yml -f environment=dev
   ```

### Azure DevOps Pipeline

Create a pipeline YAML file:

```yaml
trigger:
  branches:
    include:
    - main
    - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  azureSubscription: 'your-service-connection'
  resourceGroupName: 'rg-txt2json-dev'
  location: 'East US'

stages:
- stage: DeployInfrastructure
  displayName: 'Deploy Infrastructure'
  jobs:
  - job: DeployBicep
    displayName: 'Deploy Bicep Template'
    steps:
    - task: AzureCLI@2
      inputs:
        azureSubscription: $(azureSubscription)
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          az deployment group create \
            --resource-group $(resourceGroupName) \
            --template-file infrastructure/main.bicep \
            --parameters infrastructure/parameters.json
```

## 🛠️ Customization

### Custom Resource Naming

Modify the Bicep template to use custom naming:

```bicep
param customPrefix string = 'mycompany'
var appName = '${customPrefix}-${environment}-${uniqueSuffix}'
```

### Custom Policies

Add custom APIM policies:

1. **Create policy file**:
   ```xml
   <policies>
     <inbound>
       <!-- Custom policy logic -->
     </inbound>
   </policies>
   ```

2. **Apply policy**:
   ```bash
   az apim api policy create \
     --resource-group $RESOURCE_GROUP_NAME \
     --service-name $APIM_NAME \
     --api-id convert-text-to-json \
     --policy-file custom-policy.xml
   ```

### Custom Function Configuration

Modify Function App settings:

```bash
az functionapp config appsettings set \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $FUNCTION_APP_NAME \
  --settings "CUSTOM_SETTING=value"
```

## 🔍 Troubleshooting

### Common Deployment Issues

1. **Resource Group Not Found**:
   ```bash
   # Create resource group
   az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
   ```

2. **Permission Denied**:
   ```bash
   # Check permissions
   az role assignment list --assignee $(az account show --query user.name --output tsv) --scope /subscriptions/$(az account show --query id --output tsv)
   ```

3. **Bicep Template Errors**:
   ```bash
   # Validate template
   az deployment group validate \
     --resource-group $RESOURCE_GROUP_NAME \
     --template-file infrastructure/main.bicep \
     --parameters infrastructure/parameters.json
   ```

4. **Function App Deployment Failed**:
   ```bash
   # Check Function App logs
   az functionapp log tail --resource-group $RESOURCE_GROUP_NAME --name $FUNCTION_APP_NAME
   ```

### Debugging Steps

1. **Check deployment status**:
   ```bash
   az deployment group list --resource-group $RESOURCE_GROUP_NAME --output table
   ```

2. **View deployment outputs**:
   ```bash
   DEPLOYMENT_NAME=$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" --output tsv)
   az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME --query "properties.outputs" --output table
   ```

3. **Check resource health**:
   ```bash
   az resource list --resource-group $RESOURCE_GROUP_NAME --output table
   ```

## 📊 Post-Deployment Verification

### Health Checks

1. **Function App Health**:
   ```bash
   curl https://$FUNCTION_APP_NAME.azurewebsites.net/api/health
   ```

2. **API Management Health**:
   ```bash
   curl https://$APIM_NAME.azure-api.net/status
   ```

3. **Key Vault Access**:
   ```bash
   az keyvault secret show --vault-name $KEY_VAULT_NAME --name api-username
   ```

### Performance Testing

1. **Load Test**:
   ```bash
   # Install Apache Bench
   sudo apt-get install apache2-utils
   
   # Run load test
   ab -n 100 -c 10 -H "Authorization: Basic $AUTH_STRING" -T "multipart/form-data" -p test.txt $API_ENDPOINT
   ```

2. **Stress Test**:
   ```bash
   # Use Artillery for stress testing
   npm install -g artillery
   artillery quick --count 10 --num 10 $API_ENDPOINT
   ```

## 🔄 Updates and Maintenance

### Updating Infrastructure

1. **Modify Bicep template**
2. **Validate changes**:
   ```bash
   az deployment group validate --resource-group $RESOURCE_GROUP_NAME --template-file infrastructure/main.bicep
   ```
3. **Deploy updates**:
   ```bash
   az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file infrastructure/main.bicep
   ```

### Updating Function App

1. **Deploy new version**:
   ```bash
   func azure functionapp publish $FUNCTION_APP_NAME
   ```

2. **Verify deployment**:
   ```bash
   az functionapp show --resource-group $RESOURCE_GROUP_NAME --name $FUNCTION_APP_NAME --query "state"
   ```

### Rolling Back Changes

1. **Function App Rollback**:
   ```bash
   az functionapp deployment list --resource-group $RESOURCE_GROUP_NAME --name $FUNCTION_APP_NAME
   az functionapp deployment slot swap --resource-group $RESOURCE_GROUP_NAME --name $FUNCTION_APP_NAME --slot staging --target-slot production
   ```

2. **Infrastructure Rollback**:
   ```bash
   # Redeploy previous version
   az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file infrastructure/main.bicep --parameters infrastructure/parameters.json
   ```

## 📈 Scaling Considerations

### Horizontal Scaling

- **Function App**: Automatically scales based on load
- **API Management**: Configure appropriate tier and capacity
- **Storage**: Consider geo-replication for high availability

### Vertical Scaling

- **Function App Plan**: Upgrade to higher SKU for better performance
- **API Management**: Move to higher tier for more features
- **Key Vault**: Use Premium tier for HSM-backed keys

### Cost Optimization

- **Consumption Plan**: Use for development and testing
- **Premium Plan**: Use for production with predictable load
- **Reserved Instances**: Consider for long-term production workloads

---

For additional support, refer to the main [README.md](README.md) or create an issue in the GitHub repository.
