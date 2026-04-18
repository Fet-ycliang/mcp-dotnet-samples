---
name: outlook-email-tool-implementation
description: |
  outlook-email 工具實作指引。用於修改 `send_email`、`generate_pptx_attachment`、`generate_xlsx_attachment` 的 MCP tool 介面、
  調整 Graph 郵件 payload、變更驗證或錯誤處理，並追蹤需要一起更新的檔案。
  觸發詞："send_email", "generate_xlsx_attachment", "OutlookEmailTool", "XlsxAttachmentTool", "GraphServiceClient", "郵件 payload", "工具實作"。
---

# Outlook Email 工具實作指引

此技能專門協助 Agent 修改 `outlook-email` 的工具實作，不要延伸到其他 sample。

## 程式入口與責任分工

| 檔案 | 職責 |
| --- | --- |
| `src\McpSamples.OutlookEmail.HybridApp\Tools\OutlookEmailTool.cs` | `send_email` MCP 工具對外介面、參數描述，以及將例外轉為結果 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\OutlookEmailService.cs` | 郵件驗證、sender / replyTo allowlist、收件者拆分、Graph API 呼叫、payload 建立 |
| `src\McpSamples.OutlookEmail.HybridApp\Tools\XlsxAttachmentTool.cs` | `generate_xlsx_attachment` MCP 工具介面、參數描述與結果回傳 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\XlsxAttachmentService.cs` | XLSX 工作表 / 資料表 / 圖表驗證、Open XML 產生與 server-side attachment 暫存 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\OutlookEmailResult.cs` | `send_email` 工具回傳模型 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\Xlsx*.cs` | Excel 附件輸入 / 輸出模型 |
| `src\McpSamples.OutlookEmail.HybridApp\Program.cs` | `GraphServiceClient` 與各 tool service 註冊 |
| `src\McpSamples.OutlookEmail.HybridApp\Configurations\OutlookEmailAppSettings.cs` | 認證參數來源 |
| `src\McpSamples.OutlookEmail.HybridApp\Constants.cs` | Graph scope、預設連接埠與環境變數名稱 |

## 修改流程

### 調整 MCP tool 介面時

1. 先修改對應 tool 類別的方法參數與 `[Description]`。
2. 同步更新對應 interface 與 service interface。
3. 如果回傳內容有變動，請更新對應 `Models\`。
4. 如果使用方式有變動，請同步更新 `README.md` 與相關 skill。

### 調整 `send_email` 或附件寄送邏輯時

1. 主要修改 `OutlookEmailService.SendEmailAsync(...)`。
2. `BuildMailRequest(...)` 負責組成 `SendMailPostRequestBody`。
3. `generatedAttachmentIds` 目前同時支援 `generate_pptx_attachment` 與 `generate_xlsx_attachment`；若修改這條路徑，記得同步更新 tool 描述與 README 範例。
4. 收件者目前支援逗號與分號分隔；若要修改，必須保留或明確更新這項規則。
5. 若有調整 `AllowedSenders` 或 `AllowedReplyTo` 驗證，記得同步更新 `local.settings.sample.json` 與 `README.md`。

### 調整 XLSX 產生邏輯時

1. 主要修改 `XlsxAttachmentService.GenerateAttachmentAsync(...)` 與其 validation / normalization 流程。
2. `tables[].rows` 目前每格值都用字串輸入，再依 `columns[].type` 解析；若修改這個規則，要同步更新 README 與 skill。
3. 圖表目前是 chart-first flow，`valueColumns` 必須對應數值欄位，`pie` 只能有一個 value column；若行為有變動，要同步更新文件。
4. `generate_xlsx_attachment` 的輸出會進 `GeneratedAttachmentStore`，所以若調整 `generatedAttachmentId` 的生命週期或內容，也要同步檢查 `send_email`。

### 調整認證或 Graph client 時

1. 主要修改 `Program.cs` 中 `GraphServiceClient` 的註冊方式。
2. 認證參數有變動時，請同步更新 `OutlookEmailAppSettings.cs`。
3. 不要把 `outlook-email` 專屬的認證邏輯搬進 shared。

## 驗證方式

如果有修改 C# 程式碼，優先執行：

```powershell
dotnet build .\McpOutlookEmail.sln
```

如果修改到啟動流程、HTTP tool call、或附件暫存邏輯，也至少補跑一種本機路徑：

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http
```

## 實作原則

1. 先沿用既有的 `Tool -> Service -> GraphServiceClient / GeneratedAttachmentStore` 分層。
2. 不要在 tool 層加入過多商業邏輯；驗證與 payload 組裝優先放在 service。
3. 修改輸入參數時，請確認 MCP tool 描述、README 範例、skills 與錯誤處理已同步更新。
