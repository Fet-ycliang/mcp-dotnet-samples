using System.ComponentModel;

using McpSamples.OutlookEmail.HybridApp.Models;
using McpSamples.OutlookEmail.HybridApp.Services;

using Microsoft.Graph.Models;
using Microsoft.Graph.Users.Item.SendMail;

using ModelContextProtocol.Server;

namespace McpSamples.OutlookEmail.HybridApp.Tools;

/// <summary>
/// 提供 Outlook 電子郵件工具的介面。
/// </summary>
public interface IOutlookEmailTool
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
    /// <returns>回傳 <see cref="OutlookEmailResult"/> 執行個體。</returns>
    Task<OutlookEmailResult> SendEmailAsync(string title, string body, string sender, string recipients, string? replyTo = default, OutlookEmailAttachment[]? attachments = default);
}

/// <summary>
/// 表示 Outlook 電子郵件的工具實作。
/// </summary>
/// <param name="service"><see cref="IOutlookEmailService"/> 執行個體。</param>
/// <param name="logger"><see cref="ILogger{TCategoryName}"/> 執行個體。</param>
[McpServerToolType]
public class OutlookEmailTool(IOutlookEmailService service, ILogger<OutlookEmailTool> logger) : IOutlookEmailTool
{
    /// <inheritdoc />
    [McpServerTool(Name = "send_email", Title = "傳送電子郵件")]
    [Description("將電子郵件寄送給收件者，並可選擇附上回覆地址與附件。")]
    public async Task<OutlookEmailResult> SendEmailAsync(
        [Description("電子郵件標題")] string title,
        [Description("電子郵件內容")] string body,
        [Description("寄件者電子郵件地址。若已設定 AllowedSenders，必須位於允許清單中")] string sender,
        [Description("以逗號或分號分隔的收件者電子郵件地址")] string recipients,
        [Description("以逗號或分號分隔的選用回覆地址")] string? replyTo = default,
        [Description("選用附件。每個項目都必須包含 name、contentType 與 contentBytesBase64，並會套用附件數量與單檔大小限制")] OutlookEmailAttachment[]? attachments = default)
    {
        var result = new OutlookEmailResult();
        try
        {
            var requestBody = await service.SendEmailAsync(title, body, sender, recipients, replyTo, attachments).ConfigureAwait(false);

            logger.LogInformation("已成功從 {Sender} 將主旨為 {Subject} 的電子郵件寄送給 {Recipients}。", sender, title, recipients);

            result.RequestBody = CreateResultRequestBody(requestBody);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "從 {Sender} 傳送主旨為 {Subject} 的電子郵件給 {Recipients} 失敗。", sender, title, recipients);

            result.ErrorMessage = ex.Message;
        }

        return result;
    }

    private static SendMailPostRequestBody CreateResultRequestBody(SendMailPostRequestBody requestBody)
    {
        if (requestBody.Message?.Attachments is not { Count: > 0 } attachments)
        {
            return requestBody;
        }

        return new SendMailPostRequestBody
        {
            SaveToSentItems = requestBody.SaveToSentItems,
            Message = new Message
            {
                Subject = requestBody.Message.Subject,
                Body = requestBody.Message.Body,
                ToRecipients = requestBody.Message.ToRecipients,
                ReplyTo = requestBody.Message.ReplyTo,
                Attachments = [.. attachments.Select(SanitizeAttachment)]
            }
        };
    }

    private static Attachment SanitizeAttachment(Attachment attachment)
    {
        return attachment switch
        {
            FileAttachment fileAttachment => new FileAttachment
            {
                OdataType = fileAttachment.OdataType,
                Name = fileAttachment.Name,
                ContentType = fileAttachment.ContentType
            },
            _ => new Attachment
            {
                OdataType = attachment.OdataType,
                Name = attachment.Name,
                ContentType = attachment.ContentType
            }
        };
    }
}

