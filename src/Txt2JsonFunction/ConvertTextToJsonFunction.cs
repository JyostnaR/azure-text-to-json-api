using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Txt2JsonFunction.Models;
using Txt2JsonFunction.Services;

namespace Txt2JsonFunction;

/// <summary>
/// Azure Function that converts text files to JSON format
/// Supports Basic Authentication via Azure Key Vault
/// </summary>
public class ConvertTextToJsonFunction
{
    private readonly ILogger<ConvertTextToJsonFunction> _logger;
    private readonly AuthenticationService _authService;
    private readonly FileProcessingService _fileProcessingService;
    private readonly JsonSerializerOptions _jsonOptions;

    public ConvertTextToJsonFunction(
        ILogger<ConvertTextToJsonFunction> logger,
        AuthenticationService authService,
        FileProcessingService fileProcessingService)
    {
        _logger = logger;
        _authService = authService;
        _fileProcessingService = fileProcessingService;
        
        // Configure JSON serialization options
        _jsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
    }

    [Function("ConvertTextToJson")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "v1/convert/text-to-json")] 
        HttpRequestData req)
    {
        var correlationId = Guid.NewGuid().ToString();
        var startTime = DateTime.UtcNow;
        
        try
        {
            _logger.LogInformation("ConvertTextToJson function started. CorrelationId: {CorrelationId}", correlationId);
            
            // Step 1: Validate Basic Authentication
            var authResult = await ValidateBasicAuthentication(req);
            if (!authResult.IsValid)
            {
                _logger.LogWarning("Authentication failed. CorrelationId: {CorrelationId}, Reason: {Reason}", 
                    correlationId, authResult.ErrorMessage);
                return CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Unauthorized", authResult.ErrorMessage);
            }

            _logger.LogInformation("Authentication successful. CorrelationId: {CorrelationId}", correlationId);

            // Step 2: Validate request content
            var validationResult = ValidateRequest(req);
            if (!validationResult.IsValid)
            {
                _logger.LogWarning("Request validation failed. CorrelationId: {CorrelationId}, Reason: {Reason}", 
                    correlationId, validationResult.ErrorMessage);
                return CreateErrorResponse(req, validationResult.StatusCode, "Bad Request", validationResult.ErrorMessage);
            }

            // Step 3: Process the file
            var fileContent = await ReadFileContent(req);
            var jsonResult = ConvertTextToJson(fileContent, correlationId);

            // Step 4: Create successful response
            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "application/json");
            response.Headers.Add("X-Correlation-ID", correlationId);
            
            var responseJson = JsonSerializer.Serialize(jsonResult, _jsonOptions);
            await response.WriteStringAsync(responseJson);

            var processingTime = DateTime.UtcNow - startTime;
            _logger.LogInformation("ConvertTextToJson function completed successfully. CorrelationId: {CorrelationId}, ProcessingTime: {ProcessingTime}ms", 
                correlationId, processingTime.TotalMilliseconds);

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in ConvertTextToJson function. CorrelationId: {CorrelationId}", correlationId);
            
            var response = req.CreateResponse(HttpStatusCode.InternalServerError);
            response.Headers.Add("Content-Type", "application/json");
            response.Headers.Add("X-Correlation-ID", correlationId);
            
            var errorResponse = new
            {
                error = "Internal Server Error",
                message = "An unexpected error occurred while processing your request",
                correlationId = correlationId
            };
            
            await response.WriteStringAsync(JsonSerializer.Serialize(errorResponse, _jsonOptions));
            return response;
        }
    }

    /// <summary>
    /// Validates Basic Authentication credentials against Azure Key Vault
    /// </summary>
    private async Task<AuthenticationResult> ValidateBasicAuthentication(HttpRequestData req)
    {
        try
        {
            // Extract Authorization header
            if (!req.Headers.TryGetValues("Authorization", out var authHeaders))
            {
                return AuthenticationResult.Failed("Missing Authorization header");
            }

            var authHeader = authHeaders.FirstOrDefault();
            if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Basic ", StringComparison.OrdinalIgnoreCase))
            {
                return AuthenticationResult.Failed("Invalid Authorization header format. Expected 'Basic <base64>'");
            }

            // Decode Base64 credentials
            var base64Credentials = authHeader.Substring(6); // Remove "Basic " prefix
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

            // Retrieve expected credentials from Key Vault
            var expectedUsername = await GetSecretAsync(ApiUsernameSecretName);
            var expectedPassword = await GetSecretAsync(ApiPasswordSecretName);

            if (string.IsNullOrEmpty(expectedUsername) || string.IsNullOrEmpty(expectedPassword))
            {
                _logger.LogError("Failed to retrieve API credentials from Key Vault");
                return AuthenticationResult.Failed("Authentication service unavailable");
            }

            // Validate credentials
            if (username.Equals(expectedUsername, StringComparison.Ordinal) && 
                password.Equals(expectedPassword, StringComparison.Ordinal))
            {
                return AuthenticationResult.Success();
            }

            return AuthenticationResult.Failed("Invalid credentials");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during authentication validation");
            return AuthenticationResult.Failed("Authentication validation failed");
        }
    }

    /// <summary>
    /// Validates the incoming request for file upload
    /// </summary>
    private ValidationResult ValidateRequest(HttpRequestData req)
    {
        // Check Content-Type
        if (!req.Headers.TryGetValues("Content-Type", out var contentTypes))
        {
            return ValidationResult.Failed(HttpStatusCode.BadRequest, "Missing Content-Type header");
        }

        var contentType = contentTypes.FirstOrDefault();
        if (string.IsNullOrEmpty(contentType) || !contentType.StartsWith("multipart/form-data", StringComparison.OrdinalIgnoreCase))
        {
            return ValidationResult.Failed(HttpStatusCode.BadRequest, "Content-Type must be 'multipart/form-data'");
        }

        // Check Content-Length
        if (!req.Headers.TryGetValues("Content-Length", out var contentLengths))
        {
            return ValidationResult.Failed(HttpStatusCode.BadRequest, "Missing Content-Length header");
        }

        if (!long.TryParse(contentLengths.FirstOrDefault(), out var contentLength))
        {
            return ValidationResult.Failed(HttpStatusCode.BadRequest, "Invalid Content-Length header");
        }

        if (contentLength > MaxFileSizeBytes)
        {
            return ValidationResult.Failed(HttpStatusCode.RequestEntityTooLarge, 
                $"File size exceeds maximum allowed size of {MaxFileSizeBytes / (1024 * 1024)}MB");
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Reads the uploaded file content from the request
    /// </summary>
    private async Task<string> ReadFileContent(HttpRequestData req)
    {
        var content = await req.ReadAsStringAsync();
        
        // For multipart/form-data, we need to parse the boundary and extract the file content
        // This is a simplified implementation - in production, consider using a proper multipart parser
        var lines = content.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        
        // Find the actual file content (skip headers and boundaries)
        var fileContentStart = false;
        var fileLines = new List<string>();
        
        foreach (var line in lines)
        {
            if (line.Contains("Content-Disposition: form-data") && line.Contains("filename="))
            {
                fileContentStart = true;
                continue;
            }
            
            if (fileContentStart && !line.StartsWith("--"))
            {
                // Remove trailing \r if present
                var cleanLine = line.TrimEnd('\r');
                if (!string.IsNullOrEmpty(cleanLine))
                {
                    fileLines.Add(cleanLine);
                }
            }
        }

        if (fileLines.Count == 0)
        {
            throw new InvalidOperationException("No file content found in the request");
        }

        return string.Join("\n", fileLines);
    }

    /// <summary>
    /// Converts text content to structured JSON
    /// </summary>
    private TextToJsonResult ConvertTextToJson(string textContent, string correlationId)
    {
        try
        {
            var lines = textContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            var jsonObjects = new List<object>();

            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i].Trim();
                if (string.IsNullOrEmpty(line)) continue;

                // Create a JSON object for each line
                // You can customize this logic based on your specific text format requirements
                var lineObject = new
                {
                    lineNumber = i + 1,
                    content = line,
                    length = line.Length,
                    words = line.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length,
                    timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                };

                jsonObjects.Add(lineObject);
            }

            var result = new TextToJsonResult
            {
                Success = true,
                CorrelationId = correlationId,
                ProcessedAt = DateTime.UtcNow,
                TotalLines = jsonObjects.Count,
                Data = jsonObjects
            };

            _logger.LogInformation("Text conversion completed. CorrelationId: {CorrelationId}, LinesProcessed: {LineCount}", 
                correlationId, jsonObjects.Count);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during text to JSON conversion. CorrelationId: {CorrelationId}", correlationId);
            throw new InvalidOperationException("Failed to convert text to JSON format", ex);
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
    /// Creates an error response with the specified status code and message
    /// </summary>
    private HttpResponseData CreateErrorResponse(HttpRequestData req, HttpStatusCode statusCode, string error, string message)
    {
        var response = req.CreateResponse(statusCode);
        response.Headers.Add("Content-Type", "application/json");
        
        var errorResponse = new
        {
            error = error,
            message = message,
            timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        };
        
        response.WriteString(JsonSerializer.Serialize(errorResponse, _jsonOptions));
        return response;
    }

    #region Helper Classes

    private class AuthenticationResult
    {
        public bool IsValid { get; private set; }
        public string? ErrorMessage { get; private set; }

        private AuthenticationResult(bool isValid, string? errorMessage = null)
        {
            IsValid = isValid;
            ErrorMessage = errorMessage;
        }

        public static AuthenticationResult Success() => new(true);
        public static AuthenticationResult Failed(string errorMessage) => new(false, errorMessage);
    }

    private class ValidationResult
    {
        public bool IsValid { get; private set; }
        public HttpStatusCode StatusCode { get; private set; }
        public string? ErrorMessage { get; private set; }

        private ValidationResult(bool isValid, HttpStatusCode statusCode = HttpStatusCode.OK, string? errorMessage = null)
        {
            IsValid = isValid;
            StatusCode = statusCode;
            ErrorMessage = errorMessage;
        }

        public static ValidationResult Success() => new(true);
        public static ValidationResult Failed(HttpStatusCode statusCode, string errorMessage) => new(false, statusCode, errorMessage);
    }

    private class TextToJsonResult
    {
        public bool Success { get; set; }
        public string CorrelationId { get; set; } = string.Empty;
        public DateTime ProcessedAt { get; set; }
        public int TotalLines { get; set; }
        public object Data { get; set; } = new();
    }

    #endregion
}
