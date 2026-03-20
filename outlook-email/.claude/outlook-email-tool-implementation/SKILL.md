---
name: outlook-email-tool-implementation
description: |
  outlook-email send_email 工具實作指引。用於修改 MCP tool 介面、調整 Graph 郵件 payload、變更驗證或錯誤處理，並追蹤需要一起更新的檔案。
  Triggers: "send_email", "OutlookEmailTool", "GraphServiceClient", "郵件 payload", "recipient validation", "工具實作".
---

# Outlook Email Tool Implementation

此 skill 專門幫 Agent 修改 `outlook-email` 的 `send_email` 功能，不要延伸到其他 sample。

## 程式入口與責任分工

| 檔案 | 職責 |
| --- | --- |
| `src\McpSamples.OutlookEmail.HybridApp\Tools\OutlookEmailTool.cs` | MCP tool 對外介面、參數描述、例外轉成結果 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\OutlookEmailService.cs` | 郵件驗證、收件者拆分、Graph API 呼叫、payload 建立 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\OutlookEmailResult.cs` | tool 回傳模型 |
| `src\McpSamples.OutlookEmail.HybridApp\Program.cs` | 注入 `GraphServiceClient` 與服務註冊 |
| `src\McpSamples.OutlookEmail.HybridApp\Configurations\OutlookEmailAppSettings.cs` | 認證參數來源 |
| `src\McpSamples.OutlookEmail.HybridApp\Constants.cs` | Graph scope、預設 port 與環境變數名稱 |

## 修改 workflow

### 調整 MCP tool 介面時

1. 先改 `OutlookEmailTool.SendEmailAsync(...)` 的參數與 `[Description]`。
2. 同步改 `IOutlookEmailTool` 與 `IOutlookEmailService` 介面。
3. 若回傳內容變更，更新 `OutlookEmailResult.cs`。
4. 若使用方式改變，更新 `README.md`。

### 調整郵件內容或收件者邏輯時

1. 主要修改 `OutlookEmailService.SendEmailAsync(...)`。
2. `BuildMailRequest(...)` 負責組出 `SendMailPostRequestBody`。
3. 收件者目前支援逗號與分號分隔，修改時要保留或明確更新此規則。
4. 驗證規則改動後，要確認錯誤訊息是否仍能清楚指出問題。

### 調整認證或 Graph client 時

1. 主要修改 `Program.cs` 的 `GraphServiceClient` 註冊。
2. 認證參數改動時，同步更新 `OutlookEmailAppSettings.cs`。
3. 不要把 `outlook-email` 專屬認證邏輯移進 shared。

## 驗證方式

若有改動 C# 程式碼，優先執行：

```powershell
dotnet build .\McpOutlookEmail.sln
```

若改到啟動或參數解析，也應至少補跑一種啟動方式：

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp
```

或

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http
```

## 實作原則

1. 先沿用既有的 `OutlookEmailTool -> OutlookEmailService -> GraphServiceClient` 分層。
2. 不要在 tool 層加入過多業務邏輯；驗證與 payload 組裝優先留在 service。
3. 修改輸入參數時，注意 MCP tool 描述、README 範例與錯誤處理是否同步。
