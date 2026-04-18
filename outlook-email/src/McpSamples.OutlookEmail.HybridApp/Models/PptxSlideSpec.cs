using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示單張投影片的內容規格。
/// </summary>
public class PptxSlideSpec
{
    /// <summary>
    /// 取得或設定投影片類型。
    /// </summary>
    [Description("投影片類型。支援 title 與 content，若省略則預設為 content")]
    public string? Kind { get; set; }

    /// <summary>
    /// 取得或設定投影片標題。
    /// </summary>
    [Description("投影片標題")]
    public string Title { get; set; } = default!;

    /// <summary>
    /// 取得或設定標題頁副標題。
    /// </summary>
    [Description("標題頁副標題。只有 kind=title 時會使用")]
    public string? Subtitle { get; set; }

    /// <summary>
    /// 取得或設定一般內文。
    /// </summary>
    [Description("內容頁內文。可使用換行分成多段")]
    public string? Body { get; set; }

    /// <summary>
    /// 取得或設定條列內容。
    /// </summary>
    [Description("內容頁條列項目。每個字串會產生一個條列點")]
    public string[]? Bullets { get; set; }
}
