using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示工作表中的圖表規格。
/// </summary>
public class XlsxChartSpec
{
    /// <summary>
    /// 取得或設定圖表類型。
    /// </summary>
    [Description("圖表類型。支援 column、bar、line、pie")]
    public string Kind { get; set; } = default!;

    /// <summary>
    /// 取得或設定圖表標題。
    /// </summary>
    [Description("圖表標題")]
    public string Title { get; set; } = default!;

    /// <summary>
    /// 取得或設定圖表引用的資料表名稱。
    /// </summary>
    [Description("圖表引用的資料表名稱。必須對應到同一工作表內某個 table.name")]
    public string TableName { get; set; } = default!;

    /// <summary>
    /// 取得或設定分類欄位名稱。
    /// </summary>
    [Description("圖表分類軸使用的欄位名稱")]
    public string CategoryColumn { get; set; } = default!;

    /// <summary>
    /// 取得或設定數值欄位名稱。
    /// </summary>
    [Description("圖表數值欄位名稱陣列。column/bar/line 可多個 series，pie 只能提供一個")]
    public string[] ValueColumns { get; set; } = [];
}
