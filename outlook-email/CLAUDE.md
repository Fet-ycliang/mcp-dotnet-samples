# outlook-email

## 範圍
- 目前工作預設只針對 `outlook-email` 這個 sample。
- 不要主動規劃或修改其他 sample。
- 只有在 `outlook-email` 的需求直接碰到共用 transport / host runtime 時，才檢查 `..\shared\McpSamples.Shared\`。

## 文件分工
- `README.md` 是 **操作主來源**：
  - 放本機、Functions、容器、Azure 的完整操作步驟
  - 放 payload 範例、限制、設定注意事項
- `CLAUDE.md` 是 **agent 導航文件**：
  - 放 scope、重要檔案、常用入口命令、技能入口與修改原則
  - 不重複貼 `README.md` 的完整 runbook

## 先看哪裡

| 檔案 | 用途 |
| --- | --- |
| `README.md` | 本機、Functions、容器、Azure 與 `.vscode\mcp.*.json` 的操作主來源 |
| `src\McpSamples.OutlookEmail.HybridApp\Program.cs` | 啟動模式、HTTP 綁定埠號、`GraphServiceClient` DI |
| `src\McpSamples.OutlookEmail.HybridApp\Configurations\OutlookEmailAppSettings.cs` | `--tenant-id`、`--client-id`、`--client-secret` 解析 |
| `src\McpSamples.OutlookEmail.HybridApp\Tools\OutlookEmailTool.cs` | `send_email` MCP tool 介面、描述與結果處理 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\OutlookEmailService.cs` | 驗證、地址解析、附件處理、Graph `SendMail` 呼叫 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\` | tool input / output models |
| `src\McpSamples.OutlookEmail.HybridApp\local.settings.sample.json` | 本機 Functions 設定範本 |
| `src\McpSamples.OutlookEmail.HybridApp\host.json` / `mcp-handler\function.json` | Azure Functions custom handler 與路由轉送設定 |
| `Register-App.ps1` / `register-app.sh` | Entra ID app 註冊腳本 |
| `azure.yaml` / `infra\` | Azure 部署入口與基礎設施 |
| `.vscode\mcp*.json` | STDIO / HTTP / Functions / remote MCP 連線模板 |

## 常用指令

- 建置：`dotnet build .\McpOutlookEmail.sln`
- 本機 STDIO：`dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp`
- 本機 HTTP：`dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http`
- 詳細的 Entra 參數、user secrets、Functions、Docker、Azure 部署與 `.vscode\mcp*.json` 使用方式，請直接看 `README.md`

## 架構重點
- `Program.cs` 先透過 `AppSettings.UseStreamableHttp(...)` 決定 STDIO 或 HTTP。
- HTTP 模式下會讀取 `FUNCTIONS_CUSTOMHANDLER_PORT`，若沒有則預設使用 `5260`。
- 認證與 Graph client 建立都留在 `outlook-email` sample 內，不要隨意搬到 shared。
- `azure.yaml` 目前預設把 `outlook-email` 部署成 **Azure Functions**，不是 Container Apps。
- Azure 命名與 tag 基線目前以 **`fet-outlook-email-bst`** 為核心 stem；實際覆寫方式看 `infra\main.bicep`、`infra\main.parameters.json` 與 `README.md` 的 Azure 部署段落。
- Graph 認證模式的優先序是：`EntraId__UseManagedIdentity` 明確值 > 明確提供的 `EntraId__TenantId` / `ClientId` / `ClientSecret` > `AZURE_CLIENT_ID` fallback。不要只看 `AZURE_CLIENT_ID` 來判斷目前是否一定走 managed identity。
- `send_email` 的責任分層是：
  - `OutlookEmailTool`：MCP tool 介面、參數描述、例外轉結果
  - `OutlookEmailService`：驗證、地址解析、附件 Base64 檢查、Graph payload 建立與發送
  - `GraphServiceClient`：在 `Program.cs` 註冊
- `host.json` 與 `mcp-handler\function.json` 代表此 sample 可作為 Azure Functions custom handler，並以 catch-all route 將 HTTP 要求轉送給 app。

## MCP 連線模式
- `.vscode\mcp.stdio.local.json`：本機 STDIO
- `.vscode\mcp.http.local.json`：本機 HTTP（`http://localhost:5260/mcp`）
- `.vscode\mcp.http.local-func.json`：本機 Functions
- `.vscode\mcp.http.container.json` / `mcp.stdio.container.json`：本機容器
- `.vscode\mcp.http.remote-func.json`：遠端 Functions
- `.vscode\mcp.http.remote-apim.json`：遠端 APIM
- `.claude\mcp.json`：Claude Code 使用的 remote MCP 設定
- `~\.copilot\mcp-config.json`：Copilot CLI 使用的 MCP 設定（不在 repo 內）

## 修改時的工作原則
1. 如果修改 `send_email` 的輸入或輸出：
   - 同步更新 `IOutlookEmailTool`
   - 同步更新 `IOutlookEmailService`
   - 視情況更新 `Models\`
   - 補改 `README.md`
2. 如果修改 CLI 參數：
   - 先改 `OutlookEmailAppSettings.cs`
   - 再改 `README.md` 的執行範例
3. 如果修改啟動與認證：
   - 主要改 `Program.cs`
   - 視需求同步改 `local.settings.sample.json`、腳本與部署文件
4. 收件者與 reply-to 目前支援逗號與分號分隔；變更時要明確同步更新說明。
5. 附件目前要求 `name`、`contentType`、`contentBytesBase64`，且 `contentBytesBase64` 必須是有效 Base64。
6. 如果 `README.md` 已經是某項操作的主來源，不要把完整步驟再複製到 `CLAUDE.md`。

### `send_email` 修改同步檢查清單

| 變更類型 | 至少同步檢查哪些檔案 |
| --- | --- |
| Tool 參數、描述或輸出結果 | `Tools\OutlookEmailTool.cs`、`Interfaces\IOutlookEmailTool.cs`、相關 `Models\`、`README.md` |
| 驗證、地址解析、附件處理、Graph payload | `Services\OutlookEmailService.cs`、`Interfaces\IOutlookEmailService.cs`、相關 `Models\` |
| CLI 參數或設定欄位 | `Configurations\OutlookEmailAppSettings.cs`、`README.md`、`local.settings.sample.json` |
| Graph 認證或寄信流程 | `Program.cs`、`README.md`、`Register-App.ps1`、`register-app.sh` |
| MCP 連線模式、本機啟動方式或 Functions 路由 | `README.md`、`.vscode\mcp*.json`、必要時 `host.json`、`mcp-handler\function.json` |
| 使用者看得到的限制或錯誤訊息 | `README.md`、tool 描述、payload 範例、設定範本 |

## 常見陷阱
- `dotnet run --project ... -- --http ...` 的 `--` 不能省略。
- 若只是調整 `outlook-email` 功能，不要把其他 sample 一起納入 scope。
- 不要把 `outlook-email` 專屬的 Graph / auth 邏輯搬進 shared。
- 目前這個 sample 沒有專屬測試專案；預設驗證基線是 `dotnet build .\McpOutlookEmail.sln`，必要時再補跑 `dotnet run` 或 `func start`。
- 如果只改程式碼卻沒同步 README、設定範本或腳本，後續本機啟動與部署文件很容易失真。
- private Function App / SCM 在有公司 proxy 的環境下，通常要補 `NO_PROXY`；否則看起來像是 server 壞了，其實是流量被送去公網。
- Copilot CLI 若用 `${OUTLOOK_EMAIL_FUNCTION_KEY}` 這種 header 參照，請把值放在**真正的 OS 環境變數**，不要只放在 `mcp-config.json` 的 `env` 區塊。
- 遠端 `/mcp` 目前是 SSE 回應；若用 `curl` / PowerShell 除錯，記得解析 `data:` 行。
- 若 Azure 走 managed identity，就不要同時把 `MCP_ENTRA_*` service principal 值留在 app settings；走 service principal 時則優先使用 Key Vault reference。

## 這次建議用到的 local skills

### `/plan` + `/init` 建議預設使用
- `project-guidelines`
- `outlook-email-local-dev`
- `outlook-email-auth-deployment`

### 進入功能實作時再加
- `outlook-email-tool-implementation`：調整 `send_email`、驗證、Graph payload、工具回傳模型時
- `outlook-email-sendmail-e2e`：做 local 真實寄信、`replyTo` 驗證、CSV / XLSX 附件驗證時
- `outlook-email-mcp-host-setup`：設定 Claude Code / Copilot CLI / remote MCP 連線與排錯時

### 視需求再用
- `skill-creator`：動到 `.claude\` 技能本身時

## 目前 skill 狀態
- `outlook-email` 已具備本機開發、認證部署、工具實作，以及 `send_email` local E2E 驗證用的技能入口。
- 適合抽成 skill、避免在 `README.md` / `CLAUDE.md` 重複堆疊的內容：**host/client MCP 設定流程、remote MCP 連線排錯、private endpoint + proxy 注意事項**。
