# MCP 伺服器：Outlook Email

這是一個透過 Outlook 傳送電子郵件的 MCP 伺服器，並涵蓋 **認證** 情境。

## 安裝

[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%7B%22name%22%3A%22outlook-email%22%2C%22gallery%22%3Afalse%2C%22command%22%3A%22docker%22%2C%22args%22%3A%5B%22run%22%2C%22-i%22%2C%22--rm%22%2C%22ghcr.io%2Fmicrosoft%2Fmcp-dotnet-samples%2Foutlook-email%3Alatest%22%5D%7D) [![Install in VS Code Insiders](https://img.shields.io/badge/VS_Code_Insiders-Install-24bfa5?style=flat-square&logo=visualstudiocode&logoColor=white)](https://insiders.vscode.dev/redirect?url=vscode-insiders%3Amcp%2Finstall%3F%7B%22name%22%3A%22outlook-email%22%2C%22gallery%22%3Afalse%2C%22command%22%3A%22docker%22%2C%22args%22%3A%5B%22run%22%2C%22-i%22%2C%22--rm%22%2C%22ghcr.io%2Fmicrosoft%2Fmcp-dotnet-samples%2Foutlook-email%3Alatest%22%5D%7D) [![Install in Visual Studio](https://img.shields.io/badge/Visual_Studio-Install-C16FDE?logo=visualstudio&logoColor=white)](https://aka.ms/vs/mcp-install?%7B%22name%22%3A%22outlook-email%22%2C%22gallery%22%3Afalse%2C%22command%22%3A%22docker%22%2C%22args%22%3A%5B%22run%22%2C%22-i%22%2C%22--rm%22%2C%22ghcr.io%2Fmicrosoft%2Fmcp-dotnet-samples%2Foutlook-email%3Alatest%22%5D%7D)

## 先決條件

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Visual Studio Code](https://code.visualstudio.com/)，並安裝
  - [C# Dev Kit](https://marketplace.visualstudio.com/items/?itemName=ms-dotnettools.csdevkit) 擴充功能
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Docker Desktop](https://docs.docker.com/get-started/get-docker/)

## 內容包含

- Outlook Email MCP 伺服器可在下列情境中執行：
  - 作為遠端 MCP 伺服器，透過 Azure API Management 使用 **OAuth authentication**
  - 作為遠端 MCP 伺服器，透過 Azure Functions 使用 **API key authentication**
  - 作為本機執行的 MCP 伺服器，不額外啟用 MCP transport 認證
- Outlook Email MCP 伺服器包含以下內容：

  | 組成元件 | 名稱 | 說明 | 用法 |
  |----------|------|------|------|
  | Tools | `send_email` | 將電子郵件寄送給收件者，並可選擇加入 reply-to 位址與附件。 | `#send_email` |

`send_email` 也接受選用的 `attachments`。每個附件項目應包含：

- `name`：電子郵件中顯示的檔名
- `contentType`：MIME 類型，例如 `application/pdf`
- `contentBytesBase64`：以 Base64 編碼的檔案內容

目前支援一般檔案附件，因此 **CSV** 與 **XLSX** 都可直接使用，只要提供正確的 MIME 類型：

- `text/csv`
- `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`

預設限制如下：

- 最多 **10** 個附件
- 每個附件最大 **3 MiB**

若需要更大的附件，必須另外實作大型附件上傳流程；目前 `send_email` 不包含 upload session。

範例：

```json
{
  "attachments": [
    {
      "name": "hello.txt",
      "contentType": "text/plain",
      "contentBytesBase64": "SGVsbG8sIHdvcmxkIQ=="
    }
  ]
}
```

完整 payload 範例：

```json
{
  "title": "本週報表",
  "body": "請參考附件。",
  "sender": "shared-mailbox@contoso.com",
  "recipients": "alice@contoso.com; bob@contoso.com",
  "replyTo": "owner@contoso.com",
  "attachments": [
    {
      "name": "report.csv",
      "contentType": "text/csv",
      "contentBytesBase64": "YSxiLGMKMSwyLDMK"
    },
    {
      "name": "report.xlsx",
      "contentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "contentBytesBase64": "UEsDBBQAAAAIAAA..."
    }
  ]
}
```

> 若有設定 `AllowedSenders`，`sender` 必須位於允許清單中。若有設定 `AllowedReplyTo`，`replyTo` 也必須位於允許清單中。

<a id="getting-started"></a>
## 開始使用

### 快速起始：我該選哪種執行方式？

| 目標 | 建議路徑 | 你會用到的內容 |
| --- | --- | --- |
| 先確認 MCP tool 能否在本機跑起來 | 本機 STDIO | `dotnet run --project ./src/McpSamples.OutlookEmail.HybridApp`、`.vscode\mcp.stdio.local.json` |
| 想測 HTTP 型態的 MCP 端點 | 本機 HTTP | `dotnet run --project ./src/McpSamples.OutlookEmail.HybridApp -- --http`、`.vscode\mcp.http.local.json` |
| 想模擬 Azure Functions custom handler | 本機 Function app | `local.settings.json`、`func start`、`.vscode\mcp.http.local-func.json` |
| 想驗證容器封裝 | 容器 | `docker build`、`docker run` |
| 想做正式部署或遠端連線 | Azure | `azd up`、遠端 `.vscode\mcp.http.remote-*.json` |

如果你是第一次接手這個 sample，建議順序是：**本機 STDIO / HTTP → 本機 Function app → Azure**。先完成低成本本機驗證，再往雲端推進，通常比較省時也比較省錢。

- [取得儲存庫根目錄](#getting-repository-root)
- [在 Entra ID 註冊應用程式](#registering-an-app-on-entra-id)
- [執行 MCP 伺服器](#running-mcp-server)
  - [在本機](#on-a-local-machine)
  - [在本機以 Function app 執行](#on-a-local-machine-as-a-function-app)
  - [在容器中](#in-a-container)
  - [在 Azure 上](#on-azure)
- [將 MCP 伺服器連線到 MCP 主機／客戶端](#connect-mcp-server-to-an-mcp-hostclient)
  - [VS Code + Agent Mode + 本機 MCP 伺服器](#vs-code--agent-mode--local-mcp-server)

<a id="getting-repository-root"></a>
### 取得儲存庫根目錄

1. 取得儲存庫根目錄。

    ```bash
    # bash/zsh
    REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
    ```

    ```powershell
    # PowerShell
    $REPOSITORY_ROOT = git rev-parse --show-toplevel
    ```

<a id="registering-an-app-on-entra-id"></a>
### 在 Entra ID 註冊應用程式

> 本節適用於在本機或本機容器中執行 MCP 伺服器。若要將此 MCP 伺服器部署到 Azure，可略過本節。

> 這個腳本會替本機測試用 app 註冊 **Microsoft Graph `Mail.Send` application permission**。要成功寄信，除了 tenant / client / secret 之外，目標 `sender` 信箱也必須存在於 **Exchange Online**，且租戶管理員必須完成 admin consent。

1. 執行下列腳本。

    ```bash
    # bash/zsh
    cd $REPOSITORY_ROOT/outlook-email
    ./register-app.sh
    ```

    ```powershell
    # PowerShell
    cd $REPOSITORY_ROOT/outlook-email
    ./Register-App.ps1
    ```

1. 記下 tenant ID、client ID 與 client secret 值。

#### 註冊失敗時先檢查這些項目

| 情境 | 常見症狀 | 先檢查什麼 |
| --- | --- | --- |
| Azure CLI 尚未登入正確租戶 | 腳本一開始就失敗，或建立到錯的 tenant | 先執行 `az login`，必要時加上 `--tenant <TENANT_ID>`，再用 `az account show` 確認目前租戶 |
| 帳號沒有建立應用程式的權限 | 顯示權限不足、無法建立 app registration | 確認租戶允許一般使用者註冊 app，或改用具備 `Application Administrator` / `Cloud Application Administrator` / `Application Developer` 權限的帳號 |
| Graph 權限已加入但寄信仍失敗 | 後續呼叫 `send_email` 時出現授權錯誤 | 確認 app 具有 **Microsoft Graph `Mail.Send` application permission**，且租戶管理員已完成 admin consent |
| `sender` 信箱不存在或不可用 | 認證成功但寄信時找不到信箱或寄件失敗 | 確認目標寄件者存在於 **Exchange Online**，且目前租戶 / app 的設計允許代表該信箱寄信 |
| client secret 抄錯或已過期 | 啟動後取得 token 失敗 | 重新確認 `client secret` 值是否完整、未過期，並與目前 app registration 的有效密鑰一致 |

<a id="running-mcp-server"></a>
### 執行 MCP 伺服器

<a id="on-a-local-machine"></a>
#### 在本機

1. 執行 MCP 伺服器應用程式。

    ```bash
    cd $REPOSITORY_ROOT/outlook-email
    dotnet run --project ./src/McpSamples.OutlookEmail.HybridApp
    ```

   > 請務必記下 `McpSamples.OutlookEmail.HybridApp` 專案的絕對目錄路徑。

    > 本機不額外保護 MCP transport，**不代表寄信到 Microsoft Graph 不需要認證**。若要真的寄信，仍需透過命令列參數、user secrets 或 Azure managed identity 提供 Graph 認證。

    **參數：**

   - `--http`：表示以 streamable HTTP 類型執行此 MCP 伺服器。加入此開關後，MCP 伺服器 URL 會是 `http://localhost:5260`。
   - `--tenant-id`/`-t`: 用於登入的 tenant ID。
   - `--client-id`/`-c`: 用於登入的 client ID。
   - `--client-secret`/`-s`: 用於登入的 client secret。

   加入這些參數後，可用下列方式執行 MCP 伺服器：

    ```bash
    dotnet run --project ./src/McpSamples.OutlookEmail.HybridApp -- --http -t "{{TENANT_ID}}" -c "{{CLIENT_ID}}" -s "{{CLIENT_SECRET}}"
    ```

   除了透過命令列提供 tenant ID、client ID 與 client secret 外，也可以將它們儲存為 user secrets；**本機開發建議優先使用 user secrets，不要把 secret 長期放在命令列參數中**。

    ```bash
    dotnet user-secrets --project ./src/McpSamples.OutlookEmail.HybridApp set EntraId:UseManagedIdentity false
    dotnet user-secrets --project ./src/McpSamples.OutlookEmail.HybridApp set EntraId:TenantId "{{TENANT_ID}}"
    dotnet user-secrets --project ./src/McpSamples.OutlookEmail.HybridApp set EntraId:ClientId "{{CLIENT_ID}}"
    dotnet user-secrets --project ./src/McpSamples.OutlookEmail.HybridApp set EntraId:ClientSecret "{{CLIENT_SECRET}}"
    ```

    > 只要你透過命令列參數、user secrets 或 app settings 明確提供 `EntraId` 的 tenant / client / secret，程式就會優先視為 service principal 模式；若要強制改回 managed identity，請明確設定 `EntraId:UseManagedIdentity=true`。

<a id="on-a-local-machine-as-a-function-app"></a>
#### 在本機以 Function app 執行

1. 將 `local.settings.sample.json` 重新命名為 `local.settings.json`。

    ```bash
    # bash/zsh
    cp $REPOSITORY_ROOT/outlook-email/src/McpSamples.OutlookEmail.HybridApp/local.settings.sample.json \
       $REPOSITORY_ROOT/outlook-email/src/McpSamples.OutlookEmail.HybridApp/local.settings.json
    ```

    ```powershell
    # PowerShell
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/src/McpSamples.OutlookEmail.HybridApp/local.settings.sample.json `
              -Destination $REPOSITORY_ROOT/outlook-email/src/McpSamples.OutlookEmail.HybridApp/local.settings.json -Force
    ```

1. 開啟 `local.settings.json`，將 `{{TENANT_ID}}`、`{{CLIENT_ID}}` 和 `{{CLIENT_SECRET}}` 分別替換為 tenant ID、client ID 與 client secret 值。

    ```jsonc
    {
      "IsEncrypted": false,
      "Values": {
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "AzureWebJobsFeatureFlags": "DisableDiagnosticEventLogging",
    
        "UseHttp": "true",
      
        "EntraId__TenantId": "{{TENANT_ID}}",
        "EntraId__ClientId": "{{CLIENT_ID}}",
        "EntraId__ClientSecret": "{{CLIENT_SECRET}}",
        "EntraId__UseManagedIdentity": "false",
        "AllowedSenders__0": "shared-mailbox@contoso.com",
        "AllowedReplyTo__0": "owner@contoso.com",
        "MaxAttachmentCount": "10",
        "MaxAttachmentSizeBytes": "3145728"
      }
    }
    ```

    > `AllowedSenders__0` 代表第一個允許的寄件者；若要加更多寄件者，可依序加入 `AllowedSenders__1`、`AllowedSenders__2`。
    >
    > `AllowedReplyTo__0` 代表第一個允許的回覆地址；若要加更多回覆地址，可依序加入 `AllowedReplyTo__1`、`AllowedReplyTo__2`。
    >
    > `MaxAttachmentCount` 與 `MaxAttachmentSizeBytes` 會控制附件數量與單檔大小。
    >
    > 現在 Graph 認證模式的優先序如下：
    >
    > 1. `EntraId__UseManagedIdentity`：若有明確設定，直接以它為準
    > 2. 若未設定，但 `EntraId__TenantId` / `EntraId__ClientId` / `EntraId__ClientSecret` 有提供，則改用 service principal
    > 3. 若以上都沒有，且存在 `AZURE_CLIENT_ID`，才回退到 managed identity
    >
    > 當程式判斷要使用 service principal 時，`EntraId__TenantId`、`EntraId__ClientId`、`EntraId__ClientSecret` 三者必須完整；否則啟動後第一次建立 Graph client 就會明確失敗。
    >
    > `local.settings.json` 已被 `.gitignore` 忽略，實際授權用的 sender / replyTo 應寫在這個本機檔，不要把真實值回填到 `local.settings.sample.json`。
    >
    > 若只是一般本機開發，仍優先建議把 Graph secret 放在 `dotnet user-secrets`；`local.settings.json` 比較適合 Functions / custom handler 本機整體演練。

1. 執行 MCP 伺服器應用程式。

    ```bash
    cd $REPOSITORY_ROOT/outlook-email/src/McpSamples.OutlookEmail.HybridApp
    func start
    ```

<a id="in-a-container"></a>
#### 在容器中

1. 將 MCP 伺服器 應用程式建置為 容器映像。

    ```bash
    cd $REPOSITORY_ROOT
    docker build -f Dockerfile.outlook-email -t outlook-email:latest .
    ```

1. 在 container 中執行 MCP 伺服器 應用程式。

    ```bash
    docker run -i --rm -p 8080:8080 outlook-email:latest
    ```

   或者，也可以使用容器登錄中的容器映像。

    ```bash
    docker run -i --rm -p 8080:8080 ghcr.io/microsoft/mcp-dotnet-samples/outlook-email:latest
    ```

   **參數：**

   - `--http`：表示以 streamable HTTP 類型執行此 MCP 伺服器。加入此開關後，MCP 伺服器 URL 會是 `http://localhost:8080`。
   - `--tenant-id`/`-t`: 用於登入的 tenant ID。
   - `--client-id`/`-c`: 用於登入的 client ID。
   - `--client-secret`/`-s`: 用於登入的 client secret。

   加入這些參數後，可用下列方式執行 MCP 伺服器：

    ```bash
    # 使用本機容器映像
    docker run -i --rm -p 8080:8080 outlook-email:latest --http -t "{{TENANT_ID}}" -c "{{CLIENT_ID}}" -s "{{CLIENT_SECRET}}"
    ```

    ```bash
    # 使用容器登錄中的容器映像
    docker run -i --rm -p 8080:8080 ghcr.io/microsoft/mcp-dotnet-samples/outlook-email:latest --http -t "{{TENANT_ID}}" -c "{{CLIENT_ID}}" -s "{{CLIENT_SECRET}}"
    ```

<a id="on-azure"></a>
#### 在 Azure 上

1. **重要：** 先確認你具備必要權限：
   - 你的 Azure 帳戶必須在 訂用帳戶層級具備 `Microsoft.Authorization/roleAssignments/write` 權限，例如 [Role Based Access Control Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator)、[User Access Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/privileged#user-access-administrator) 或 [Owner](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/privileged#owner)。
   - 你的 Azure 帳戶也必須在 訂用帳戶層級具備 `Microsoft.Resources/deployments/write` 權限。

1. 切換到目錄。

    ```bash
    cd $REPOSITORY_ROOT/outlook-email
    ```

1. 登入 Azure。

    ```bash
    # 使用 Azure Developer CLI 登入
    azd auth login
    ```

<!-- 1. 預設會將 MCP 伺服器 部署為 Azure Functions。若要將此 MCP 伺服器 部署到 Azure Container Apps，請新增環境變數 `USE_ACA`。

    ```bash
    azd env set USE_ACA true
    ``` -->

1. 將 MCP 伺服器應用程式部署到 Azure。

    ```bash
    azd up
    ```

   在佈建與部署過程中，系統會要求提供 subscription ID、location 與 環境名稱。

1. 正式環境建議先設定下列 azd 環境變數，再部署：

    ```bash
    azd env set MCP_ALLOWED_SENDERS_CSV "shared-mailbox@contoso.com;ops-mailbox@contoso.com"
    azd env set MCP_ALLOWED_REPLY_TO_CSV "owner@contoso.com"
    azd env set AZURE_ALLOW_USER_IDENTITY_RBAC false
    ```

     > `MCP_ALLOWED_SENDERS_CSV` 會在 Azure Functions 上展開為 `AllowedSenders__0`、`AllowedSenders__1` 等 app settings，讓正式環境維持與 local 相同的 sender allowlist。
     >
     > `MCP_ALLOWED_REPLY_TO_CSV` 會在 Azure Functions 上展開為 `AllowedReplyTo__0`、`AllowedReplyTo__1` 等 app settings。
     >
     > `AZURE_ALLOW_USER_IDENTITY_RBAC` 預設應保持 `false`。只有在你真的需要讓部署用互動身分暫時取得 Storage / Application Insights 的除錯權限時，才短暫改成 `true`。

1. 若你要讓 Azure 資源名稱直接與專案用途掛勾，並補齊成本 / 維運 tags，可再設定下列 azd 環境變數：

    ```bash
    azd env set AZURE_RESOURCE_NAME_STEM "fet-outlook-email-bst"
    azd env set AZURE_TAG_COST_CENTER "3901"
    azd env set AZURE_TAG_PURPOSE "ai_lab"
    azd env set AZURE_TAG_ENV_TYPE "Develop"
    azd env set AZURE_TAG_WORKLOAD "outlook-email"
    azd env set AZURE_TAG_SERVICE "mcp"
    azd env set AZURE_TAG_MANAGED_BY "azd"
    ```

     > 若未設定 `AZURE_RESOURCE_NAME_STEM`，Bicep 會預設沿用 `environmentName`。以目前核定的命名方式，建議使用 `fet-outlook-email-bst`，讓資源名稱能直接看出 workload。
     >
     > 這組 naming / tag baseline 套用後，預期名稱會像：
     > - Function App：`func-fet-outlook-email-bst`
     > - Flex plan：`plan-fet-outlook-email-bst`
     > - Application Insights：`appi-fet-outlook-email-bst`
     > - Log Analytics：`log-fet-outlook-email-bst`
     > - User-assigned managed identity：`id-fet-outlook-email-bst`
     > - Dashboard：`dash-fet-outlook-email-bst`
     > - Storage account：`stfetoutlookemailbst`
     >
     > `AZURE_TAG_*` 未設定時，sample 會預設使用：`cost_center=3901`、`Purpose=ai_lab`、`EnvType=Develop`、`workload=outlook-email`、`service=mcp`、`managed_by=azd`。

1. 若正式環境要先用 **service principal + environment variables**，而不是 managed identity，可再設定下列 azd 環境變數：

    ```bash
    azd env set MCP_ENTRA_USE_MANAGED_IDENTITY false
    azd env set MCP_ENTRA_TENANT_ID "{{TENANT_ID}}"
    azd env set MCP_ENTRA_CLIENT_ID "{{CLIENT_ID}}"
    azd env set MCP_ENTRA_CLIENT_SECRET "{{CLIENT_SECRET_OR_KEYVAULT_REFERENCE}}"
    ```

     > 這組值會進入 Azure Functions 的 app settings：`EntraId__UseManagedIdentity`、`EntraId__TenantId`、`EntraId__ClientId`、`EntraId__ClientSecret`。
     >
     > 當 `MCP_ENTRA_USE_MANAGED_IDENTITY=false` 時，`MCP_ENTRA_TENANT_ID`、`MCP_ENTRA_CLIENT_ID`、`MCP_ENTRA_CLIENT_SECRET` 必須一起提供；缺任何一個都會讓寄信時的 Graph 認證明確失敗。
     >
     > **安全建議順序**：Azure managed identity > Azure service principal + Key Vault reference > local `dotnet user-secrets` > 明文 CLI / env var。若你先把 secret 直接放在 environment variable，後續請盡快把 `MCP_ENTRA_CLIENT_SECRET` 改成 App Service Key Vault reference 字串，例如 `@Microsoft.KeyVault(SecretUri=https://<vault-name>.vault.azure.net/secrets/<secret-name>/<secret-version>)`。
     >
     > 若你要走 managed identity，請不要同時保留 `MCP_ENTRA_TENANT_ID`、`MCP_ENTRA_CLIENT_ID`、`MCP_ENTRA_CLIENT_SECRET`，避免把不需要的 credential 長期留在 Function App app settings 中。

1. 若你要沿用既有 resource group / VNet，而不是讓 sample 自建新的 RG / VNet，可再設定下列 azd 環境變數：

    ```bash
    azd env set AZURE_RESOURCE_GROUP_NAME "apim-app-bst-rg"
    azd env set AZURE_EXISTING_VNET_NAME "apim-bst-vnet"
    azd env set AZURE_PRIVATE_ENDPOINT_SUBNET_NAME "PE_Subnet"
    azd env set AZURE_INTEGRATION_SUBNET_NAME "app-flex-out-subnet"
    azd env set AZURE_INTEGRATION_SUBNET_ADDRESS_PREFIX "172.18.79.192/27"
    azd env set AZURE_INTEGRATION_SUBNET_ROUTE_TABLE_RESOURCE_ID "/subscriptions/<subscription-id>/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/routeTables/DG-Route-CP"
    azd env set AZURE_INTEGRATION_SUBNET_NSG_RESOURCE_ID "/subscriptions/1d077479-3fc2-4f1f-82b4-0a5789393fd2/resourceGroups/apim-app-bst-rg/providers/Microsoft.Network/networkSecurityGroups/172.18.79.0_24_ASI"
    azd env set AZURE_PRIVATE_DNS_ZONE_RESOURCE_GROUP_NAME "aibde-common-rg"
    azd env set AZURE_DEPLOY_APIM false
    azd env set AZURE_DEPLOY_FUNCTIONAPP_PRIVATE_ENDPOINT true
    ```

    > `AZURE_RESOURCE_GROUP_NAME` 有值時，Bicep 會直接部署到既有 RG，不再建立 `rg-<environmentName>`。
    >
    > `AZURE_EXISTING_VNET_NAME` 有值時，Bicep 會直接沿用既有 VNet；若只提供 `AZURE_INTEGRATION_SUBNET_NAME`，則會把該 subnet 視為已存在並直接參考；若 `AZURE_INTEGRATION_SUBNET_ADDRESS_PREFIX` 也有值，則會在既有 VNet 內建立或更新對應的 integration subnet。
    >
    > `AZURE_INTEGRATION_SUBNET_ROUTE_TABLE_RESOURCE_ID` 可讓新建的 Flex integration subnet 直接沿用既有 UDR；若你的出口已統一走 Azure Firewall / NVA，建議把現有 route table 一起掛上去。
    >
    > `AZURE_INTEGRATION_SUBNET_NSG_RESOURCE_ID` 可讓新建的 Flex integration subnet 直接套用既有 NSG。以目前這個專案的既有網路配置，建議直接使用 **`172.18.79.0_24_ASI`**。
    >
    > `AZURE_PRIVATE_DNS_ZONE_RESOURCE_GROUP_NAME` 有值時，Bicep 會直接重用該 RG 內既有的 `privatelink.azurewebsites.net`、`privatelink.blob.core.windows.net` 等 zone，不再另外建立新的 private DNS zone。
    >
    > `AZURE_DEPLOY_APIM=false` 適合目前這種 **Function App-only** 階段；若仍要保留 APIM facade，再改回 `true`。
    >
    > `AZURE_DEPLOY_FUNCTIONAPP_PRIVATE_ENDPOINT=true` 時，Bicep 會替 Function App 建立 inbound private endpoint，並將 Function App 的 `publicNetworkAccess` 關閉；若同時指定 `AZURE_PRIVATE_DNS_ZONE_RESOURCE_GROUP_NAME`，則會直接把 private endpoint 掛到該 RG 內既有的 `privatelink.azurewebsites.net` zone。

1. Flex Consumption 重用既有 VNet 時，請特別注意 integration subnet 限制：

   - **subnet 名稱不能包含底線 `_`**
   - 必須使用 **`Microsoft.App/environments` delegation**
   - 不能與 private endpoint / service endpoint 混用

   這代表若你現有的 App Service integration subnet 是像 `App_Out_Subnet`、`App2_Out_Subnet` 這種帶底線、且 delegation 為 `Microsoft.Web/serverfarms` 的子網，**不能直接拿來給 Flex Consumption 使用**。此時應另開一條新的、名稱不含底線的 subnet（例如 `app-flex-out-subnet`）。

1. 若你採用共用 private DNS zone 模式，請先確認目標 VNet 已經在共用 zone 上建立好 link；例如這次的 `apim-bst-vnet` 就應先連到：

   - `privatelink.azurewebsites.net`
   - `privatelink.blob.core.windows.net`

   若未先建立 link，private endpoint 建好後仍可能無法在該 VNet 內正確解析名稱。

1. 本次建議的 integration subnet 治理參數如下：

    ```bash
    azd env set AZURE_INTEGRATION_SUBNET_ROUTE_TABLE_RESOURCE_ID "/subscriptions/<subscription-id>/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/routeTables/DG-Route-CP"
    azd env set AZURE_INTEGRATION_SUBNET_NSG_RESOURCE_ID "/subscriptions/1d077479-3fc2-4f1f-82b4-0a5789393fd2/resourceGroups/apim-app-bst-rg/providers/Microsoft.Network/networkSecurityGroups/172.18.79.0_24_ASI"
    ```

1. 架構選型與成本參考（`eastus2`，2026-04-03 估算）：

   - 估算基準：**730 小時 / 月**、Azure Retail Prices API 公開零售價。
   - **未包含**：Storage、Private Endpoint、Private DNS、Log Analytics、頻寬、NAT Gateway、APIM 等其他資源成本。
   - Flex 的 **always-ready baseline** 只代表固定底座成本；實際執行量仍會另外計價。

   | 方案 | 粗估月成本 | 適用判斷 |
   | --- | ---: | --- |
   | Flex Consumption，always-ready = 0 | **接近 0 固定成本** | 最省，適合目前 `send_email` 這種低到中頻率工具流量 |
   | Flex Consumption，always-ready = 1，2048 MB | **約 USD 21.02 / 月起** | 僅 baseline；適合想先小幅降低 cold start |
   | Flex Consumption，always-ready = 2，2048 MB | **約 USD 42.05 / 月起** | 若後續要更高可用性或更穩定低延遲可參考這級距 |
   | Azure Functions Premium，EP1 | **約 USD 145.93 / 月起** | 至少 1 個 instance 常駐，成本明顯高於 Flex |
   | App Service P0v3 Linux，Pay-as-you-go | **約 USD 56.58 / 月** | Dedicated / App Service 路線，不是 Functions Premium |
   | App Service P0v3 Linux，1 年 RI 等效 | **約 USD 36.92 / 月** | 僅適用 App Service Premium v3 的 Reservation 模型 |
   | App Service P0v3 Linux，3 年 RI 等效 | **約 USD 25.56 / 月** | 僅適用 App Service Premium v3 的 Reservation 模型 |

   - 目前這個 sample 若優先目標是 **低固定成本 + 可私網化 + 可 scale-to-zero**，仍以 **Flex Consumption + always-ready 關閉** 為起始方案最合理。
   - 如果未來觀察到 cold start 影響可接受度，建議先從 **always-ready = 1** 開始，而不是直接跳 Premium。
   - Azure Functions Premium 的官方 pricing 頁面目前提供 **1 年 / 3 年 Savings Plan** 比較欄位；我們查到的 Retail Prices API 中，**Premium Functions 沒有傳統 Reservation 條目**。
   - App Service Premium v3 / v4 則屬另一種產品模型，**可用 RI**，但它代表你已經改成 Dedicated / App Service 路線，不應直接拿來當作 Functions Premium 的同義替代。
   - 若後續啟用 **zone redundancy** 且同時想用 always-ready，Flex 官方限制是 **always-ready 至少要 2**，屆時固定底座成本也要一併上修。

1. 正式環境縮權建議：

   - Azure 資源面：部署完成後，**預設只保留 Function App 的 user-assigned managed identity** 擁有 Storage / Application Insights 所需的最小權限；不要把部署用互動帳號長期保留在資料面角色中。
   - 應用程式面：`AllowedSenders` 應只列出正式允許的 shared mailbox / user mailbox，不要留空。
   - Exchange Online 面：對實際用來寄信的 service principal / managed identity，優先採用 **Exchange Online Application RBAC** 將 `Application Mail.Send` 之類的應用程式角色限制在允許的 mailbox scope。
   - 若租戶目前尚未使用 Application RBAC，可暫時評估 **Application Access Policies**，但它已屬 **legacy** 做法，新規劃應優先採用 Application RBAC。
   - `AllowedSenders` 與 Exchange Online 的 mailbox scope 應維持同一份允許清單，避免程式層與租戶權限層出現落差。

1. Exchange Online mailbox scope 建議流程：

   1. 先找出 Azure Functions 所使用的 user-assigned managed identity 對應的 **AppId / Service Principal ObjectId**。
   2. 在 Exchange Online 建立對應的 `ServicePrincipal` 指標。
   3. 用 **Management Scope** 或 **Administrative Unit** 定義允許寄信的 mailbox 範圍。
   4. 建立 `Application Mail.Send` 的 management role assignment，將權限綁到前述 scope。
   5. 使用 `Test-ServicePrincipalAuthorization` 驗證目標信箱是否真的在 scope 內。

   參考文件：
   - Exchange Online Application RBAC：<https://learn.microsoft.com/exchange/permissions-exo/application-rbac>
   - Application Access Policies（legacy）：<https://learn.microsoft.com/exchange/permissions-exo/application-access-policies>

1. 部署完成後，可執行下列指令取得相關資訊：

   - Azure Functions Apps FQDN：

      ```bash
      azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
      ```

   <!-- - Azure Container Apps FQDN：

      ```bash
      azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ACA_FQDN
      ``` -->

   - Azure API Management FQDN：

      ```bash
      azd env get-value AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN
      ```

      > 如果這次部署採 `AZURE_DEPLOY_APIM=false`，這個值會是空字串；請改用 Function App FQDN 與 `.vscode\mcp.http.remote-func.json`。

<a id="connect-mcp-server-to-an-mcp-hostclient"></a>
### 將 MCP 伺服器連線到 MCP 主機／客戶端

<a id="vs-code--agent-mode--local-mcp-server"></a>
#### VS Code + Agent Mode + 本機 MCP 伺服器

1. 將 `mcp.json` 複製到儲存庫根目錄。

   **用於本機執行的 MCP 伺服器（STDIO）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.stdio.local.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.stdio.local.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

   **用於本機執行的 MCP 伺服器（HTTP）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.local.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.local.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

   **用於本機執行的 MCP 伺服器（Function app / HTTP）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.local-func.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.local-func.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

   **用於本機容器中執行的 MCP 伺服器（STDIO）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.stdio.container.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.stdio.container.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

   **用於本機容器中執行的 MCP 伺服器（HTTP）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.container.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.container.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

   **用於遠端執行的 MCP 伺服器（Function app / HTTP）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote-func.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote-func.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

   <!-- **用於遠端執行的 MCP 伺服器（container app / HTTP）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ``` -->

   **用於透過 API Management 存取的遠端 MCP 伺服器（HTTP）：**

    ```bash
    mkdir -p $REPOSITORY_ROOT/.vscode
    cp $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote-apim.json \
       $REPOSITORY_ROOT/.vscode/mcp.json
    ```

    ```powershell
    New-Item -Type Directory -Path $REPOSITORY_ROOT/.vscode -Force
    Copy-Item -Path $REPOSITORY_ROOT/outlook-email/.vscode/mcp.http.remote-apim.json `
              -Destination $REPOSITORY_ROOT/.vscode/mcp.json -Force
    ```

1. 在 Windows 按 `F1` 或 `Ctrl`+`Shift`+`P`、在 macOS 按 `Cmd`+`Shift`+`P` 開啟 Command Palette，然後搜尋 `MCP: List Servers`。
1. 選取 `outlook-email`，然後按一下 `Start Server`。
1. 系統提示時，請輸入下列值：
   - `McpSamples.OutlookEmail.HybridApp` 專案的絕對目錄路徑。
   - Azure Container Apps 的 FQDN。
   - Azure Functions Apps 的 FQDN。
   - Tenant ID。
   - Client ID。
   - Client secret。
1. 輸入如下提示：

    ```text
    請從 xyz@contoso.com 寄一封主旨為「lorem ipsum」、內容為「hello world」的電子郵件給 abc@contoso.com。
    ```

1. 確認結果。

#### Claude Code / Copilot CLI + 遠端 MCP 伺服器

- **Claude Code**：可直接使用 `outlook-email\.claude\mcp.json`
- **Copilot CLI**：設定檔位置在 `~/.copilot/mcp-config.json`，也可用 `/mcp add` 建立

若遠端 MCP 使用 `${OUTLOOK_EMAIL_FUNCTION_KEY}` 這種 header 參照，**請把它設成實際的 OS 環境變數**，不要只放在工具自己的 JSON 設定內：

```powershell
[Environment]::SetEnvironmentVariable(
  'OUTLOOK_EMAIL_FUNCTION_KEY',
  '<your-functions-key>',
  'User'
)
```

如果你的 Function App 只走 **private route**，而本機又有公司 proxy，請把下列 host 加進 `NO_PROXY`，否則 Claude Code / Copilot CLI / `curl` 都可能一直卡在連線或把流量錯送到公網：

```powershell
$existing = [Environment]::GetEnvironmentVariable('NO_PROXY', 'User')
$extra = @(
  'func-xlxpcx7ss2kmy.azurewebsites.net',
  'func-xlxpcx7ss2kmy.scm.azurewebsites.net',
  'azurewebsites.net'
)
$combined = (($existing -split ',') + $extra | Where-Object { $_ } | Select-Object -Unique) -join ','
[Environment]::SetEnvironmentVariable('NO_PROXY', $combined, 'User')
```

> 這個 sample 的遠端 `/mcp` 目前回的是 **`text/event-stream` (SSE)**。若你用 `curl` / PowerShell 直接除錯，不要把整個回應當成純 JSON；應改抓 `data:` 那一行再解析。

## 常見陷阱與排錯入口

| 情境 | 常見症狀 | 先檢查什麼 |
| --- | --- | --- |
| `dotnet run --project ... -- --http ...` 少了第二個 `--` | `--http`、tenant / client / secret 參數沒有生效 | `dotnet run` 後面要保留第二個 `--`，讓 sample-specific 參數正確傳入 |
| MCP 伺服器有啟動，但一寄信就失敗 | 出現 Graph 認證、授權或 token 相關錯誤 | 檢查 tenant ID、client ID、client secret、`Mail.Send` application permission 與 admin consent |
| `sender` 被拒絕 | 提示寄件者不在允許清單中 | 檢查 `AllowedSenders`、`AllowedSenders__0`、`AllowedSenders__1` 等設定是否包含該信箱 |
| `replyTo` 被拒絕 | 提示 replyTo 位址不在允許清單中 | 檢查 `AllowedReplyTo`、`AllowedReplyTo__0`、`AllowedReplyTo__1` 等設定是否包含該地址 |
| 附件被拒絕 | 提示 Base64、MIME、大小或數量錯誤 | 檢查 `contentType` 是否正確、`contentBytesBase64` 是否有效、單檔是否超過 **3 MiB**、附件總數是否超過 **10** |
| local / Azure 設定看起來正確，但認證模式不如預期 | 誤以為程式一定會跟著 `AZURE_CLIENT_ID` 或一定會跟著 client secret 走 | 先看 `EntraId__UseManagedIdentity`；若未明確設定，程式會優先採用已提供的 tenant / client / secret，只有在這些都不存在時才回退到 `AZURE_CLIENT_ID` |
| Copilot CLI / Claude Code 一直顯示 `Connecting` | 遠端 MCP server 遲遲連不上 | 先確認 `OUTLOOK_EMAIL_FUNCTION_KEY` 是**實際的 OS 環境變數**，再確認 `NO_PROXY` 是否包含 `func-xlxpcx7ss2kmy.azurewebsites.net` |
| private endpoint 明明存在，但 `curl` / CLI 還是連不上 | 看到 proxy 相關錯誤、`403 Ip Forbidden` 或 schannel revocation 錯誤 | 先檢查 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`；診斷時可用 `curl --noproxy '*' ...` 直接驗證私網路徑 |
| 改了程式碼，但文件或範本沒跟著改 | 新加入的人照文件操作卻跑不起來 | 若你改了 `send_email`、認證流程、啟動方式或設定欄位，記得同步更新 `README.md`、`local.settings.sample.json` 與相關腳本 |

### 本輪踩雷與避坑紀錄（2026-04）

| 類別 | 這次踩到的雷 | 典型症狀 | 下次怎麼避開 |
| --- | --- | --- | --- |
| Flex private deploy | Flex Consumption 不能直接用通用 Kudu zip publish | `/api/publish?type=zip` 失敗，或 private SCM 行為和預期不同 | 對 private SCM 使用 `POST /api/publish?RemoteBuild=<bool>&Deployer=az_cli`，並以 `Content-Type: application/zip` + Bearer token 發佈 |
| 公司 proxy + private endpoint | 要求被公司 proxy 轉送到公網 | `403 Ip Forbidden`、proxy `CONNECT`、TLS / revocation 錯誤 | 把 Function App / SCM host 加進 `NO_PROXY`；診斷時可先用 `curl --noproxy '*'` |
| Copilot CLI remote header 參照 | `mcp-config.json` 內的 `env` 區塊不一定會替 remote header 自動展開 | Copilot CLI server 一直 `Connecting` | 把 `OUTLOOK_EMAIL_FUNCTION_KEY` 設成實際的 OS 環境變數，不要只寫在 JSON 的 `env` 物件裡 |
| 遠端 `/mcp` 回應型態 | 直接把回應當純 JSON 解析 | `ConvertFrom-Json` 失敗 | 先把 SSE 的 `data:` 行取出，再解析 JSON |
| Graph auth 模式判斷 | 只用 `AZURE_CLIENT_ID` 判斷是否走 managed identity | 明明給了 tenant/client/secret，程式卻走錯認證模式 | 以 `EntraId__UseManagedIdentity` 明確值為第一優先；若未設定，才依是否有完整 SP 設定與 `AZURE_CLIENT_ID` fallback 判斷 |
| Service principal 缺值 | 只填一部分 `tenant/client/secret` | 直到寄信時才發現 Graph 認證炸掉 | `UseManagedIdentity=false` 時，三個值要一次到位；目前程式已改成 fail-fast |
| Credential hygiene | 走 managed identity 時仍把 SP secret 留在 app settings | 部署雖然能跑，但把不必要的 secret 長期留在 Azure | 走 managed identity 就不要設定 `MCP_ENTRA_*`；走 service principal 則優先用 Key Vault reference |
| Function runtime 版本 | Flex runtime 與 app target framework 不一致 | `/mcp` 回 `502` | `net10.0` app 要對齊 `dotnet-isolated 10.0` |
| 既有 VNet / subnet 重用 | Flex integration subnet 名稱、delegation、既有關聯不符 | subnet 不能用、或更新時意外掉 NSG / route table 關聯 | integration subnet 名稱不要用 `_`，要用 `Microsoft.App/environments` delegation；若 Bicep 會更新 subnet，也要一併帶入 NSG / route table ID |
| 既有 VNet 跨 RG | 目前 template 仍預設既有 VNet 與部署 RG 同一個 resource group | 跨 RG reuse 時找不到 VNet | 若要跨 RG 重用既有 VNet，先擴充 template，再部署；不要先假設目前版本支援 |


