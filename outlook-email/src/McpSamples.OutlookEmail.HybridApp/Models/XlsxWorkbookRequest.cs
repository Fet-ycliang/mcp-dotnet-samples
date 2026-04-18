namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示 Excel 活頁簿產生要求。
/// </summary>
public class XlsxWorkbookRequest
{
    /// <summary>
    /// 取得或設定輸出檔名。
    /// </summary>
    public string? FileName { get; set; }

    /// <summary>
    /// 取得或設定主題色。
    /// </summary>
    public string? ThemeColorHex { get; set; }

    /// <summary>
    /// 取得或設定工作表內容。
    /// </summary>
    public XlsxSheetSpec[] Sheets { get; set; } = [];
}
