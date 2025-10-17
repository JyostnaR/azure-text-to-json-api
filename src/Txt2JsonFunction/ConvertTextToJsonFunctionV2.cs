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
public class ConvertTextToJsonFunctionV2
{
    private readonly ILogger<ConvertTextToJsonFunctionV2> _logger;
    private readonly AuthenticationService _authService;
    private readonly FileProcessingService _fileProcessingService;
    private readonly JsonSerializerOptions _jsonOptions;

    public ConvertTextToJsonFunctionV2(
        ILogger<ConvertTextToJsonFunctionV2> logger,
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

    [Function("ConvertTextToJsonV2")]
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
            var authHeader = GetAuthorizationHeader(req);
            var authResult = await _authService.ValidateBasicAuthenticationAsync(authHeader);
            
            if (!authResult.IsValid)
            {
                _logger.LogWarning("Authentication failed. CorrelationId: {CorrelationId}, Reason: {Reason}", 
                    correlationId, authResult.ErrorMessage);
                return CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Unauthorized", authResult.ErrorMessage, correlationId);
            }

            _logger.LogInformation("Authentication successful. CorrelationId: {CorrelationId}, User: {Username}", 
                correlationId, authResult.Username);

            // Step 2: Parse multipart form data and extract file
            var fileData = await ParseMultipartFormDataAsync(req);
            if (fileData == null)
            {
                _logger.LogWarning("Failed to parse file from request. CorrelationId: {CorrelationId}", correlationId);
                return CreateErrorResponse(req, HttpStatusCode.BadRequest, "Bad Request", "No file found in request", correlationId);
            }

            // Step 3: Validate file
            var validationResult = _fileProcessingService.ValidateFile(
                fileData.Content, fileData.FileName, fileData.ContentType, fileData.Size);
                
            if (!validationResult.IsValid)
            {
                _logger.LogWarning("File validation failed. CorrelationId: {CorrelationId}, Reason: {Reason}", 
                    correlationId, validationResult.ErrorMessage);
                return CreateErrorResponse(req, HttpStatusCode.BadRequest, "Bad Request", validationResult.ErrorMessage, correlationId);
            }

            // Step 4: Process the file
            var jsonResult = await _fileProcessingService.ProcessTextFileAsync(
                fileData.Content, fileData.FileName, fileData.ContentType, correlationId);

            // Step 5: Create successful response
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
            return CreateErrorResponse(req, HttpStatusCode.InternalServerError, "Internal Server Error", 
                "An unexpected error occurred while processing your request", correlationId);
        }
    }

    /// <summary>
    /// Extracts the Authorization header from the request
    /// </summary>
    private string GetAuthorizationHeader(HttpRequestData req)
    {
        if (req.Headers.TryGetValues("Authorization", out var authHeaders))
        {
            return authHeaders.FirstOrDefault() ?? string.Empty;
        }
        return string.Empty;
    }

    /// <summary>
    /// Parses multipart form data to extract the uploaded file
    /// </summary>
    private async Task<FileUploadData?> ParseMultipartFormDataAsync(HttpRequestData req)
    {
        try
        {
            var contentType = req.Headers.GetValues("Content-Type").FirstOrDefault();
            if (string.IsNullOrEmpty(contentType) || !contentType.Contains("multipart/form-data"))
            {
                return null;
            }

            // For simplicity, we'll read the entire request body and parse it
            // In a production environment, you might want to use a more robust multipart parser
            var body = await req.ReadAsStringAsync();
            
            // Simple multipart parsing - this is a basic implementation
            // In production, consider using a library like Microsoft.AspNetCore.WebUtilities
            var boundary = ExtractBoundary(contentType);
            if (string.IsNullOrEmpty(boundary))
            {
                return null;
            }

            var parts = body.Split(new[] { $"--{boundary}" }, StringSplitOptions.RemoveEmptyEntries);
            
            foreach (var part in parts)
            {
                if (part.Contains("Content-Disposition: form-data") && part.Contains("filename="))
                {
                    var lines = part.Split('\n');
                    var fileName = ExtractFileName(lines);
                    var contentStartIndex = FindContentStartIndex(lines);
                    
                    if (contentStartIndex > 0 && !string.IsNullOrEmpty(fileName))
                    {
                        var content = string.Join("\n", lines.Skip(contentStartIndex)).TrimEnd('\r');
                        
                        return new FileUploadData
                        {
                            FileName = fileName,
                            Content = new MemoryStream(Encoding.UTF8.GetBytes(content)),
                            ContentType = "text/plain",
                            Size = Encoding.UTF8.GetByteCount(content)
                        };
                    }
                }
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error parsing multipart form data");
            return null;
        }
    }

    /// <summary>
    /// Extracts the boundary from the Content-Type header
    /// </summary>
    private string ExtractBoundary(string contentType)
    {
        var boundaryIndex = contentType.IndexOf("boundary=");
        if (boundaryIndex == -1) return string.Empty;
        
        var boundary = contentType.Substring(boundaryIndex + 9).Trim();
        return boundary.Trim('"');
    }

    /// <summary>
    /// Extracts the filename from the Content-Disposition header
    /// </summary>
    private string ExtractFileName(string[] lines)
    {
        foreach (var line in lines)
        {
            if (line.Contains("filename="))
            {
                var filenameIndex = line.IndexOf("filename=");
                var filename = line.Substring(filenameIndex + 9).Trim();
                filename = filename.Trim('"', ';', '\r', '\n');
                return filename;
            }
        }
        return string.Empty;
    }

    /// <summary>
    /// Finds the index where the actual content starts
    /// </summary>
    private int FindContentStartIndex(string[] lines)
    {
        for (int i = 0; i < lines.Length; i++)
        {
            if (string.IsNullOrWhiteSpace(lines[i]) || lines[i].Trim() == "")
            {
                return i + 1;
            }
        }
        return -1;
    }

    /// <summary>
    /// Creates an error response with the specified status code and message
    /// </summary>
    private HttpResponseData CreateErrorResponse(HttpRequestData req, HttpStatusCode statusCode, string error, string message, string correlationId)
    {
        var response = req.CreateResponse(statusCode);
        response.Headers.Add("Content-Type", "application/json");
        response.Headers.Add("X-Correlation-ID", correlationId);
        
        var errorResponse = new
        {
            error = error,
            message = message,
            correlationId = correlationId,
            timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        };
        
        response.WriteString(JsonSerializer.Serialize(errorResponse, _jsonOptions));
        return response;
    }

    /// <summary>
    /// Represents uploaded file data
    /// </summary>
    private class FileUploadData
    {
        public string FileName { get; set; } = string.Empty;
        public Stream Content { get; set; } = Stream.Null;
        public string ContentType { get; set; } = string.Empty;
        public long Size { get; set; }
    }
}
