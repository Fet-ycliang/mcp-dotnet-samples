using System.ComponentModel;

namespace McpSamples.OutlookEmail.HybridApp.Models;

/// <summary>
/// 表示工作表中的資料表規格。
/// </summary>
public class XlsxTableSpec
{
    /// <summary>
    /// 取得或設定資料表名稱。
    /// </summary>
    [Description("資料表名稱。供同一工作表內的圖表透過 tableName 參照")]
    public string Name { get; set; } = default!;

    /// <summary>
    /// 取得或設定欄位定義。
    /// </summary>
    [Description("欄位定義。每個欄位都包含 name 與可選的 type")]
    public XlsxTableColumnSpec[] Columns { get; set; } = [];

    /// <summary>
    /// 取得或設定資料列。
    /// </summary>
    [Description("資料列。每一列都必須與 columns 數量一致；number/date/boolean 欄位同樣以字串提供，服務端會依欄位 type 解析")]
    public string[][] Rows { get; set; } = [];
}
