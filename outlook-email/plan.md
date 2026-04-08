# Outlook Email 上線計劃

## 背景

目前 `outlook-email` 的正式部署目標是 **Azure Functions (Flex Consumption)**，搭配 **Azure API Management (APIM)** 提供 OAuth 閘道。已落地的環境以 `fet-outlook-email-bst` 為 naming stem，private APIM 名稱為 `fet-mcp-apim-bst`。

本文件提供兩條路徑：

1. **Path A：不搬的緩解方案** — 保留 Azure Functions，修正已知部署限制
2. **Path B：搬到 ACA** — 改以 Azure Container Apps 為主機，透過容器映像部署

---

## Path A：不搬的緩解方案（保留 Azure Functions）

### 已知問題清單

| # | 問題 | 症狀 | 影響評估 |
|---|------|------|----------|
| A1 | 既有 VNet 跨 RG | Bicep 找不到 VNet，部署失敗 | **已修復**：新增 `existingVirtualNetworkResourceGroupName` 參數 |
| A2 | Flex private SCM 部署方式 | `azd deploy` 在 private endpoint 環境下的 zip publish 行為和公開環境不同 | 緩解：設 `NO_PROXY`，或改用 `az functionapp deploy --src-url` |
| A3 | 公司 Proxy + private endpoint | `403 Ip Forbidden`，流量被送到公網 | 緩解：把 Function App / SCM host 加進 `NO_PROXY` |
| A4 | Function runtime 版本不符 | `/mcp` 回 `502` | 緩解：確認 Flex runtime = `dotnet-isolated 10.0`，app = `net10.0` |
| A5 | Entra app 建立權限 | `mcpEntraApp` 建立失敗，需要 `Application Administrator` 或 `Cloud Application Administrator` | 緩解：提供既有 app 的 `MCP_OAUTH_TENANT_ID` / `MCP_OAUTH_CLIENT_ID` 跳過自動建立 |
| A6 | azd/ARM TLS 問題 | `x509: negative serial number` 阻擋 `azd provision` | 緩解：換一台乾淨機器，或改用 ARM REST API 直接 patch |
| A7 | APIM internal VNet NSG 前置條件 | APIM provisioning 長時間卡在 `Activating` | 緩解：先放行 `ApiManagement -> VirtualNetwork TCP 3443` 與 `AzureLoadBalancer -> VirtualNetwork TCP 6390` |
| A8 | Databricks 到 private APIM 的可達性 | `Failed to list tools`，但 CLI 直打 APIM 成功 | 緩解：給 Databricks 一個公開 / restricted APIM facade，或在 Databricks 可達網路內加 proxy |

### A1 修復：跨 RG 既有 VNet 支援

**問題根本原因**：`resources.bicep` 中的 `resource existingVirtualNetwork` 沒有指定 `scope`，Bicep 預設以部署 RG 找 VNet；當 VNet 在不同 RG 時部署就會失敗。

**修復內容**（已套用）：
- `infra/resources.bicep`：新增 `existingVirtualNetworkResourceGroupName` 參數，對 `resource existingVirtualNetwork` 加上 `scope: resourceGroup(effectiveVnetResourceGroupName)`，並修正三處 `resourceId()` 呼叫
- `infra/modules/storage-privateendpoint.bicep`：新增 `vnetResourceGroupName` 參數，修正 `resource vnet` scope
- `infra/main.bicep`：新增 `existingVirtualNetworkResourceGroupName` 參數並傳入 resources module
- `infra/main.parameters.json`：新增 `existingVirtualNetworkResourceGroupName` 對應 `${AZURE_EXISTING_VNET_RESOURCE_GROUP_NAME=}`

**使用方式**：
```bash
azd env set AZURE_EXISTING_VNET_RESOURCE_GROUP_NAME "apim-app-bst-rg"
azd env set AZURE_EXISTING_VNET_NAME "apim-bst-vnet"
```

### A2 緩解：Flex private SCM 部署

Flex Consumption + private endpoint 環境下，`azd deploy` 的 zip publish 行為和公開環境不同。目前已知的緩解方式：

1. 確認 `NO_PROXY` 包含 Function App SCM hostname：
   ```powershell
   # PowerShell
   $fqdn = azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
   $scmHost = $fqdn -replace '\.azurewebsites\.net$', '.scm.azurewebsites.net'
   $existing = [Environment]::GetEnvironmentVariable('NO_PROXY', 'User')
   $combined = (($existing -split ',') + $scmHost | Where-Object { $_ } | Select-Object -Unique) -join ','
   [Environment]::SetEnvironmentVariable('NO_PROXY', $combined, 'User')
   ```

2. 若 `azd deploy` 在 private 環境下仍失敗，改用 `az functionapp deploy`：
   ```bash
   cd outlook-email/src/McpSamples.OutlookEmail.HybridApp
   dotnet publish -c Release -o /tmp/publish-out
   (cd /tmp/publish-out && zip -r /tmp/app.zip .)
   az functionapp deployment source config-zip \
     --resource-group <rg> --name <func-name> \
     --src /tmp/app.zip
   ```

### A3 緩解：公司 Proxy + private endpoint

診斷流程：
```powershell
# 先確認 proxy 設定
$env:HTTPS_PROXY; $env:HTTP_PROXY; $env:NO_PROXY

# 使用 curl 繞過 proxy 直連驗證
curl --noproxy '*' -v https://<func-fqdn>/mcp
```

把受影響的 host 加進 `NO_PROXY`：
```powershell
$hosts = @('<func-name>.azurewebsites.net', '<func-name>.scm.azurewebsites.net', 'fet-mcp-apim-bst.azure-api.net', '.azure-api.net')
$existing = [Environment]::GetEnvironmentVariable('NO_PROXY', 'User') -split ','
$combined = ($existing + $hosts | Where-Object { $_ } | Select-Object -Unique) -join ','
[Environment]::SetEnvironmentVariable('NO_PROXY', $combined, 'User')
```

### A4 緩解：Function runtime 版本

確認 Flex runtime 設定：
```bash
az functionapp config show --resource-group <rg> --name <func-name> \
  --query "netFrameworkVersion"
# 應為 null 或 dotnet-isolated 對應版本

# 確認 app settings
az functionapp config appsettings list --resource-group <rg> --name <func-name> \
  --query "[?name=='FUNCTIONS_WORKER_RUNTIME']"
```

若需要修正，在 `functionapp.bicep` 確認：
- `runtimeName: 'dotnet-isolated'`
- `runtimeVersion: '10.0'`

### A5 緩解：Entra app 建立權限

若不具備 `Application Administrator` 或 `Cloud Application Administrator` 角色，先讓 administrator 建立 Entra app，再設定：
```bash
azd env set MCP_OAUTH_TENANT_ID "{{TENANT_ID}}"
azd env set MCP_OAUTH_CLIENT_ID "{{EXISTING_APP_CLIENT_ID}}"
```

Entra app 最低需求：
- **Expose an API** → delegated scope `user_impersonation`
- 若要支援 M2M → application role `access_as_application`

### Path A 建議部署順序（全新環境）

```
1. azd auth login
2. 設定 azd 環境變數（見 README.md）
3. azd env set AZURE_DEPLOY_APIM false     # 先不部署 APIM
4. azd env set AZURE_DEPLOY_FUNCTIONAPP_PRIVATE_ENDPOINT false  # 先不加 private endpoint
5. azd up                                  # 驗證基礎設施與 Function App
6. 驗證 /mcp 端點可達（不透過 APIM）
7. azd env set AZURE_DEPLOY_APIM true
8. azd env set AZURE_APIM_SKU "Developer"  # dev/test
9. azd up                                  # 加上 APIM
10. 驗證 APIM /mcp 端點與 OAuth
```

---

## Path B：搬到 ACA（Azure Container Apps）

### 架構差異

| 面向 | Function App（目前） | ACA（新） |
|------|---------------------|-----------|
| 主機 | Azure Functions Flex Consumption | Azure Container Apps |
| 部署單元 | dotnet-isolated zip package | Docker 容器映像 |
| 背後儲存 | Azure Storage（AzureWebJobsStorage） | 不需要（無 Functions runtime） |
| 延伸縮放 | scale-to-zero 預設 | scale-to-zero 可設 minReplicas=0 |
| 冷啟動 | Flex 有冷啟動 | ACA minReplicas=0 也有冷啟動 |
| APIM 整合 | 目前 `mcp-api.bicep` 以 Function App 為後端 | 需改 APIM backend URL 為 ACA FQDN（尚未自動化） |
| 認證（Graph） | Managed identity 或 SP | Managed identity 或 SP（同樣的 `EntraId__*` 設定） |
| 容器映像 | 不需要 | 需要 ACR + 映像建置 |

### ACA 修復內容（已套用）

- `infra/resources.bicep`：新增 `deployAca` 參數；啟用 ACR、Container Apps Environment、Container App 模組（`if (deployAca)`）；讓 App Service Plan 與 Function App 變為 `if (!deployAca)` 條件式；更新輸出以同時支援兩條路徑
- `infra/main.bicep`：新增 `deployAca` 參數，加上 ACA FQDN 輸出
- `infra/main.parameters.json`：新增 `deployAca` 對應 `${AZURE_DEPLOY_ACA=false}`
- `azure.yaml`：加上 ACA service 區塊（預設 comment out，需手動切換）

### Path B 部署步驟

#### 前置準備

1. 確認已有可用的容器映像或 ACR：
   - 部署流程會自動建立 ACR（`cr<stem>`）並推送映像
   - 第一次部署可能稍慢（需建置容器）

2. 設定環境變數：
   ```bash
   azd env set AZURE_DEPLOY_ACA true
   azd env set AZURE_DEPLOY_APIM false     # ACA 路徑目前不含自動 APIM 整合
   ```

3. **切換 `azure.yaml`**（必要步驟）：
   開啟 `azure.yaml`，將 Functions 服務區塊 comment out，將 ACA 服務區塊 uncomment：
   ```yaml
   services:
     outlook-email:
       project: src/McpSamples.OutlookEmail.HybridApp
       host: containerapp
       language: dotnet
       docker:
         path: ../../../Dockerfile.outlook-email-azure
         context: ../../../
         remoteBuild: true
   ```
   > 注意：`azure.yaml` 目前不支援透過 env var 動態切換 host 類型；需手動調整。

4. 設定 Graph 認證：
   ```bash
   # 選項 1：managed identity（部署後確認 managed identity 有 Mail.Send 權限）
   azd env set MCP_ENTRA_USE_MANAGED_IDENTITY true

   # 選項 2：service principal
   azd env set MCP_ENTRA_USE_MANAGED_IDENTITY false
   azd env set MCP_ENTRA_TENANT_ID "{{TENANT_ID}}"
   azd env set MCP_ENTRA_CLIENT_ID "{{CLIENT_ID}}"
   azd env set MCP_ENTRA_CLIENT_SECRET "{{CLIENT_SECRET}}"
   ```

#### 部署

```bash
cd $REPOSITORY_ROOT/outlook-email
azd auth login
azd up
```

#### 取得 ACA FQDN

```bash
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ACA_FQDN
```

#### 連線 MCP 主機（ACA）

複製 ACA 遠端連線設定：
```bash
mkdir -p $REPOSITORY_ROOT/.vscode
cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote.json \
   $REPOSITORY_ROOT/.vscode/mcp.json
```

啟動後輸入 `Azure Container Apps FQDN`（例如 `ca-fet-outlook-email-bst.bluefield-....eastus2.azurecontainerapps.io`）。

### Path B 注意事項

1. **APIM 整合**：ACA 路徑目前不含自動 APIM / OAuth 整合。若要在 ACA 前加 APIM，需手動更新 `mcp-api.bicep` 中的 `serviceUrl` 改指向 ACA FQDN，並調整 backend 驗證（ACA ingress 不使用 `x-functions-key`）。

2. **managed identity `Mail.Send` 授權**：和 Functions 路徑一樣，切換 ACA 不會自動免除 `Mail.Send` 申請；仍需要 administrator 對 managed identity 的 service principal 完成 admin consent。

3. **Exchange Online Application RBAC**：若已啟用 Application Access Policy 或 Application RBAC，managed identity 的 service principal 需納入允許 mailbox scope。

4. **scale-to-zero 冷啟動**：ACA `minReplicas=1` 會讓 container 常駐但有固定成本（大約 USD 21–42/月依規格），`minReplicas=0` 則 scale-to-zero 但有冷啟動，類似 Flex Consumption 的 always-ready=0 行為。

5. **first-deploy 映像**：第一次 deploy 若 ACR 內尚無映像，Container App 會用 fallback 映像（`mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`），需先完成 `azd deploy` 推送真實映像。

### 成本比較（ACA vs Functions，eastus2）

| 方案 | 粗估月固定成本 | 備註 |
|------|-------------:|------|
| ACA，minReplicas=0 | **接近 0** | 冷啟動，與 Flex always-ready=0 類似 |
| ACA，minReplicas=1，0.5 CPU / 1 GiB | **約 USD 14–20/月** | 規格依 Azure Retail Prices；類似 Flex always-ready=1 |
| Flex Consumption，always-ready=0 | **接近 0** | 目前預設，適合低頻工具流量 |
| Flex Consumption，always-ready=1，2048 MB | **約 USD 21/月** | 小幅降低冷啟動 |

---

## 選路建議

| 情境 | 建議 |
|------|------|
| 已有既有 VNet，只是 VNet 在不同 RG | **Path A** + 設 `AZURE_EXISTING_VNET_RESOURCE_GROUP_NAME` |
| 想盡快驗通，不動現有網路 | **Path A**，先設 `AZURE_DEPLOY_APIM=false` / `AZURE_DEPLOY_FUNCTIONAPP_PRIVATE_ENDPOINT=false` 降低複雜度 |
| 公司 proxy + private APIM 已驗通，只需修一個部署 gap | **Path A** + 補 `NO_PROXY` |
| 希望簡化後端運維，不想管 Functions runtime / zip deploy | **Path B**（ACA） |
| 需要在同一台環境跑多個 container | **Path B**（ACA + shared Container Apps Environment） |
| 需要和其他 ACA workload 共用 VNet / private DNS | **Path B** + 設 `AZURE_EXISTING_VNET_NAME` |
