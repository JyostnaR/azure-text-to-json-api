using System.Text.Json.Serialization;

namespace Txt2JsonFunction.Models;

/// <summary>
/// Represents the content of an uploaded text file
/// </summary>
public class TextFileContent
{
    [JsonPropertyName("fileName")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("content")]
    public string Content { get; set; } = string.Empty;

    [JsonPropertyName("contentType")]
    public string ContentType { get; set; } = string.Empty;

    [JsonPropertyName("size")]
    public long Size { get; set; }

    [JsonPropertyName("lineCount")]
    public int LineCount => Content.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length;
}

/// <summary>
/// Represents the result of text to JSON conversion
/// </summary>
public class TextToJsonResult
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("correlationId")]
    public string CorrelationId { get; set; } = string.Empty;

    [JsonPropertyName("processedAt")]
    public DateTime ProcessedAt { get; set; }

    [JsonPropertyName("totalLines")]
    public int TotalLines { get; set; }

    [JsonPropertyName("fileName")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("data")]
    public object Data { get; set; } = new();

    [JsonPropertyName("metadata")]
    public FileMetadata Metadata { get; set; } = new();
}

/// <summary>
/// File metadata information
/// </summary>
public class FileMetadata
{
    [JsonPropertyName("originalSize")]
    public long OriginalSize { get; set; }

    [JsonPropertyName("contentType")]
    public string ContentType { get; set; } = string.Empty;

    [JsonPropertyName("encoding")]
    public string Encoding { get; set; } = "UTF-8";

    [JsonPropertyName("processingTimeMs")]
    public double ProcessingTimeMs { get; set; }
}

/// <summary>
/// Represents a line in the text file with additional metadata
/// </summary>
public class TextLine
{
    [JsonPropertyName("lineNumber")]
    public int LineNumber { get; set; }

    [JsonPropertyName("content")]
    public string Content { get; set; } = string.Empty;

    [JsonPropertyName("length")]
    public int Length { get; set; }

    [JsonPropertyName("wordCount")]
    public int WordCount { get; set; }

    [JsonPropertyName("isEmpty")]
    public bool IsEmpty { get; set; }

    [JsonPropertyName("timestamp")]
    public string Timestamp { get; set; } = string.Empty;
}
