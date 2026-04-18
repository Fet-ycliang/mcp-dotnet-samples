using Microsoft.Extensions.Caching.Memory;

namespace McpSamples.OutlookEmail.HybridApp.Services;

/// <summary>
/// 提供伺服器端附件暫存的介面。
/// </summary>
public interface IGeneratedAttachmentStore
{
    /// <summary>
    /// 取得附件在暫存區中的有效分鐘數。
    /// </summary>
    int ExpirationMinutes { get; }

    /// <summary>
    /// 儲存附件內容並回傳識別碼。
    /// </summary>
    /// <param name="name">附件檔名。</param>
    /// <param name="contentType">附件 MIME 類型。</param>
    /// <param name="contentBytes">附件位元組內容。</param>
    /// <returns>附件識別碼。</returns>
    string Save(string name, string contentType, byte[] contentBytes);

    /// <summary>
    /// 取得指定的附件內容。
    /// </summary>
    /// <param name="attachmentId">附件識別碼。</param>
    /// <param name="parameterName">參數名稱。</param>
    /// <returns>暫存的附件內容。</returns>
    GeneratedAttachmentContent GetRequired(string attachmentId, string parameterName);
}

/// <summary>
/// 表示伺服器端暫存的附件內容。
/// </summary>
/// <param name="Name">附件檔名。</param>
/// <param name="ContentType">附件 MIME 類型。</param>
/// <param name="ContentBytes">附件內容。</param>
public sealed record GeneratedAttachmentContent(string Name, string ContentType, byte[] ContentBytes);

/// <summary>
/// 表示記憶體型態的附件暫存實作。
/// </summary>
/// <param name="cache"><see cref="IMemoryCache"/> 執行個體。</param>
public class GeneratedAttachmentStore(IMemoryCache cache) : IGeneratedAttachmentStore
{
    private const int DefaultExpirationMinutes = 60;

    /// <inheritdoc />
    public int ExpirationMinutes => DefaultExpirationMinutes;

    /// <inheritdoc />
    public string Save(string name, string contentType, byte[] contentBytes)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name, nameof(name));
        ArgumentException.ThrowIfNullOrWhiteSpace(contentType, nameof(contentType));
        ArgumentNullException.ThrowIfNull(contentBytes);

        var attachmentId = Guid.NewGuid().ToString("N");
        cache.Set(CreateCacheKey(attachmentId),
                  new GeneratedAttachmentContent(name, contentType, contentBytes),
                  new MemoryCacheEntryOptions
                  {
                      SlidingExpiration = TimeSpan.FromMinutes(DefaultExpirationMinutes)
                  });

        return attachmentId;
    }

    /// <inheritdoc />
    public GeneratedAttachmentContent GetRequired(string attachmentId, string parameterName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(attachmentId, parameterName);

        var normalizedId = attachmentId.Trim();
        if (cache.TryGetValue(CreateCacheKey(normalizedId), out GeneratedAttachmentContent? attachment) == false || attachment is null)
        {
            throw new ArgumentException($"附件識別碼 '{normalizedId}' 不存在或已過期，請重新產生附件。", parameterName);
        }

        return attachment;
    }

    private static string CreateCacheKey(string attachmentId) => $"generated-attachment:{attachmentId}";
}
