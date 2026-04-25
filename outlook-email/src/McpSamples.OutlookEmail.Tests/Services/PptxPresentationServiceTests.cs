using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Models;
using McpSamples.OutlookEmail.HybridApp.Services;

using Microsoft.Extensions.Logging.Abstractions;

using NSubstitute;

namespace McpSamples.OutlookEmail.Tests.Services;

public sealed class PptxPresentationServiceTests
{
    private readonly IGeneratedAttachmentStore _store;
    private readonly PptxPresentationService _service;

    public PptxPresentationServiceTests()
    {
        _store = Substitute.For<IGeneratedAttachmentStore>();
        _store.ExpirationMinutes.Returns(60);
        _store.Save(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<byte[]>()).Returns("test-id");

        _service = new PptxPresentationService(_store, new OutlookEmailAppSettings(), NullLogger<PptxPresentationService>.Instance);
    }

    [Fact]
    public async Task GenerateAttachment_NullRequest_ThrowsArgumentNullException()
    {
        await Assert.ThrowsAsync<ArgumentNullException>(() => _service.GenerateAttachmentAsync(null!));
    }

    [Fact]
    public async Task EmptySlides_ThrowsArgumentException()
    {
        var request = new PptxPresentationRequest { Slides = [] };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task TooManySlides_ThrowsArgumentException()
    {
        var slides = Enumerable.Range(1, 21)
                               .Select(i => new PptxSlideSpec
                               {
                                   Kind = "content",
                                   Title = $"Slide {i}",
                                   Body = "Content"
                               })
                               .ToArray();
        var request = new PptxPresentationRequest { Slides = slides };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task ContentSlide_NeitherBodyNorBullets_ThrowsArgumentException()
    {
        var request = new PptxPresentationRequest
        {
            Slides = [new PptxSlideSpec { Kind = "content", Title = "No content" }]
        };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }

    [Fact]
    public async Task InvalidSlideKind_ThrowsArgumentException()
    {
        var request = new PptxPresentationRequest
        {
            Slides = [new PptxSlideSpec { Kind = "unknown", Title = "Test" }]
        };

        await Assert.ThrowsAsync<ArgumentException>(() => _service.GenerateAttachmentAsync(request));
    }
}
