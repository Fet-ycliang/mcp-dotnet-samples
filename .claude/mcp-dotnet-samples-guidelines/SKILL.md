---
name: mcp-dotnet-samples-guidelines
description: |
  mcp-dotnet-samples repo-wide 指引。用於判斷應該修改哪個 sample、理解 mono-repo 結構、遵循 shared/runtime 慣例，或執行正確的 build/run 流程。
  觸發詞："mcp-dotnet-samples", "mono-repo", "哪個 sample", "repo conventions", "shared runtime", "dotnet build", "dotnet run"。
---

# MCP .NET Samples Repo 指引

此技能處理整個 repo 的共通結構與工作邊界，不負責單一 sample 的深度實作。

## 先看哪裡

| 檔案 | 用途 |
| --- | --- |
| `.github\copilot-instructions.md` | repo 已驗證的 build、architecture 與 conventions 摘要 |
| `README.md` | 4 個 sample 的入口與安裝連結 |
| `shared\McpSamples.Shared\` | 共用 MCP host/runtime plumbing |
| `<sample>\README.md` | 各 sample 的實際執行方式、port、部署與 `.vscode\mcp.*.json` 用法 |

## Repo 結構判斷

1. 這是 mono-repo，但每個 sample 都是**獨立專案**：
   - `awesome-copilot`
   - `markdown-to-html`
   - `todo-list`
   - `outlook-email`
2. `shared\McpSamples.Shared` 只放共通 host/runtime、app settings 與 OpenAPI wiring。
3. sample 專屬的認證、資料存取、業務邏輯、工具行為，都應留在各自 sample 目錄，不要隨意搬進 `shared`。

## 常用指令

### 建置單一 sample

```powershell
dotnet build .\todo-list\McpTodoList.sln
```

### 用 CI 的方式建置 sample

```powershell
Set-Location .\todo-list
dotnet restore
dotnet build
```

### 啟動 sample

```powershell
dotnet run --project .\todo-list\src\McpSamples.TodoList.HybridApp
dotnet run --project .\todo-list\src\McpSamples.TodoList.HybridApp -- --http
```

## 工作原則

1. 新的 MCP tools / prompts / resources，優先放在 sample 專案內，以 public attributed types 讓 assembly scanning 自動註冊。
2. 不要發明 repo 內不存在的 test、lint 或 format 流程；目前 repo 沒有內建 `dotnet test` 或 `dotnet format` 工作流。
3. `dotnet run --project ... -- --http <其他參數>` 這個 `--` 分隔符號必須保留，否則 sample-specific flags 不會正確解析。
4. Root Dockerfile 命名採 `Dockerfile.<sample>`，容器內一律 expose `8080`。
5. VS Code MCP 設定是從各 sample 的 `.vscode\mcp.*.json` 複製到 repo root `.vscode\mcp.json`，不是直接改 sample 模板。

## 何時切換到其他技能

- shared transport / AppSettings / OpenAPI / MCP registration：改看 `shared-hybrid-runtime`
- `awesome-copilot` metadata 或 registry workflow：改看 `awesome-copilot-metadata`
- `markdown-to-html` 轉換與 flags：改看 `markdown-to-html-local-dev`
- `todo-list` 的 tool、repository 與 SQLite：改看 `todo-list-tool-implementation`

