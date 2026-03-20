---
name: outlook-email-auth-deployment
description: |
  outlook-email 認證與部署指引。用於註冊 Entra ID app、設定 local.settings.json、以 Functions 方式本機執行，或使用 azd 部署到 Azure。
  Triggers: "register app", "Entra ID", "func start", "local.settings.json", "azd up", "Azure 部署".
---

# Outlook Email Auth and Deployment

此 skill 專門處理 `outlook-email` 的認證設定與部署步驟，只看這個 sample。

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

### 1. 註冊 Entra ID app

在 `outlook-email` 目錄執行：

```powershell
.\Register-App.ps1
```

完成後記下 tenant ID、client ID、client secret。

### 2. 本機 Hybrid App 認證

有兩種方式：

- 直接用命令列參數：`-t`、`-c`、`-s`
- 存到 user secrets，讓 `Program.cs` 啟動時從設定讀取

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

部署後可用下列指令查詢資源 FQDN：

```powershell
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN
```

## 變更時應注意

1. 若新增認證來源或設定鍵，優先同步更新 `README.md` 與 `local.settings.sample.json`。
2. 不要把 sample 專屬的認證邏輯移到 shared。
3. 若部署流程有改動，確認 `azure.yaml` 與 `infra\` 說明仍一致。

## 常見錯誤檢查

- `func start` 啟不來：先檢查 `local.settings.json` 是否存在，且 `UseHttp` 為 `true`。
- Graph 認證失敗：先確認 tenant/client/client secret 是否對應同一個 app registration。
- `azd up` 後連不到：先查 FQDN，再確認部署模式與 README 內敘述一致。
