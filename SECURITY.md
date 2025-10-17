# Security Guide

This document outlines the security measures implemented in the Azure Text to JSON REST API and provides guidance for maintaining security in production environments.

## 🔒 Security Architecture

### Defense in Depth

The solution implements multiple layers of security:

1. **Network Security**: HTTPS enforcement, VNet integration
2. **Authentication**: Basic Auth with secure credential storage
3. **Authorization**: Role-based access control (RBAC)
4. **Data Protection**: Encryption at rest and in transit
5. **Monitoring**: Security logging and alerting
6. **Compliance**: Audit trails and compliance reporting

## 🛡️ Authentication & Authorization

### Basic Authentication

The API uses Basic Authentication with credentials stored securely in Azure Key Vault:

```http
Authorization: Basic <base64-encoded-credentials>
```

**Security Features**:
- Credentials stored in Azure Key Vault with encryption
- Timing-attack-resistant credential comparison
- Secure credential retrieval using Managed Identity
- Automatic credential rotation support

### Access Control

#### Azure RBAC Roles

| Role | Purpose | Scope |
|------|---------|-------|
| **Contributor** | Deploy and manage resources | Resource Group |
| **Key Vault Secrets User** | Read secrets from Key Vault | Key Vault |
| **Storage Blob Data Contributor** | Read/write blob storage | Storage Account |
| **Application Insights Component Contributor** | Manage Application Insights | Application Insights |

#### API Management Subscriptions

- **Subscription-based access**: All API calls require valid subscription
- **Rate limiting**: Prevents abuse and DoS attacks
- **IP filtering**: Optional IP address restrictions
- **Usage quotas**: Configurable usage limits

### Managed Identity

The Function App uses System-Assigned Managed Identity for secure access to Azure resources:

```csharp
// Automatic credential management
var secretClient = new SecretClient(new Uri(keyVaultUrl), new DefaultAzureCredential());
```

**Benefits**:
- No credentials stored in code
- Automatic credential rotation
- Principle of least privilege
- Audit trail for all access

## 🔐 Data Protection

### Encryption

#### At Rest
- **Azure Storage**: 256-bit AES encryption
- **Azure Key Vault**: HSM-backed encryption (Premium tier)
- **Application Insights**: Encrypted data storage
- **Function App**: Encrypted file system

#### In Transit
- **TLS 1.2+**: All API communications
- **HTTPS Only**: Enforced across all services
- **Certificate Management**: Automatic SSL certificate renewal

### Data Classification

| Data Type | Classification | Protection Level |
|-----------|----------------|------------------|
| **API Credentials** | Highly Sensitive | Key Vault + Encryption |
| **User Files** | Sensitive | Encrypted Storage |
| **Logs** | Internal | Application Insights |
| **Configuration** | Internal | Environment Variables |

## 🔍 Security Monitoring

### Application Insights Security Logging

The solution logs all security-relevant events:

```csharp
// Authentication events
_logger.LogInformation("Authentication successful for user: {Username}", username);
_logger.LogWarning("Authentication failed for user: {Username}", username);

// File processing events
_logger.LogInformation("File processed successfully. Size: {Size} bytes", fileSize);
_logger.LogWarning("File validation failed. Reason: {Reason}", validationError);
```

### Security Alerts

Configure alerts for suspicious activities:

1. **Failed Authentication Attempts**:
   ```bash
   # Create alert rule
   az monitor metrics alert create \
     --name "High Auth Failures" \
     --resource-group $RESOURCE_GROUP_NAME \
     --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/microsoft.insights/components/$APP_INSIGHTS_NAME \
     --condition "count 'customMetrics | where name == \"AuthenticationFailure\"' > 10" \
     --description "High number of authentication failures detected"
   ```

2. **Unusual API Usage**:
   ```bash
   # Create alert for high API usage
   az monitor metrics alert create \
     --name "High API Usage" \
     --resource-group $RESOURCE_GROUP_NAME \
     --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/microsoft.insights/components/$APP_INSIGHTS_NAME \
     --condition "count 'requests | where name contains \"convert-text-to-json\"' > 1000" \
     --description "Unusually high API usage detected"
   ```

### Audit Logging

All administrative actions are logged:

- **Key Vault Access**: Who accessed what secrets when
- **Function App Deployments**: Deployment history and changes
- **API Management Changes**: Policy and configuration updates
- **Resource Creation/Deletion**: Infrastructure changes

## 🚨 Security Policies

### API Management Policies

#### Rate Limiting
```xml
<rate-limit calls="100" renewal-period="60" />
<rate-limit-by-key calls="1000" renewal-period="3600" counter-key="@(context.Subscription.Id)" />
```

#### Request Validation
```xml
<choose>
  <when condition="@(!context.Request.Headers.GetValueOrDefault("Content-Type", "").Contains("multipart/form-data"))">
    <return-response>
      <set-status code="400" reason="Bad Request" />
      <set-body>{"error": "Invalid content type"}</set-body>
    </return-response>
  </when>
</choose>
```

#### Security Headers
```xml
<set-header name="X-Content-Type-Options" exists-action="override">
  <value>nosniff</value>
</set-header>
<set-header name="X-Frame-Options" exists-action="override">
  <value>DENY</value>
</set-header>
<set-header name="X-XSS-Protection" exists-action="override">
  <value>1; mode=block</value>
</set-header>
```

### Function App Security

#### Input Validation
```csharp
// File size validation
if (contentLength > MaxFileSizeBytes)
{
    return ValidationResult.Failed($"File size exceeds maximum allowed size");
}

// File type validation
if (!contentType.Equals("text/plain", StringComparison.OrdinalIgnoreCase))
{
    return ValidationResult.Failed($"Invalid content type");
}
```

#### Secure Credential Handling
```csharp
// Timing-attack-resistant comparison
private static bool SecureEquals(string a, string b)
{
    if (a.Length != b.Length) return false;
    var result = 0;
    for (int i = 0; i < a.Length; i++)
    {
        result |= a[i] ^ b[i];
    }
    return result == 0;
}
```

## 🔧 Security Configuration

### Key Vault Security

#### Enable Soft Delete and Purge Protection
```bash
az keyvault update \
  --name $KEY_VAULT_NAME \
  --enable-soft-delete true \
  --soft-delete-retention-days 90 \
  --enable-purge-protection true
```

#### Configure Access Policies
```bash
# Grant Function App access to secrets
az keyvault set-policy \
  --name $KEY_VAULT_NAME \
  --object-id $FUNCTION_APP_PRINCIPAL_ID \
  --secret-permissions get list
```

#### Enable Diagnostic Logging
```bash
az monitor diagnostic-settings create \
  --name "KeyVaultSecurityLogs" \
  --resource $KEY_VAULT_ID \
  --logs '[{"category": "AuditEvent", "enabled": true}]' \
  --workspace $LOG_ANALYTICS_WORKSPACE_ID
```

### Function App Security

#### Enable Managed Identity
```bash
az functionapp identity assign \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP_NAME
```

#### Configure Security Settings
```bash
az functionapp config set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --min-tls-version "1.2" \
  --https-only true
```

#### Enable Diagnostic Logging
```bash
az monitor diagnostic-settings create \
  --name "FunctionAppSecurityLogs" \
  --resource $FUNCTION_APP_ID \
  --logs '[{"category": "FunctionAppLogs", "enabled": true}]' \
  --workspace $LOG_ANALYTICS_WORKSPACE_ID
```

### API Management Security

#### Enable HTTPS Only
```bash
az apim update \
  --name $APIM_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --protocols https
```

#### Configure Custom Domain with SSL
```bash
az apim hostname create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $APIM_NAME \
  --hostname-type "Proxy" \
  --hostname "api.yourdomain.com" \
  --certificate-name "your-ssl-certificate"
```

## 🛠️ Security Best Practices

### Development Security

1. **Secure Coding Practices**:
   - Input validation and sanitization
   - Output encoding
   - Error handling without information disclosure
   - Secure credential handling

2. **Dependency Management**:
   - Regular dependency updates
   - Vulnerability scanning
   - License compliance

3. **Code Review**:
   - Security-focused code reviews
   - Static analysis tools
   - Penetration testing

### Deployment Security

1. **Infrastructure as Code**:
   - Version-controlled infrastructure
   - Automated security scanning
   - Compliance validation

2. **Secrets Management**:
   - No secrets in code
   - Secure secret rotation
   - Least privilege access

3. **Network Security**:
   - Private endpoints where possible
   - Network security groups
   - Firewall rules

### Operational Security

1. **Monitoring and Alerting**:
   - Real-time security monitoring
   - Automated incident response
   - Regular security assessments

2. **Access Management**:
   - Regular access reviews
   - Privileged access management
   - Multi-factor authentication

3. **Incident Response**:
   - Security incident playbooks
   - Forensic capabilities
   - Communication plans

## 🔍 Security Testing

### Automated Security Testing

#### SAST (Static Application Security Testing)
```bash
# Install security scanner
dotnet tool install --global security-scan

# Run security scan
security-scan src/Txt2JsonFunction/
```

#### DAST (Dynamic Application Security Testing)
```bash
# Install OWASP ZAP
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://your-api-endpoint.com
```

#### Dependency Scanning
```bash
# Scan for vulnerabilities
dotnet list package --vulnerable
```

### Manual Security Testing

1. **Authentication Testing**:
   - Test invalid credentials
   - Test credential enumeration
   - Test session management

2. **Input Validation Testing**:
   - Test file upload limits
   - Test malicious file uploads
   - Test parameter manipulation

3. **Authorization Testing**:
   - Test privilege escalation
   - Test direct object references
   - Test function-level access control

## 📋 Security Checklist

### Pre-Production Checklist

- [ ] All default credentials changed
- [ ] HTTPS enforced across all services
- [ ] Security headers configured
- [ ] Rate limiting enabled
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery procedures tested
- [ ] Security incident response plan documented
- [ ] Compliance requirements validated

### Production Checklist

- [ ] Regular security updates scheduled
- [ ] Access reviews conducted quarterly
- [ ] Security monitoring dashboards configured
- [ ] Incident response team trained
- [ ] Security documentation maintained
- [ ] Penetration testing completed
- [ ] Compliance audits scheduled

## 🚨 Incident Response

### Security Incident Response Plan

1. **Detection and Analysis**:
   - Monitor security alerts
   - Analyze log data
   - Determine incident scope

2. **Containment**:
   - Isolate affected systems
   - Preserve evidence
   - Implement temporary fixes

3. **Eradication**:
   - Remove threats
   - Patch vulnerabilities
   - Strengthen defenses

4. **Recovery**:
   - Restore services
   - Validate security
   - Monitor for recurrence

5. **Lessons Learned**:
   - Document incident
   - Update procedures
   - Train team members

### Contact Information

- **Security Team**: security@yourcompany.com
- **Incident Response**: incident@yourcompany.com
- **Emergency Hotline**: +1-XXX-XXX-XXXX

## 📚 Compliance

### Regulatory Compliance

The solution supports compliance with:

- **GDPR**: Data protection and privacy
- **HIPAA**: Healthcare data protection
- **SOC 2**: Security and availability
- **ISO 27001**: Information security management

### Compliance Monitoring

- **Data Processing Logs**: Track all data processing activities
- **Access Logs**: Monitor who accessed what data when
- **Change Logs**: Track all system changes
- **Audit Reports**: Generate compliance reports

---

For security questions or to report vulnerabilities, please contact the security team or create a private issue in the repository.
