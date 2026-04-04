---
name: outlook-email-sendmail-e2e
description: |
  outlook-email 的 send_email 真實寄信 E2E 指引。用於設定 local.settings.json 的 sender / replyTo allowlist、啟動本機 Function App、組出含 CSV / XLSX 附件的 payload，並完成正向與負向驗證；也包含 direct Microsoft Graph 測試寄信腳本。
  觸發詞："sendmail e2e", "send_email e2e", "replyTo", "csv attachment", "xlsx attachment", "func start 發信", "graph 測試寄信", "sendMail fallback"。
---

# Outlook Email send_email E2E 指引

此技能只處理 `outlook-email` sample 的本機真實寄信驗證，不要延伸到其他 sample。

## 主要檔案

| 檔案 | 用途 |
| --- | --- |
| `README.md` | 本機 Function App 啟動、payload 與 local settings 主說明 |
| `src\McpSamples.OutlookEmail.HybridApp\local.settings.json` | 本機實際認證與 sender / replyTo allowlist；此檔已被 `.gitignore` 忽略 |
| `src\McpSamples.OutlookEmail.HybridApp\local.settings.sample.json` | 設定範本 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\OutlookEmailService.cs` | sender / replyTo / 附件驗證與 Graph 發信流程 |
| `.vscode\mcp.http.local-func.json` | VS Code / Agent Mode 連到本機 Function App 的 MCP 設定 |
| `.claude\outlook-email-sendmail-e2e\scripts\send-test-mail.ps1` | 直接透過 Microsoft Graph 發送測試信的 fallback 腳本 |

## local.settings.json 最小設定

至少準備下列設定：

```jsonc
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "AzureWebJobsFeatureFlags": "DisableDiagnosticEventLogging",
    "UseHttp": "true",
    "EntraId__TenantId": "{{TENANT_ID}}",
    "EntraId__ClientId": "{{CLIENT_ID}}",
    "EntraId__ClientSecret": "{{CLIENT_SECRET}}",
    "EntraId__UseManagedIdentity": "false",
    "AllowedSenders__0": "shared-mailbox@contoso.com",
    "AllowedReplyTo__0": "owner@contoso.com"
  }
}
```

- `AllowedSenders__N`：允許的寄件者。
- `AllowedReplyTo__N`：允許的回覆地址。
- `AllowedRecipients__N`：可選。若有設定，Graph fallback script 會限制收件者只能落在這份名單內。
- 若要加多筆，依序加入 `__1`、`__2`。
- `send-test-mail.ps1` **只支援 service principal secret flow**；它會優先讀 OS 環境變數 `EntraId__TenantId` / `EntraId__ClientId` / `EntraId__ClientSecret`，讀不到才回退到 `local.settings.json`。
- `send-test-mail.ps1` 不會解析 managed identity，也不會自動讀 `dotnet user-secrets`。
- 做 local 真實寄信時，建議明確設定 `EntraId__UseManagedIdentity=false`。

## 建議 E2E 流程

1. 在 `outlook-email\src\McpSamples.OutlookEmail.HybridApp` 準備好 `local.settings.json`。
2. 在同一目錄執行：

   ```powershell
   func start
   ```

3. 使用 `.vscode\mcp.http.local-func.json` 連到本機 Function App。
4. 若目前執行環境對 `http://127.0.0.1:7071/mcp` 有 loopback 限制，改查看 `func start` 輸出，直接命中 **custom handler port** 的 `/mcp`。
5. 先做負向驗證：用不在 `AllowedSenders` 或 `AllowedReplyTo` 的值呼叫 `send_email`，確認服務會拒絕。
6. 再做正向驗證：使用允許的 `sender`、`replyTo` 與附件 payload 呼叫 `send_email`。

## Graph 直送 fallback

當目的只是確認 **Graph 認證 / mailbox scope / sender allowlist** 是否正常，而不是驗證 MCP transport，本技能直接提供腳本，不要再手組 token + `sendMail` one-liner。

**先回到 `outlook-email` 根目錄再執行：**

```powershell
.\.claude\outlook-email-sendmail-e2e\scripts\send-test-mail.ps1 `
  -Recipients "alice@contoso.com" `
  -Title "Outlook Email Graph 測試信" `
  -Body "這封信直接透過 Microsoft Graph 送出。"
```

- 預設讀取 `src\McpSamples.OutlookEmail.HybridApp\local.settings.json`
- 未指定 `-Sender` 時，使用 `AllowedSenders__0`
- `-ReplyTo` 若有提供，會比對 `AllowedReplyTo__N`
- `-Recipients` 預設只允許 `AllowedRecipients__N`；若未設定 `AllowedRecipients__N`，則回退為 `AllowedSenders__N` + `AllowedReplyTo__N` 的聯集
- 若要寄給 allowlist 以外的收件者，必須明確加上 `-AllowAnyRecipient`
- 這條路徑**刻意繞過 MCP host/client**，用來切開「Graph 正常、MCP transport 異常」的情境
- 若只想先確認參數與設定解析，可加 `-WhatIf`

若不想把 secret 放進 `local.settings.json`，可先設成 OS 環境變數：

```powershell
$env:EntraId__TenantId = 'tenant-id'
$env:EntraId__ClientId = 'client-id'
$env:EntraId__ClientSecret = 'client-secret'
```

若要一次寄給多位收件者，可直接傳字串陣列：

```powershell
.\.claude\outlook-email-sendmail-e2e\scripts\send-test-mail.ps1 `
  -Recipients @("alice@contoso.com", "bob@contoso.com") `
  -Title "多收件者測試"
```

若工作目錄還停在 `src\McpSamples.OutlookEmail.HybridApp`，可改用：

```powershell
..\..\..\.claude\outlook-email-sendmail-e2e\scripts\send-test-mail.ps1 `
  -Recipients "alice@contoso.com" `
  -Title "HybridApp 相對路徑測試"
```

若要覆寫設定檔路徑或寄給 allowlist 外的測試信箱：

```powershell
.\.claude\outlook-email-sendmail-e2e\scripts\send-test-mail.ps1 `
  -Recipients "alice@contoso.com" `
  -ConfigPath ".\src\McpSamples.OutlookEmail.HybridApp\local.settings.json" `
  -AllowAnyRecipient `
  -Title "指定設定檔測試"
```

## 附件 payload 準備

### 直接使用小型 Base64 範例

```json
{
  "title": "本週報表",
  "body": "請參考附件。",
  "sender": "shared-mailbox@contoso.com",
  "recipients": "alice@contoso.com;bob@contoso.com",
  "replyTo": "owner@contoso.com",
  "attachments": [
    {
      "name": "report.csv",
      "contentType": "text/csv",
      "contentBytesBase64": "YSxiLGMKMSwyLDMK"
    },
    {
      "name": "report.xlsx",
      "contentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "contentBytesBase64": "UEsDBBQAAAAIAAA..."
    }
  ]
}
```

### 從本機檔案產生 Base64

```powershell
$csvBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\report.csv"))
$xlsxBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\report.xlsx"))
```

然後把 `$csvBase64` 與 `$xlsxBase64` 填回 `attachments[].contentBytesBase64`。

## 驗證重點

1. `sender` 必須在 `AllowedSenders` 中。
2. `replyTo` 若有提供，必須全部在 `AllowedReplyTo` 中。
3. CSV MIME 使用 `text/csv`。
4. XLSX MIME 使用 `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`。
5. 附件數量與大小仍受 `MaxAttachmentCount` / `MaxAttachmentSizeBytes` 限制。

## 何時同步更新其他檔案

- 如果調整 allowlist 欄位名稱：同步更新 `OutlookEmailAppSettings.cs`、`OutlookEmailService.cs`、`README.md`、`local.settings.sample.json`。
- 如果調整 payload 格式：同步更新 `README.md` 與 `outlook-email-tool-implementation` skill。
- 如果調整 direct Graph 測試寄信流程：同步更新本技能中的 `scripts\send-test-mail.ps1` 與這段說明。
- 如果改了本機啟動方式：同步更新 `README.md`、`.vscode\mcp.http.local-func.json`，必要時更新 `outlook-email-local-dev` skill。
- 如果改到 Claude Code / Copilot CLI 的 remote 連線方式：同步更新 `README.md` 與 `outlook-email-mcp-host-setup` skill。
