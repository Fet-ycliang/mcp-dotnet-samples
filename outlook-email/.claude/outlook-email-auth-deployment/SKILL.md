---
name: outlook-email-auth-deployment
description: |
  outlook-email 認證與部署指引。用於註冊 Entra ID app、設定 `local.settings.json`、以 Functions 方式本機執行，或使用 `azd` 部署到 Azure。
  觸發詞："register app", "Entra ID", "func start", "local.settings.json", "azd up", "Azure 部署"。
---

# Outlook Email 認證與部署指引

此技能專門處理 `outlook-email` 的認證設定與部署步驟，只看這個 sample。

## 主要檔案與腳本

| 檔案 | 用途 |
| --- | --- |
| `Register-App.ps1` | 以 PowerShell 註冊 Entra ID app |
| `register-app.sh` | 以 bash 註冊 Entra ID app |
| `README.md` | 本層認證、Functions、本機與 Azure 部署步驟 |
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

若 Azure 要走 service principal：

- `MCP_ENTRA_USE_MANAGED_IDENTITY=false`
- `MCP_ENTRA_TENANT_ID`
- `MCP_ENTRA_CLIENT_ID`
- `MCP_ENTRA_CLIENT_SECRET`

若 Azure 要走 managed identity：

- 不要同時保留 `MCP_ENTRA_TENANT_ID` / `MCP_ENTRA_CLIENT_ID` / `MCP_ENTRA_CLIENT_SECRET`
- 若先前曾用過 service principal，切回 managed identity 時要一併清掉這些值

若 Azure 走 service principal，**優先建議把 `MCP_ENTRA_CLIENT_SECRET` 改成 Key Vault reference**；raw env var 只適合短期 bootstrap。

部署後可用下列指令查詢資源 FQDN：

```powershell
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN
```

## 變更時的注意事項

1. 如果新增認證來源或設定鍵，請優先同步更新 `README.md` 與 `local.settings.sample.json`。
2. 不要把 sample 專屬的認證邏輯搬到 shared。
3. 如果部署流程有改動，請確認 `azure.yaml` 與 `infra\` 的說明仍然一致。

## 常見錯誤檢查

- `func start` 無法啟動：先檢查 `local.settings.json` 是否存在，且 `UseHttp` 是否為 `true`。
- Graph 認證失敗：先確認 tenant/client/client secret 是否對應同一個 app registration，且 `UseManagedIdentity=false` 時三個值都有提供。
- `azd up` / private 發佈後無法連線：先查 FQDN，再確認部署模式與 README 內敘述一致；若是 private endpoint 路徑，再檢查 `NO_PROXY`。
- Flex Consumption private 發佈不要套用通用 Kudu zip publish 心智模型；應走 private SCM 的 `/api/publish?RemoteBuild=<bool>&Deployer=az_cli`。
