using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Models;
using McpSamples.OutlookEmail.HybridApp.Services;

using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Kiota.Abstractions;

using NSubstitute;

namespace McpSamples.OutlookEmail.Tests.Services;

public sealed class OutlookEmailServiceTests : IDisposable
{
    private readonly IGeneratedAttachmentStore _store;
    private readonly Microsoft.Graph.GraphServiceClient _graph;
    private readonly OutlookEmailService _service;

    public OutlookEmailServiceTests()
    {
        _store = Substitute.For<IGeneratedAttachmentStore>();
        _store.ExpirationMinutes.Returns(60);

        var adapter = Substitute.For<IRequestAdapter>();
        adapter.BaseUrl = "https://graph.microsoft.com/v1.0";
        _graph = new Microsoft.Graph.GraphServiceClient(adapter);

        _service = new OutlookEmailService(_graph, new OutlookEmailAppSettings(), _store, NullLogger<OutlookEmailService>.Instance);
    }

    public void Dispose() => _graph.Dispose();

    [Fact]
    public async Task SendEmail_NullTitle_ThrowsArgumentException()
    {
        await Assert.ThrowsAnyAsync<ArgumentException>(() =>
            _service.SendEmailAsync(null!, "body", "sender@example.com", "to@example.com"));
    }

    [Fact]
    public async Task SendEmail_NullBody_ThrowsArgumentException()
    {
        await Assert.ThrowsAnyAsync<ArgumentException>(() =>
            _service.SendEmailAsync("title", null!, "sender@example.com", "to@example.com"));
    }

    [Fact]
    public async Task SendEmail_NullSender_ThrowsArgumentException()
    {
        await Assert.ThrowsAnyAsync<ArgumentException>(() =>
            _service.SendEmailAsync("title", "body", null!, "to@example.com"));
    }

    [Fact]
    public async Task SendEmail_NullRecipients_ThrowsArgumentException()
    {
        await Assert.ThrowsAnyAsync<ArgumentException>(() =>
            _service.SendEmailAsync("title", "body", "sender@example.com", null!));
    }

    [Fact]
    public async Task SendEmail_SenderNotInAllowlist_ThrowsArgumentException()
    {
        var settings = new OutlookEmailAppSettings
        {
            AllowedSenders = ["allowed@example.com"]
        };
        var service = new OutlookEmailService(_graph, settings, _store, NullLogger<OutlookEmailService>.Instance);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.SendEmailAsync("title", "body", "notallowed@example.com", "to@example.com"));
    }

    [Fact]
    public async Task SendEmail_InvalidBase64Attachment_ThrowsArgumentException()
    {
        var attachment = new OutlookEmailAttachment
        {
            Name = "file.txt",
            ContentType = "text/plain",
            ContentBytesBase64 = "not-valid-base64!!!"
        };

        await Assert.ThrowsAsync<ArgumentException>(() =>
            _service.SendEmailAsync("title", "body", "sender@example.com", "to@example.com", attachments: [attachment]));
    }

    [Fact]
    public async Task SendEmail_InvalidBodyContentType_ThrowsArgumentException()
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            _service.SendEmailAsync("title", "body", "sender@example.com", "to@example.com", bodyContentType: "xml"));
    }
}
