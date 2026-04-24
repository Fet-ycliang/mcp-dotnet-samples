# outlook-email

## 最高準則（Top Priority — overrides everything below）
- **Every mistake → write a rule.**
- **Every correction → permanent memory.**
- **Every session → smarter than the last.**

只要犯錯，就要寫下一條規則；只要被修正，就要化為永久記憶；要讓下一個 session 比上一個更聰明。這是凌駕本文件所有指引之上的元準則：
1. 當使用者指出錯誤或提出修正，**立刻**把它記下（這份 CLAUDE.md 的對應章節 + memory 系統），不要留到「之後再整理」。
2. 記得成功：若使用者明確肯定某個非顯而易見的做法，也要寫下來，避免下次又退回錯誤的預設行為。
3. 寫規則時要附 **Why** 與 **How to apply**，讓未來的我能判斷邊界情境，不是盲從。
4. 不確定要寫到 CLAUDE.md 還是 memory 時，兩邊都寫：CLAUDE.md 保存專案層級規範，memory 保存跨 session 的人機互動準則。

## 範圍
- 目前工作預設只針對 `outlook-email` 這個 專案。
- 不要主動規劃或修改其他 專案。
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
| `src\McpSamples.OutlookEmail.HybridApp\Tools\XlsxAttachmentTool.cs` | `generate_xlsx_attachment` MCP tool 介面、參數描述與結果處理 |
| `src\McpSamples.OutlookEmail.HybridApp\Services\XlsxAttachmentService.cs` | 工作表/資料表/圖表驗證、Open XML Excel 產生與 `GeneratedAttachmentStore` 暫存 |
| `src\McpSamples.OutlookEmail.HybridApp\Models\` | tool input / output models |
| `src\McpSamples.OutlookEmail.HybridApp\local.settings.sample.json` | 本機 Functions 設定範本 |
| `src\McpSamples.OutlookEmail.HybridApp\host.json` / `mcp-handler\function.json` | Azure Functions custom handler 與路由轉送設定 |
| `Register-App.ps1` / `register-app.sh` | Entra ID app 註冊腳本 |
| `azure.yaml` / `infra\` | Azure 部署入口與基礎設施 |
| `infra\remove-apim.bicep` / `infra\remove-apim.parameters.json` | 手動刪除 APIM 用（`az deployment group create`）|
| `infra\rebuild-apim.bicep` / `infra\rebuild-apim.parameters.json` | 手動重建 APIM 用（`az deployment group create`）|
| `..\.github\workflows\build.yaml` / `..\.github\workflows\build-container.yaml` | repo-level GitHub Actions matrix build、GHCR tag 組法與 fail-fast 設定 |
| `..\.github\workflows\deploy-outlook-email-main.yaml` | `main` branch 對 live ACA 的 GitHub Actions rollout；會重建 azd env、同步 ACA secrets、`az acr build`，再執行 `deploy-containerapp-ready-image.ps1` |
| `.vscode\mcp*.json` | STDIO / HTTP / Functions / remote MCP 連線模板 |
| `.mcp.json` | Claude Code 使用的**本地** project-level MCP 設定（不進版控）；這個 repo 的 project code 是 `y94` |
| `.claude\mcp.json` | APIM remote header 參考範例；不是目前 Claude Code 的 project-level 載入入口 |

## 常用指令

- 建置：`dotnet build .\McpOutlookEmail.sln`
- 本機 STDIO：`dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp`
- 本機 HTTP：`dotnet run --project .\src\McpSamples.OutlookEmail.HybridApp -- --http`
- 詳細的 Entra 參數、user secrets、Functions、Docker、Azure 部署與 `.vscode\mcp*.json` 使用方式，請直接看 `README.md`

## 架構重點
- `Program.cs` 先透過 `AppSettings.UseStreamableHttp(...)` 決定 STDIO 或 HTTP。
- HTTP 模式下會讀取 `FUNCTIONS_CUSTOMHANDLER_PORT`，若沒有則預設使用 `5260`。
- 認證與 Graph client 建立都留在 `outlook-email` sample 內，不要隨意搬到 shared。
- `azure.yaml` 現在預設把 `outlook-email` 部署成 **Azure Container Apps**；若你手動跑 `azd up` / `azd deploy`，它仍會用 `Dockerfile.outlook-email-azure` + remote build 自動把映像推到既有 ACR **`fetimageacr`**，並 rollout 到 Container App。
- `main` branch 的 checked-in Azure rollout 入口是 `..\.github\workflows\deploy-outlook-email-main.yaml`；它和 `build.yaml` 分開，前者負責 `fetimageacr` + ACA，後者仍是 GHCR matrix build。
- `main` workflow 已改成 **重建 azd env + 同步 ACA secrets + `az acr build` + `deploy-containerapp-ready-image.ps1`**，故意避開 `azd` 預設產生的 `outlook-email-fet-outlook-email-bst:azd-deploy-<unix>` naming，改用 **`fetimageacr.azurecr.io/fet-outlook-email-ca:<taipei-timestamp>`**。
- ACA secret contract 目前固定保留兩顆：`graph-client-secret` 與 `mcp-oauth-client-secret`。前者給 **Graph outbound auth**，後者給 **ACA inbound MCP OAuth**；不要混用，也不要只更新其中一顆。
- `MCP_ENTRA_CLIENT_SECRET` 與 `MCP_DIRECT_CLIENT_SECRET` 都支援 `@Microsoft.KeyVault(SecretUri=...)`，`main` workflow 與 `deploy-containerapp-ready-image.ps1` 會先同步這兩顆 ACA secret，再做 image rollout；`MCP_OAUTH_CLIENT_SECRET` 只保留 legacy fallback。
- **目前 live Key Vault** 是 `outlook-email-kv`，位於 `apim-app-bst-rg`。它目前已補上 private endpoint `pe-outlook-email-kv`（`PE_Subnet`）與 `aibde-common-rg/privatelink.vaultcore.azure.net`，但 migration 期間仍暫時保留 `publicNetworkAccess=Enabled`。
- `outlook-email-kv` 目前是 **RBAC mode**；不要再用 `az keyvault set-policy`。operator / pipeline 若要寫 secret，走 Azure RBAC；ACA 的 user-assigned managed identity 若要讀 secret，也走 Azure RBAC。
- 目前 repo / azd env / GitHub Actions secrets 內的 `@Microsoft.KeyVault(SecretUri=...)` 都是 **versioned URI**。之後 rotate `graph-client-secret` 或 `mcp-oauth-client-secret` 時，除了寫新值到 Key Vault，也要同步更新 reference 字串本身。
- repo 內的 checked-in infra 現在已支援用 `AZURE_DEPLOY_KEY_VAULT=true`、`AZURE_KEY_VAULT_NAME=outlook-email-kv`、`AZURE_DEPLOY_KEY_VAULT_PRIVATE_ENDPOINT=true`、`AZURE_KEY_VAULT_PUBLIC_NETWORK_ACCESS=Enabled|Disabled` 來接手管理 vault / RBAC / private endpoint；`main` workflow 目前預設把 Key Vault public network access 關成 `Disabled`。
- repo 內的 checked-in APIM Bicep 現在已補上 `mcp-oauth` API（`register` / well-known / `authorize` / `token` / `oauth-protected-resource`）、`mcp` API 的 `validate-jwt` + App Insights diagnostics；`validate-jwt` 目前仍暫時接受新 `mcp.access` 與 legacy `user_impersonation` / `access_as_application`，但 retained path 已多了 caller-app allowlist、`/authorize` client/redirect-uri 檢查，以及 OAuth facade rate limit。
- `mcp-api.policy.xml` 的 `<audiences>` 目前同時接受 `{{McpClientId}}` / `{{McpAppIdUri}}`（新 APIM resource app `apim-mcp`）**與** `{{BackendMcpClientId}}` / `{{BackendMcpAppIdUri}}`（舊 direct path app `mcpEntraApp`）。這是刻意為了 split-auth 後過渡期保留的 legacy audience，Databricks SP `4c2d441f-...`（DatabricksExternalMcp）目前仍只有 `access_as_application` 角色在 `87123f9d-...`（`mcpEntraApp`），所以它拿到的 token `aud=api://87123f9d-...` 需要被允許；等 Databricks 端改成請求 `api://apim-mcp` 並把 role 重新指派到新 app 後，再把這兩個 legacy audience 拿掉。
- `mcp-api.policy.xml` 的 `<issuers>` 同時接受 v2（`https://login.microsoftonline.com/<tenant>/v2.0`）**與** v1（`https://sts.windows.net/<tenant>/`）。舊 `mcpEntraApp` (`87123f9d-...`) 的 `api.requestedAccessTokenVersion` 是 null → 預設 v1，Databricks 用 `api://87123f9d-.../.default` 取得的 token 就是 v1（`iss=sts.windows.net`）。新 `apim-mcp` (`ddfcc64c-...`) 明確設 `requestedAccessTokenVersion=2`，所以是 v2 token。兩條路同時在跑時 validate-jwt 必須兩個 issuer 都接受；未來統一到 v2 後可以把 v1 issuer 拿掉。
- `/authorize` redirect_uri 檢查已支援 **RFC 8252 loopback wildcard**：當 `McpClaudeRedirectUrisCsv` 裡有裸的 `http://localhost` 或 `http://127.0.0.1`（沒帶 port），policy 會比對任何 `http://localhost:<port>/...` / `http://127.0.0.1:<port>/...`；這樣 Claude Code / Copilot CLI 這種每次開不同 port 的 native client 不用重複註冊。非 loopback 的 redirect（例如 Databricks workspace 的 `https://<workspace>/login/oauth/http.html`）**還是 exact match**，要逐個加進 CSV。
- `/register`（DCR）policy 已改成 **RFC 7591 compliant**：讀 request body 的 `redirect_uris`，有效就 echo 回去；沒送就 fallback 回 `McpClaudeRedirectUrisCsv` 預設清單。這是為了讓 Databricks Genie Code 這種 web client 的 DCR 不會收到錯誤的 `http://localhost` 回應。
- `/authorize` 跟 `/token` policy 會**剝掉 `resource` 參數**再轉 forward 到 Entra。MCP 規範（RFC 8707 Resource Indicators）要 client 帶 `resource=<mcp-server-url>`，但 Entra v2 不吃 resource indicator；只要 `resource` value 不等於 scope 對應 app 的 identifier URI，Entra 會回 `AADSTS9010010: The resource parameter provided in the request doesn't match with the requested scopes`。所以在 APIM facade 層吃掉 `resource`，讓 Entra 只看 scope；audience 靠下游 `/mcp` 的 `validate-jwt` 驗。
- `/authorize` 也會把 scope 裡的 `+` 在 split 前換成空白（form-urlencoded 風格 `+` 代表空白，但 `Uri.UnescapeDataString` 不處理），避免 `api://apim-mcp/mcp.access+offline_access` 被當一個 token，導致 scope 清單裡塞進一筆怪字串。
- 目前 `MCP_CLAUDE_REDIRECT_URIS_CSV` azd env 值為 `http://localhost;https://adb-2654999172504234.14.azuredatabricks.net/login/oauth/http.html`（Claude Code loopback + FET 共用 Databricks workspace）；如需新增其他 web caller（Copilot Studio / VS Code Web 等）要同步三處：(a) `azd env set MCP_CLAUDE_REDIRECT_URIS_CSV`、(b) 把同一個 URI 加進 Entra public client app `f4d7461b-...` 的 web redirect URIs、(c) 要不要重跑 `azd provision` 視 branch 而定。
- split-auth 後請分開看三條線：`MCP_DIRECT_*` = direct Function / ACA resource app，`MCP_APIM_RESOURCE_*` = APIM retained path resource app，`MCP_CLAUDE_CLIENT_ID` = Claude public client app（PKCE / `http://localhost`）。
- `MCP_CLAUDE_CLIENT_ID` 在 retained APIM OAuth 路徑下應視為必填；不要再讓它 fallback 成 APIM resource app 自己的 client ID，否則 `/register` 會回錯 client metadata。
- retained APIM path 目前預設只自動放行 `MCP_CLAUDE_CLIENT_ID`；若你還要讓 Azure CLI / Copilot CLI / 其他 caller app 直接帶 Bearer token 打 `/mcp`，請另外補 `MCP_APIM_ALLOWED_CLIENT_APPLICATIONS_CSV`。
- 若要做實際 localhost callback 驗證，`MCP_CLAUDE_CLIENT_ID` 對應的 app 不能只留裸的 `http://localhost`；像這輪用 `http://localhost:8765/callback`，若沒把**完整 URI** 加進 redirect URIs，Entra 會直接回 `AADSTS50011`。
- 若 retained OAuth 第一次人工驗證在 token exchange 才回 `AADSTS50076`，先別急著怪 APIM；通常是 tenant 要求 MFA / step-up，重跑 authorize 時加 `prompt=login` 先完成完整登入。
- `deploy-outlook-email-main.yaml` 目前固定帶 `AZURE_DEPLOY_APIM=false`，只做 routine ACA rollout；若要連 retained APIM / private DNS 一起變更，請改走人工 `azd up`。
- 若要手動或用 CI 發布這條 **main ACA rollout** 的容器映像，命名規則使用 **`<acr-login-server>/fet-outlook-email-ca:<taipei-timestamp>`**。
- **ACA / ACR 這條線固定使用 `Dockerfile.outlook-email-azure`**；不要再把 `Dockerfile.outlook-email` 丟給 `az acr build` / ACR Task，否則容易在 dependency scanner 卡在 `FROM --platform=$BUILDPLATFORM ...`。
- Azure 命名與 tag 基線目前以 **`fet-outlook-email-bst`** 為核心 stem；實際覆寫方式看 `infra\main.bicep`、`infra\main.parameters.json` 與 `README.md` 的 Azure 部署段落。
- **目前 live APIM resource 名稱**是 `apim-fet-outlook-email`；`AZURE_APIM_NAME` 或 README 內的 `fet-mcp-apim-bst` 只應視為 env / 範例值，不要直接當成已落地資源名稱。
- **目前 live APIM retained path backend** 是 ACA `fet-outlook-email-ca`；若要讓 azd 直接接手並持續更新這個既有 ACA，請設定 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME=fet-outlook-email-ca`。template 會沿用該 ACA 的 managed environment / 目前 image 當 deploy baseline，再把 azd service 與 APIM backend 一起對準它。這個參數目前假設 ACA 與本次部署在**同一個 resource group**，而且該 ACA 已啟用 ingress 並有可用 FQDN。注意：template **不會**順手替既有 ACA 補完所有 auth / network 鎖定，你仍要自己確認 ACA 不會變成繞過 APIM 的入口。
- **目前 live frontend 已是 private-only ingress**：Function App 走 **Private Link / private endpoint**，且 `publicNetworkAccess=Disabled`；APIM gateway 走 **Internal VNet + private DNS**。若有人說「frontend 都走 private link」，要先確認他是泛指私網入口，還是嚴格要求 **APIM 也必須是 Azure Private Link**。
- **注意這不是 template 預設值**：目前 live retained path 之所以對準 `fet-outlook-email-ca`，是因為這個 azd env 已把 `AZURE_APIM_INTERNAL_VNET=true` 與 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME=fet-outlook-email-ca` 打開；`main.parameters.json` 的預設仍是空字串或 `false`。
- **APIM subnet**：`apim-subnet`，`172.18.78.0/28`，位於 `apim-bst-vnet`，NSG `172.18.78.0_24_APIM` 與 Route Table `DG-Route-APIM` 已就位，重建 APIM 時 subnet 本身不需異動。
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
- `.mcp.json`：Claude Code 使用的**本地** project-level MCP 設定（不進版控）；若要加 project-level server（例如 `databricks-genie`）請改這裡；這個 repo 的 project code 是 `y94`
- `.mcp.json` 改完後，既有 Claude Code session 不會熱載入；要看新的 server 清單需重開該 repo 的 project / session（`y94`）
- `.claude\mcp.json`：APIM remote header 參考範例（目前以 live APIM `https://apim-fet-outlook-email.azure-api.net/mcp` 當預設例子）；不是目前 Claude Code 的 project-level 載入入口
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
- `send_email` 的 `body` 就算看起來是 HTML，若沒明確提供 `bodyContentType=html`，Graph 仍會以純文字寄出，收件者會看到原始標記。
- 本機直接打 HTTP `/mcp` 除錯時，回應可能是 SSE `text/event-stream`，而且不一定會帶 `mcp-session-id` header；PowerShell / curl 要直接解析 `event:` / `data:` 行，不要只假設是一般 JSON。
- `send_email` 的 payload 驗證雖然在 `OutlookEmailService`，但 tool instance 先要能 resolve `GraphServiceClient`；若本機沒設好 Entra 參數，可能會在進入 tool / service 驗證前就先因 DI 或 auth 設定失敗。
- `send_email` 目前會把 service 例外轉成 `errorMessage` 放在 tool 結果內，因此 `tools/call` 不一定會用 MCP envelope 的 `isError=true` 呈現；排查時要一起看 `result.content[0].text` 與 server log。
- private Function App / SCM 在有公司 proxy 的環境下，通常要補 `NO_PROXY`；否則看起來像是 server 壞了，其實是流量被送去公網。
- 若 APIM remote MCP 使用 `Authorization: Bearer ${OUTLOOK_EMAIL_APIM_ACCESS_TOKEN}`（例如 `.claude\mcp.json` 內的範例），啟動 Claude Code / Copilot CLI 前，先在同一個 shell 刷新 access token。
- **但更推薦直接走 OAuth auto-discovery**：APIM `/mcp-oauth/*` facade 已完整；Claude Code / Copilot CLI 的 `.mcp.json` 對 outlook-email 只要寫 `{"type":"http","url":"https://apim-fet-outlook-email.azure-api.net/mcp"}`，**不要**再放 `headers.Authorization` 或 env var 的 bearer。原因：client 看到 `headers.Authorization` 時優先用它送 request；就算 OAuth flow 已完成並在 `~/.claude/.credentials.json` 存了 token，UI 顯示 `Auth: ✔ authenticated`，實際 request 仍會套設定檔的靜態 header（env var 展開為空就變 `Bearer `），結果 APIM 回 401 → UI `Status: ✘ failed`。移除 `headers` 後，client 會改用已存的 OAuth token，`/mcp initialize` 回 200 SSE 正常。
- 若要重用既有 `MCP_APIM_RESOURCE_CLIENT_ID`，這裡必須填 **Application (client) ID / `appId`**，不是 Entra object ID；這輪 live migration 就曾把 `7dfdd946-...` object ID 誤填進 env，結果 APIM policy / token audience 全部接錯，最後才改回真正的 client ID `ddfcc64c-b3c5-419f-a2c6-c3abed72b64d`。
- `generate_pptx_attachment` 的建議流程是：先產出 `generatedAttachmentId`，再交給 `send_email.generatedAttachmentIds`；不要在遠端 APIM 路徑搬整份 `.pptx` Base64。
- `generate_xlsx_attachment` 與 `generate_pptx_attachment` 共用 `send_email.generatedAttachmentIds`；若附件是伺服器端生成，優先傳 `generatedAttachmentId`，不要把整份 `.xlsx` Base64 搬進 remote MCP payload。
- `generate_xlsx_attachment` 目前是 **chart-first**：`tables[].rows` 每格值都用字串輸入，再依 `columns[].type` 解析；圖表的 `valueColumns` 必須指向 `number` 欄位，且 `pie` 只能指定一個 value column。
- Databricks external MCP 若要打 internal/private APIM，M2M 欄位就算填對，仍可能因 private DNS / reachability 卡在 `tools/list`；若同一組 caller app 直打 APIM `/mcp initialize` / `/mcp tools/list` 成功，先把問題歸在 Databricks 到 private APIM 的可達性，而不是 tool 定義本身。
- 遠端 `/mcp` 目前是 SSE 回應；若用 `curl` / PowerShell 除錯，記得解析 `data:` 行。
- 但 `initialize` 也可能直接回一般 JSON；remote MCP parser 不要只假設一種 response shape。
- `tools/call` 的結果在某些 remote path 下可能被包在 `result.content[0].text`，不要只讀 `structuredContent`。
- Windows PowerShell 若直接用 `curl.exe --data-raw` 送中文 JSON，主旨 / 內文 / slide text 可能變亂碼；改用 **UTF-8 檔案 + `--data-binary`**。
- 若 Azure 走 managed identity，就不要同時把 `MCP_ENTRA_*` service principal 值留在 app settings；走 service principal 時則優先使用 Key Vault reference。
- Key Vault 只是在保存 **secret value**；真正會被 ACA auth sidecar 讀的是 Container App secret name。若 deploy path 只宣告 `graph-client-secret`、沒把 `mcp-oauth-client-secret` 一起帶上，新的 revision 仍會卡在 `Activating`。
- 建 Key Vault private endpoint 後，不要只看 private endpoint connection `Approved`；還要檢查 `privatelink.vaultcore.azure.net` 內是否真的有 `outlook-email-kv` 的 A record。這次 zone group 存在，但 zone 內最初只有 SOA，A record 要另外補。
- 若本機 / jumpbox / runner 沒有 private DNS / VNet reachability，就算補了 `NO_PROXY`，Key Vault data plane 還是可能直接 `getaddrinfo failed`。看到這種錯先查 DNS / network，不要先懷疑 secret value。
- 若 retained APIM 走 shared private DNS zones，而 zone 到目標 VNet 的 link 早就手動建好了，請把既有 link name 一起放進 `AZURE_APIM_PRIVATE_DNS_VNET_LINK_NAME`；不然 `azd provision` 會在 `azure-api.net` / `portal.azure-api.net` / `management.azure-api.net` 等 zone 上直接撞 `already linked to the virtual network`。
- ACR tag 不是資料夾；若要做 branch 分目錄，請把 branch 放在 repository path（例如 `fet-mcp-server-dotnet/feature/pptx-mailer:20260418-101011`），不要放進 tag。
- 若沿用既有 shared ACR，而 ACA user-assigned identity 的 `AcrPull` 角色指派是歷史上用隨機 GUID 建的，請把既有 assignment name 放進 `AZURE_CONTAINER_REGISTRY_ACR_PULL_ROLE_ASSIGNMENT_NAME`；否則 ARM 可能在 role / principal / scope 全都已正確存在時，仍回 `RoleAssignmentExists`。
- branch 名稱若直接拿 `refs/heads/*`、大寫或特殊字元組 image ref，常會踩到非法名稱；先轉小寫、去掉 `refs/heads/`，其餘不安全字元改成 `-`。
- GitHub Actions reusable workflow 若要推 GHCR image，不要直接拿原始 `GITHUB_REPOSITORY` 組 image ref；owner / repo 要先轉小寫，否則 `docker buildx` 常會報 `repository name must be lowercase`。
- 查 `Build MCP Servers` 這種 matrix workflow 時，`outlook-email` job 若顯示 `cancelled` / `The operation was canceled.`，先別把它當根因；先找同一個 run 裡最早的 `failure` job。若不想讓其他 image 被連帶取消，記得把 `strategy.fail-fast` 關掉。
- `Build MCP Servers` 成功不等於 live ACA 已更新；`main` 真正的 Azure rollout 要看 `deploy-outlook-email-main.yaml`，而且若 repo 沒有 `MCP_VALIDATION_*` secrets，workflow 會刻意帶 `MCP_SKIP_POSTDEPLOY_VALIDATION=true`，先避免 GitHub deployment service principal 卡在 direct ACA 的 `user_impersonation` fallback。
- `awesome-copilot` 的 MCP Registry 名稱固定是 `io.github.microsoft/awesome-copilot`；fork repo（例如 `Fet-ycliang/mcp-dotnet-samples`）只有 `io.github.<fork-owner>/*` 的 publish 權限，若 workflow 沒有把 metadata sync / registry publish 限制在官方 repo，就會在 `mcp-publisher publish` 收到 `403 Forbidden`。
- 若要建 ACA / ACR 映像，請固定用 `Dockerfile.outlook-email-azure`；`Dockerfile.outlook-email` 只要進 ACR scanner，就可能卡在 `FROM --platform=$BUILDPLATFORM ...`。
- `PptxPresentationService` 若再動到 Open XML packaging，**不要**把 `ThemePart` 再掛回 `PresentationPart`，也不要自己手寫 slide relationship ID；交給 SDK 指派，否則 deck 在 4+ slides 可能壞掉。
- `generate_pptx_attachment` 目前刻意讓 **封面頁不帶 footer**、內容頁才帶 deck title + page number；若你再改模板，README / skills 也要一起同步。
- 若調整內容框大小或文字上限，記得保留 auto-fit 或同步收緊 validation；不然 deck 雖然能開，但長標題 / 長 bullets 會被裁掉。

### APIM 維運相關陷阱
- **APIM 刪除是長時間操作**（實測約 10 分鐘），不要中途 Ctrl+C；中斷後資源狀態會卡在 Deleting，需在 Portal 確認完成。
- **`az role assignment list --assignee <managed-identity-resource-id>` 會因 Graph API 限制報錯**；查 managed identity 的角色指派時，需先用 `az identity show --query principalId` 取得 `principalId`，再用 `--assignee-object-id <principalId>` 查詢。
- **`remove-apim.bicep` 的 deploymentScript 需要 managed identity 具備 Contributor 以上權限**；若指定的 identity 沒有足夠 RBAC，script 會在 Azure 端靜默失敗或卡住。
- **APIM subnet 不會隨 APIM 一起刪除**；重建前先確認 subnet 仍存在且 prefix 正確，不要重複建立。

### APIM policy expression 陷阱（Razor / CSHTML）
- **單行 `if`/`else` 必須加大括號**：APIM policy expression 是 Razor/CSHTML syntax，不接受 `if (cond) return false;` 這種無大括號寫法，PUT 時會回 `ValidationError: Block statements must be enclosed in "{" and "}"`。一律寫成 `if (cond) { return false; }`。
- **字串裡的 `//` 會被 Razor lexer 誤判為 line comment**：像 `"http://localhost"` 放在 `var x = foo.StartsWith("http://localhost", ...)` 這種 `var =` 右值裡，APIM parser 會從 `//` 開始把剩下的當註解，最後報 `( missing )`。已知 workaround：用 `"http:\u002F\u002Flocalhost"` 或把 `/` 拆開字串拼接；放進 `.Any(lambda => ...)` 的 lambda body 內**不會**踩到這個問題，因為 parser 對 lambda body 有不同 tokenization。若要改 `mcp-oauth-authorize.policy.xml` 這類檔案，優先把含 `//` 的 URL 字串抽成 `var localhostHost = "http:\u002F\u002Flocalhost";` 再組合，不要直接 inline `"http://..."`。
- **改 policy 時直接用 ARM REST `az rest` / curl + Management API 比 `az apim` CLI 快**：`az apim api operation policy` 這個 subcommand 不存在（2.79 CLI）；改用 `PUT /subscriptions/.../apis/{id}/operations/{id}/policies/policy?api-version=2023-05-01-preview`，body 為 `{"properties":{"format":"rawxml","value":"<policies>..."}}`。Windows bash 下 `curl --data-binary @file` 的 file 路徑要用 Unix 樣式 `/tmp/...`，不要寫 Windows 絕對路徑。

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
