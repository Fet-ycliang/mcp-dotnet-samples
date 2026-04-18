---
name: outlook-email-mcp-host-setup
description: |
  outlook-email 的 MCP host/client 設定與排錯指引。用於 Claude Code、Copilot CLI、VS Code 連到 APIM-backed remote MCP server；目前正式路徑以 APIM inbound OAuth、Bearer token、NO_PROXY 與 SSE 除錯為主，stdio / localhost 配置只保留做 UT 與開發參考。
  觸發詞："Claude Code", "Copilot CLI", ".mcp.json", ".claude/mcp.json", "mcp-config.json", "Bearer token", "Authorization", "NO_PROXY", "Connecting", "remote MCP", "APIM"。
---

# Outlook Email MCP host/client 設定與排錯

此技能只處理 `outlook-email` sample 的 MCP host/client 連線，不處理其他 sample。

## 主要檔案

| 檔案 | 用途 |
| --- | --- |
| `README.md` | 人類操作主文件，包含 MCP host/client 的入口說明與踩雷紀錄 |
| `.vscode\mcp*.json` | VS Code / Agent Mode 連線模板 |
| `.mcp.json` | Claude Code 使用的**本地** project-level MCP 設定（不進版控）；這個 repo 的 project code 是 `y94` |
| `.claude\mcp.json` | APIM remote header 參考範例（手動 Bearer header）；不是目前 Claude Code 的 project-level 載入入口 |
| `~\.copilot\mcp-config.json` | Copilot CLI 使用的 MCP 設定（不在 repo 內） |

## 設定原則

1. **VS Code**：APIM 路徑優先使用 `.vscode\mcp.http.remote-apim.json`
2. **Claude Code**：正式使用 repo 根目錄的本地 `.\.mcp.json` 內的 `mcpServers`；這個 repo 的 project code 是 `y94`
3. 若要在 Claude Code 新增或調整 project-level MCP server（例如 `databricks-genie`），請直接改你本地的 `.\.mcp.json`
4. `.\.mcp.json` 的變更不會在既有 Claude Code session 內熱載入；改完後請重開該 repo 的 Claude Code project / session（`y94`）
5. **Copilot CLI**：正式使用 `~\.copilot\mcp-config.json` 內的 `outlook-email`
6. localhost / UT 參考改看 `.vscode\mcp.http.local-func.json`、`.vscode\mcp.stdio.local.json`，不是 `.\.mcp.json` 的正式遠端路徑
7. `.claude\mcp.json` 目前保留作 APIM remote header 參考範例，不是 Claude Code 現在的 project-level 載入入口

> 目前 repo 內的 `.claude\mcp.json` 以 live APIM `https://apim-fet-outlook-email.azure-api.net/mcp` 當預設例子；換環境時請改成對應 `https://<apim-fqdn>/mcp`。若你是在維護 Claude Code project-level server 清單，請改你本地的 `.\.mcp.json`，而且這份檔案不進版控。

## APIM remote MCP 連線必要條件

### 1. `OUTLOOK_EMAIL_APIM_ACCESS_TOKEN`

若設定檔使用 `Authorization: Bearer ${OUTLOOK_EMAIL_APIM_ACCESS_TOKEN}`，請在**啟動 Claude Code / Copilot CLI 的同一個 shell** 先刷新 token。

目前 repo 內的 `.claude\mcp.json` 是這類手動 Bearer header 的 APIM 範例；若你在 `.\.mcp.json` 內也採用相同做法，Claude Code 啟動前同樣需要先刷新這個 token。

```powershell
$env:OUTLOOK_EMAIL_APIM_ACCESS_TOKEN = az account get-access-token `
  --scope "api://87123f9d-6cf0-4672-9003-c8eba016749d/user_impersonation" `
  --query accessToken -o tsv
```

> 目前已驗證 Copilot CLI 可以正常展開 header 內的 `${OUTLOOK_EMAIL_APIM_ACCESS_TOKEN}`。但 token 本身有時效，不要把短效 access token 直接寫死在 JSON 檔裡。

### 2. `NO_PROXY`

若 APIM gateway 只走 private route，且本機有公司 proxy，請把下列 host 加進 `NO_PROXY`：

```powershell
$existing = [Environment]::GetEnvironmentVariable('NO_PROXY', 'User')
$extra = @(
  'apim-fet-outlook-email.azure-api.net',
  '.azure-api.net'
)
$combined = (($existing -split ',') + $extra | Where-Object { $_ } | Select-Object -Unique) -join ','
[Environment]::SetEnvironmentVariable('NO_PROXY', $combined, 'User')
```

> 若沒補 `NO_PROXY`，常見症狀是：proxy `CONNECT`、`403 Ip Forbidden`、TLS / revocation 錯誤，或 MCP host/client 一直顯示 `Connecting`。

## 除錯重點

1. 遠端 `/mcp` **不保證每個方法都只回同一種包裝**：`tools/list` / `tools/call` 常是 **SSE (`text/event-stream`)**，但 `initialize` 也可能直接回一般 JSON
2. 用 `curl` / PowerShell 除錯時，不要把整個 body 一律當純 JSON，也不要一律當 SSE
3. 應先看 `Content-Type` 與 body 形狀，再決定是直接 parse JSON，還是先抓 `data:` 行
4. 某些 remote path 下，tool payload 可能包在 `result.content[0].text` 的 JSON 字串，不一定會落在 `result.structuredContent`
5. 若在 **Windows PowerShell** 下送中文 JSON，優先用 **UTF-8 檔案 + `curl.exe --data-binary @body.json`**；不要直接用 `--data-raw`

### 診斷範例

```powershell
$bodyObject = @{
  jsonrpc = '2.0'
  id = 1
  method = 'initialize'
  params = @{
    protocolVersion = '2025-03-26'
    capabilities = @{}
    clientInfo = @{ name = 'diag'; version = '1.0' }
  }
}

$bodyPath = Join-Path $env:TEMP 'outlook-email-apim-init.json'
[IO.File]::WriteAllText(
  $bodyPath,
  ($bodyObject | ConvertTo-Json -Depth 20 -Compress),
  [Text.UTF8Encoding]::new($false))

curl.exe --noproxy '*' -i -sS `
  -H "Authorization: Bearer $env:OUTLOOK_EMAIL_APIM_ACCESS_TOKEN" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  --data-binary "@$bodyPath" `
  https://apim-fet-outlook-email.azure-api.net/mcp
```

> 如果 body 含中文，這種 **UTF-8 file + `--data-binary`** 寫法比 `--data-raw` 穩定很多。

### 目前建議的 APIM 驗證順序

1. `initialize`
2. `tools/list`，確認至少列出 `send_email` 與 `generate_pptx_attachment`
3. 若要測試簡報附件路徑，先呼叫 `generate_pptx_attachment`
4. 再把回傳的 `generatedAttachmentId` 放進 `send_email.generatedAttachmentIds`

> 若只是想驗證「新 tool 有沒有上到 retained path」，先看 `tools/list` 即可；若要驗證實際附件流程，再做第 3、4 步。

## remote MCP 下產生商務簡報的內容原則

若使用者是透過 Claude Code / Copilot CLI 走 **APIM retained path** 產生 `.pptx`，請在呼叫 `generate_pptx_attachment` 前先做一層內容整理，不要把技術除錯敘述直接放進 slides：

1. `title` 寫成**商務結論句**，不要寫成測試步驟或驗證結果。
2. `subtitle` 只放期間、資料來源或範圍。
3. `body` 先濃縮成 1-2 句高階摘要。
4. `bullets` 用 3-5 點支撐結論，每點盡量短且可直接朗讀。
5. 若資料仍是 raw query / raw log，先整理成 deck outline，再送進 `generate_pptx_attachment`。

> `generate_pptx_attachment` 目前的責任是 render 成商務模板，不是自動把工程語氣重寫成高階簡報語氣。

## 何時用這個技能

- 設定 Claude Code 的 `.\.mcp.json`
- 設定 Copilot CLI 的 `mcp-config.json`
- 遇到 MCP server 一直顯示 `Connecting`
- 排查 private endpoint / proxy / Bearer token 問題
- 用 `initialize` / `tools/list` 直接驗證遠端 MCP transport
