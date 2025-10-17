using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Txt2JsonFunction.Models;

namespace Txt2JsonFunction.Services;

/// <summary>
/// Service for processing uploaded text files
/// </summary>
public class FileProcessingService
{
    private readonly ILogger<FileProcessingService> _logger;
    private readonly JsonSerializerOptions _jsonOptions;

    public FileProcessingService(ILogger<FileProcessingService> logger)
    {
        _logger = logger;
        _jsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
    }

    /// <summary>
    /// Processes the uploaded text file and converts it to structured JSON
    /// </summary>
    public async Task<TextToJsonResult> ProcessTextFileAsync(Stream fileStream, string fileName, string contentType, string correlationId)
    {
        var startTime = DateTime.UtcNow;
        
        try
        {
            _logger.LogInformation("Starting file processing. CorrelationId: {CorrelationId}, FileName: {FileName}", 
                correlationId, fileName);

            // Read file content
            using var reader = new StreamReader(fileStream, Encoding.UTF8);
            var content = await reader.ReadToEndAsync();
            
            var fileSize = Encoding.UTF8.GetByteCount(content);
            
            // Convert to structured JSON
            var lines = content.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            var textLines = new List<TextLine>();

            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i].Trim();
                var words = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);

                var textLine = new TextLine
                {
                    LineNumber = i + 1,
                    Content = line,
                    Length = line.Length,
                    WordCount = words.Length,
                    IsEmpty = string.IsNullOrEmpty(line),
                    Timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                };

                textLines.Add(textLine);
            }

            var processingTime = DateTime.UtcNow - startTime;

            var result = new TextToJsonResult
            {
                Success = true,
                CorrelationId = correlationId,
                ProcessedAt = DateTime.UtcNow,
                TotalLines = textLines.Count,
                FileName = fileName,
                Data = textLines,
                Metadata = new FileMetadata
                {
                    OriginalSize = fileSize,
                    ContentType = contentType,
                    Encoding = "UTF-8",
                    ProcessingTimeMs = processingTime.TotalMilliseconds
                }
            };

            _logger.LogInformation("File processing completed successfully. CorrelationId: {CorrelationId}, LinesProcessed: {LineCount}, ProcessingTime: {ProcessingTime}ms", 
                correlationId, textLines.Count, processingTime.TotalMilliseconds);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during file processing. CorrelationId: {CorrelationId}, FileName: {FileName}", 
                correlationId, fileName);
            throw;
        }
    }

    /// <summary>
    /// Validates the uploaded file
    /// </summary>
    public ValidationResult ValidateFile(Stream fileStream, string fileName, string contentType, long contentLength)
    {
        const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
        const string allowedContentType = "text/plain";
        
        // Check file extension
        var fileExtension = Path.GetExtension(fileName).ToLowerInvariant();
        if (fileExtension != ".txt")
        {
            return ValidationResult.Failed($"Invalid file type. Only .txt files are allowed. Received: {fileExtension}");
        }

        // Check content type
        if (!contentType.Equals(allowedContentType, StringComparison.OrdinalIgnoreCase))
        {
            return ValidationResult.Failed($"Invalid content type. Expected 'text/plain', received: {contentType}");
        }

        // Check file size
        if (contentLength > maxFileSizeBytes)
        {
            var maxSizeMB = maxFileSizeBytes / (1024.0 * 1024.0);
            return ValidationResult.Failed($"File size exceeds maximum allowed size of {maxSizeMB:F1}MB");
        }

        return ValidationResult.Success();
    }
}

/// <summary>
/// Validation result for file processing
/// </summary>
public class ValidationResult
{
    public bool IsValid { get; private set; }
    public string? ErrorMessage { get; private set; }

    private ValidationResult(bool isValid, string? errorMessage = null)
    {
        IsValid = isValid;
        ErrorMessage = errorMessage;
    }

    public static ValidationResult Success() => new(true);
    public static ValidationResult Failed(string errorMessage) => new(false, errorMessage);
}
