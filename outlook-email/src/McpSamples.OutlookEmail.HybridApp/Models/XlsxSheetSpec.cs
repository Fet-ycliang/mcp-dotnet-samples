using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示單一工作表的內容規格。
/// </summary>
public class XlsxSheetSpec
{
    /// <summary>
    /// 取得或設定工作表名稱。
    /// </summary>
    [Description("工作表名稱。若省略會自動使用 Sheet1、Sheet2 這類預設名稱")]
    public string? Name { get; set; }

    /// <summary>
    /// 取得或設定工作表標題。
    /// </summary>
    [Description("工作表標題。若提供，會寫在工作表最上方")]
    public string? Title { get; set; }

    /// <summary>
    /// 取得或設定資料表定義。
    /// </summary>
    [Description("工作表內的資料表定義。每張工作表至少需要一個資料表")]
    public XlsxTableSpec[] Tables { get; set; } = [];

    /// <summary>
    /// 取得或設定圖表定義。
    /// </summary>
    [Description("工作表內的圖表定義。圖表會引用同一張工作表內某個資料表的欄位")]
    public XlsxChartSpec[]? Charts { get; set; }
}
