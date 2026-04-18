namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示簡報產生要求。
/// </summary>
public class PptxPresentationRequest
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
    /// 取得或設定投影片內容。
    /// </summary>
    public PptxSlideSpec[] Slides { get; set; } = [];
}
