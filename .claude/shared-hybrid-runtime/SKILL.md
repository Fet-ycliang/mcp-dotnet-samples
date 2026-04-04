---
name: shared-hybrid-runtime
description: |
  shared\McpSamples.Shared 的 Hybrid MCP host/runtime 指引。用於修改 transport selection、AppSettings、BuildApp、OpenAPI transformer，或排查 tools/prompts/resources 的自動註冊問題。
  觸發詞："BuildApp", "AppSettings", "--http", "MapMcp", "WithToolsFromAssembly", "shared runtime", "McpDocumentTransformer"。
---

# Shared Hybrid Runtime 指引

此技能只處理 `shared\McpSamples.Shared`。sample 專屬邏輯不要搬進 shared。

## 主要檔案

| 檔案 | 職責 |
| --- | --- |
| `shared\McpSamples.Shared\Configurations\AppSettings.cs` | 共通 CLI / environment 行為，包含 `UseStreamableHttp(...)`、`--http`、`--help` |
| `shared\McpSamples.Shared\Extensions\ServiceCollectionExtensions.cs` | `AddAppSettings<T>()`，將設定註冊進 DI |
| `shared\McpSamples.Shared\Extensions\HostApplicationBuilderExtensions.cs` | `BuildApp(...)`，負責 STDIO / HTTP transport 與 assembly scanning |
| `shared\McpSamples.Shared\OpenApi\McpDocumentTransformer.cs` | HTTP 模式下的 OpenAPI 文件轉換與 `/mcp` 描述 |

## 修改原則

1. shared 只處理共通 flag 與共通 runtime 行為；sample-specific flags 要留在各 sample 的 `ParseMore<T>()`。
2. `BuildApp(...)` 已經會自動用 entry assembly 掃描 tools / prompts / resources。新增 MCP 介面時，優先沿用 attribute + assembly scan，不要先走手動註冊。
3. 如果新增或調整 HTTP 模式的 OpenAPI wiring，記得完整模式包含：
   - `AddHttpContextAccessor()`
   - 兩份文件：Swagger 2.0 與 OpenAPI 3.0
   - `McpDocumentTransformer<T>`
   - `MapOpenApi("/{documentName}.json")`
4. 不要讓 `shared` 依賴單一 sample 的認證、資料模型或外部服務。

## 常見陷阱

1. 忘記 sample 端的 `--` 分隔符號，導致看起來像 shared parsing 壞掉，其實是命令列沒被正確傳入。
2. 在 `BuildApp(...)` 假設永遠是 `WebApplicationBuilder`；STDIO 模式其實走 `HostApplicationBuilder`。
3. 修改 `AddAppSettings<T>()` 或 `BuildApp(...)` 後只驗證單一 sample。shared 變更應視為跨 sample 影響。

## 建議驗證

shared 有變更時，至少建置 4 個 sample：

```powershell
dotnet build .\awesome-copilot\McpAwesomeCopilot.sln
dotnet build .\markdown-to-html\McpMarkdownToHtml.sln
dotnet build .\todo-list\McpTodoList.sln
dotnet build .\outlook-email\McpOutlookEmail.sln
```

## 延伸判斷

- 如果你要改某個 sample 的工具邏輯，先回該 sample 的 skill，不要在 shared 直接實作 sample 行為。
- 如果你要新增 repo-level 規範或操作說明，先參考 `mcp-dotnet-samples-guidelines`，避免和 `.github\copilot-instructions.md` 重複貼整段內容。

