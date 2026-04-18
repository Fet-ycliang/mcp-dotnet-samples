using System.ComponentModel;

using McpSamples.OutlookEmail.HybridApp.Models;
using McpSamples.OutlookEmail.HybridApp.Services;

using ModelContextProtocol.Server;

namespace McpSamples.OutlookEmail.HybridApp.Tools;

/// <summary>
/// 提供 Excel 附件工具的介面。
/// </summary>
public interface IXlsxAttachmentTool
{
    /// <summary>
    /// 產生 Excel 附件。
    /// </summary>
    /// <param name="sheets">工作表內容。</param>
    /// <param name="fileName">輸出檔名。</param>
    /// <param name="themeColorHex">主題色十六進位值。</param>
    /// <returns>回傳 <see cref="XlsxAttachmentResult"/> 執行個體。</returns>
    Task<XlsxAttachmentResult> GenerateXlsxAttachmentAsync(XlsxSheetSpec[] sheets, string? fileName = default, string? themeColorHex = default);
}

/// <summary>
/// 表示 Excel 附件工具實作。
/// </summary>
/// <param name="service"><see cref="IXlsxAttachmentService"/> 執行個體。</param>
/// <param name="logger"><see cref="ILogger{TCategoryName}"/> 執行個體。</param>
[McpServerToolType]
public class XlsxAttachmentTool(IXlsxAttachmentService service, ILogger<XlsxAttachmentTool> logger) : IXlsxAttachmentTool
{
    /// <inheritdoc />
    [McpServerTool(Name = "generate_xlsx_attachment", Title = "產生 Excel 報表附件")]
    [Description("根據結構化工作表、資料表與圖表內容產生 Excel 活頁簿，並回傳可直接提供給 send_email.generatedAttachmentIds 使用的附件識別碼。")]
    public async Task<XlsxAttachmentResult> GenerateXlsxAttachmentAsync(
        [Description("工作表陣列。每張工作表至少需要一個 table，並可選擇定義 column、bar、line、pie 圖表")] XlsxSheetSpec[] sheets,
        [Description("輸出的 Excel 檔名。若未提供 .xlsx 副檔名會自動補上")] string? fileName = default,
        [Description("主題色十六進位值，不含 #，例如 2F5597。會用於圖表配色")] string? themeColorHex = default)
    {
        try
        {
            return await service.GenerateAttachmentAsync(new XlsxWorkbookRequest
            {
                FileName = fileName,
                ThemeColorHex = themeColorHex,
                Sheets = sheets
            }).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "產生 Excel 附件失敗。");
            return new XlsxAttachmentResult
            {
                ErrorMessage = ex.Message
            };
        }
    }
}
