---
name: markdown-to-html-local-dev
description: |
  markdown-to-html sample 的本機開發與轉換設定指引。用於調整 CLI flags、Markdig 轉換流程、HTML 後處理與 README 範例。
  觸發詞："markdown-to-html", "--tags", "--tech-community", "-tc", "-p", "Markdig", "convert_markdown_to_html"。
---

# Markdown to HTML 本機開發指引

此技能只處理 `markdown-to-html` sample。

## 主要檔案

| 檔案 | 職責 |
| --- | --- |
| `README.md` | 本機、容器與 Azure 執行方式，以及 flags 範例 |
| `src\McpSamples.MarkdownToHtml.HybridApp\Program.cs` | 啟動模式與 regex 注入 |
| `src\McpSamples.MarkdownToHtml.HybridApp\Configurations\MarkdownToHtmlAppSettings.cs` | `--tech-community`、`--extra-paragraph`、`--tags` 解析 |
| `src\McpSamples.MarkdownToHtml.HybridApp\Tools\MarkdownToHtmlTool.cs` | `convert_markdown_to_html` MCP tool 與轉換主流程 |
| `src\McpSamples.MarkdownToHtml.HybridApp\Extensions\StringExtensions.cs` | HTML 後處理輔助邏輯 |

## 常用指令

```powershell
dotnet build .\McpMarkdownToHtml.sln
dotnet run --project .\src\McpSamples.MarkdownToHtml.HybridApp
dotnet run --project .\src\McpSamples.MarkdownToHtml.HybridApp -- --http -tc -p --tags "p,h1,h2,h3,ol,ul,dl"
```

## 修改原則

1. 新增或調整 flags 時，先改 `MarkdownToHtmlAppSettings.ParseMore(...)`，再同步更新 `README.md` 範例。
2. `--tags` 是逗號分隔字串，處理時要保留 trim 與空值過濾行為。
3. 此 sample 是**無狀態**轉換流程；不要加入不必要的持久化或 sample 外部依賴。
4. 轉換邏輯若有變動，優先維持既有的 Markdig pipeline 與 HTML 後處理責任分界。

## 常見陷阱

1. 忘記 `dotnet run --project ... -- --http ...` 的 `--`，導致 flags 沒有送進 app。
2. 把 sample-specific 格式規則塞進 `shared`。
3. 修改 regex 或 HTML 後處理後，卻沒有同步檢查 README 例子是否仍然成立。

