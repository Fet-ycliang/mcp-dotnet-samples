---
name: retro
description: |
  outlook-email 週期性覆盤助手。回顧近期變更、把踩坑化為規則、更新 CLAUDE.md 與 memory。
  觸發詞: "retro", "覆盤", "週會", "session review", "學到什麼", "補規則"
---

# Retro — 週期性覆盤

每次 session 結束、每週，或任何「剛完成一段比較大的工作」之後執行。目標是讓下一個 session 比這個更聰明。

## 執行順序

### Step 1：掃近期 commits

```bash
git log --oneline -20
```

逐筆確認：有沒有 `fix:` 或修正性 commit 是因為犯錯才有的？那個錯誤有沒有對應規則？

### Step 2：掃 CLAUDE.md 的「常見陷阱」是否已補上

對照近期踩到的坑，逐項確認：

- APIM policy expression 的 Razor 語法坑（`if` 大括號、`//` 字串問題）→ 已在 CLAUDE.md ✅
- APIM `validate-jwt` issuer / audience 錯誤 → 已在 memory ✅
- 靜態 Bearer header 蓋掉 OAuth token → 已在 memory ✅
- **若發現新坑** → 立刻寫進 CLAUDE.md 對應章節，並寫 `feedback_*.md` 存進 memory

### Step 3：掃 memory 是否需要更新

檢查 `~/.claude/projects/D--azure-code-mcp-dotnet-samples/memory/MEMORY.md`：

- 有沒有過期的 project 事實？（例如 live APIM 名稱、ACA endpoint 已異動）
- 有沒有這輪新確認的「非直覺但有效做法」需要補 feedback 記憶？

### Step 4：查 ADO Sprint 當前 PBI / Task 狀態

使用 `wit_query_by_wiql` 查 Sprint 202604（或目前 Sprint）的 PBI 與 Task：

```wiql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.WorkItemType]
FROM WorkItems
WHERE [System.TeamProject] = 'FET-Delivery'
  AND [System.AreaPath] UNDER 'FET-Delivery\PJT-1375-DataOps-Assistant'
  AND [System.IterationPath] UNDER 'FET-Delivery\PJT-1375-DataOps-Assistant\202604'
  AND [System.WorkItemType] IN ('Product Backlog Item', 'Task')
ORDER BY [System.WorkItemType], [System.Id]
```

逐項確認：

- 有沒有 Active PBI 或 Task 遺漏了本週進展？→ 更新 State 或補 comment
- 有沒有這輪新完成的工作需要建 PBI / Task 才能反映出工時？
- 下個 Sprint 有沒有要搬移或新建的項目？

### Step 4b：掃本 session 待辦任務清單（本地）

用 `TaskList` 確認：

- 哪些 task 已完成但沒標 completed？→ 補標
- 哪些 task 的描述因為情況改變而過時？→ 更新或刪除
- split-auth 過渡的四項任務（#1–#4）有沒有新進展？

### Step 5：確認文件一致性

快速比對三個地方是否同步：

| 檢查點 | 確認項目 |
|--------|----------|
| `README.md` | 本機啟動指令、APIM URL、Azure 資源名稱是否仍正確 |
| `CLAUDE.md` | 架構重點的 live 資源名稱（APIM、ACA、Key Vault）是否已是最新 |
| `.claude/skills/` | 近期若新增功能（例如新 MCP tool），對應 skill 是否有更新 |

## 覆盤輸出格式

```markdown
## Retro — {日期}

### 這週做了什麼
- {commit 或任務摘要}

### 踩了什麼坑 → 寫了哪條規則
- 坑：{描述}  
  規則：已補進 {CLAUDE.md 章節 / memory/feedback_xxx.md}

### 下週待辦
- {最高優先的 1–3 件事}
```

## 注意事項

- 覆盤重點是**讓規則留下來**，不是寫長篇報告。
- 若沒有新坑、文件都對齊，直接說「本週無新坑，文件同步」即可。
- 每條新規則都要附 **Why** 與 **How to apply**，讓未來的 session 能判斷邊界情境。
