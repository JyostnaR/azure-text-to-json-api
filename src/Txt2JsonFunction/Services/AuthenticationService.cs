using System.Net;
using System.Text;
using Azure.Core;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Extensions.Logging;

namespace Txt2JsonFunction.Services;

/// <summary>
/// Service for handling Basic Authentication via Azure Key Vault
/// </summary>
public class AuthenticationService
{
    private readonly ILogger<AuthenticationService> _logger;
    private readonly SecretClient _secretClient;
    private readonly string _keyVaultUrl;

    // Constants
    private const string ApiUsernameSecretName = "api-username";
    private const string ApiPasswordSecretName = "api-password";

    public AuthenticationService(ILogger<AuthenticationService> logger)
    {
        _logger = logger;
        
        _keyVaultUrl = Environment.GetEnvironmentVariable("KEYVAULT_URL") ?? 
                      throw new InvalidOperationException("KEYVAULT_URL environment variable is not set");
        
        _secretClient = new SecretClient(new Uri(_keyVaultUrl), new DefaultAzureCredential());
    }

    /// <summary>
    /// Validates Basic Authentication credentials against Azure Key Vault
    /// </summary>
    public async Task<AuthenticationResult> ValidateBasicAuthenticationAsync(string authorizationHeader)
    {
        try
        {
            if (string.IsNullOrEmpty(authorizationHeader))
            {
                return AuthenticationResult.Failed("Missing Authorization header");
            }

            if (!authorizationHeader.StartsWith("Basic ", StringComparison.OrdinalIgnoreCase))
            {
                return AuthenticationResult.Failed("Invalid Authorization header format. Expected 'Basic <base64>'");
            }

            // Decode Base64 credentials
            var base64Credentials = authorizationHeader.Substring(6); // Remove "Basic " prefix
            string decodedCredentials;
            
            try
            {
                decodedCredentials = Encoding.UTF8.GetString(Convert.FromBase64String(base64Credentials));
            }
            catch (FormatException)
            {
                return AuthenticationResult.Failed("Invalid Base64 encoding in Authorization header");
            }

            // Parse username:password
            var credentials = decodedCredentials.Split(':', 2);
            if (credentials.Length != 2)
            {
                return AuthenticationResult.Failed("Invalid credential format. Expected 'username:password'");
            }

            var username = credentials[0];
            var password = credentials[1];

            // Validate credentials against Key Vault
            var isValid = await ValidateCredentialsAsync(username, password);
            
            if (isValid)
            {
                _logger.LogInformation("Authentication successful for user: {Username}", username);
                return AuthenticationResult.Success(username);
            }
            else
            {
                _logger.LogWarning("Authentication failed for user: {Username}", username);
                return AuthenticationResult.Failed("Invalid credentials");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during authentication validation");
            return AuthenticationResult.Failed("Authentication validation failed");
        }
    }

    /// <summary>
    /// Validates credentials against Azure Key Vault
    /// </summary>
    private async Task<bool> ValidateCredentialsAsync(string username, string password)
    {
        try
        {
            // Retrieve expected credentials from Key Vault
            var expectedUsername = await GetSecretAsync(ApiUsernameSecretName);
            var expectedPassword = await GetSecretAsync(ApiPasswordSecretName);

            if (string.IsNullOrEmpty(expectedUsername) || string.IsNullOrEmpty(expectedPassword))
            {
                _logger.LogError("Failed to retrieve API credentials from Key Vault");
                return false;
            }

            // Validate credentials using secure comparison
            return SecureEquals(username, expectedUsername) && SecureEquals(password, expectedPassword);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating credentials against Key Vault");
            return false;
        }
    }

    /// <summary>
    /// Retrieves a secret from Azure Key Vault
    /// </summary>
    private async Task<string?> GetSecretAsync(string secretName)
    {
        try
        {
            var secret = await _secretClient.GetSecretAsync(secretName);
            return secret.Value.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to retrieve secret '{SecretName}' from Key Vault", secretName);
            return null;
        }
    }

    /// <summary>
    /// Performs a secure string comparison to prevent timing attacks
    /// </summary>
    private static bool SecureEquals(string a, string b)
    {
        if (a.Length != b.Length)
            return false;

        var result = 0;
        for (int i = 0; i < a.Length; i++)
        {
            result |= a[i] ^ b[i];
        }
        return result == 0;
    }
}

/// <summary>
/// Result of authentication validation
/// </summary>
public class AuthenticationResult
{
    public bool IsValid { get; private set; }
    public string? Username { get; private set; }
    public string? ErrorMessage { get; private set; }

    private AuthenticationResult(bool isValid, string? username = null, string? errorMessage = null)
    {
        IsValid = isValid;
        Username = username;
        ErrorMessage = errorMessage;
    }

    public static AuthenticationResult Success(string username) => new(true, username);
    public static AuthenticationResult Failed(string errorMessage) => new(false, errorMessage: errorMessage);
}
