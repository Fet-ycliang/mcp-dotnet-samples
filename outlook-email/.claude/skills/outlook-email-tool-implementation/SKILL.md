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
| `src\McpSamples.OutlookEmail.HybridApp\Tools\PptxPresentationTool.cs` | `generate_pptx_attachment` MCP 工具介面、參數描述與結果回傳 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\PptxPresentationService.cs` | PPTX 投影片驗證、Open XML 產生與 server-side attachment 暫存 |
| `src\McpSamples.OutlookEmail.HybridApp\Tools\XlsxAttachmentTool.cs` | `generate_xlsx_attachment` MCP 工具介面、參數描述與結果回傳 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\XlsxAttachmentService.cs` | XLSX 工作表 / 資料表 / 圖表驗證、Open XML 產生與 server-side attachment 暫存 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\OutlookEmailResult.cs` | `send_email` 工具回傳模型 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\Pptx*.cs` | PowerPoint 附件輸入 / 輸出模型 |
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
6. `body` 若要以 HTML render，必須明確傳 `bodyContentType=html`；僅把 HTML 字串塞進 `body` 並不會自動切成 Graph `BodyType.Html`。
7. 若新增 / 調整 `bodyContentType` 這類輸入，請保留顯式 validation（例如只接受 `text` / `html`），並讓預設值維持既有行為，避免把所有舊 caller 一次變成 HTML。
8. `send_email` 的例外目前會在 tool 層轉成 `OutlookEmailResult.ErrorMessage`；除錯 `tools/call` 時，不要只看 MCP envelope 的 `isError`，也要檢查 `result.content[0].text`。
9. 本機要驗證 `send_email` payload / validation 時，先確認 `GraphServiceClient` 能被 DI 建出來；若 Entra 設定缺漏，可能會在進入 tool / service validation 前就先失敗。

### 調整 PPTX 產生邏輯時

1. 主要修改 `PptxPresentationService.GenerateAttachmentAsync(...)` 與相關 layout / validation 流程。
2. 目前 baseline 是 **封面頁不帶 footer**、內容頁才帶 deck title + page number；若要改模板，請同步更新 `README.md`、相關 skill 與驗收基準。
3. Open XML packaging 不要把 `ThemePart` 再掛回 `PresentationPart`，也不要自己手寫 slide relationship ID；交給 SDK 自動指派。
4. 若調整內容框大小、字級或文字上限，記得保留 auto-fit，或同步收緊 validation；否則 deck 雖然能開，但長標題 / bullets 可能被裁掉。
5. `generate_pptx_attachment` 的輸出同樣會進 `GeneratedAttachmentStore`；若調整 `generatedAttachmentId` 的生命週期、附件 metadata 或回傳模型，也要同步檢查 `send_email` 與 `Models\Pptx*.cs`。

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

直接打本機 HTTP `/mcp` 除錯時，回應可能是 `text/event-stream`，而且不一定會帶 `mcp-session-id` header；請直接解析 SSE `event:` / `data:` 行，不要只假設會拿到一般 JSON。

## 實作原則

1. 先沿用既有的 `Tool -> Service -> GraphServiceClient / GeneratedAttachmentStore` 分層。
2. 不要在 tool 層加入過多商業邏輯；驗證與 payload 組裝優先放在 service。
3. 修改輸入參數時，請確認 MCP tool 描述、README 範例、skills 與錯誤處理已同步更新。
