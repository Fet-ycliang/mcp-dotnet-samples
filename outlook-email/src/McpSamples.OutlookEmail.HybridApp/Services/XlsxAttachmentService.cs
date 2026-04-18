using System.Globalization;
using System.Text.RegularExpressions;

using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;

using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Models;

using A = DocumentFormat.OpenXml.Drawing;
using C = DocumentFormat.OpenXml.Drawing.Charts;
using S = DocumentFormat.OpenXml.Spreadsheet;
using Xdr = DocumentFormat.OpenXml.Drawing.Spreadsheet;

namespace McpSamples.OutlookEmail.HybridApp.Services;

/// <summary>
/// 提供 Excel 報表附件產生功能的介面。
/// </summary>
public interface IXlsxAttachmentService
{
    /// <summary>
    /// 產生 Excel 附件並暫存於伺服器端。
    /// </summary>
    /// <param name="request">活頁簿要求。</param>
    /// <param name="cancellationToken"><see cref="CancellationToken"/> 執行個體。</param>
    /// <returns>產生結果。</returns>
    Task<XlsxAttachmentResult> GenerateAttachmentAsync(XlsxWorkbookRequest request, CancellationToken cancellationToken = default);
}

/// <summary>
/// 表示 Excel 報表附件產生服務。
/// </summary>
/// <param name="generatedAttachmentStore"><see cref="IGeneratedAttachmentStore"/> 執行個體。</param>
/// <param name="settings"><see cref="OutlookEmailAppSettings"/> 執行個體。</param>
/// <param name="logger"><see cref="ILogger{TCategoryName}"/> 執行個體。</param>
public class XlsxAttachmentService(IGeneratedAttachmentStore generatedAttachmentStore, OutlookEmailAppSettings settings, ILogger<XlsxAttachmentService> logger) : IXlsxAttachmentService
{
    private const string DefaultFileName = "report.xlsx";
    private const string DefaultThemeColorHex = "2F5597";
    private const string DefaultContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private const string DefaultLanguage = "zh-TW";
    private const int MaxSheets = 10;
    private const int MaxTablesPerSheet = 6;
    private const int MaxChartsPerSheet = 8;
    private const int MaxRowsPerTable = 500;
    private const int MaxColumnsPerTable = 20;
    private const int MaxTextLength = 2000;
    private const uint ChartHeightRows = 18;
    private const uint ChartWidthColumns = 10;
    private static readonly Regex SheetNameInvalidCharsRegex = new(@"[\[\]\*:/\\\?]", RegexOptions.CultureInvariant | RegexOptions.Compiled);
    private static readonly string[] FallbackPalette = [ "5B9BD5", "70AD47", "ED7D31", "A5A5A5", "FFC000", "4472C4" ];

    private readonly int _maxAttachmentSizeBytes = settings.MaxAttachmentSizeBytes > 0
                                                       ? settings.MaxAttachmentSizeBytes
                                                       : OutlookEmailAppSettings.DefaultMaxAttachmentSizeBytes;

    /// <inheritdoc />
    public Task<XlsxAttachmentResult> GenerateAttachmentAsync(XlsxWorkbookRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        cancellationToken.ThrowIfCancellationRequested();

        var workbook = NormalizeWorkbook(request);
        var xlsxBytes = CreateWorkbookBytes(workbook, cancellationToken);
        if (xlsxBytes.Length > _maxAttachmentSizeBytes)
        {
            throw new ArgumentException($"產生的 Excel 大小不得超過 {FormatBinarySize(_maxAttachmentSizeBytes)}。請減少工作表、資料列或圖表數量。", nameof(request));
        }

        var attachmentId = generatedAttachmentStore.Save(workbook.FileName, DefaultContentType, xlsxBytes);
        var totalTableCount = workbook.Sheets.Sum(static sheet => sheet.Tables.Length);
        var totalChartCount = workbook.Sheets.Sum(static sheet => sheet.Charts.Length);

        logger.LogInformation("已產生 Excel 附件 {FileName}，共 {SheetCount} 張工作表、{TableCount} 個資料表、{ChartCount} 張圖表，大小 {SizeBytes} bytes，識別碼 {AttachmentId}。",
                              workbook.FileName,
                              workbook.Sheets.Length,
                              totalTableCount,
                              totalChartCount,
                              xlsxBytes.Length,
                              attachmentId);

        return Task.FromResult(new XlsxAttachmentResult
        {
            GeneratedAttachmentId = attachmentId,
            Name = workbook.FileName,
            ContentType = DefaultContentType,
            SheetCount = workbook.Sheets.Length,
            TableCount = totalTableCount,
            ChartCount = totalChartCount,
            SizeBytes = xlsxBytes.Length,
            ExpiresInMinutes = generatedAttachmentStore.ExpirationMinutes,
            UsageHint = "將 generatedAttachmentId 放入 send_email.generatedAttachmentIds 即可把這份 Excel 報表當成附件寄出。",
            Warnings = workbook.Warnings
        });
    }

    private static NormalizedWorkbook NormalizeWorkbook(XlsxWorkbookRequest request)
    {
        var warnings = new List<string>();
        var normalizedSheets = NormalizeSheets(request.Sheets, warnings);
        if (normalizedSheets.Sum(static sheet => sheet.Charts.Length) == 0)
        {
            warnings.Add("這份活頁簿未包含任何圖表，輸出將只包含資料表。");
        }

        return new NormalizedWorkbook(
            NormalizeFileName(request.FileName),
            NormalizeHexColor(request.ThemeColorHex, DefaultThemeColorHex, nameof(request.ThemeColorHex)),
            normalizedSheets,
            [.. warnings]);
    }

    private static NormalizedSheetSpec[] NormalizeSheets(XlsxSheetSpec[]? sheets, List<string> warnings)
    {
        if (sheets is null || sheets.Length == 0)
        {
            throw new ArgumentException("至少需要一張工作表。", nameof(sheets));
        }

        if (sheets.Length > MaxSheets)
        {
            throw new ArgumentException($"工作表數量不得超過 {MaxSheets} 張。", nameof(sheets));
        }

        var usedSheetNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var normalizedSheets = new NormalizedSheetSpec[sheets.Length];
        for (var i = 0; i < sheets.Length; i++)
        {
            var sheet = sheets[i] ?? throw new ArgumentException($"索引 {i} 的工作表不得為 null。", nameof(sheets));
            var sheetPrefix = $"{nameof(sheets)}[{i}]";
            var sheetName = NormalizeSheetName(sheet.Name, i, usedSheetNames, warnings);
            var title = NormalizeOptionalText(sheet.Title, $"{sheetPrefix}.{nameof(XlsxSheetSpec.Title)}");
            var tables = NormalizeTables(sheet.Tables, $"{sheetPrefix}.{nameof(XlsxSheetSpec.Tables)}");
            var charts = NormalizeCharts(sheet.Charts, tables, $"{sheetPrefix}.{nameof(XlsxSheetSpec.Charts)}");

            normalizedSheets[i] = new NormalizedSheetSpec(sheetName, title, tables, charts);
        }

        return normalizedSheets;
    }

    private static NormalizedTableSpec[] NormalizeTables(XlsxTableSpec[]? tables, string parameterName)
    {
        if (tables is null || tables.Length == 0)
        {
            throw new ArgumentException("每張工作表至少需要一個資料表。", parameterName);
        }

        if (tables.Length > MaxTablesPerSheet)
        {
            throw new ArgumentException($"每張工作表的資料表數量不得超過 {MaxTablesPerSheet} 個。", parameterName);
        }

        var tableNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var normalizedTables = new NormalizedTableSpec[tables.Length];
        for (var i = 0; i < tables.Length; i++)
        {
            var table = tables[i] ?? throw new ArgumentException($"索引 {i} 的資料表不得為 null。", parameterName);
            var tablePrefix = $"{parameterName}[{i}]";
            var tableName = NormalizeRequiredText(table.Name, $"{tablePrefix}.{nameof(XlsxTableSpec.Name)}");
            if (!tableNames.Add(tableName))
            {
                throw new ArgumentException($"資料表名稱 '{tableName}' 重複。", $"{tablePrefix}.{nameof(XlsxTableSpec.Name)}");
            }

            var columns = NormalizeColumns(table.Columns, $"{tablePrefix}.{nameof(XlsxTableSpec.Columns)}");
            var rows = NormalizeRows(table.Rows, columns, $"{tablePrefix}.{nameof(XlsxTableSpec.Rows)}");

            normalizedTables[i] = new NormalizedTableSpec(tableName, columns, rows);
        }

        return normalizedTables;
    }

    private static NormalizedColumnSpec[] NormalizeColumns(XlsxTableColumnSpec[]? columns, string parameterName)
    {
        if (columns is null || columns.Length == 0)
        {
            throw new ArgumentException("每個資料表至少需要一個欄位。", parameterName);
        }

        if (columns.Length > MaxColumnsPerTable)
        {
            throw new ArgumentException($"每個資料表的欄位數量不得超過 {MaxColumnsPerTable} 個。", parameterName);
        }

        var columnNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var normalizedColumns = new NormalizedColumnSpec[columns.Length];
        for (var i = 0; i < columns.Length; i++)
        {
            var column = columns[i] ?? throw new ArgumentException($"索引 {i} 的欄位不得為 null。", parameterName);
            var columnPrefix = $"{parameterName}[{i}]";
            var columnName = NormalizeRequiredText(column.Name, $"{columnPrefix}.{nameof(XlsxTableColumnSpec.Name)}");
            if (!columnNames.Add(columnName))
            {
                throw new ArgumentException($"欄位名稱 '{columnName}' 重複。", $"{columnPrefix}.{nameof(XlsxTableColumnSpec.Name)}");
            }

            normalizedColumns[i] = new NormalizedColumnSpec(columnName, NormalizeColumnType(column.Type, $"{columnPrefix}.{nameof(XlsxTableColumnSpec.Type)}"));
        }

        return normalizedColumns;
    }

    private static NormalizedCellValue[][] NormalizeRows(string[][]? rows, NormalizedColumnSpec[] columns, string parameterName)
    {
        if (rows is null || rows.Length == 0)
        {
            throw new ArgumentException("每個資料表至少需要一列資料。", parameterName);
        }

        if (rows.Length > MaxRowsPerTable)
        {
            throw new ArgumentException($"每個資料表的資料列數不得超過 {MaxRowsPerTable} 列。", parameterName);
        }

        var normalizedRows = new NormalizedCellValue[rows.Length][];
        for (var rowIndex = 0; rowIndex < rows.Length; rowIndex++)
        {
            var row = rows[rowIndex] ?? throw new ArgumentException($"索引 {rowIndex} 的資料列不得為 null。", parameterName);
            if (row.Length != columns.Length)
            {
                throw new ArgumentException($"索引 {rowIndex} 的資料列欄位數必須等於 columns 數量 {columns.Length}。", $"{parameterName}[{rowIndex}]");
            }

            var normalizedRow = new NormalizedCellValue[row.Length];
            for (var columnIndex = 0; columnIndex < row.Length; columnIndex++)
            {
                normalizedRow[columnIndex] = NormalizeCellValue(
                    row[columnIndex],
                    columns[columnIndex],
                    $"{parameterName}[{rowIndex}][{columnIndex}]");
            }

            normalizedRows[rowIndex] = normalizedRow;
        }

        return normalizedRows;
    }

    private static NormalizedChartSpec[] NormalizeCharts(XlsxChartSpec[]? charts, NormalizedTableSpec[] tables, string parameterName)
    {
        if (charts is null || charts.Length == 0)
        {
            return [];
        }

        if (charts.Length > MaxChartsPerSheet)
        {
            throw new ArgumentException($"每張工作表的圖表數量不得超過 {MaxChartsPerSheet} 張。", parameterName);
        }

        var tableLookup = tables.ToDictionary(static table => table.Name, StringComparer.OrdinalIgnoreCase);
        var normalizedCharts = new NormalizedChartSpec[charts.Length];
        for (var i = 0; i < charts.Length; i++)
        {
            var chart = charts[i] ?? throw new ArgumentException($"索引 {i} 的圖表不得為 null。", parameterName);
            var chartPrefix = $"{parameterName}[{i}]";
            var kind = NormalizeChartKind(chart.Kind, $"{chartPrefix}.{nameof(XlsxChartSpec.Kind)}");
            var title = NormalizeRequiredText(chart.Title, $"{chartPrefix}.{nameof(XlsxChartSpec.Title)}");
            var tableName = NormalizeRequiredText(chart.TableName, $"{chartPrefix}.{nameof(XlsxChartSpec.TableName)}");
            if (!tableLookup.TryGetValue(tableName, out var table))
            {
                throw new ArgumentException($"找不到資料表 '{tableName}'。", $"{chartPrefix}.{nameof(XlsxChartSpec.TableName)}");
            }

            var categoryColumn = NormalizeRequiredText(chart.CategoryColumn, $"{chartPrefix}.{nameof(XlsxChartSpec.CategoryColumn)}");
            var categorySpec = ResolveColumn(table, categoryColumn, $"{chartPrefix}.{nameof(XlsxChartSpec.CategoryColumn)}");
            var valueColumns = NormalizeValueColumns(chart.ValueColumns, table, kind, $"{chartPrefix}.{nameof(XlsxChartSpec.ValueColumns)}");

            normalizedCharts[i] = new NormalizedChartSpec(kind, title, table.Name, categorySpec.Name, valueColumns);
        }

        return normalizedCharts;
    }

    private static string[] NormalizeValueColumns(string[]? valueColumns, NormalizedTableSpec table, XlsxChartKind kind, string parameterName)
    {
        if (valueColumns is null || valueColumns.Length == 0)
        {
            throw new ArgumentException("每張圖表至少要指定一個數值欄位。", parameterName);
        }

        if (kind == XlsxChartKind.Pie && valueColumns.Length != 1)
        {
            throw new ArgumentException("pie 圖表只能指定一個數值欄位。", parameterName);
        }

        var normalizedValueColumns = new string[valueColumns.Length];
        var columnNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < valueColumns.Length; i++)
        {
            var valueColumn = NormalizeRequiredText(valueColumns[i], $"{parameterName}[{i}]");
            if (!columnNames.Add(valueColumn))
            {
                throw new ArgumentException($"數值欄位 '{valueColumn}' 重複。", $"{parameterName}[{i}]");
            }

            var columnSpec = ResolveColumn(table, valueColumn, $"{parameterName}[{i}]");
            if (columnSpec.Type != XlsxColumnType.Number)
            {
                throw new ArgumentException($"欄位 '{columnSpec.Name}' 必須是 number 類型才可用於圖表數值軸。", $"{parameterName}[{i}]");
            }

            normalizedValueColumns[i] = columnSpec.Name;
        }

        return normalizedValueColumns;
    }

    private static NormalizedColumnSpec ResolveColumn(NormalizedTableSpec table, string columnName, string parameterName)
    {
        var column = table.Columns.FirstOrDefault(column => string.Equals(column.Name, columnName, StringComparison.OrdinalIgnoreCase));
        return column ?? throw new ArgumentException($"找不到欄位 '{columnName}'。", parameterName);
    }

    private static XlsxColumnType NormalizeColumnType(string? type, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(type))
        {
            return XlsxColumnType.String;
        }

        return type.Trim().ToLowerInvariant() switch
        {
            "string" => XlsxColumnType.String,
            "number" => XlsxColumnType.Number,
            "date" => XlsxColumnType.Date,
            "boolean" => XlsxColumnType.Boolean,
            _ => throw new ArgumentException("欄位型別只支援 string、number、date、boolean。", parameterName)
        };
    }

    private static XlsxChartKind NormalizeChartKind(string? kind, string parameterName)
    {
        return kind?.Trim().ToLowerInvariant() switch
        {
            "column" => XlsxChartKind.Column,
            "bar" => XlsxChartKind.Bar,
            "line" => XlsxChartKind.Line,
            "pie" => XlsxChartKind.Pie,
            _ => throw new ArgumentException("圖表類型只支援 column、bar、line、pie。", parameterName)
        };
    }

    private static NormalizedCellValue NormalizeCellValue(string? rawValue, NormalizedColumnSpec column, string parameterName)
    {
        var normalized = NormalizeRequiredText(rawValue, parameterName);
        return column.Type switch
        {
            XlsxColumnType.String => new NormalizedCellValue(NormalizedCellKind.Text, normalized, null),
            XlsxColumnType.Date => new NormalizedCellValue(NormalizedCellKind.Text, NormalizeDate(normalized, parameterName), null),
            XlsxColumnType.Boolean => new NormalizedCellValue(NormalizedCellKind.Text, NormalizeBoolean(normalized, parameterName), null),
            XlsxColumnType.Number => new NormalizedCellValue(NormalizedCellKind.Number, normalized, NormalizeNumber(normalized, parameterName)),
            _ => throw new ArgumentOutOfRangeException(nameof(column.Type), column.Type, null)
        };
    }

    private static string NormalizeDate(string value, string parameterName)
    {
        if (DateOnly.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var dateOnly))
        {
            return dateOnly.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces | DateTimeStyles.RoundtripKind, out var dateTimeOffset))
        {
            return dateTimeOffset.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        }

        throw new ArgumentException("date 欄位必須是有效的日期字串，例如 2026-04-18。", parameterName);
    }

    private static string NormalizeBoolean(string value, string parameterName)
    {
        return value.Trim().ToLowerInvariant() switch
        {
            "true" or "1" or "yes" => "TRUE",
            "false" or "0" or "no" => "FALSE",
            _ => throw new ArgumentException("boolean 欄位只支援 true、false、1、0、yes、no。", parameterName)
        };
    }

    private static double NormalizeNumber(string value, string parameterName)
    {
        if (double.TryParse(value, NumberStyles.Float | NumberStyles.AllowThousands, CultureInfo.InvariantCulture, out var number))
        {
            return number;
        }

        throw new ArgumentException("number 欄位必須是有效的數值字串，例如 1234.56。", parameterName);
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

    private static string NormalizeFileName(string? fileName)
    {
        var normalized = string.IsNullOrWhiteSpace(fileName) ? DefaultFileName : fileName.Trim();
        if (normalized.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
        {
            throw new ArgumentException("fileName 包含無效字元。", nameof(fileName));
        }

        if (!normalized.EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase))
        {
            normalized = $"{normalized}.xlsx";
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

    private static string NormalizeSheetName(string? sheetName, int sheetIndex, HashSet<string> usedSheetNames, List<string> warnings)
    {
        var original = string.IsNullOrWhiteSpace(sheetName) ? $"Sheet{sheetIndex + 1}" : sheetName.Trim();
        var sanitized = SheetNameInvalidCharsRegex.Replace(original, "_").Trim();
        if (string.IsNullOrWhiteSpace(sanitized))
        {
            sanitized = $"Sheet{sheetIndex + 1}";
        }

        sanitized = sanitized.Trim('\'');
        sanitized = sanitized.Length > 31 ? sanitized[..31] : sanitized;
        if (string.IsNullOrWhiteSpace(sanitized))
        {
            sanitized = $"Sheet{sheetIndex + 1}";
        }

        var candidate = sanitized;
        var suffix = 2;
        while (!usedSheetNames.Add(candidate))
        {
            var suffixText = $"_{suffix}";
            var maxBaseLength = Math.Max(1, 31 - suffixText.Length);
            candidate = $"{sanitized[..Math.Min(sanitized.Length, maxBaseLength)]}{suffixText}";
            suffix++;
        }

        if (!string.Equals(original, candidate, StringComparison.Ordinal))
        {
            warnings.Add($"工作表名稱 '{original}' 已自動調整為 '{candidate}'。");
        }

        return candidate;
    }

    private static byte[] CreateWorkbookBytes(NormalizedWorkbook workbook, CancellationToken cancellationToken)
    {
        using var stream = new MemoryStream();
        using (var spreadsheetDocument = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
        {
            var workbookPart = spreadsheetDocument.AddWorkbookPart();
            workbookPart.Workbook = new S.Workbook();

            var sheets = workbookPart.Workbook.AppendChild(new S.Sheets());
            uint sheetId = 1;
            foreach (var sheet in workbook.Sheets)
            {
                cancellationToken.ThrowIfCancellationRequested();

                var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                worksheetPart.Worksheet = new S.Worksheet(new S.SheetData());
                var sheetDefinition = new S.Sheet
                {
                    Id = workbookPart.GetIdOfPart(worksheetPart),
                    SheetId = sheetId++,
                    Name = sheet.Name
                };
                sheets.Append(sheetDefinition);

                var placedTables = WriteSheetContent(worksheetPart, sheet);
                if (sheet.Charts.Length > 0)
                {
                    AppendCharts(worksheetPart, sheet, placedTables, workbook.ThemeColorHex, cancellationToken);
                }

                worksheetPart.Worksheet.Save();
            }

            workbookPart.Workbook.Save();
        }

        return stream.ToArray();
    }

    private static Dictionary<string, PlacedTableSpec> WriteSheetContent(WorksheetPart worksheetPart, NormalizedSheetSpec sheet)
    {
        var worksheet = worksheetPart.Worksheet ?? throw new InvalidOperationException("Worksheet is missing.");
        var sheetData = worksheet.GetFirstChild<S.SheetData>() ?? throw new InvalidOperationException("SheetData is missing.");
        var placedTables = new Dictionary<string, PlacedTableSpec>(StringComparer.OrdinalIgnoreCase);

        uint currentRow = 1;
        if (sheet.Title is not null)
        {
            sheetData.Append(CreateTextRow(currentRow, [sheet.Title]));
            currentRow += 2;
        }

        foreach (var table in sheet.Tables)
        {
            var placedTable = WriteTable(sheetData, sheet.Name, table, currentRow);
            placedTables.Add(table.Name, placedTable);
            currentRow = placedTable.NextAvailableRow;
        }

        return placedTables;
    }

    private static PlacedTableSpec WriteTable(S.SheetData sheetData, string sheetName, NormalizedTableSpec table, uint startRowIndex)
    {
        var titleRow = CreateTextRow(startRowIndex, [table.Name]);
        sheetData.Append(titleRow);

        var headerRowIndex = startRowIndex + 1;
        var headerRow = CreateTextRow(headerRowIndex, table.Columns.Select(static column => column.Name));
        sheetData.Append(headerRow);

        var placedColumns = new Dictionary<string, PlacedColumnSpec>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < table.Columns.Length; i++)
        {
            placedColumns.Add(table.Columns[i].Name, new PlacedColumnSpec(i, table.Columns[i].Type));
        }

        uint rowIndex = headerRowIndex + 1;
        foreach (var rowValues in table.Rows)
        {
            var row = new S.Row
            {
                RowIndex = rowIndex
            };

            foreach (var cellValue in rowValues)
            {
                row.Append(cellValue.Kind == NormalizedCellKind.Number
                               ? CreateNumberCell(cellValue.NumberValue!.Value)
                               : CreateTextCell(cellValue.TextValue));
            }

            sheetData.Append(row);
            rowIndex++;
        }

        var firstDataRowIndex = headerRowIndex + 1;
        var lastDataRowIndex = rowIndex - 1;
        return new PlacedTableSpec(sheetName, table.Name, headerRowIndex, firstDataRowIndex, lastDataRowIndex, rowIndex + 2, placedColumns);
    }

    private static void AppendCharts(WorksheetPart worksheetPart, NormalizedSheetSpec sheet, Dictionary<string, PlacedTableSpec> placedTables, string themeColorHex, CancellationToken cancellationToken)
    {
        var worksheet = worksheetPart.Worksheet ?? throw new InvalidOperationException("Worksheet is missing.");
        var drawingsPart = worksheetPart.AddNewPart<DrawingsPart>();
        drawingsPart.WorksheetDrawing = new Xdr.WorksheetDrawing();

        var drawingRelationshipId = worksheetPart.GetIdOfPart(drawingsPart) ?? throw new InvalidOperationException("Drawing relationship ID is missing.");
        worksheet.Append(new S.Drawing
        {
            Id = drawingRelationshipId
        });

        var nextChartRow = placedTables.Values.Max(static table => table.NextAvailableRow);
        uint drawingObjectId = 1;
        foreach (var chart in sheet.Charts)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var table = placedTables[chart.TableName];
            var chartPart = drawingsPart.AddNewPart<ChartPart>();
            BuildChartPart(chartPart, table, chart, themeColorHex);

            var chartRelationshipId = drawingsPart.GetIdOfPart(chartPart) ?? throw new InvalidOperationException("Chart relationship ID is missing.");
            drawingsPart.WorksheetDrawing.Append(CreateChartAnchor(chartRelationshipId, drawingObjectId++, chart.Title, nextChartRow));
            nextChartRow += ChartHeightRows;
        }

        drawingsPart.WorksheetDrawing.Save();
    }

    private static void BuildChartPart(ChartPart chartPart, PlacedTableSpec table, NormalizedChartSpec chart, string themeColorHex)
    {
        var chartSpace = new C.ChartSpace();
        chartSpace.Append(new C.EditingLanguage
        {
            Val = DefaultLanguage
        });

        var chartElement = new C.Chart();
        chartElement.Append(CreateChartTitle(chart.Title));
        chartElement.Append(new C.AutoTitleDeleted
        {
            Val = false
        });

        var plotArea = new C.PlotArea();
        plotArea.Append(new C.Layout());

        if (chart.Kind == XlsxChartKind.Pie)
        {
            plotArea.Append(CreatePieChart(table, chart, themeColorHex));
        }
        else
        {
            const uint categoryAxisId = 48650112U;
            const uint valueAxisId = 48672768U;

            plotArea.Append(chart.Kind switch
            {
                XlsxChartKind.Column => CreateBarChart(table, chart, themeColorHex, isBar: false, categoryAxisId, valueAxisId),
                XlsxChartKind.Bar => CreateBarChart(table, chart, themeColorHex, isBar: true, categoryAxisId, valueAxisId),
                XlsxChartKind.Line => CreateLineChart(table, chart, themeColorHex, categoryAxisId, valueAxisId),
                _ => throw new ArgumentOutOfRangeException(nameof(chart.Kind), chart.Kind, null)
            });
            plotArea.Append(CreateCategoryAxis(chart.Kind == XlsxChartKind.Bar ? C.AxisPositionValues.Left : C.AxisPositionValues.Bottom, categoryAxisId, valueAxisId));
            plotArea.Append(CreateValueAxis(chart.Kind == XlsxChartKind.Bar ? C.AxisPositionValues.Bottom : C.AxisPositionValues.Left, valueAxisId, categoryAxisId));
        }

        chartElement.Append(plotArea);
        chartElement.Append(new C.Legend(new C.LegendPosition
        {
            Val = C.LegendPositionValues.Right
        }, new C.Layout()));
        chartElement.Append(new C.PlotVisibleOnly
        {
            Val = true
        });
        chartElement.Append(new C.DisplayBlanksAs
        {
            Val = C.DisplayBlanksAsValues.Gap
        });

        chartSpace.Append(chartElement);
        chartPart.ChartSpace = chartSpace;
        chartPart.ChartSpace.Save();
    }

    private static C.BarChart CreateBarChart(PlacedTableSpec table, NormalizedChartSpec chart, string themeColorHex, bool isBar, uint categoryAxisId, uint valueAxisId)
    {
        var barChart = new C.BarChart(
            new C.BarDirection
            {
                Val = isBar ? C.BarDirectionValues.Bar : C.BarDirectionValues.Column
            },
            new C.BarGrouping
            {
                Val = C.BarGroupingValues.Clustered
            },
            new C.VaryColors
            {
                Val = false
            });

        var colors = CreateSeriesColors(themeColorHex, chart.ValueColumns.Length);
        for (var i = 0; i < chart.ValueColumns.Length; i++)
        {
            var series = new C.BarChartSeries(
                new C.Index
                {
                    Val = (uint)i
                },
                new C.Order
                {
                    Val = (uint)i
                },
                new C.SeriesText(CreateStringReference(GetHeaderFormula(table, chart.ValueColumns[i]))),
                CreateCategoryAxisData(table, chart.CategoryColumn),
                new C.Values(CreateNumberReference(GetDataFormula(table, chart.ValueColumns[i]))));

            series.Append(CreateSolidSeriesShape(colors[i]));
            barChart.Append(series);
        }

        barChart.Append(new C.AxisId
        {
            Val = categoryAxisId
        });
        barChart.Append(new C.AxisId
        {
            Val = valueAxisId
        });

        return barChart;
    }

    private static C.LineChart CreateLineChart(PlacedTableSpec table, NormalizedChartSpec chart, string themeColorHex, uint categoryAxisId, uint valueAxisId)
    {
        var lineChart = new C.LineChart(
            new C.Grouping
            {
                Val = C.GroupingValues.Standard
            },
            new C.VaryColors
            {
                Val = false
            });

        var colors = CreateSeriesColors(themeColorHex, chart.ValueColumns.Length);
        for (var i = 0; i < chart.ValueColumns.Length; i++)
        {
            var series = new C.LineChartSeries(
                new C.Index
                {
                    Val = (uint)i
                },
                new C.Order
                {
                    Val = (uint)i
                },
                new C.SeriesText(CreateStringReference(GetHeaderFormula(table, chart.ValueColumns[i]))),
                CreateCategoryAxisData(table, chart.CategoryColumn),
                new C.Values(CreateNumberReference(GetDataFormula(table, chart.ValueColumns[i]))),
                new C.Marker(new C.Symbol
                {
                    Val = C.MarkerStyleValues.Circle
                }));

            series.Append(CreateLineSeriesShape(colors[i]));
            lineChart.Append(series);
        }

        lineChart.Append(new C.AxisId
        {
            Val = categoryAxisId
        });
        lineChart.Append(new C.AxisId
        {
            Val = valueAxisId
        });

        return lineChart;
    }

    private static C.PieChart CreatePieChart(PlacedTableSpec table, NormalizedChartSpec chart, string themeColorHex)
    {
        var pieChart = new C.PieChart(
            new C.VaryColors
            {
                Val = true
            });

        var valueColumn = chart.ValueColumns[0];
        var series = new C.PieChartSeries(
            new C.Index
            {
                Val = 0U
            },
            new C.Order
            {
                Val = 0U
            },
            new C.SeriesText(CreateStringReference(GetHeaderFormula(table, valueColumn))),
            CreateCategoryAxisData(table, chart.CategoryColumn),
            new C.Values(CreateNumberReference(GetDataFormula(table, valueColumn))));

        series.Append(CreateSolidSeriesShape(CreateSeriesColors(themeColorHex, 1)[0]));
        pieChart.Append(series);
        return pieChart;
    }

    private static C.CategoryAxisData CreateCategoryAxisData(PlacedTableSpec table, string categoryColumn)
    {
        var column = table.ColumnsByName[categoryColumn];
        return column.Type == XlsxColumnType.Number
                   ? new C.CategoryAxisData(CreateNumberReference(GetDataFormula(table, categoryColumn)))
                   : new C.CategoryAxisData(CreateStringReference(GetDataFormula(table, categoryColumn)));
    }

    private static C.CategoryAxis CreateCategoryAxis(C.AxisPositionValues axisPosition, uint categoryAxisId, uint valueAxisId)
    {
        return new C.CategoryAxis(
            new C.AxisId
            {
                Val = categoryAxisId
            },
            new C.Scaling(new C.Orientation
            {
                Val = C.OrientationValues.MinMax
            }),
            new C.Delete
            {
                Val = false
            },
            new C.AxisPosition
            {
                Val = axisPosition
            },
            new C.TickLabelPosition
            {
                Val = C.TickLabelPositionValues.NextTo
            },
            new C.CrossingAxis
            {
                Val = valueAxisId
            },
            new C.Crosses
            {
                Val = C.CrossesValues.AutoZero
            },
            new C.AutoLabeled
            {
                Val = true
            },
            new C.LabelAlignment
            {
                Val = C.LabelAlignmentValues.Center
            },
            new C.LabelOffset
            {
                Val = 100
            });
    }

    private static C.ValueAxis CreateValueAxis(C.AxisPositionValues axisPosition, uint valueAxisId, uint categoryAxisId)
    {
        return new C.ValueAxis(
            new C.AxisId
            {
                Val = valueAxisId
            },
            new C.Scaling(new C.Orientation
            {
                Val = C.OrientationValues.MinMax
            }),
            new C.Delete
            {
                Val = false
            },
            new C.AxisPosition
            {
                Val = axisPosition
            },
            new C.MajorGridlines(),
            new C.NumberingFormat
            {
                FormatCode = "General",
                SourceLinked = true
            },
            new C.TickLabelPosition
            {
                Val = C.TickLabelPositionValues.NextTo
            },
            new C.CrossingAxis
            {
                Val = categoryAxisId
            },
            new C.Crosses
            {
                Val = C.CrossesValues.AutoZero
            },
            new C.CrossBetween
            {
                Val = C.CrossBetweenValues.Between
            });
    }

    private static C.Title CreateChartTitle(string title)
    {
        return new C.Title(
            new C.ChartText(
                new C.RichText(
                    new A.BodyProperties(),
                    new A.ListStyle(),
                    new A.Paragraph(
                        new A.Run(
                            new A.RunProperties
                            {
                                Language = DefaultLanguage
                            },
                            new A.Text(title)),
                        new A.EndParagraphRunProperties
                        {
                            Language = DefaultLanguage
                        }))),
            new C.Overlay
            {
                Val = false
            });
    }

    private static C.StringReference CreateStringReference(string formula)
    {
        return new C.StringReference
        {
            Formula = new C.Formula(formula)
        };
    }

    private static C.NumberReference CreateNumberReference(string formula)
    {
        return new C.NumberReference
        {
            Formula = new C.Formula(formula)
        };
    }

    private static C.ChartShapeProperties CreateSolidSeriesShape(string colorHex)
    {
        return new C.ChartShapeProperties(
            new A.SolidFill(new A.RgbColorModelHex
            {
                Val = colorHex
            }),
            new A.Outline(new A.SolidFill(new A.RgbColorModelHex
            {
                Val = colorHex
            })));
    }

    private static C.ChartShapeProperties CreateLineSeriesShape(string colorHex)
    {
        return new C.ChartShapeProperties(
            new A.Outline(
                new A.SolidFill(new A.RgbColorModelHex
                {
                    Val = colorHex
                }))
            {
                Width = 28575
            });
    }

    private static string[] CreateSeriesColors(string themeColorHex, int count)
    {
        var colors = new string[count];
        for (var i = 0; i < count; i++)
        {
            colors[i] = i switch
            {
                0 => themeColorHex,
                _ when i - 1 < FallbackPalette.Length => FallbackPalette[i - 1],
                _ => FallbackPalette[(i - 1) % FallbackPalette.Length]
            };
        }

        return colors;
    }

    private static Xdr.TwoCellAnchor CreateChartAnchor(string chartRelationshipId, uint drawingObjectId, string title, uint startRowIndex)
    {
        var graphicFrame = new Xdr.GraphicFrame(
            new Xdr.NonVisualGraphicFrameProperties(
                new Xdr.NonVisualDrawingProperties
                {
                    Id = drawingObjectId,
                    Name = title
                },
                new Xdr.NonVisualGraphicFrameDrawingProperties()),
            new Xdr.Transform(
                new A.Offset
                {
                    X = 0L,
                    Y = 0L
                },
                new A.Extents
                {
                    Cx = 0L,
                    Cy = 0L
                }),
            new A.Graphic(
                new A.GraphicData(
                    new C.ChartReference
                    {
                        Id = chartRelationshipId
                    })
                {
                    Uri = "http://schemas.openxmlformats.org/drawingml/2006/chart"
                }));

        return new Xdr.TwoCellAnchor(
            new Xdr.FromMarker(
                new Xdr.ColumnId("0"),
                new Xdr.ColumnOffset("0"),
                new Xdr.RowId((startRowIndex - 1).ToString(CultureInfo.InvariantCulture)),
                new Xdr.RowOffset("0")),
            new Xdr.ToMarker(
                new Xdr.ColumnId(ChartWidthColumns.ToString(CultureInfo.InvariantCulture)),
                new Xdr.ColumnOffset("0"),
                new Xdr.RowId((startRowIndex + ChartHeightRows - 1).ToString(CultureInfo.InvariantCulture)),
                new Xdr.RowOffset("0")),
            graphicFrame,
            new Xdr.ClientData());
    }

    private static S.Row CreateTextRow(uint rowIndex, IEnumerable<string> values)
    {
        var row = new S.Row
        {
            RowIndex = rowIndex
        };

        foreach (var value in values)
        {
            row.Append(CreateTextCell(value));
        }

        return row;
    }

    private static S.Cell CreateTextCell(string value)
    {
        return new S.Cell
        {
            DataType = S.CellValues.InlineString,
            InlineString = new S.InlineString(new S.Text(value)
            {
                Space = SpaceProcessingModeValues.Preserve
            })
        };
    }

    private static S.Cell CreateNumberCell(double value)
    {
        return new S.Cell
        {
            DataType = S.CellValues.Number,
            CellValue = new S.CellValue(value.ToString(CultureInfo.InvariantCulture))
        };
    }

    private static string GetHeaderFormula(PlacedTableSpec table, string columnName)
    {
        var columnIndex = table.ColumnsByName[columnName].ColumnIndex + 1;
        return $"{QuoteSheetName(table.SheetName)}!${GetColumnName(columnIndex)}${table.HeaderRowIndex}";
    }

    private static string GetDataFormula(PlacedTableSpec table, string columnName)
    {
        var columnIndex = table.ColumnsByName[columnName].ColumnIndex + 1;
        return $"{QuoteSheetName(table.SheetName)}!${GetColumnName(columnIndex)}${table.FirstDataRowIndex}:${GetColumnName(columnIndex)}${table.LastDataRowIndex}";
    }

    private static string QuoteSheetName(string sheetName)
        => $"'{sheetName.Replace("'", "''", StringComparison.Ordinal)}'";

    private static string GetColumnName(int columnIndex)
    {
        if (columnIndex <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(columnIndex));
        }

        var name = string.Empty;
        var dividend = columnIndex;
        while (dividend > 0)
        {
            var modulo = (dividend - 1) % 26;
            name = Convert.ToChar('A' + modulo, CultureInfo.InvariantCulture) + name;
            dividend = (dividend - modulo) / 26;
        }

        return name;
    }

    private static string FormatBinarySize(int sizeInBytes)
    {
        const int oneMiB = 1024 * 1024;
        return sizeInBytes % oneMiB == 0
                   ? $"{sizeInBytes / oneMiB} MiB"
                   : $"{sizeInBytes} bytes";
    }

    private enum XlsxColumnType
    {
        String,
        Number,
        Date,
        Boolean
    }

    private enum XlsxChartKind
    {
        Column,
        Bar,
        Line,
        Pie
    }

    private enum NormalizedCellKind
    {
        Text,
        Number
    }

    private sealed record NormalizedWorkbook(string FileName, string ThemeColorHex, NormalizedSheetSpec[] Sheets, string[] Warnings);

    private sealed record NormalizedSheetSpec(string Name, string? Title, NormalizedTableSpec[] Tables, NormalizedChartSpec[] Charts);

    private sealed record NormalizedTableSpec(string Name, NormalizedColumnSpec[] Columns, NormalizedCellValue[][] Rows);

    private sealed record NormalizedColumnSpec(string Name, XlsxColumnType Type);

    private sealed record NormalizedCellValue(NormalizedCellKind Kind, string TextValue, double? NumberValue);

    private sealed record NormalizedChartSpec(XlsxChartKind Kind, string Title, string TableName, string CategoryColumn, string[] ValueColumns);

    private sealed record PlacedTableSpec(string SheetName,
                                          string TableName,
                                          uint HeaderRowIndex,
                                          uint FirstDataRowIndex,
                                          uint LastDataRowIndex,
                                          uint NextAvailableRow,
                                          IReadOnlyDictionary<string, PlacedColumnSpec> ColumnsByName);

    private sealed record PlacedColumnSpec(int ColumnIndex, XlsxColumnType Type);
}
