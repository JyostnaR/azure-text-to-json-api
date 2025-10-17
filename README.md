# Azure Text to JSON REST API

A complete Azure-based REST API solution that accepts `.txt` files via `multipart/form-data`, converts them to structured JSON, and returns the result. The API uses **Basic Authentication** with credentials stored securely in **Azure Key Vault**, and includes comprehensive monitoring through **Application Insights**.

## 🏗️ Architecture

The solution implements a modern, cloud-native architecture using Azure services:

- **Azure API Management (APIM)** - API Gateway with authentication and rate limiting
- **Azure Functions (C#)** - Serverless backend for file processing
- **Azure Key Vault** - Secure credential storage
- **Azure Application Insights** - Monitoring and logging
- **Azure Blob Storage** - Optional audit storage
- **GitHub Actions** - CI/CD pipeline

![Architecture Diagram](./architecture-diagram.md)

## 🚀 Features

- **Secure Authentication**: Basic Auth with credentials stored in Azure Key Vault
- **File Processing**: Converts text files to structured JSON format
- **Error Handling**: Comprehensive error responses with correlation IDs
- **Rate Limiting**: Configurable rate limits via APIM policies
- **Monitoring**: Full observability with Application Insights
- **CI/CD**: Automated deployment via GitHub Actions
- **Infrastructure as Code**: Complete Bicep templates for reproducible deployments

## 📋 Prerequisites

- Azure CLI installed and configured
- Azure subscription with appropriate permissions
- GitHub repository with Actions enabled
- .NET 8.0 SDK (for local development)

## 🛠️ Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd cursor_convertTxt2Json_vibeCoding
```

### 2. Deploy Infrastructure

```bash
cd infrastructure
./deploy.sh
```

This script will:
- Create a resource group
- Deploy all Azure resources using Bicep templates
- Configure managed identities and access policies
- Create sample secrets in Key Vault

### 3. Setup Key Vault Secrets

```bash
cd ../scripts
./setup-keyvault-secrets.sh
```

### 4. Configure API Management

```bash
cd ../apim
./configure-apim.sh
```

### 5. Deploy Function App

The Function App will be deployed automatically via GitHub Actions, or you can deploy it manually:

```bash
cd src/Txt2JsonFunction
func azure functionapp publish <function-app-name>
```

## 🔧 Configuration

### Environment Variables

The Function App requires the following environment variables:

- `KEYVAULT_URL` - Azure Key Vault URL (automatically set by Bicep)
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - App Insights connection string
- `AzureWebJobsStorage` - Storage account connection string

### Key Vault Secrets

The following secrets are automatically created:

- `api-username` - Basic Auth username
- `api-password` - Basic Auth password
- `app-insights-connection-string` - Application Insights connection
- `blob-storage-connection-string` - Blob storage connection
- `jwt-secret` - JWT signing secret (for future use)
- `rate-limit-per-minute` - Rate limiting configuration
- `rate-limit-per-hour` - Rate limiting configuration

## 📡 API Usage

### Endpoint

```
POST https://<apim-instance>.azure-api.net/convert/v1/convert/text-to-json
```

### Authentication

Include Basic Authentication header:

```bash
Authorization: Basic <base64-encoded-credentials>
```

### Request Format

- **Content-Type**: `multipart/form-data`
- **File Parameter**: `file` (must be a `.txt` file)
- **Max File Size**: 10MB

### Example Request

```bash
curl -X POST \
  'https://txt2json-dev-xxx-apim.azure-api.net/convert/v1/convert/text-to-json' \
  -H 'Authorization: Basic YXBpdXNlcjpTZWN1cmVQYXNzd29yZDEyMyE=' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@sample.txt'
```

### Example Response

```json
{
  "success": true,
  "correlationId": "12345678-1234-1234-1234-123456789abc",
  "processedAt": "2024-01-15T10:30:00.000Z",
  "totalLines": 4,
  "fileName": "sample.txt",
  "data": [
    {
      "lineNumber": 1,
      "content": "Line 1: This is the first line of the test file.",
      "length": 48,
      "wordCount": 10,
      "isEmpty": false,
      "timestamp": "2024-01-15T10:30:00.000Z"
    },
    {
      "lineNumber": 2,
      "content": "Line 2: This is the second line with some numbers 123.",
      "length": 54,
      "wordCount": 10,
      "isEmpty": false,
      "timestamp": "2024-01-15T10:30:00.000Z"
    }
  ],
  "metadata": {
    "originalSize": 1024,
    "contentType": "text/plain",
    "encoding": "UTF-8",
    "processingTimeMs": 15.5
  }
}
```

### Error Responses

#### 400 Bad Request
```json
{
  "error": "Bad Request",
  "message": "Content-Type must be 'multipart/form-data' for file uploads",
  "correlationId": "12345678-1234-1234-1234-123456789abc",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "message": "Invalid credentials",
  "correlationId": "12345678-1234-1234-1234-123456789abc",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### 413 Payload Too Large
```json
{
  "error": "Payload Too Large",
  "message": "File size exceeds maximum allowed size of 10MB",
  "maxSizeBytes": 10485760,
  "correlationId": "12345678-1234-1234-1234-123456789abc",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## 🏃‍♂️ Local Development

### Prerequisites

- .NET 8.0 SDK
- Azure Functions Core Tools v4
- Azure CLI

### Setup

1. **Install Azure Functions Core Tools**:
   ```bash
   npm install -g azure-functions-core-tools@4 --unsafe-perm true
   ```

2. **Configure local settings**:
   ```bash
   cd src/Txt2JsonFunction
   cp local.settings.json.example local.settings.json
   ```
   
   Update `local.settings.json` with your Azure resources:
   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "FUNCTIONS_WORKER_RUNTIME": "dotnet",
       "KEYVAULT_URL": "https://your-keyvault.vault.azure.net/",
       "APPLICATIONINSIGHTS_CONNECTION_STRING": "your-connection-string",
       "BlobStorageConnectionString": "your-blob-connection-string"
     }
   }
   ```

3. **Run locally**:
   ```bash
   func start
   ```

4. **Test locally**:
   ```bash
   curl -X POST \
     'http://localhost:7071/api/v1/convert/text-to-json' \
     -H 'Authorization: Basic YXBpdXNlcjpTZWN1cmVQYXNzd29yZDEyMyE=' \
     -H 'Content-Type: multipart/form-data' \
     -F 'file=@sample.txt'
   ```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflows

The repository includes two main workflows:

1. **Deploy Workflow** (`.github/workflows/deploy.yml`):
   - Builds and tests the application
   - Deploys infrastructure using Bicep
   - Deploys Function App
   - Configures API Management

2. **Test Workflow** (`.github/workflows/test.yml`):
   - Runs unit tests
   - Performs integration tests against deployed API
   - Executes security tests
   - Generates test reports

### Required GitHub Secrets

Configure the following secrets in your GitHub repository:

- `AZURE_CREDENTIALS` - Service Principal credentials for Azure deployment
- `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` - Function App publish profile

### Manual Deployment

You can trigger manual deployments using GitHub Actions:

```bash
gh workflow run deploy.yml -f environment=dev -f deploy_infrastructure=true -f deploy_function=true
```

## 📊 Monitoring and Observability

### Application Insights

The solution includes comprehensive monitoring:

- **Request Tracking**: All API requests are logged with correlation IDs
- **Performance Metrics**: Response times, throughput, and error rates
- **Custom Telemetry**: File processing metrics and business events
- **Error Tracking**: Detailed error logs with stack traces

### Key Metrics

- API response times
- File processing duration
- Authentication success/failure rates
- Error rates by endpoint
- Resource utilization

### Alerts

Configure alerts for:

- High error rates (>5%)
- Slow response times (>5 seconds)
- Authentication failures
- Resource quota limits

## 🔒 Security

### Authentication

- **Basic Authentication** with credentials stored in Azure Key Vault
- **Secure credential validation** using timing-attack-resistant comparison
- **Managed Identity** for secure access to Azure resources

### Network Security

- **HTTPS Only** - All communications encrypted in transit
- **VNet Integration** - Optional private endpoint configuration
- **Firewall Rules** - Configurable IP restrictions

### Data Protection

- **Encryption at Rest** - All data encrypted using Azure managed keys
- **Encryption in Transit** - TLS 1.2+ for all communications
- **Secret Rotation** - Automated secret rotation policies

## 🛡️ Best Practices

### Production Deployment

1. **Update Default Credentials**:
   ```bash
   az keyvault secret set --vault-name <keyvault-name> --name "api-password" --value "<secure-password>"
   ```

2. **Enable Soft Delete**:
   ```bash
   az keyvault update --name <keyvault-name> --enable-soft-delete true --enable-purge-protection true
   ```

3. **Configure Private Endpoints**:
   ```bash
   az network private-endpoint create --name <endpoint-name> --resource-group <rg-name> --vnet-name <vnet-name> --subnet <subnet-name> --private-connection-resource-id $(az keyvault show --name <keyvault-name> --query id -o tsv) --group-id vault --connection-name <connection-name>
   ```

4. **Set up Monitoring Alerts**:
   ```bash
   az monitor action-group create --name "api-alerts" --resource-group <rg-name> --short-name "api-alerts"
   ```

### Scaling Considerations

- **Function App**: Configure appropriate App Service Plan based on load
- **API Management**: Choose appropriate tier (Consumption, Basic, Standard, Premium)
- **Storage**: Consider geo-redundant storage for production
- **Key Vault**: Use Premium tier for HSM-backed keys in production

## 🔧 Troubleshooting

### Common Issues

1. **Authentication Failures**:
   - Verify credentials in Key Vault
   - Check Base64 encoding of Authorization header
   - Ensure Key Vault access policies are configured

2. **File Upload Issues**:
   - Verify Content-Type is `multipart/form-data`
   - Check file size limits (10MB max)
   - Ensure file has `.txt` extension

3. **Deployment Failures**:
   - Check Azure CLI authentication
   - Verify resource group permissions
   - Review Bicep template syntax

### Logs and Diagnostics

- **Function App Logs**: Available in Application Insights
- **API Management Logs**: Configure diagnostic settings
- **Key Vault Logs**: Enable logging for audit trails

## 📚 API Documentation

### OpenAPI Specification

The API includes a complete OpenAPI 3.0 specification available at:

```
https://<apim-instance>.azure-api.net/convert/swagger.json
```

### Postman Collection

Import the provided Postman collection for easy API testing:

```
https://<apim-instance>.azure-api.net/convert/postman-collection.json
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- Create an issue in the GitHub repository
- Check the troubleshooting section above
- Review Azure documentation for specific services

## 🔄 Version History

- **v1.0.0** - Initial release with basic text to JSON conversion
- **v1.1.0** - Added comprehensive monitoring and error handling
- **v1.2.0** - Implemented rate limiting and security enhancements
- **v1.3.0** - Added CI/CD pipeline and infrastructure as code

---

**Built with ❤️ using Azure services and modern DevOps practices.**
