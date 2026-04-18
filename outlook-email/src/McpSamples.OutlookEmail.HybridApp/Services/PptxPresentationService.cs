using System.Text.RegularExpressions;

using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;

using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Models;

using A = DocumentFormat.OpenXml.Drawing;
using P = DocumentFormat.OpenXml.Presentation;

namespace McpSamples.OutlookEmail.HybridApp.Services;

/// <summary>
/// 提供 PowerPoint 簡報附件產生功能的介面。
/// </summary>
public interface IPptxPresentationService
{
    /// <summary>
    /// 產生 PowerPoint 附件並暫存於伺服器端。
    /// </summary>
    /// <param name="request">簡報要求。</param>
    /// <param name="cancellationToken"><see cref="CancellationToken"/> 執行個體。</param>
    /// <returns>產生結果。</returns>
    Task<PptxAttachmentResult> GenerateAttachmentAsync(PptxPresentationRequest request, CancellationToken cancellationToken = default);
}

/// <summary>
/// 表示 PowerPoint 簡報附件產生服務。
/// </summary>
/// <param name="generatedAttachmentStore"><see cref="IGeneratedAttachmentStore"/> 執行個體。</param>
/// <param name="settings"><see cref="OutlookEmailAppSettings"/> 執行個體。</param>
/// <param name="logger"><see cref="ILogger{TCategoryName}"/> 執行個體。</param>
public class PptxPresentationService(IGeneratedAttachmentStore generatedAttachmentStore, OutlookEmailAppSettings settings, ILogger<PptxPresentationService> logger) : IPptxPresentationService
{
    private const string DefaultFileName = "presentation.pptx";
    private const string DefaultThemeColorHex = "2F5597";
    private const string DefaultTextColorHex = "1F1F1F";
    private const string DefaultSecondaryTextColorHex = "5B6573";
    private const string DefaultContentType = "application/vnd.openxmlformats-officedocument.presentationml.presentation";
    private const string DefaultLanguage = "zh-TW";
    private const int MaxSlides = 20;
    private const int MaxBulletsPerSlide = 8;
    private const int MaxTextLength = 2000;
    private const long SlideWidth = 12192000L;
    private const long SlideHeight = 6858000L;

    private readonly int _maxAttachmentSizeBytes = settings.MaxAttachmentSizeBytes > 0
                                                       ? settings.MaxAttachmentSizeBytes
                                                       : OutlookEmailAppSettings.DefaultMaxAttachmentSizeBytes;

    /// <inheritdoc />
    public Task<PptxAttachmentResult> GenerateAttachmentAsync(PptxPresentationRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        cancellationToken.ThrowIfCancellationRequested();

        var normalizedSlides = NormalizeSlides(request.Slides);
        var normalizedFileName = NormalizeFileName(request.FileName);
        var themeColorHex = NormalizeHexColor(request.ThemeColorHex, DefaultThemeColorHex, nameof(request.ThemeColorHex));
        var warnings = CreateWarnings(normalizedSlides);
        var pptxBytes = CreatePresentationBytes(normalizedSlides, themeColorHex, cancellationToken);

        if (pptxBytes.Length > _maxAttachmentSizeBytes)
        {
            throw new ArgumentException($"產生的簡報大小不得超過 {FormatBinarySize(_maxAttachmentSizeBytes)}。請減少投影片數量或縮短文字內容。", nameof(request));
        }

        var attachmentId = generatedAttachmentStore.Save(normalizedFileName, DefaultContentType, pptxBytes);
        logger.LogInformation("已產生簡報附件 {FileName}，共 {SlideCount} 頁，大小 {SizeBytes} bytes，識別碼 {AttachmentId}。", normalizedFileName, normalizedSlides.Length, pptxBytes.Length, attachmentId);

        return Task.FromResult(new PptxAttachmentResult
        {
            GeneratedAttachmentId = attachmentId,
            Name = normalizedFileName,
            ContentType = DefaultContentType,
            SlideCount = normalizedSlides.Length,
            SizeBytes = pptxBytes.Length,
            ExpiresInMinutes = generatedAttachmentStore.ExpirationMinutes,
            UsageHint = "將 generatedAttachmentId 放入 send_email.generatedAttachmentIds 即可把這份簡報當成附件寄出。",
            Warnings = warnings
        });
    }

    private static string[] CreateWarnings(IReadOnlyList<NormalizedSlideSpec> slides)
    {
        return slides.Count > 0 && slides[0].Kind != PptxSlideKind.Title
                   ? ["第一張投影片不是 title 類型，因此簡報不會自動產生封面頁。"]
                   : [];
    }

    private static NormalizedSlideSpec[] NormalizeSlides(PptxSlideSpec[]? slides)
    {
        if (slides is null || slides.Length == 0)
        {
            throw new ArgumentException("至少需要一張投影片。", nameof(slides));
        }

        if (slides.Length > MaxSlides)
        {
            throw new ArgumentException($"投影片數量不得超過 {MaxSlides} 張。", nameof(slides));
        }

        var normalizedSlides = new NormalizedSlideSpec[slides.Length];
        for (var i = 0; i < slides.Length; i++)
        {
            var slide = slides[i] ?? throw new ArgumentException($"索引 {i} 的投影片不得為 null。", nameof(slides));
            var slidePrefix = $"{nameof(slides)}[{i}]";
            var kind = NormalizeSlideKind(slide.Kind, $"{slidePrefix}.{nameof(PptxSlideSpec.Kind)}");
            var title = NormalizeRequiredText(slide.Title, $"{slidePrefix}.{nameof(PptxSlideSpec.Title)}");
            var subtitle = NormalizeOptionalText(slide.Subtitle, $"{slidePrefix}.{nameof(PptxSlideSpec.Subtitle)}");
            var bodyParagraphs = NormalizeBody(slide.Body, $"{slidePrefix}.{nameof(PptxSlideSpec.Body)}");
            var bullets = NormalizeBullets(slide.Bullets, $"{slidePrefix}.{nameof(PptxSlideSpec.Bullets)}");

            switch (kind)
            {
                case PptxSlideKind.Title when bodyParagraphs.Length > 0 || bullets.Length > 0:
                    throw new ArgumentException("title 投影片只支援 title 與 subtitle。", slidePrefix);

                case PptxSlideKind.Content when subtitle is not null:
                    throw new ArgumentException("content 投影片不支援 subtitle；請改用 body 或 bullets。", $"{slidePrefix}.{nameof(PptxSlideSpec.Subtitle)}");

                case PptxSlideKind.Content when bodyParagraphs.Length == 0 && bullets.Length == 0:
                    throw new ArgumentException("content 投影片至少要提供 body 或 bullets。", slidePrefix);
            }

            normalizedSlides[i] = new NormalizedSlideSpec(kind, title, subtitle, bodyParagraphs, bullets);
        }

        return normalizedSlides;
    }

    private static PptxSlideKind NormalizeSlideKind(string? kind, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(kind))
        {
            return PptxSlideKind.Content;
        }

        return kind.Trim().ToLowerInvariant() switch
        {
            "title" => PptxSlideKind.Title,
            "content" => PptxSlideKind.Content,
            _ => throw new ArgumentException("投影片類型只支援 title 或 content。", parameterName)
        };
    }

    private static string NormalizeRequiredText(string? value, string parameterName)
    {
        var normalized = NormalizeOptionalText(value, parameterName);
        return normalized ?? throw new ArgumentException("此欄位為必填。", parameterName);
    }

    private static string? NormalizeOptionalText(string? value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        if (normalized.Length > MaxTextLength)
        {
            throw new ArgumentException($"文字長度不得超過 {MaxTextLength} 個字元。", parameterName);
        }

        return normalized;
    }

    private static string[] NormalizeBody(string? body, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return [];
        }

        return body.Split(["\r\n", "\n"], StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                   .Select(line => NormalizeRequiredText(line, parameterName))
                   .ToArray();
    }

    private static string[] NormalizeBullets(string[]? bullets, string parameterName)
    {
        if (bullets is null || bullets.Length == 0)
        {
            return [];
        }

        if (bullets.Length > MaxBulletsPerSlide)
        {
            throw new ArgumentException($"每張投影片的 bullets 不得超過 {MaxBulletsPerSlide} 項。", parameterName);
        }

        var normalized = new string[bullets.Length];
        for (var i = 0; i < bullets.Length; i++)
        {
            normalized[i] = NormalizeRequiredText(bullets[i], $"{parameterName}[{i}]");
        }

        return normalized;
    }

    private static string NormalizeFileName(string? fileName)
    {
        var normalized = string.IsNullOrWhiteSpace(fileName) ? DefaultFileName : fileName.Trim();
        if (normalized.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
        {
            throw new ArgumentException("fileName 包含無效字元。", nameof(fileName));
        }

        if (!normalized.EndsWith(".pptx", StringComparison.OrdinalIgnoreCase))
        {
            normalized = $"{normalized}.pptx";
        }

        return normalized;
    }

    private static string NormalizeHexColor(string? colorHex, string defaultValue, string parameterName)
    {
        var normalized = string.IsNullOrWhiteSpace(colorHex)
                             ? defaultValue
                             : colorHex.Trim().TrimStart('#');

        if (!Regex.IsMatch(normalized, "^[0-9A-Fa-f]{6}$", RegexOptions.CultureInvariant))
        {
            throw new ArgumentException("themeColorHex 必須是 6 位十六進位色碼，例如 2F5597。", parameterName);
        }

        return normalized.ToUpperInvariant();
    }

    private static byte[] CreatePresentationBytes(IReadOnlyList<NormalizedSlideSpec> slides, string themeColorHex, CancellationToken cancellationToken)
    {
        using var stream = new MemoryStream();
        using (var presentationDoc = PresentationDocument.Create(stream, PresentationDocumentType.Presentation))
        {
            var presentationPart = presentationDoc.AddPresentationPart();
            presentationPart.Presentation = new P.Presentation();

            CreatePresentationParts(presentationPart, slides, themeColorHex, cancellationToken);
            presentationPart.Presentation.Save();
        }

        return stream.ToArray();
    }

    private static void CreatePresentationParts(PresentationPart presentationPart, IReadOnlyList<NormalizedSlideSpec> slides, string themeColorHex, CancellationToken cancellationToken)
    {
        var slideMasterIdList = new P.SlideMasterIdList(new P.SlideMasterId
        {
            Id = (UInt32Value)2147483648U,
            RelationshipId = "rId1"
        });
        var slideIdList = new P.SlideIdList();
        var slideSize = new P.SlideSize
        {
            Cx = checked((int)SlideWidth),
            Cy = checked((int)SlideHeight),
            Type = P.SlideSizeValues.Screen16x9
        };
        var notesSize = new P.NotesSize
        {
            Cx = 6858000L,
            Cy = 9144000L
        };
        var defaultTextStyle = new P.DefaultTextStyle();
        var presentation = presentationPart.Presentation ?? throw new InvalidOperationException("Presentation root element is missing.");

        presentation.Append(slideMasterIdList, slideIdList, slideSize, notesSize, defaultTextStyle);

        SlideLayoutPart? slideLayoutPart = null;
        for (var i = 0; i < slides.Count; i++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var relationshipId = $"rId{i + 2}";
            var slidePart = CreateSlidePart(presentationPart, relationshipId, slides[i], themeColorHex);
            if (i == 0)
            {
                slideLayoutPart = CreateSlideLayoutPart(slidePart);
                var slideMasterPart = CreateSlideMasterPart(slideLayoutPart);
                var themePart = CreateTheme(slideMasterPart, themeColorHex);

                slideMasterPart.AddPart(slideLayoutPart, "rId1");
                presentationPart.AddPart(slideMasterPart, "rId1");
                presentationPart.AddPart(themePart, "rId5");
            }
            else
            {
                slidePart.AddPart(slideLayoutPart!, "rId1");
            }

            slideIdList.Append(new P.SlideId
            {
                Id = (UInt32Value)(256U + (uint)i),
                RelationshipId = relationshipId
            });
        }
    }

    private static SlidePart CreateSlidePart(PresentationPart presentationPart, string relationshipId, NormalizedSlideSpec slideSpec, string themeColorHex)
    {
        var slidePart = presentationPart.AddNewPart<SlidePart>(relationshipId);
        var shapeTree = CreateBaseShapeTree();

        shapeTree.Append(CreateFilledRectangle(2U, "Accent Bar", 0L, 0L, SlideWidth, ToEmu(0.28), themeColorHex));

        switch (slideSpec.Kind)
        {
            case PptxSlideKind.Title:
                shapeTree.Append(CreateTextShape(3U, "Title", ToEmu(1.10), ToEmu(1.75), SlideWidth - ToEmu(2.20), ToEmu(1.40),
                                                 [CreateParagraph(slideSpec.Title, 3000, themeColorHex, true, A.TextAlignmentTypeValues.Center)]));

                if (slideSpec.Subtitle is not null)
                {
                    shapeTree.Append(CreateTextShape(4U, "Subtitle", ToEmu(1.20), ToEmu(3.10), SlideWidth - ToEmu(2.40), ToEmu(1.00),
                                                     [CreateParagraph(slideSpec.Subtitle, 1800, DefaultSecondaryTextColorHex, false, A.TextAlignmentTypeValues.Center)]));
                }
                break;

            default:
                shapeTree.Append(CreateTextShape(3U, "Title", ToEmu(0.85), ToEmu(0.52), SlideWidth - ToEmu(1.70), ToEmu(0.80),
                                                 [CreateParagraph(slideSpec.Title, 2400, themeColorHex, true)]));

                shapeTree.Append(CreateTextShape(4U, "Body", ToEmu(0.95), ToEmu(1.45), SlideWidth - ToEmu(1.90), ToEmu(5.35),
                                                 BuildContentParagraphs(slideSpec)));
                break;
        }

        slidePart.Slide = new P.Slide(
            new P.CommonSlideData(shapeTree),
            new P.ColorMapOverride(new A.MasterColorMapping()));

        slidePart.Slide.Save();
        return slidePart;
    }

    private static P.ShapeTree CreateBaseShapeTree()
    {
        var shapeTree = new P.ShapeTree();
        shapeTree.Append(new P.NonVisualGroupShapeProperties(
                             new P.NonVisualDrawingProperties
                             {
                                 Id = 1U,
                                 Name = string.Empty
                             },
                             new P.NonVisualGroupShapeDrawingProperties(),
                             new P.ApplicationNonVisualDrawingProperties()),
                         new P.GroupShapeProperties(new A.TransformGroup()));

        return shapeTree;
    }

    private static IEnumerable<A.Paragraph> BuildContentParagraphs(NormalizedSlideSpec slideSpec)
    {
        var paragraphs = new List<A.Paragraph>();
        paragraphs.AddRange(slideSpec.BodyParagraphs.Select(body => CreateParagraph(body, 1800, DefaultTextColorHex, false)));
        paragraphs.AddRange(slideSpec.Bullets.Select(bullet => CreateParagraph($"• {bullet}", 1800, DefaultTextColorHex, false)));

        return paragraphs.Count > 0 ? paragraphs : [CreateParagraph(" ", 1800, DefaultTextColorHex, false)];
    }

    private static P.Shape CreateFilledRectangle(uint shapeId, string name, long x, long y, long width, long height, string fillColorHex)
    {
        return new P.Shape(
            new P.NonVisualShapeProperties(
                new P.NonVisualDrawingProperties
                {
                    Id = shapeId,
                    Name = name
                },
                new P.NonVisualShapeDrawingProperties(new A.ShapeLocks
                {
                    NoGrouping = true
                }),
                new P.ApplicationNonVisualDrawingProperties()),
            new P.ShapeProperties(
                new A.Transform2D(
                    new A.Offset
                    {
                        X = x,
                        Y = y
                    },
                    new A.Extents
                    {
                        Cx = width,
                        Cy = height
                    }),
                new A.PresetGeometry(new A.AdjustValueList())
                {
                    Preset = A.ShapeTypeValues.Rectangle
                },
                new A.SolidFill(new A.RgbColorModelHex
                {
                    Val = fillColorHex
                }),
                new A.Outline(new A.NoFill())),
            new P.TextBody(
                new A.BodyProperties(),
                new A.ListStyle(),
                new A.Paragraph(new A.EndParagraphRunProperties
                {
                    Language = DefaultLanguage
                })));
    }

    private static P.Shape CreateTextShape(uint shapeId, string name, long x, long y, long width, long height, IEnumerable<A.Paragraph> paragraphs)
    {
        var textBody = new P.TextBody(
            new A.BodyProperties
            {
                Wrap = A.TextWrappingValues.Square,
                Anchor = A.TextAnchoringTypeValues.Top,
                LeftInset = 0,
                TopInset = 0,
                RightInset = 0,
                BottomInset = 0
            },
            new A.ListStyle());
        textBody.Append(paragraphs);

        return new P.Shape(
            new P.NonVisualShapeProperties(
                new P.NonVisualDrawingProperties
                {
                    Id = shapeId,
                    Name = name
                },
                new P.NonVisualShapeDrawingProperties(new A.ShapeLocks
                {
                    NoGrouping = true
                }),
                new P.ApplicationNonVisualDrawingProperties()),
            new P.ShapeProperties(
                new A.Transform2D(
                    new A.Offset
                    {
                        X = x,
                        Y = y
                    },
                    new A.Extents
                    {
                        Cx = width,
                        Cy = height
                    }),
                new A.PresetGeometry(new A.AdjustValueList())
                {
                    Preset = A.ShapeTypeValues.Rectangle
                },
                new A.NoFill(),
                new A.Outline(new A.NoFill())),
            textBody);
    }

    private static A.Paragraph CreateParagraph(string text, int fontSize, string colorHex, bool bold, A.TextAlignmentTypeValues? alignment = null)
    {
        var paragraph = new A.Paragraph();
        if (alignment.HasValue)
        {
            paragraph.ParagraphProperties = new A.ParagraphProperties
            {
                Alignment = alignment.Value
            };
        }

        var runProperties = new A.RunProperties
        {
            Language = DefaultLanguage,
            FontSize = fontSize,
            Bold = bold
        };
        runProperties.Append(new A.SolidFill(new A.RgbColorModelHex
        {
            Val = colorHex
        }));

        var run = new A.Run();
        run.RunProperties = runProperties;
        run.Text = new A.Text(text);

        paragraph.Append(run);
        paragraph.Append(new A.EndParagraphRunProperties
        {
            Language = DefaultLanguage
        });

        return paragraph;
    }

    private static SlideLayoutPart CreateSlideLayoutPart(SlidePart slidePart)
    {
        var slideLayoutPart = slidePart.AddNewPart<SlideLayoutPart>("rId1");
        slideLayoutPart.SlideLayout = new P.SlideLayout(
            new P.CommonSlideData(
                new P.ShapeTree(
                    new P.NonVisualGroupShapeProperties(
                        new P.NonVisualDrawingProperties
                        {
                            Id = 1U,
                            Name = string.Empty
                        },
                        new P.NonVisualGroupShapeDrawingProperties(),
                        new P.ApplicationNonVisualDrawingProperties()),
                    new P.GroupShapeProperties(new A.TransformGroup()),
                    new P.Shape(
                        new P.NonVisualShapeProperties(
                            new P.NonVisualDrawingProperties
                            {
                                Id = 2U,
                                Name = string.Empty
                            },
                            new P.NonVisualShapeDrawingProperties(new A.ShapeLocks
                            {
                                NoGrouping = true
                            }),
                            new P.ApplicationNonVisualDrawingProperties(new P.PlaceholderShape())),
                        new P.ShapeProperties(),
                        new P.TextBody(
                            new A.BodyProperties(),
                            new A.ListStyle(),
                            new A.Paragraph(new A.EndParagraphRunProperties()))))),
            new P.ColorMapOverride(new A.MasterColorMapping()));

        slideLayoutPart.SlideLayout.Save();
        return slideLayoutPart;
    }

    private static SlideMasterPart CreateSlideMasterPart(SlideLayoutPart slideLayoutPart)
    {
        var slideMasterPart = slideLayoutPart.AddNewPart<SlideMasterPart>("rId1");
        slideMasterPart.SlideMaster = new P.SlideMaster(
            new P.CommonSlideData(
                new P.ShapeTree(
                    new P.NonVisualGroupShapeProperties(
                        new P.NonVisualDrawingProperties
                        {
                            Id = 1U,
                            Name = string.Empty
                        },
                        new P.NonVisualGroupShapeDrawingProperties(),
                        new P.ApplicationNonVisualDrawingProperties()),
                    new P.GroupShapeProperties(new A.TransformGroup()),
                    new P.Shape(
                        new P.NonVisualShapeProperties(
                            new P.NonVisualDrawingProperties
                            {
                                Id = 2U,
                                Name = "Title Placeholder 1"
                            },
                            new P.NonVisualShapeDrawingProperties(new A.ShapeLocks
                            {
                                NoGrouping = true
                            }),
                            new P.ApplicationNonVisualDrawingProperties(new P.PlaceholderShape
                            {
                                Type = P.PlaceholderValues.Title
                            })),
                        new P.ShapeProperties(),
                        new P.TextBody(
                            new A.BodyProperties(),
                            new A.ListStyle(),
                            new A.Paragraph())))),
            new P.ColorMap
            {
                Background1 = A.ColorSchemeIndexValues.Light1,
                Text1 = A.ColorSchemeIndexValues.Dark1,
                Background2 = A.ColorSchemeIndexValues.Light2,
                Text2 = A.ColorSchemeIndexValues.Dark2,
                Accent1 = A.ColorSchemeIndexValues.Accent1,
                Accent2 = A.ColorSchemeIndexValues.Accent2,
                Accent3 = A.ColorSchemeIndexValues.Accent3,
                Accent4 = A.ColorSchemeIndexValues.Accent4,
                Accent5 = A.ColorSchemeIndexValues.Accent5,
                Accent6 = A.ColorSchemeIndexValues.Accent6,
                Hyperlink = A.ColorSchemeIndexValues.Hyperlink,
                FollowedHyperlink = A.ColorSchemeIndexValues.FollowedHyperlink
            },
            new P.SlideLayoutIdList(new P.SlideLayoutId
            {
                Id = (UInt32Value)2147483649U,
                RelationshipId = "rId1"
            }),
            new P.TextStyles(new P.TitleStyle(), new P.BodyStyle(), new P.OtherStyle()));

        slideMasterPart.SlideMaster.Save();
        return slideMasterPart;
    }

    private static ThemePart CreateTheme(SlideMasterPart slideMasterPart, string themeColorHex)
    {
        var themePart = slideMasterPart.AddNewPart<ThemePart>("rId5");
        var theme = new A.Theme
        {
            Name = "Outlook Email PPTX Theme"
        };

        var themeElements = new A.ThemeElements(
            new A.ColorScheme(
                new A.Dark1Color(new A.SystemColor
                {
                    Val = A.SystemColorValues.WindowText,
                    LastColor = "000000"
                }),
                new A.Light1Color(new A.SystemColor
                {
                    Val = A.SystemColorValues.Window,
                    LastColor = "FFFFFF"
                }),
                new A.Dark2Color(new A.RgbColorModelHex
                {
                    Val = DefaultTextColorHex
                }),
                new A.Light2Color(new A.RgbColorModelHex
                {
                    Val = "F7F9FC"
                }),
                new A.Accent1Color(new A.RgbColorModelHex
                {
                    Val = themeColorHex
                }),
                new A.Accent2Color(new A.RgbColorModelHex
                {
                    Val = "5B6573"
                }),
                new A.Accent3Color(new A.RgbColorModelHex
                {
                    Val = "7B8BA6"
                }),
                new A.Accent4Color(new A.RgbColorModelHex
                {
                    Val = "BFC7D5"
                }),
                new A.Accent5Color(new A.RgbColorModelHex
                {
                    Val = "DCE3ED"
                }),
                new A.Accent6Color(new A.RgbColorModelHex
                {
                    Val = "E9EDF4"
                }),
                new A.Hyperlink(new A.RgbColorModelHex
                {
                    Val = "0000FF"
                }),
                new A.FollowedHyperlinkColor(new A.RgbColorModelHex
                {
                    Val = "800080"
                }))
            {
                Name = "Outlook Email PPTX Colors"
            },
            new A.FontScheme(
                new A.MajorFont(
                    new A.LatinFont
                    {
                        Typeface = "Aptos"
                    },
                    new A.EastAsianFont
                    {
                        Typeface = string.Empty
                    },
                    new A.ComplexScriptFont
                    {
                        Typeface = string.Empty
                    }),
                new A.MinorFont(
                    new A.LatinFont
                    {
                        Typeface = "Aptos"
                    },
                    new A.EastAsianFont
                    {
                        Typeface = string.Empty
                    },
                    new A.ComplexScriptFont
                    {
                        Typeface = string.Empty
                    }))
            {
                Name = "Office"
            },
            new A.FormatScheme(
                new A.FillStyleList(
                    new A.SolidFill(new A.SchemeColor
                    {
                        Val = A.SchemeColorValues.PhColor
                    }),
                    new A.NoFill(),
                    new A.PatternFill(),
                    new A.GroupFill()),
                new A.LineStyleList(
                    new A.Outline(
                        new A.SolidFill(new A.SchemeColor
                        {
                            Val = A.SchemeColorValues.PhColor
                        }),
                        new A.PresetDash
                        {
                            Val = A.PresetLineDashValues.Solid
                        })
                    {
                        Width = 9525,
                        CapType = A.LineCapValues.Flat,
                        CompoundLineType = A.CompoundLineValues.Single,
                        Alignment = A.PenAlignmentValues.Center
                    }),
                new A.EffectStyleList(new A.EffectStyle(new A.EffectList())),
                new A.BackgroundFillStyleList(
                    new A.SolidFill(new A.SchemeColor
                    {
                        Val = A.SchemeColorValues.PhColor
                    }),
                    new A.SolidFill(new A.RgbColorModelHex
                    {
                        Val = "FFFFFF"
                    })))
            {
                Name = "Office"
            });

        theme.Append(themeElements);
        theme.Append(new A.ObjectDefaults());
        theme.Append(new A.ExtraColorSchemeList());

        themePart.Theme = theme;
        themePart.Theme.Save();
        return themePart;
    }

    private static long ToEmu(double inches) => (long)Math.Round(inches * 914400d);

    private static string FormatBinarySize(int sizeInBytes)
    {
        const int oneMiB = 1024 * 1024;
        return sizeInBytes % oneMiB == 0
                   ? $"{sizeInBytes / oneMiB} MiB"
                   : $"{sizeInBytes} bytes";
    }

    private enum PptxSlideKind
    {
        Title,
        Content
    }

    private sealed record NormalizedSlideSpec(PptxSlideKind Kind, string Title, string? Subtitle, string[] BodyParagraphs, string[] Bullets);
}
