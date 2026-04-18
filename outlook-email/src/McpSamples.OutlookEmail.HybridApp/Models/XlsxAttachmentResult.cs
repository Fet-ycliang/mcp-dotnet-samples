using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示 Excel 附件產生結果。
/// </summary>
public class XlsxAttachmentResult
{
    /// <summary>
    /// 取得或設定可供 send_email 使用的附件識別碼。
    /// </summary>
    [Description("可直接提供給 send_email.generatedAttachmentIds 使用的附件識別碼")]
    public string? GeneratedAttachmentId { get; set; }

    /// <summary>
    /// 取得或設定產出的檔名。
    /// </summary>
    [Description("產出的 Excel 檔名")]
    public string? Name { get; set; }

    /// <summary>
    /// 取得或設定內容類型。
    /// </summary>
    [Description("產出附件的 MIME 類型")]
    public string? ContentType { get; set; }

    /// <summary>
    /// 取得或設定工作表數量。
    /// </summary>
    [Description("產生的工作表數量")]
    public int SheetCount { get; set; }

    /// <summary>
    /// 取得或設定資料表數量。
    /// </summary>
    [Description("產生的資料表數量")]
    public int TableCount { get; set; }

    /// <summary>
    /// 取得或設定圖表數量。
    /// </summary>
    [Description("產生的圖表數量")]
    public int ChartCount { get; set; }

    /// <summary>
    /// 取得或設定輸出大小。
    /// </summary>
    [Description("產出檔案大小（位元組）")]
    public int SizeBytes { get; set; }

    /// <summary>
    /// 取得或設定附件在記憶體中的有效分鐘數。
    /// </summary>
    [Description("附件識別碼在伺服器端暫存的有效分鐘數")]
    public int ExpiresInMinutes { get; set; }

    /// <summary>
    /// 取得或設定使用提示。
    /// </summary>
    [Description("如何將此結果提供給 send_email 的提示")]
    public string? UsageHint { get; set; }

    /// <summary>
    /// 取得或設定警告訊息。
    /// </summary>
    [Description("非致命警告")]
    public string[] Warnings { get; set; } = [];

    /// <summary>
    /// 取得或設定錯誤訊息。
    /// </summary>
    public string? ErrorMessage { get; set; }
}
