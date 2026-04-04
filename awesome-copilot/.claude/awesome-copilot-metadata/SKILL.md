---
name: awesome-copilot-metadata
description: |
  awesome-copilot sample 的 metadata / tool / registry workflow 指引。用於修改 `search_instructions`、`load_instruction`、`metadata.json` 載入與更新流程，或處理 `update-metadata.cs`。
  觸發詞："awesome-copilot", "metadata.json", "search_instructions", "load_instruction", "update-metadata.cs", "server.json"。
---

# Awesome Copilot Metadata 指引

此技能只處理 `awesome-copilot` sample。

## 主要檔案

| 檔案 | 職責 |
| --- | --- |
| `README.md` | sample 的本機、容器與 Azure 執行方式 |
| `src\McpSamples.AwesomeCopilot.HybridApp\Program.cs` | JSON options、`IMetadataService`、HTTP OpenAPI wiring |
| `src\McpSamples.AwesomeCopilot.HybridApp\Services\MetadataService.cs` | `metadata.json` 讀取、快取、關鍵字搜尋與 GitHub raw content 載入 |
| `src\McpSamples.AwesomeCopilot.HybridApp\Tools\MetadataTool.cs` | `search_instructions` / `load_instruction` MCP tool 介面 |
| `src\McpSamples.AwesomeCopilot.HybridApp\metadata.json` | 預先索引的 metadata 資料 |
| `update-metadata.cs` | 更新 metadata 的腳本 |
| `server.json` | awesome-copilot registry metadata |

## 修改流程

### 調整 MCP tool 介面時

1. 先改 `MetadataTool.cs`。
2. 若輸入或回傳模型有變動，連同 `Models\` 一起更新。
3. 如果使用方式改變，補改 `README.md`。

### 調整 metadata 載入或搜尋行為時

1. 主要修改 `MetadataService.cs`。
2. 保留 `_cachedMetadata` 的快取模式，不要每次搜尋都重新讀檔與反序列化。
3. `load_instruction` 目前只在需要時透過 GitHub raw URL 載入實際內容，這個責任分界不要打散。

### 調整更新 / 發布流程時

1. metadata 結構變動時，檢查 `update-metadata.cs` 是否也要同步修改。
2. 影響 registry package 資訊時，檢查 `server.json` 與相關 workflow。

## 常用指令

```powershell
dotnet build .\McpAwesomeCopilot.sln
dotnet run --project .\src\McpSamples.AwesomeCopilot.HybridApp
dotnet run --project .\src\McpSamples.AwesomeCopilot.HybridApp -- --http
dotnet run .\update-metadata.cs
```

## 常見陷阱

1. 不要把 `metadata.json` 的載入改成每次請求都重讀。
2. `search_instructions` 與 `load_instruction` 是對外 MCP tool 名稱，變更時要一起考慮相容性。
3. `Program.cs` 已經設定 camelCase 與 case-insensitive JSON 行為；處理 metadata payload 時要延用同樣語意。

