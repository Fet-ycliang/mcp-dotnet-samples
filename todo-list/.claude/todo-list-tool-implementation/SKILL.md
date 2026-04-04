---
name: todo-list-tool-implementation
description: |
  todo-list sample 的 tool、資料存放與 EF Core 指引。用於修改 todo MCP tools、repository、DbContext 或 in-memory SQLite 啟動方式。
  觸發詞："todo-list", "add_todo_item", "ExecuteUpdateAsync", "SqliteConnection", "TodoRepository", "TodoDbContext"。
---

# Todo List 工具與資料指引

此技能只處理 `todo-list` sample。

## 主要檔案

| 檔案 | 職責 |
| --- | --- |
| `README.md` | sample 的執行方式與 `.vscode\mcp.*.json` 使用說明 |
| `src\McpSamples.TodoList.HybridApp\Program.cs` | singleton `SqliteConnection`、DbContext、repository 與 HTTP OpenAPI wiring |
| `src\McpSamples.TodoList.HybridApp\Tools\TodoTool.cs` | 5 個 MCP tools 的對外介面與使用者訊息 |
| `src\McpSamples.TodoList.HybridApp\Repositories\TodoRepository.cs` | CRUD 實作，包含 `ExecuteUpdateAsync` / `ExecuteDeleteAsync` |
| `src\McpSamples.TodoList.HybridApp\Data\TodoDbContext.cs` | 資料表 schema |
| `src\McpSamples.TodoList.HybridApp\Models\TodoItem.cs` | todo entity |

## 常用指令

```powershell
dotnet build .\McpTodoList.sln
dotnet run --project .\src\McpSamples.TodoList.HybridApp
dotnet run --project .\src\McpSamples.TodoList.HybridApp -- --http
```

## 修改原則

1. `Program.cs` 內的 in-memory `SqliteConnection` 必須保持 singleton 並在 process lifetime 內維持 open；不要把它改成每次 request 重建。
2. repository 更新 / 刪除沿用 EF Core set-based API（`ExecuteUpdateAsync`、`ExecuteDeleteAsync`），不要改回手動 mutation loop。
3. 如果調整 MCP tool 名稱、參數或回傳訊息，要同步更新 `TodoTool.cs`、相關介面與 `README.md`。
4. 若改到 HTTP 文件輸出，保留既有 `AddHttpContextAccessor()`、`AddOpenApi(...)`、`MapOpenApi("/{documentName}.json")` 模式。

## 常見陷阱

1. 把 SQLite connection lifecycle 弄壞之後，所有資料會看起來像每次重啟都被清空。
2. 忘記 `--` 分隔符號，誤判成 HTTP mode 問題。
3. 直接在 tool 層堆疊過多資料邏輯，而不是維持 `Tool -> Repository -> DbContext` 分層。

