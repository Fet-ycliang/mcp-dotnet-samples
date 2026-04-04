---
name: outlook-email-mcp-host-setup
description: |
  outlook-email 的 MCP host/client 設定與排錯指引。用於 Claude Code、Copilot CLI、VS Code 連到本機或遠端 Function App MCP server，特別是 private endpoint、x-functions-key、NO_PROXY 與 SSE 除錯情境。
  觸發詞："Claude Code", "Copilot CLI", ".claude/mcp.json", "mcp-config.json", "x-functions-key", "NO_PROXY", "Connecting", "remote MCP"。
---

# Outlook Email MCP host/client 設定與排錯

此技能只處理 `outlook-email` sample 的 MCP host/client 連線，不處理其他 sample。

## 主要檔案

| 檔案 | 用途 |
| --- | --- |
| `README.md` | 人類操作主文件，包含 MCP host/client 的入口說明與踩雷紀錄 |
| `.vscode\mcp*.json` | VS Code / Agent Mode 連線模板 |
| `.claude\mcp.json` | Claude Code 使用的 remote MCP 設定 |
| `~\.copilot\mcp-config.json` | Copilot CLI 使用的 MCP 設定（不在 repo 內） |

## 設定原則

1. **VS Code**：沿用 `.vscode\mcp*.json` 模板，複製到 repo root `.vscode\mcp.json`
2. **Claude Code**：使用 `outlook-email\.claude\mcp.json`
3. **Copilot CLI**：使用 `~/.copilot/mcp-config.json` 或 `/mcp add`

## Remote Function App 連線必要條件

### 1. `x-functions-key`

若設定檔使用 `${OUTLOOK_EMAIL_FUNCTION_KEY}` 這種 header 參照，請把值設成**真正的 OS 環境變數**。

```powershell
[Environment]::SetEnvironmentVariable(
  'OUTLOOK_EMAIL_FUNCTION_KEY',
  '<your-functions-key>',
  'User'
)
```

> 在目前這個環境中，Copilot CLI remote HTTP server 的 header 參照不能只依賴 `mcp-config.json` 內部的 `env` 區塊；若只放在那裡，server 可能一直停在 `Connecting`。

### 2. `NO_PROXY`

若遠端 Function App 只走 private route，且本機有公司 proxy，請把下列 host 加進 `NO_PROXY`：

```powershell
$existing = [Environment]::GetEnvironmentVariable('NO_PROXY', 'User')
$extra = @(
  'func-xlxpcx7ss2kmy.azurewebsites.net',
  'func-xlxpcx7ss2kmy.scm.azurewebsites.net',
  'azurewebsites.net'
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
  -H "x-functions-key: $env:OUTLOOK_EMAIL_FUNCTION_KEY" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  --data-raw $body `
  https://func-xlxpcx7ss2kmy.azurewebsites.net/mcp
```

## 何時用這個技能

- 設定 Claude Code 的 `.claude\mcp.json`
- 設定 Copilot CLI 的 `mcp-config.json`
- 遇到 MCP server 一直顯示 `Connecting`
- 排查 private endpoint / proxy / function key 問題
- 用 `initialize` / `tools/list` 直接驗證遠端 MCP transport
