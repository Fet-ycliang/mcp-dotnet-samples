---
name: outlook-email-local-dev
description: |
  outlook-email 本機開發與啟動指引。用於啟動此 sample、切換 STDIO 或 HTTP 模式、設定 user secrets，或排查本機認證參數。
  觸發詞："outlook-email", "local dev", "dotnet run", "--http", "user secrets", "本機啟動"。
---

# Outlook Email 本機開發指引

此技能專門處理 `outlook-email` 這一層的本機開發，不要延伸到其他 sample。

## 主要檔案

| 檔案 | 用途 |
| --- | --- |
| `README.md` | 本層操作說明與執行範例 |
| `src\McpSamples.OutlookEmail.HybridApp\Program.cs` | 決定 STDIO / HTTP 啟動模式與 `GraphServiceClient` 註冊 |
| `src\McpSamples.OutlookEmail.HybridApp\Configurations\OutlookEmailAppSettings.cs` | 解析 `--tenant-id`、`--client-id`、`--client-secret` |
| `src\McpSamples.OutlookEmail.HybridApp\local.settings.sample.json` | 本機 Function App 設定範本，含 sender / replyTo allowlist |
| `src\McpSamples.OutlookEmail.HybridApp\McpSamples.OutlookEmail.HybridApp.csproj` | 專案與套件參考 |

## 本機啟動流程

1. 先停在 `outlook-email` 目錄。
2. 如果只是執行 STDIO 模式，直接啟動 Hybrid App。
3. 如果要執行 HTTP 模式，**一定要保留 `--` 分隔符號**，再接 `--http` 與其他參數。
4. 若不想把認證資料放在命令列，請改用 `dotnet user-secrets`。
5. 若要模擬本機 Function App 真實寄信，請在 `local.settings.json` 設定 `AllowedSenders__0`；若測試會帶 `replyTo`，再額外設定 `AllowedReplyTo__0`。
6. 若要驗證 server-side 附件流程，先確認 `tools/list` 看得到 `generate_pptx_attachment` 或 `generate_xlsx_attachment`，再走 `generate_*_attachment -> send_email.generatedAttachmentIds`。
7. 若要 direct 打本機 HTTP `/mcp` 做 `tools/call`，記得固定帶 `Accept: application/json, text/event-stream` 與 `MCP-Protocol-Version: 2025-03-26`。

## 本機驗證簡報附件時的內容整理原則

- `generate_pptx_attachment` 現在會輸出較接近商務模板的版型，但它不會自動幫你把測試文字改寫成主管簡報。
- 若要驗證「輸出看起來是否專業」，請用**商務語氣**準備 `slides`：
  1. 第一張用 `kind=title`
  2. 內容頁的 `title` 寫成結論句
  3. `body` 先放 1-2 句摘要
  4. `bullets` 再放支撐點、影響與建議
- 若只是做工具穩定性驗證，可以保留技術字句；若是要看視覺效果，請改用正式簡報語氣，不要直接塞 `E2E 成功`、`validator 0 errors` 這類字串。

## 常用指令

### STDIO 模式

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp
```

### HTTP 模式

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http
```

### HTTP 模式加上 Entra ID 參數

```powershell
dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http -t "tenant-id" -c "client-id" -s "client-secret"
```

### 設定 user secrets

```powershell
dotnet user-secrets --project .\src\McpSamples.OutlookEmail.HybridApp set EntraId:TenantId "tenant-id"
dotnet user-secrets --project .\src\McpSamples.OutlookEmail.HybridApp set EntraId:ClientId "client-id"
dotnet user-secrets --project .\src\McpSamples.OutlookEmail.HybridApp set EntraId:ClientSecret "client-secret"
```

## 如何判斷問題位置

- 啟動模式不正確：先看 `Program.cs` 的 `AppSettings.UseStreamableHttp(...)` 與 `UseUrls(...)`。
- 參數沒有生效：先看 `OutlookEmailAppSettings.ParseMore(...)` 是否正確解析，並確認命令列保留 `--`。
- 認證失敗：先確認是否提供 tenant/client/client secret，或目前環境是否預期走 Managed Identity。
- `sender` / `replyTo` 被拒絕：先檢查 `local.settings.json` 中的 `AllowedSenders__N`、`AllowedReplyTo__N`。
- `generate_pptx_attachment` 看不到：先確認目前 build 已包含 `Tools\PptxPresentationTool.cs`，再用本機 `tools/list` 驗證 assembly scanning 是否正常。
- `generate_xlsx_attachment` 看不到：先確認目前 build 已包含 `Tools\XlsxAttachmentTool.cs`；若 build 有 DLL copy / file lock 警告，先停掉既有 `McpSamples.OutlookEmail.HybridApp` process 再重建。
- `tools/call` 在 direct local HTTP 路徑一直不穩：先補 `MCP-Protocol-Version: 2025-03-26`，並確認 caller 同時接受 `application/json` 與 `text/event-stream`。
- 若只想切開「Graph 認證有沒有問題」與「MCP transport 有沒有問題」：先回到 `outlook-email` 根目錄，再改用 `.\.claude\skills\outlook-email-sendmail-e2e\scripts\send-test-mail.ps1` 直接寄測試信。
- 如果要做真實寄信與附件驗證，優先改用 `outlook-email-sendmail-e2e` skill；若附件是投影片內容，先產出 `generatedAttachmentId` 再寄。

## 修改時的工作原則

1. 只修改 `outlook-email` 這一層。
2. 命令列參數若有新增或變更，要同步更新 `README.md` 與 `OutlookEmailAppSettings.cs`。
3. 啟動流程若有變更，至少重新執行一次 `dotnet run`，驗證 STDIO 或 HTTP 模式。
