using System.Net.Http.Headers;

using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Models;

using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Graph.Users.Item.SendMail;

namespace McpSamples.OutlookEmail.HybridApp.Services;

/// <summary>
/// 提供 Outlook 電子郵件服務作業的介面。
/// </summary>
public interface IOutlookEmailService
{
    /// <summary>
    /// 傳送電子郵件。
    /// </summary>
    /// <param name="title">電子郵件標題。</param>
    /// <param name="body">電子郵件內容。</param>
    /// <param name="sender">寄件者電子郵件地址。</param>
    /// <param name="recipients">以逗號或分號分隔的收件者電子郵件地址。</param>
    /// <param name="replyTo">以逗號或分號分隔的選用回覆地址。</param>
    /// <param name="attachments">選用的電子郵件附件。</param>
    /// <param name="generatedAttachmentIds">由其他工具產生並暫存於伺服器端的附件識別碼。</param>
    /// <returns>電子郵件傳送作業的結果。</returns>
    Task<SendMailPostRequestBody> SendEmailAsync(string title, string body, string sender, string recipients, string? replyTo = default, OutlookEmailAttachment[]? attachments = default, string[]? generatedAttachmentIds = default);
}

/// <summary>
/// 表示 Outlook 電子郵件的服務實作。
/// </summary>
/// <param name="graph"><see cref="GraphServiceClient"/> 執行個體。</param>
/// <param name="settings"><see cref="OutlookEmailAppSettings"/> 執行個體。</param>
/// <param name="generatedAttachmentStore"><see cref="IGeneratedAttachmentStore"/> 執行個體。</param>
/// <param name="logger"><see cref="ILogger{TCategoryName}"/> 執行個體。</param>
public class OutlookEmailService(GraphServiceClient graph, OutlookEmailAppSettings settings, IGeneratedAttachmentStore generatedAttachmentStore, ILogger<OutlookEmailService> logger) : IOutlookEmailService
{
    private readonly string[] _allowedSenders = settings.AllowedSenders
                                                        .Where(static sender => string.IsNullOrWhiteSpace(sender) == false)
                                                        .Select(static sender => sender.Trim())
                                                        .Distinct(StringComparer.OrdinalIgnoreCase)
                                                        .ToArray();

    private readonly string[] _allowedReplyTo = settings.AllowedReplyTo
                                                        .Where(static address => string.IsNullOrWhiteSpace(address) == false)
                                                        .Select(static address => address.Trim())
                                                        .Distinct(StringComparer.OrdinalIgnoreCase)
                                                        .ToArray();

    private readonly int _maxAttachmentCount = settings.MaxAttachmentCount > 0
                                                   ? settings.MaxAttachmentCount
                                                   : OutlookEmailAppSettings.DefaultMaxAttachmentCount;

    private readonly int _maxAttachmentSizeBytes = settings.MaxAttachmentSizeBytes > 0
                                                       ? settings.MaxAttachmentSizeBytes
                                                       : OutlookEmailAppSettings.DefaultMaxAttachmentSizeBytes;

    /// <inheritdoc />
    public async Task<SendMailPostRequestBody> SendEmailAsync(string title, string body, string sender, string recipients, string? replyTo = default, OutlookEmailAttachment[]? attachments = default, string[]? generatedAttachmentIds = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(title, nameof(title));
        ArgumentException.ThrowIfNullOrWhiteSpace(body, nameof(body));
        ArgumentException.ThrowIfNullOrWhiteSpace(sender, nameof(sender));
        ArgumentException.ThrowIfNullOrWhiteSpace(recipients, nameof(recipients));

        var normalizedSender = ParseSender(sender, nameof(sender));
        ValidateSender(normalizedSender, nameof(sender));
        var recipientList = ParseAddresses(recipients, nameof(recipients), "至少需要一位收件者");
        var replyToList = ParseAddresses(replyTo, nameof(replyTo), "提供 replyTo 時，至少需要一個回覆地址");
        ValidateReplyTo(replyToList, nameof(replyTo));
        var directAttachments = ParseAttachments(attachments, nameof(attachments));
        var generatedAttachments = ParseGeneratedAttachments(generatedAttachmentIds, nameof(generatedAttachmentIds));
        ValidateAttachmentCount(directAttachments.Length + generatedAttachments.Length);
        var attachmentList = directAttachments.Concat(generatedAttachments).ToArray();

        var req = BuildMailRequest(title, body, recipientList, replyToList, attachmentList);

        try
        {
            var user = graph.Users[normalizedSender];
            await user.SendMail.PostAsync(req);

            logger.LogInformation("已成功從 {Sender} 將主旨為 {Subject} 的電子郵件寄送給 {Recipients}。", normalizedSender, title, string.Join(", ", recipientList));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "從 {Sender} 傳送主旨為 {Subject} 的電子郵件給 {Recipients} 失敗。", normalizedSender, title, string.Join(", ", recipientList));
            throw;
        }

        return req;
    }

    private static string ParseSender(string sender, string parameterName)
    {
        var senderList = ParseAddresses(sender, parameterName, "寄件者必須是一個有效的電子郵件地址");
        if (senderList.Length != 1)
        {
            throw new ArgumentException("寄件者只能指定一個電子郵件地址。", parameterName);
        }

        return senderList[0];
    }

    private void ValidateSender(string sender, string parameterName)
    {
        if (_allowedSenders.Length == 0)
        {
            return;
        }

        if (_allowedSenders.Contains(sender, StringComparer.OrdinalIgnoreCase))
        {
            return;
        }

        throw new ArgumentException($"寄件者 '{sender}' 不在允許清單中。", parameterName);
    }

    private void ValidateReplyTo(string[] replyToAddresses, string parameterName)
    {
        if (_allowedReplyTo.Length == 0 || replyToAddresses.Length == 0)
        {
            return;
        }

        var invalidReplyToAddresses = replyToAddresses.Where(address => _allowedReplyTo.Contains(address, StringComparer.OrdinalIgnoreCase) == false)
                                                      .Distinct(StringComparer.OrdinalIgnoreCase)
                                                      .ToArray();
        if (invalidReplyToAddresses.Length == 0)
        {
            return;
        }

        throw new ArgumentException($"replyTo 位址 '{string.Join(", ", invalidReplyToAddresses)}' 不在允許清單中。", parameterName);
    }

    private static string[] ParseAddresses(string? addresses, string parameterName, string validationMessage)
    {
        if (addresses is null)
        {
            return [];
        }

        var addressList = addresses.Split([',', ';'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (addressList.Length == 0)
        {
            throw new ArgumentException(validationMessage, parameterName);
        }

        return addressList;
    }

    private FileAttachment[] ParseAttachments(OutlookEmailAttachment[]? attachments, string parameterName)
    {
        if (attachments is null || attachments.Length == 0)
        {
            return [];
        }

        var attachmentList = new FileAttachment[attachments.Length];
        for (var i = 0; i < attachments.Length; i++)
        {
            var attachment = attachments[i] ?? throw new ArgumentException($"索引 {i} 的附件不得為 null。", parameterName);
            var attachmentParameterPrefix = $"{parameterName}[{i}]";

            ArgumentException.ThrowIfNullOrWhiteSpace(attachment.Name, $"{attachmentParameterPrefix}.{nameof(OutlookEmailAttachment.Name)}");
            ArgumentException.ThrowIfNullOrWhiteSpace(attachment.ContentType, $"{attachmentParameterPrefix}.{nameof(OutlookEmailAttachment.ContentType)}");
            ArgumentException.ThrowIfNullOrWhiteSpace(attachment.ContentBytesBase64, $"{attachmentParameterPrefix}.{nameof(OutlookEmailAttachment.ContentBytesBase64)}");

            var contentType = ParseContentType(
                attachment.ContentType,
                $"{attachmentParameterPrefix}.{nameof(OutlookEmailAttachment.ContentType)}",
                attachment.Name);

            byte[] contentBytes;
            try
            {
                contentBytes = Convert.FromBase64String(attachment.ContentBytesBase64);
            }
            catch (FormatException ex)
            {
                throw new ArgumentException($"附件 '{attachment.Name}' 必須包含有效的 Base64 內容。", $"{attachmentParameterPrefix}.{nameof(OutlookEmailAttachment.ContentBytesBase64)}", ex);
            }

            if (contentBytes.Length > _maxAttachmentSizeBytes)
            {
                throw new ArgumentException(
                    $"附件 '{attachment.Name}' 大小不得超過 {FormatBinarySize(_maxAttachmentSizeBytes)}。",
                    $"{attachmentParameterPrefix}.{nameof(OutlookEmailAttachment.ContentBytesBase64)}");
            }

            attachmentList[i] = new FileAttachment
            {
                OdataType = "#microsoft.graph.fileAttachment",
                Name = attachment.Name,
                ContentType = contentType,
                ContentBytes = contentBytes
            };
        }

        return attachmentList;
    }

    private FileAttachment[] ParseGeneratedAttachments(string[]? generatedAttachmentIds, string parameterName)
    {
        if (generatedAttachmentIds is null || generatedAttachmentIds.Length == 0)
        {
            return [];
        }

        var attachmentList = new FileAttachment[generatedAttachmentIds.Length];
        for (var i = 0; i < generatedAttachmentIds.Length; i++)
        {
            var attachmentParameterName = $"{parameterName}[{i}]";
            var storedAttachment = generatedAttachmentStore.GetRequired(generatedAttachmentIds[i], attachmentParameterName);

            if (storedAttachment.ContentBytes.Length > _maxAttachmentSizeBytes)
            {
                throw new ArgumentException(
                    $"附件 '{storedAttachment.Name}' 大小不得超過 {FormatBinarySize(_maxAttachmentSizeBytes)}。",
                    attachmentParameterName);
            }

            attachmentList[i] = new FileAttachment
            {
                OdataType = "#microsoft.graph.fileAttachment",
                Name = storedAttachment.Name,
                ContentType = storedAttachment.ContentType,
                ContentBytes = storedAttachment.ContentBytes
            };
        }

        return attachmentList;
    }

    private void ValidateAttachmentCount(int attachmentCount)
    {
        if (attachmentCount > _maxAttachmentCount)
        {
            throw new ArgumentException($"附件總數不得超過 {_maxAttachmentCount} 個（包含 attachments 與 generatedAttachmentIds）。", nameof(attachmentCount));
        }
    }

    private static string ParseContentType(string contentType, string parameterName, string attachmentName)
    {
        if (MediaTypeHeaderValue.TryParse(contentType, out var mediaType) == false || string.IsNullOrWhiteSpace(mediaType.MediaType))
        {
            throw new ArgumentException($"附件 '{attachmentName}' 必須包含有效的 MIME 類型。", parameterName);
        }

        return mediaType.MediaType;
    }

    private static string FormatBinarySize(int sizeInBytes)
    {
        const int oneMiB = 1024 * 1024;
        return sizeInBytes % oneMiB == 0
                   ? $"{sizeInBytes / oneMiB} MiB"
                   : $"{sizeInBytes} bytes";
    }

    private static SendMailPostRequestBody BuildMailRequest(string title, string body, IEnumerable<string> recipients, IEnumerable<string> replyToRecipients, IEnumerable<FileAttachment> attachments)
    {
        var replyToList = replyToRecipients.Select(r => new Recipient
        {
            EmailAddress = new EmailAddress
            {
                Address = r
            }
        }).ToArray();
        var attachmentList = attachments.Cast<Attachment>().ToArray();

        var message = new Message
        {
            Subject = title,
            Body = new ItemBody
            {
                ContentType = BodyType.Text,
                Content = body
            },
            ToRecipients = [.. recipients.Select(r => new Recipient
            {
                EmailAddress = new EmailAddress
                {
                    Address = r
                }
            })]
        };

        if (replyToList.Length > 0)
        {
            message.ReplyTo = [.. replyToList];
        }

        if (attachmentList.Length > 0)
        {
            message.Attachments = [.. attachmentList];
        }

        var req = new SendMailPostRequestBody
        {
            Message = message,
            SaveToSentItems = true
        };

        return req;
    }
}
