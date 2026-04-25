---
name: document-release
description: |
  outlook-email 部署後文件更新助手。確認 README、CLAUDE.md、ADO Release Notes、memory 在每次 rollout 後維持同步。
  觸發詞: "deploy 完了", "rollout 完成", "發布文檔", "release notes", "document release", "部署後更新"
---

# Document Release — 部署後文件更新

每次 `main` branch rollout 到 ACA（透過 `deploy-outlook-email-main.yaml`）、或手動 `azd up` 完成後執行。

## 前置：確認本次部署範圍

```bash
# 確認這次 rollout 包含哪些 commits
git log --oneline main..HEAD   # 若已 merge 到 main
# 或
git log --oneline <上次 tag>..HEAD
```

同時確認：

- 是否有 infra 變更（`infra/` 目錄）？→ 可能影響 Azure 資源名稱 / 設定
- 是否有 MCP tool 介面變更（`Tools/`、`Models/`）？→ 需同步 README payload 範例
- 是否有認證 / 設定流程異動（`Program.cs`、`local.settings.sample.json`）？→ 需同步 README 操作步驟

## Step 1：更新 README.md

| 異動類型 | 要更新的段落 |
|----------|------------|
| MCP tool 參數 / 描述 / 回傳 | payload 範例、限制說明 |
| CLI 參數或設定欄位 | 執行範例、`local.settings.sample.json` 對應說明 |
| Azure 資源名稱（APIM、ACA、Key Vault）| 操作步驟中的 live 資源名稱 |
| MCP 連線模式 | `.vscode/mcp*.json` 使用說明 |
| 認證流程 | Entra app 設定、token 取得步驟 |

## Step 2：更新 CLAUDE.md

確認「架構重點」段落的以下項目仍正確：

- **目前 live APIM 名稱**（`apim-fet-outlook-email`）
- **目前 live ACA 名稱**（`fet-outlook-email-ca`）
- **目前 live Key Vault 名稱**（`outlook-email-kv`）
- ACA secret contract（`graph-client-secret`、`mcp-oauth-client-secret`）
- split-auth 三條線的 client ID 是否仍是最新值

若有新踩坑 → 補進「常見陷阱」段落。

## Step 3：生成 ADO Release Notes（可選）

若本次部署有對應的 Sprint 工作項目，使用 `azdo-release-manager` skill：

```
/azdo-release-manager
```

從 commits 與 PRs 自動產出結構化變更記錄，可發布至 ADO Wiki。

## Step 4：更新 memory

確認以下 memory 檔案是否需要更新：

| Memory 檔案 | 更新時機 |
|-------------|---------|
| `project_apim_client_topology.md` | APIM caller 拓撲有變動時 |
| `feedback_*.md` | 本次 rollout 過程踩到新坑時 |

若有新的專案事實（例如新建了 private endpoint、更換了 Key Vault URI）：

```bash
# 寫入新 project memory
# 路徑：~/.claude/projects/D--azure-code-mcp-dotnet-samples/memory/project_*.md
```

## Step 5：確認 GitHub Actions 狀態

```bash
gh run list --workflow=deploy-outlook-email-main.yaml --limit=3
```

確認最新 run 是 `completed / success`，並記下 image tag（`fetimageacr.azurecr.io/fet-outlook-email-ca:<taipei-timestamp>`）。

## 輸出格式

```markdown
## Release — {日期} / {image tag}

### 本次變更摘要
- {feat/fix/docs 分類列表}

### 文件更新項目
- README.md：{更新了哪些段落}
- CLAUDE.md：{更新了哪些段落，或「無異動」}
- Memory：{更新了哪個 memory 檔，或「無異動」}

### ADO Release Notes
- {Wiki 連結，或「本次無對應工作項目」}

### 已知遺留問題
- {若有 known issue 或 TODO，列在這裡}
```

## 注意事項

- 若只是 hotfix（單一 bug fix），Step 3（ADO Release Notes）可省略。
- `README.md` 是操作主來源，`CLAUDE.md` 是 agent 導航文件，兩者職責不重疊，不要把 runbook 貼進 `CLAUDE.md`。
- image tag 命名規則固定用 `fetimageacr.azurecr.io/fet-outlook-email-ca:<taipei-timestamp>`，不要用其他命名。
