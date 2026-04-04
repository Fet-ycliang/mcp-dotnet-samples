using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示電子郵件附件內容。
/// </summary>
public class OutlookEmailAttachment
{
    /// <summary>
    /// 取得或設定附件檔名。
    /// </summary>
    [Description("會顯示在電子郵件中的檔案名稱")]
    public string Name { get; set; } = default!;

    /// <summary>
    /// 取得或設定附件的 MIME 內容類型。
    /// </summary>
    [Description("MIME 內容類型，例如 application/pdf 或 text/plain")]
    public string ContentType { get; set; } = default!;

    /// <summary>
    /// 取得或設定以 Base64 編碼的附件內容。
    /// </summary>
    [Description("以 Base64 字串編碼的附件內容")]
    public string ContentBytesBase64 { get; set; } = default!;
}
