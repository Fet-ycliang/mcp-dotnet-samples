using Azure.Core;
using Azure.Identity;

using McpSamples.OutlookEmail.HybridApp.Configurations;
using McpSamples.OutlookEmail.HybridApp.Services;
using McpSamples.Shared.Configurations;
using McpSamples.Shared.Extensions;

using Microsoft.Graph;

using Constants = McpSamples.OutlookEmail.HybridApp.Constants;

var envs = Environment.GetEnvironmentVariables();
var useStreamableHttp = AppSettings.UseStreamableHttp(envs, args);

IHostApplicationBuilder builder = useStreamableHttp
                                ? WebApplication.CreateBuilder(args)
                                : Host.CreateApplicationBuilder(args);

if (useStreamableHttp == true)
{
    var port = Environment.GetEnvironmentVariable(Constants.AzureFunctionsCustomHandlerPortEnvironmentKey) ?? $"{Constants.DefaultAppPort}";
    (builder as WebApplicationBuilder)!.WebHost.UseUrls(string.Format(Constants.DefaultAppUrl, port));

    Console.WriteLine($"正在監聽連接埠 {port}");
}

builder.Services.AddAppSettings<OutlookEmailAppSettings>(builder.Configuration, args);
builder.Services.AddMemoryCache();
builder.Services.AddSingleton<IGeneratedAttachmentStore, GeneratedAttachmentStore>();
builder.Services.AddScoped<IOutlookEmailService, OutlookEmailService>();
builder.Services.AddScoped<IPptxPresentationService, PptxPresentationService>();
builder.Services.AddScoped<IXlsxAttachmentService, XlsxAttachmentService>();
builder.Services.AddScoped<GraphServiceClient>(sp =>
{
    var settings = sp.GetRequiredService<OutlookEmailAppSettings>();
    var entraId = settings.EntraId;
    var credential = CreateGraphCredential(entraId);
 
    string[] scopes = [ Constants.DefaultScope ];
    var client = new GraphServiceClient(credential, scopes);
 
    return client;
});

static TokenCredential CreateGraphCredential(EntraIdSettings entraId)
{
    if (entraId.ShouldUseManagedIdentity)
    {
        return string.IsNullOrWhiteSpace(entraId.UserAssignedClientId)
                   ? new ManagedIdentityCredential(new ManagedIdentityCredentialOptions())
                   : new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(entraId.UserAssignedClientId));
    }
 
    if (!entraId.HasCompleteServicePrincipalSettings)
    {
        throw new InvalidOperationException("Service principal Graph auth requires EntraId:TenantId, EntraId:ClientId, and EntraId:ClientSecret. Set EntraId:UseManagedIdentity=true to use managed identity instead.");
    }
 
    return new ClientSecretCredential(entraId.TenantId, entraId.ClientId, entraId.ClientSecret);
}
 
IHost app = builder.BuildApp(useStreamableHttp);
 
await app.RunAsync();
