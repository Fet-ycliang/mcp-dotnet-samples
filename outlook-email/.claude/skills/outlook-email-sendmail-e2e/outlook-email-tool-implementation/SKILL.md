---
name: outlook-email-tool-implementation
description: |
  outlook-email `send_email` 工具實作指引。用於修改 MCP 工具 介面、調整 Graph 郵件 payload、變更驗證或錯誤處理，並追蹤需要一起更新的檔案。
  觸發詞："send_email", "OutlookEmailTool", "GraphServiceClient", "郵件 payload", "recipient validation", "工具實作"。
---

# Outlook Email 工具實作指引

此技能專門協助 Agent 修改 `outlook-email` 的 `send_email` 功能，不要延伸到其他 sample。

## 程式入口與責任分工

| 檔案 | 職責 |
| --- | --- |
| `src\McpSamples.OutlookEmail.HybridApp\Tools\OutlookEmailTool.cs` | MCP 工具 對外介面、參數描述，以及將例外轉為結果 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\OutlookEmailService.cs` | 郵件驗證、sender / replyTo allowlist、收件者拆分、Graph API 呼叫、payload 建立 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\OutlookEmailResult.cs` | 工具回傳模型 |
| `src\McpSamples.OutlookEmail.HybridApp\Program.cs` | 注入 `GraphServiceClient` 與服務註冊 |
| `src\McpSamples.OutlookEmail.HybridApp\Configurations\OutlookEmailAppSettings.cs` | 認證參數來源 |
| `src\McpSamples.OutlookEmail.HybridApp\Constants.cs` | Graph scope、預設連接埠 與環境變數名稱 |

## 修改流程

### 調整 MCP 工具 介面時

1. 先修改 `OutlookEmailTool.SendEmailAsync(...)` 的參數與 `[Description]`。
2. 同步更新 `IOutlookEmailTool` 與 `IOutlookEmailService` 介面。
3. 如果回傳內容有變動，請更新 `OutlookEmailResult.cs`。
4. 如果使用方式有變動，請同步更新 `README.md`。

### 調整郵件內容或收件者邏輯時

1. 主要修改 `OutlookEmailService.SendEmailAsync(...)`。
2. `BuildMailRequest(...)` 負責組成 `SendMailPostRequestBody`。
3. 收件者目前支援逗號與分號分隔；若要修改，必須保留或明確更新這項規則。
4. 若有調整 `AllowedSenders` 或 `AllowedReplyTo` 驗證，記得同步更新 `local.settings.sample.json` 與 `README.md`。
5. 驗證規則變更後，要確認錯誤訊息仍能清楚指出問題。

### 調整認證或 Graph client 時

1. 主要修改 `Program.cs` 中 `GraphServiceClient` 的註冊方式。
2. 認證參數有變動時，請同步更新 `OutlookEmailAppSettings.cs`。
3. 不要把 `outlook-email` 專屬的認證邏輯搬進 shared。

## 驗證方式

如果有修改 C# 程式碼，優先執行：

```powershell
dotnet build .\McpOutlookEmail.sln
```

如果修改到啟動流程或參數解析，也至少要補跑一種啟動方式：

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp
```

或

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http
```

## 實作原則

1. 先沿用既有的 `OutlookEmailTool -> OutlookEmailService -> GraphServiceClient` 分層。
2. 不要在 tool 層加入過多商業邏輯；驗證與 payload 組裝優先放在 service。
3. 修改輸入參數時，請確認 MCP 工具 描述、README 範例與錯誤處理已同步更新。

