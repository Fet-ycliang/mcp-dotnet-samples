using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示資料表欄位定義。
/// </summary>
public class XlsxTableColumnSpec
{
    /// <summary>
    /// 取得或設定欄位名稱。
    /// </summary>
    [Description("欄位名稱")]
    public string Name { get; set; } = default!;

    /// <summary>
    /// 取得或設定欄位型別。
    /// </summary>
    [Description("欄位型別。支援 string、number、date、boolean；若省略則預設為 string")]
    public string? Type { get; set; }
}
