using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Models;
using McpSamples.OutlookEmail.HybridApp.Services;

using Microsoft.Extensions.Logging.Abstractions;

using NSubstitute;

namespace McpSamples.OutlookEmail.Tests.Services;

public sealed class XlsxAttachmentServiceTests
{
    private readonly IGeneratedAttachmentStore _store;
    private readonly XlsxAttachmentService _service;

    public XlsxAttachmentServiceTests()
    {
        _store = Substitute.For<IGeneratedAttachmentStore>();
        _store.ExpirationMinutes.Returns(60);
        _store.Save(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<byte[]>()).Returns("test-id");

        _service = new XlsxAttachmentService(_store, new OutlookEmailAppSettings(), NullLogger<XlsxAttachmentService>.Instance);
    }

    [Fact]
    public async Task GenerateAttachment_NullRequest_ThrowsArgumentNullException()
    {
        await Assert.ThrowsAsync<ArgumentNullException>(() => _service.GenerateAttachmentAsync(null!));
    }

    [Fact]
    public async Task EmptySheets_ThrowsArgumentException()
    {
        var request = new XlsxWorkbookRequest { Sheets = [] };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task TooManySheets_ThrowsArgumentException()
    {
        var sheets = Enumerable.Range(1, 11).Select(i => MakeMinimalSheet($"Sheet{i}")).ToArray();
        var request = new XlsxWorkbookRequest { Sheets = sheets };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task DuplicateTableName_ThrowsArgumentException()
    {
        var table1 = MakeMinimalTable("SameTable");
        var table2 = MakeMinimalTable("SameTable");
        var request = new XlsxWorkbookRequest
        {
            Sheets = [new XlsxSheetSpec { Name = "Sheet1", Tables = [table1, table2] }]
        };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    private static readonly string[] SingleValRow = ["val"];

    [Fact]
    public async Task TooManyRows_ThrowsArgumentException()
    {
        var rows = Enumerable.Range(1, 501).Select(_ => SingleValRow).ToArray();
        var table = new XlsxTableSpec
        {
            Name = "T",
            Columns = [new XlsxTableColumnSpec { Name = "Col", Type = "string" }],
            Rows = rows
        };
        var request = new XlsxWorkbookRequest { Sheets = [new XlsxSheetSpec { Name = "S", Tables = [table] }] };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task PieChart_MultipleValueColumns_ThrowsArgumentException()
    {
        var table = MakeNumericTable("T");
        var chart = new XlsxChartSpec
        {
            Kind = "pie",
            Title = "Pie",
            TableName = "T",
            CategoryColumn = "Name",
            ValueColumns = ["Val1", "Val2"]
        };
        var request = new XlsxWorkbookRequest
        {
            Sheets = [new XlsxSheetSpec { Name = "S", Tables = [table], Charts = [chart] }]
        };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task InvalidColumnType_ThrowsArgumentException()
    {
        var table = new XlsxTableSpec
        {
            Name = "T",
            Columns = [new XlsxTableColumnSpec { Name = "Col", Type = "invalid" }],
            Rows = [["val"]]
        };
        var request = new XlsxWorkbookRequest { Sheets = [new XlsxSheetSpec { Name = "S", Tables = [table] }] };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task InvalidHexColor_ThrowsArgumentException()
    {
        var request = new XlsxWorkbookRequest
        {
            ThemeColorHex = "ZZZZZZ",
            Sheets = [MakeMinimalSheet("S")]
        };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    private static XlsxSheetSpec MakeMinimalSheet(string name) => new()
    {
        Name = name,
        Tables = [MakeMinimalTable("T")]
    };

    private static XlsxTableSpec MakeMinimalTable(string name) => new()
    {
        Name = name,
        Columns = [new XlsxTableColumnSpec { Name = "Col", Type = "string" }],
        Rows = [["val"]]
    };

    private static XlsxTableSpec MakeNumericTable(string name) => new()
    {
        Name = name,
        Columns =
        [
            new XlsxTableColumnSpec { Name = "Name", Type = "string" },
            new XlsxTableColumnSpec { Name = "Val1", Type = "number" },
            new XlsxTableColumnSpec { Name = "Val2", Type = "number" }
        ],
        Rows = [["Alpha", "100", "200"]]
    };
}
