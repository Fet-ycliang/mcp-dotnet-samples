using Microsoft.Graph.Users.Item.SendMail;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示 Outlook 電子郵件作業的結果。
/// </summary>
public class OutlookEmailResult
{
    /// <summary>
    /// 取得或設定電子郵件的要求本文。
    /// </summary>
    public SendMailPostRequestBody? RequestBody { get; set; }

    /// <summary>
    /// 取得或設定發生錯誤時的錯誤訊息。
    /// </summary>
    public string? ErrorMessage { get; set; }
}
