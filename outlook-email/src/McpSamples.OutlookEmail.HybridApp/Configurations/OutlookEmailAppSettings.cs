using McpSamples.Shared.Configurations;

using Microsoft.OpenApi;

namespace McpSamples.OutlookEmail.HybridApp.Configurations;

/// <summary>
/// 表示 outlook-email 應用程式的設定。
/// </summary>
public class OutlookEmailAppSettings : AppSettings
{
    /// <summary>
    /// 預設允許的最大附件數量。
    /// </summary>
    public const int DefaultMaxAttachmentCount = 10;

    /// <summary>
    /// 預設單一附件大小上限（3 MiB）。
    /// </summary>
    public const int DefaultMaxAttachmentSizeBytes = 3 * 1024 * 1024;

    /// <inheritdoc />
    public override OpenApiInfo OpenApi { get; set; } = new()
    {
        Title = "MCP Outlook Email",
        Version = "1.0.0",
        Description = "用於透過 Outlook 傳送電子郵件，並可產生供寄送使用的 PowerPoint 簡報附件的簡易 MCP 伺服器。"
    };

    /// <summary>
    /// 取得或設定 <see cref="EntraIdSettings"/> 執行個體。
    /// </summary>
    public EntraIdSettings EntraId { get; set; } = new EntraIdSettings(Environment.GetEnvironmentVariable(Constants.AzureClientIdEnvironmentKey));

    /// <summary>
    /// 取得或設定允許的寄件者清單。若未設定則不限制寄件者。
    /// </summary>
    public string[] AllowedSenders { get; set; } = [];

    /// <summary>
    /// 取得或設定允許的 reply-to 清單。若未設定則不限制回覆地址。
    /// </summary>
    public string[] AllowedReplyTo { get; set; } = [];

    /// <summary>
    /// 取得或設定允許的最大附件數量。
    /// </summary>
    public int MaxAttachmentCount { get; set; } = DefaultMaxAttachmentCount;

    /// <summary>
    /// 取得或設定單一附件大小上限（位元組）。
    /// </summary>
    public int MaxAttachmentSizeBytes { get; set; } = DefaultMaxAttachmentSizeBytes;

    /// <inheritdoc />
    protected override T ParseMore<T>(IConfiguration config, string[] args)
    {
        var settings = base.ParseMore<T>(config, args);
        var outlookSettings = (settings as OutlookEmailAppSettings)!;
 
        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "--tenant-id":
                case "-t":
                    outlookSettings.EntraId.UseManagedIdentity = false;
                    outlookSettings.EntraId.TenantId = args[++i];
                    break;
 
                case "--client-id":
                case "-c":
                    outlookSettings.EntraId.UseManagedIdentity = false;
                    outlookSettings.EntraId.ClientId = args[++i];
                    break;
 
                case "--client-secret":
                case "-s":
                    outlookSettings.EntraId.UseManagedIdentity = false;
                    outlookSettings.EntraId.ClientSecret = args[++i];
                    break;
 
                default:
                    settings.Help = true;
                    break;
            }
        }

        return settings;
    }
}

/// <summary>
/// 表示 Entra ID 設定。
/// </summary>
/// <param name="userAssignedClientId">使用者指派的 client ID。</param>
public class EntraIdSettings(string? userAssignedClientId = default)
{
    /// <summary>
    /// 取得或設定 tenant ID。
    /// </summary>
    public string? TenantId { get; set; }

    /// <summary>
    /// 取得或設定 client ID。
    /// </summary>
    public string? ClientId { get; set; }

    /// <summary>
    /// 取得或設定 client secret。
    /// </summary>
    public string? ClientSecret { get; set; }

    /// <summary>
    /// 取得是否使用受控識別的值。
    /// </summary>
    public bool? UseManagedIdentity { get; set; }

    /// <summary>
    /// 取得使用者指派的 client ID。
    /// </summary>
    public string? UserAssignedClientId { get; } = userAssignedClientId;

    /// <summary>
    /// 取得是否存在任何明確的 service principal 設定值。
    /// </summary>
    public bool HasServicePrincipalSettings => IsConfiguredValue(TenantId) || IsConfiguredValue(ClientId) || IsConfiguredValue(ClientSecret);

    /// <summary>
    /// 取得 service principal 設定是否完整。
    /// </summary>
    public bool HasCompleteServicePrincipalSettings => IsConfiguredValue(TenantId) && IsConfiguredValue(ClientId) && IsConfiguredValue(ClientSecret);

    /// <summary>
    /// 取得最終是否使用受控識別的值。
    /// </summary>
    public bool ShouldUseManagedIdentity => UseManagedIdentity ?? (!HasServicePrincipalSettings && string.IsNullOrWhiteSpace(UserAssignedClientId) == false);

    private static bool IsConfiguredValue(string? value)
    {
        return !string.IsNullOrWhiteSpace(value)
               && !(value.StartsWith("{{", StringComparison.Ordinal) && value.EndsWith("}}", StringComparison.Ordinal));
    }
}
