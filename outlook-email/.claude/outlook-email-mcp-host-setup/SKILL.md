---
name: outlook-email-mcp-host-setup
description: |
  outlook-email 的 MCP host/client 設定與排錯指引。用於 Claude Code、Copilot CLI、VS Code 連到 APIM-backed remote MCP server；目前正式路徑以 APIM inbound OAuth、Bearer token、NO_PROXY 與 SSE 除錯為主，stdio / localhost 配置只保留做 UT 與開發參考。
  觸發詞："Claude Code", "Copilot CLI", ".claude/mcp.json", "mcp-config.json", "Bearer token", "Authorization", "NO_PROXY", "Connecting", "remote MCP", "APIM"。
---

# Outlook Email MCP host/client 設定與排錯

此技能只處理 `outlook-email` sample 的 MCP host/client 連線，不處理其他 sample。

## 主要檔案

| 檔案 | 用途 |
| --- | --- |
| `README.md` | 人類操作主文件，包含 MCP host/client 的入口說明與踩雷紀錄 |
| `.vscode\mcp*.json` | VS Code / Agent Mode 連線模板 |
| `.claude\mcp.json` | Claude Code 使用的正式 APIM remote MCP 設定（手動 Bearer header） |
| `~\.copilot\mcp-config.json` | Copilot CLI 使用的 MCP 設定（不在 repo 內） |

## 設定原則

1. **VS Code**：APIM 路徑優先使用 `.vscode\mcp.http.remote-apim.json`
2. **Claude Code**：正式使用 `outlook-email\.claude\mcp.json` 內的 `outlook-email`
3. **Copilot CLI**：正式使用 `~/.copilot/mcp-config.json` 內的 `outlook-email`
4. localhost / UT 參考改看 `.vscode\mcp.http.local-func.json`、`.vscode\mcp.stdio.local.json`，不是 `.claude\mcp.json` 的預設遠端路徑

## APIM remote MCP 連線必要條件

### 1. `OUTLOOK_EMAIL_APIM_ACCESS_TOKEN`

若設定檔使用 `Authorization: Bearer ${OUTLOOK_EMAIL_APIM_ACCESS_TOKEN}`，請在**啟動 Claude Code / Copilot CLI 的同一個 shell** 先刷新 token。

目前 repo 內的 `.claude\mcp.json` 維持手動 Bearer header，因此 Claude Code 啟動前也需要先刷新這個 token。

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
  'fet-mcp-apim-bst.azure-api.net',
  '.azure-api.net'
)
$combined = (($existing -split ',') + $extra | Where-Object { $_ } | Select-Object -Unique) -join ','
[Environment]::SetEnvironmentVariable('NO_PROXY', $combined, 'User')
```

> 若沒補 `NO_PROXY`，常見症狀是：proxy `CONNECT`、`403 Ip Forbidden`、TLS / revocation 錯誤，或 MCP host/client 一直顯示 `Connecting`。

## 除錯重點

1. 遠端 `/mcp` 目前回的是 **SSE (`text/event-stream`)**
2. 用 `curl` / PowerShell 除錯時，不要把整個 body 當純 JSON
3. 應先抓 `data:` 那一行，再解析 JSON

### 診斷範例

```powershell
$body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"diag","version":"1.0"}}}'
curl.exe --noproxy '*' -i -sS `
  -H "Authorization: Bearer $env:OUTLOOK_EMAIL_APIM_ACCESS_TOKEN" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  --data-raw $body `
  https://fet-mcp-apim-bst.azure-api.net/mcp
```

## 何時用這個技能

- 設定 Claude Code 的 `.claude\mcp.json`
- 設定 Copilot CLI 的 `mcp-config.json`
- 遇到 MCP server 一直顯示 `Connecting`
- 排查 private endpoint / proxy / Bearer token 問題
- 用 `initialize` / `tools/list` 直接驗證遠端 MCP transport
