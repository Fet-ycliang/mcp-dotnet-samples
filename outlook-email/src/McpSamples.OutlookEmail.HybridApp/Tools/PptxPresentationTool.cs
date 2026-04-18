using System.ComponentModel;

using McpSamples.OutlookEmail.HybridApp.Models;
using McpSamples.OutlookEmail.HybridApp.Services;

using ModelContextProtocol.Server;

namespace McpSamples.OutlookEmail.HybridApp.Tools;

/// <summary>
/// 提供 PowerPoint 附件工具的介面。
/// </summary>
public interface IPptxPresentationTool
{
    /// <summary>
    /// 產生 PowerPoint 附件。
    /// </summary>
    /// <param name="slides">投影片內容。</param>
    /// <param name="fileName">輸出檔名。</param>
    /// <param name="themeColorHex">主題色十六進位值。</param>
    /// <returns>回傳 <see cref="PptxAttachmentResult"/> 執行個體。</returns>
    Task<PptxAttachmentResult> GeneratePptxAttachmentAsync(PptxSlideSpec[] slides, string? fileName = default, string? themeColorHex = default);
}

/// <summary>
/// 表示 PowerPoint 附件工具實作。
/// </summary>
/// <param name="service"><see cref="IPptxPresentationService"/> 執行個體。</param>
/// <param name="logger"><see cref="ILogger{TCategoryName}"/> 執行個體。</param>
[McpServerToolType]
public class PptxPresentationTool(IPptxPresentationService service, ILogger<PptxPresentationTool> logger) : IPptxPresentationTool
{
    /// <inheritdoc />
    [McpServerTool(Name = "generate_pptx_attachment", Title = "產生 PowerPoint 簡報附件")]
    [Description("根據結構化投影片內容產生 PowerPoint 簡報，並回傳可直接提供給 send_email.generatedAttachmentIds 使用的附件識別碼。")]
    public async Task<PptxAttachmentResult> GeneratePptxAttachmentAsync(
        [Description("投影片陣列。每張投影片支援 kind=title 或 content，並使用 title、subtitle、body、bullets 描述內容")] PptxSlideSpec[] slides,
        [Description("輸出的簡報檔名。若未提供 .pptx 副檔名會自動補上")] string? fileName = default,
        [Description("主題色十六進位值，不含 #，例如 2F5597")] string? themeColorHex = default)
    {
        try
        {
            return await service.GenerateAttachmentAsync(new PptxPresentationRequest
            {
                FileName = fileName,
                ThemeColorHex = themeColorHex,
                Slides = slides
            }).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "產生 PowerPoint 附件失敗。");
            return new PptxAttachmentResult
            {
                ErrorMessage = ex.Message
            };
        }
    }
}
