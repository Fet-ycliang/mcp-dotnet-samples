---
name: outlook-email-auth-deployment
description: |
  outlook-email 認證與部署指引。用於註冊 Entra ID app、設定 `local.settings.json`、以 Functions 方式本機執行，或使用 `azd` 將主要 backend 部署到 Azure Container Apps。
  觸發詞："register app", "Entra ID", "func start", "local.settings.json", "azd up", "Azure 部署"。
---

# Outlook Email 認證與部署指引

此技能專門處理 `outlook-email` 的認證設定與部署步驟，只看這個 sample。

## 主要檔案與腳本

| 檔案 | 用途 |
| --- | --- |
| `Register-App.ps1` | 以 PowerShell 註冊 Entra ID app |
| `register-app.sh` | 以 bash 註冊 Entra ID app |
| `README.md` | 本層認證、Functions、本機、Container Apps 與 Azure 部署步驟 |
| `src\McpSamples.OutlookEmail.HybridApp\local.settings.sample.json` | Functions 本機設定範本 |
| `azure.yaml` | `azd` 入口設定 |
| `infra\` | Azure 基礎設施定義 |

## 認證設定流程

詳細命令以 `README.md` 為主；此技能只保留 agent 需要重複使用的決策與檢查點，避免和 `README.md` 重複維護。

### 1. 註冊 Entra ID app

在 `outlook-email` 目錄執行：

```powershell
.\Register-App.ps1
```

完成後請記下 tenant ID、client ID 與 client secret。

### 2. 本機 Hybrid App 認證

有兩種方式：

- **優先**存到 user secrets，讓 `Program.cs` 啟動時從設定讀取
- 直接使用命令列參數：`-t`、`-c`、`-s`（只適合暫時除錯，不建議長期使用）

### 3. 本機 Functions 認證

先複製設定檔：

```powershell
Copy-Item .\src\McpSamples.OutlookEmail.HybridApp\local.settings.sample.json .\src\McpSamples.OutlookEmail.HybridApp\local.settings.json -Force
```

再把 `local.settings.json` 內的下列值填好：

- `EntraId__TenantId`
- `EntraId__ClientId`
- `EntraId__ClientSecret`
- `UseHttp`

若這次要用 service principal，請一併設定：

- `EntraId__UseManagedIdentity=false`

然後在專案目錄執行：

```powershell
Set-Location .\src\McpSamples.OutlookEmail.HybridApp
func start
```

## Azure 部署流程

在 `outlook-email` 目錄執行：

```powershell
azd auth login
azd up
```

目前 `azure.yaml` 已改成：

- `host: containerapp`
- `docker.path: ../../../Dockerfile.outlook-email-azure`
- `docker.remoteBuild: true`

也就是說：

- `azd up` / `azd deploy` 會先把映像建到既有 ACR `fetimageacr`
- 再把新 revision rollout 到 ACA
- `postdeploy` hook 會驗 direct ACA `/mcp` 的 `initialize` 與 `tools/list`

> `postdeploy` hook 在 `azure.yaml` 內寫的是 `./hooks/postdeploy-validate-mcp.ps1`，因為 **service hook 的工作目錄就是 `project: src/McpSamples.OutlookEmail.HybridApp`**；不要誤改成再多包一層 `src/...`

若 Azure 要走 service principal：

- `MCP_ENTRA_USE_MANAGED_IDENTITY=false`
- `MCP_ENTRA_TENANT_ID`
- `MCP_ENTRA_CLIENT_ID`
- `MCP_ENTRA_CLIENT_SECRET`

若要保留 APIM + OAuth，建議使用 split-auth contract：

- `MCP_DIRECT_TENANT_ID`
- `MCP_DIRECT_CLIENT_ID`
- `MCP_DIRECT_CLIENT_SECRET`
- `MCP_DIRECT_APPLICATION_ID_URI`（選填）
- `MCP_APIM_RESOURCE_TENANT_ID`
- `MCP_APIM_RESOURCE_CLIENT_ID`
- `MCP_APIM_RESOURCE_APPLICATION_ID_URI`（選填）
- `MCP_CLAUDE_CLIENT_ID`
- `MCP_CLAUDE_REDIRECT_URIS_CSV`（選填，預設 `http://localhost`）
- `MCP_APIM_ALLOWED_CLIENT_APPLICATIONS_CSV`（選填）
- `MCP_EXTERNAL_CALLER_APP_IDS_CSV`（選填）— 外部 M2M caller 的 Entra app ID 清單

> `MCP_DIRECT_*` 是 direct Function / ACA 路徑的 resource app 與 secret contract。
>
> `MCP_APIM_RESOURCE_*` 是 APIM inbound token 驗證用的 resource app；若 tenant/client ID 同時存在，部署就會重用既有 app，而不再建立新的 APIM MCP resource app。
>
> `MCP_APIM_RESOURCE_CLIENT_ID` 要填 **Application (client) ID / `appId`**，不要填 Entra object ID。這輪 live migration 就曾把 `7dfdd946-...` object ID 當成 client ID，最後要改回真正的 client ID `ddfcc64c-b3c5-419f-a2c6-c3abed72b64d`。
>
> `MCP_DIRECT_CLIENT_SECRET` 會落成 ACA secret name `mcp-oauth-client-secret`。它要跟 `MCP_ENTRA_CLIENT_SECRET` 分開保管，兩者都建議直接放 `@Microsoft.KeyVault(SecretUri=...)`。
>
> `MCP_CLAUDE_CLIENT_ID` 對應的是 Claude caller public client app（PKCE / `http://localhost`），不是 resource app；這條路徑不要再塞 confidential client secret，而且在 retained APIM OAuth 路徑下應視為必填，不要再 fallback 成 resource app 自己的 client ID。
>
> `MCP_CLAUDE_REDIRECT_URIS_CSV` 會同時決定 `/register` 回傳的 `redirect_uris`，以及 `/authorize` 允許前轉到 Entra 的 `redirect_uri` allowlist。實際 browser PKCE callback 若不是裸的 `http://localhost`，請把完整 URI 補進來。
>
> `MCP_APIM_ALLOWED_CLIENT_APPLICATIONS_CSV` 是 retained `/mcp` 的額外 caller allowlist。模板會自動把 `MCP_CLAUDE_CLIENT_ID` 放進去；若你還要讓 Azure CLI / Copilot CLI / 其他 dedicated caller app 帶 Bearer token 直打 APIM retained path，記得把那些 caller app 的 client ID 也加進來。
>
> `MCP_EXTERNAL_CALLER_APP_IDS_CSV` 是外部 M2M caller（例如 Databricks SP）的 Entra app ID 清單。部署時 `resources.bicep` 會用 `infra/modules/entra-app-role-assignment.bicep` 模組迴圈為每個外部 caller 授予 `access_as_application` role；若只有外部 M2M caller 需要 grant、不部署 APIM facade，這個參數也能獨立生效。完整的 Grant 作業清單（G-1 到 G-6）在 `README.md`。
>
> 若你要做實際的 localhost callback 測試，不要只註冊裸的 `http://localhost`。這輪 live E2E 就曾因為 `http://localhost:8765/callback` 沒被明確加入 redirect URIs 而撞到 `AADSTS50011`。
>
> 目前 live `outlook-email-kv` 是 **RBAC mode**。若你要重建或遷移這顆 vault，operator / pipeline 要用 Azure RBAC 寫 secret，ACA 的 user-assigned managed identity 要用 Azure RBAC 讀 secret；`az keyvault set-policy` 不適用。
>
> 目前 repo / azd env / GitHub Actions secrets 內放的是 **versioned SecretUri**。rotate `graph-client-secret` 或 `mcp-oauth-client-secret` 時，不只要寫新 secret value，還要同步更新 `@Microsoft.KeyVault(SecretUri=...)` 指到新的 version。
>
> 若要讓 checked-in infra 直接接手這顆 live vault / private endpoint，可再補：
> - `AZURE_DEPLOY_KEY_VAULT=true`
> - `AZURE_KEY_VAULT_NAME=outlook-email-kv`
> - `AZURE_DEPLOY_KEY_VAULT_PRIVATE_ENDPOINT=true`
> - `AZURE_KEY_VAULT_PUBLIC_NETWORK_ACCESS=Disabled`
>
> `main` branch routine rollout 現在已改成 `publicNetworkAccess=Disabled`。若你還有 caller / runner 必須走公網，請在自己的 env 額外覆寫。
>
> repo 內現在也已經把 `mcp-oauth` APIM facade、`mcp` API `validate-jwt`、以及 App Insights diagnostics 收進 Bicep；split-auth 後，APIM resource app 與 Claude caller app 要分開維護：resource app 管 `mcp.access` / `access_as_application`，`http://localhost` public client redirect 應留在 Claude caller app。
>
> 若 tenant 會對 retained MCP resource app 要求 MFA / Conditional Access，人工驗證 authorize -> token 流程時可先帶 `prompt=login`，避免在 token exchange 才收到 `AADSTS50076`。

若要請 administrator 補齊權限，請分開看：

- **APIM inbound OAuth**
  - 若要讓部署流程自動建立 APIM MCP resource app，執行 `azd provision` 的身分至少要有 Microsoft Entra `Application Administrator` 或 `Cloud Application Administrator`
  - 若不讓部署自動建立 app，則 administrator 要先提供一顆已完成 **Expose an API** 的既有 app registration，至少要同時具備：
    - delegated scope：`mcp.access`
    - application role：`access_as_application`
- **backend 出站 sendMail**
  - 若用 service principal：`MCP_ENTRA_CLIENT_ID` 對應的 app 需要 Microsoft Graph **Application** permission `Mail.Send`，並完成 **admin consent**
  - 若改用 managed identity：backend 使用的 user-assigned managed identity service principal 一樣需要 Microsoft Graph **Application** permission `Mail.Send`，並完成 **admin consent**
  - 若 Exchange Online 有 **Application Access Policy / Application RBAC**，還要把寄件者 mailbox 或 mail-enabled security group 納入允許範圍
  - **天條 SaaS 例外**：Exchange Online（`Mail.Send`）與 Microsoft Entra ID（`login.microsoftonline.com`）本質上只有 internet 入口，走 internet + TLS 是合規設計，不視為天條違規。天條保護的是「公司擁有的業務資料」；OAuth token 本身不屬之。若要審查 data path，重點放在 email content 是否透過私網（NCC / private endpoint）抵達 ACA，而不是 Entra token endpoint 的 routing。

> 這些是 Entra / Microsoft Graph / Exchange Online 權限，不是 Azure subscription RBAC。

若 Azure 要走 managed identity：

- 不要同時保留 `MCP_ENTRA_TENANT_ID` / `MCP_ENTRA_CLIENT_ID` / `MCP_ENTRA_CLIENT_SECRET`
- 若先前曾用過 service principal，切回 managed identity 時要一併清掉這些值

若 Azure 走 service principal，**優先建議把 `MCP_ENTRA_CLIENT_SECRET` 與 `MCP_DIRECT_CLIENT_SECRET` 都改成 Key Vault reference**；raw env var 只適合短期 bootstrap。

若要把 Key Vault 也收進 private networking：

- 目前 live 例子是 `outlook-email-kv` + private endpoint `pe-outlook-email-kv`
- subnet 用 `apim-bst-vnet/PE_Subnet`
- private DNS zone 用 `aibde-common-rg/privatelink.vaultcore.azure.net`
- 若要讓 azd / workflow 一起管理這條路徑，記得同步設 `AZURE_DEPLOY_KEY_VAULT=true` 與 `AZURE_DEPLOY_KEY_VAULT_PRIVATE_ENDPOINT=true`
- 建完 private endpoint 後，不要只看 connection `Approved`；要再確認 zone 內真的有 `outlook-email-kv` 的 A record
- 若 caller 沒有 private DNS / VNet reachability，就算補 `NO_PROXY`，Key Vault data plane 仍可能 `getaddrinfo failed`

若你要走 **APIM + OAuth** 的遠端 MCP 路徑：

- 保持 `AZURE_DEPLOY_APIM=true`
- 開發 / 測試若想先控制固定成本，可設 `AZURE_APIM_SKU=Developer`
- 若要精準固定 APIM 名稱，可設 `AZURE_APIM_NAME=fet-mcp-apim-bst`
- 若要讓 azd **直接接手既有 ACA 名稱**，並讓 retained path 一起對準它，可設 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME=fet-outlook-email-ca`
- 若要把 APIM 放進 internal/private VNet mode，可再設 `AZURE_APIM_INTERNAL_VNET=true` 與 `AZURE_APIM_SUBNET_NAME=apim-subnet`
- 若只要先落地 APIM internal/private 基礎設施，可加 `AZURE_DEPLOY_APIM_MCP_API=false`，先跳過 MCP API facade 與 OAuth app
- 若未設定 `AZURE_APIM_SKU`，目前預設仍是 `Basicv2`
- 若這次部署採 `AZURE_DEPLOY_APIM=false`，`AZURE_APIM_SKU` 會被忽略
- 若這次部署採 `AZURE_DEPLOY_APIM=false`，`AZURE_APIM_NAME` 也會被忽略
- 若未設定 `AZURE_APIM_NAME`，APIM 仍會沿用標準衍生命名
- 若已設定 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME`，template 會沿用該 ACA 的 managed environment / 目前 image 當 deploy baseline，再把 azd service 與 APIM backend 一起對準它
- 若未設定 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME`，template 會用 sample 衍生名稱建立新的 ACA，並讓 APIM backend 指到那個新 ACA
- `AZURE_APIM_BACKEND_CONTAINER_APP_NAME` 目前假設目標 ACA 與本次部署在**同一個 resource group**，而且已啟用 ingress 並有有效 FQDN；若不符合，需先擴充 template
- `AZURE_APIM_BACKEND_CONTAINER_APP_NAME` 會讓 template 重管 image、identity 與 registry wiring，但 **不會**順手補完環境外額外需要的 auth / network hardening；若 retained path 要正式 front APIM，仍要自行確保該 ACA 不會變成繞過 APIM 的入口
- internal/private APIM 目前假設重用既有 VNet / subnet，且會在 `AZURE_PRIVATE_DNS_ZONE_RESOURCE_GROUP_NAME` 建立 / 更新 APIM 預設 hostname 的 private DNS zone 與 A records
- APIM subnet 的 NSG 至少要先有：
  - Inbound `ApiManagement` -> `VirtualNetwork` TCP `3443`
  - Inbound `AzureLoadBalancer` -> `VirtualNetwork` TCP `6390`
- 若缺這些規則，internal APIM 常見症狀是 provisioning 長時間停在 `Activating`
- 正式環境再回頭評估 `Basicv2` / `Standardv2` / `Premium`

### APIM internal / private 快速記憶點（2026-04）

- `MCP_APIM_RESOURCE_*` 是 **APIM inbound OAuth**；`MCP_DIRECT_*` 是 **direct Function / ACA auth**；`MCP_ENTRA_*` 或 managed identity 是 **backend outbound Graph auth**
- 目前 live retained path backend 是 ACA `fet-outlook-email-ca`；APIM gateway 走 **Internal VNet + private DNS**
- 若有人要求「frontend 都走 private link」，先確認他是泛指私網入口，還是嚴格要求 **APIM 也必須改成 Azure Private Link / private endpoint**；目前這份 template 的 APIM 路徑是 internal injection，不是 APIM inbound private endpoint
- 這個結論是 **live azd env** 的現況，不是 repo default；目前能成立是因為環境已把 `AZURE_APIM_INTERNAL_VNET=true` 與 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME=fet-outlook-email-ca` 打開
- 若呼叫端是 **Copilot CLI / Claude Code**，通常走 delegated `mcp.access`（policy 仍暫時接受 legacy `user_impersonation`）
- 若呼叫端是 **Databricks / job / daemon / 外部平台**，應走 **OAuth Machine to Machine**；打 direct Function 就用 `api://<MCP_DIRECT_CLIENT_ID>/.default`，打 APIM retained path 就用 `api://<MCP_APIM_RESOURCE_CLIENT_ID>/.default`
- 外部平台 UI 若出現 **Host / Port / Client ID / Client secret / OAuth scope**：
  - Host = APIM gateway base URL（例如 `https://apim-fet-outlook-email.azure-api.net`），不是 Entra token endpoint
  - Port = `443`
  - Client ID / secret = **caller client app**，不是 resource app
  - OAuth scope = resource app 的 `.default`，不是 delegated `mcp.access`
- 若下一步 UI 出現 **Token endpoint / Is mcp connection / Base path**：
  - Token endpoint = `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token`
  - Is mcp connection = **checked**
  - Base path = `/mcp`（若 Host 已經誤帶 `/mcp`，則 Base path 改成 `/`）
- 建議為外部平台建立 **dedicated caller client app**，只指派 `access_as_application`；不要直接重用 backend 出站打 Graph 的 app
- 若 Databricks external MCP 的 connection overview 已經顯示 token expiration，但 `Failed to list tools` 仍發生，不要先一直改 Host / Base path；先用**同一組 caller app** 從 CLI 直接打 APIM `/mcp initialize` / `/mcp tools/list`
- 若 CLI 直打成功、Databricks 仍失敗，而 APIM host 又解析到 private / intranet IP（這輪環境是 `172.18.78.4`），優先判定為 **Databricks managed proxy 無法 reach private APIM / private DNS**
- 這種情況要改的是**網路可達性方案**（public/restricted facade、Databricks 可達 proxy、或 private DNS / VNet 路徑），不是反覆重填 M2M 表單
- `AZURE_DEPLOY_APIM_MCP_API=false` 只會先落地 APIM service / private DNS 骨架，不會建立 `mcp` API facade
- internal APIM 驗證順序建議固定為：**control plane** -> **private DNS / TCP 443** -> **`/.well-known/oauth-protected-resource`** -> **`initialize` / `tools/list`** -> **`send_email`**
- 若 `apim-subnet` 要走 UDR，不要直接重用共用 `DG-Route-CP`；改用 APIM 專用 route table，至少保留 `ApiManagement -> Internet`
- 這次實際落地的 APIM 架構圖、資料流與 lessons learned 以 `README.md` 的 **「本輪踩雷與避坑紀錄（2026-04）」** 為主

部署後可用下列指令查詢資源 FQDN：

```powershell
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN
azd env get-value AZURE_CONTAINER_REGISTRY_ENDPOINT
```

### ACR image naming 快速記憶點

- 目前 `azure.yaml` 是 `host: containerapp`，所以你手動跑 `azd up` / `azd deploy` 時，仍會自動把容器映像推到既有 ACR `fetimageacr`，然後 rollout 到 ACA。
- 若你要**精準控制** repository path / tag naming，請改走手動 `docker build` / `docker push` 或 CI pipeline；不要把 azd remote build 當成可完全客製命名的發版流程。
- `main` 這條 ACA rollout 若要手動或用 CI 發布容器映像，命名規則使用：`<acr-login-server>/fet-outlook-email-ca:<taipei-timestamp>`
- ACA / ACR 這條線固定使用 `Dockerfile.outlook-email-azure`；不要再把 `Dockerfile.outlook-email` 丟給 `az acr build` / ACR Task，否則容易卡在 dependency scanner 的 `FROM --platform=$BUILDPLATFORM ...`
- `main` 這條路徑直接沿用 ACA 名稱當 repository；tag 建議固定用 Asia/Taipei `yyyyMMdd-HHmmss`
- branch 名稱先轉小寫、移除 `refs/heads/`，其餘不安全字元轉成 `-`
- 若同一秒可能產出多個映像，tag 再補一段 short SHA，避免碰撞

### 目前推薦的使用順序

1. 先決定 backend Graph auth 要走 managed identity 還是 service principal，並把 `MCP_ENTRA_*` / Key Vault reference 整理好。
2. 若要保留 retained path，再決定 APIM 是 public 還是 internal/private，並補齊 `MCP_APIM_RESOURCE_*`、`MCP_CLAUDE_CLIENT_ID` 與 `AZURE_APIM_*`。
3. 若要讓這次部署直接更新既有 `fet-outlook-email-ca`，先設 `AZURE_APIM_BACKEND_CONTAINER_APP_NAME=fet-outlook-email-ca`。
4. 執行 `azd up` 或 `azd deploy`。
5. 部署後先看 `postdeploy` hook 是否成功列出 `send_email`、`generate_pptx_attachment`、`generate_xlsx_attachment`，再做真實寄信 E2E。

### 這輪踩到的雷與注意事項

- service hook 的 `run` 路徑是**相對 service project**，不是相對 repo root。
- `AZURE_APIM_BACKEND_CONTAINER_APP_NAME` 不只是 APIM backend 開關；現在它也決定 azd 是否直接接手既有 ACA 名稱。
- 若 cloud endpoint 看不到新 tool，不要先怪 APIM 需要 refresh；先確認 backend 是不是新版，或 caller 還在用舊 session / 舊 discovery。
- `postdeploy` 現在驗的是 direct ACA `/mcp`，不是 `/.well-known/oauth-protected-resource`。
- 若 direct / retained path 都要排錯，先分清楚是 **APIM inbound OAuth**、**APIM -> ACA backend token**，還是 **backend -> Graph** 出站權限，不要混成同一組 credential 問題。

### APIM 維運 / 重建記憶點

- 手動維運入口主要是 `infra\remove-apim.bicep` / `infra\rebuild-apim.bicep`。
- APIM 刪除是**長時間操作**；不要因為 Azure 一段時間沒回應就中途 Ctrl+C，否則資源可能長時間卡在 `Deleting`。
- 查 managed identity 的角色指派時，不要直接用 `az role assignment list --assignee <managed-identity-resource-id>`；先用 `az identity show --query principalId` 取出 `principalId`，再改用 `--assignee-object-id <principalId>` 查詢。
- `remove-apim.bicep` 的 deploymentScript 需要執行用 managed identity 至少具備 Contributor 以上權限；若 RBAC 不足，常見症狀是 script 卡住或看似成功但沒有真的清乾淨。
- APIM 刪掉後，`apim-subnet` 不會跟著一起刪除；重建前先確認 prefix、NSG 與 route table 仍是預期值，不要重複建立 subnet。
- 更完整的 lessons learned 與症狀對照，以 `README.md` 的 **「本輪踩雷與避坑紀錄（2026-04）」** 為主。

## 變更時的注意事項

1. 如果新增認證來源或設定鍵，請優先同步更新 `README.md` 與 `local.settings.sample.json`。
2. 不要把 sample 專屬的認證邏輯搬到 shared。
3. 如果部署流程有改動，請確認 `azure.yaml` 與 `infra\` 的說明仍然一致。

## 常見錯誤檢查

- `func start` 無法啟動：先檢查 `local.settings.json` 是否存在，且 `UseHttp` 是否為 `true`。
- Graph 認證失敗：先確認 tenant/client/client secret 是否對應同一個 app registration，且 `UseManagedIdentity=false` 時三個值都有提供。
- `azd up` / `azd deploy` 後工具列不完整：先查 `AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN` 指到哪個 ACA，再看 `postdeploy` hook 的 `tools/list` 輸出。
- `azd up` / private 發佈後無法連線：先查 FQDN，再確認現在驗的是 ACA backend 還是 APIM gateway；若是 private 路徑，再檢查 `NO_PROXY`。
- Flex Consumption private 發佈不要套用通用 Kudu zip publish 心智模型；應走 private SCM 的 `/api/publish?RemoteBuild=<bool>&Deployer=az_cli`。
