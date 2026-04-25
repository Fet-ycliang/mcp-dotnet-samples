using McpSamples.OutlookEmail.HybridApp.Services;

using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace McpSamples.OutlookEmail.Tests.Services;

public sealed class GeneratedAttachmentStoreTests : IDisposable
{
    private readonly MemoryCache _cache;
    private readonly GeneratedAttachmentStore _store;

    public GeneratedAttachmentStoreTests()
    {
        _cache = new MemoryCache(Options.Create(new MemoryCacheOptions()));
        _store = new GeneratedAttachmentStore(_cache);
    }

    public void Dispose() => _cache.Dispose();

    [Fact]
    public void Save_NullName_ThrowsArgumentException()
    {
        Assert.ThrowsAny<ArgumentException>(() => _store.Save(null!, "application/pdf", [0x01]));
    }

    [Fact]
    public void Save_EmptyName_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => _store.Save("   ", "application/pdf", [0x01]));
    }

    [Fact]
    public void Save_NullContentType_ThrowsArgumentException()
    {
        Assert.ThrowsAny<ArgumentException>(() => _store.Save("file.pdf", null!, [0x01]));
    }

    [Fact]
    public void Save_NullContentBytes_ThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => _store.Save("file.pdf", "application/pdf", null!));
    }

    [Fact]
    public void Save_ValidInput_ReturnsGuidId()
    {
        var id = _store.Save("file.pdf", "application/pdf", [0x01, 0x02]);

        Assert.False(string.IsNullOrWhiteSpace(id));
        Assert.True(Guid.TryParse(id, out _));
    }

    [Fact]
    public void GetRequired_NullAttachmentId_ThrowsArgumentException()
    {
        Assert.ThrowsAny<ArgumentException>(() => _store.GetRequired(null!, "param"));
    }

    [Fact]
    public void GetRequired_UnknownId_ThrowsArgumentException()
    {
        var ex = Assert.Throws<ArgumentException>(() => _store.GetRequired("nonexistent-id", "param"));

        Assert.Contains("不存在或已過期", ex.Message);
    }

    [Fact]
    public void SaveThenGetRequired_Roundtrip_ReturnsContent()
    {
        byte[] bytes = [0x01, 0x02, 0x03];
        var id = _store.Save("report.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", bytes);

        var result = _store.GetRequired(id, "param");

        Assert.Equal("report.xlsx", result.Name);
        Assert.Equal("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", result.ContentType);
        Assert.Equal(bytes, result.ContentBytes);
    }
}
