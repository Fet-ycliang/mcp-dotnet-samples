namespace McpSamples.OutlookEmail.HybridApp;

/// <summary>
/// 集中管理共用常數值。
/// </summary>
public class Constants
{
    /// <summary>
    /// Microsoft Graph API 的預設 scope。
    /// </summary>
    public const string DefaultScope = "https://graph.microsoft.com/.default";

    /// <summary>
    /// Azure Client ID 的環境變數鍵值。
    /// </summary>
    public const string AzureClientIdEnvironmentKey = "AZURE_CLIENT_ID";

    /// <summary>
    /// Azure Functions Custom Handler Port 的環境變數鍵值。
    /// </summary>
    public const string AzureFunctionsCustomHandlerPortEnvironmentKey = "FUNCTIONS_CUSTOMHANDLER_PORT";

    /// <summary>
    /// Custom Handler 的預設連接埠。
    /// </summary>
    public const int DefaultAppPort = 5260;

    /// <summary>
    /// 應用程式的預設 URL。
    /// </summary>
    public const string DefaultAppUrl = "http://0.0.0.0:{0}";
}
