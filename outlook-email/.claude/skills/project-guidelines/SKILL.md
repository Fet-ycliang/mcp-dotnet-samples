---
name: project-guidelines
description: |
  專案核心規範、工作規劃與撰寫標準。產生程式碼、註解、文件、報表或 bot 回覆時，
  用於確保整體一致性。每當要寫 commit 訊息、規劃 /plan、建立 ADO work item、
  決定語言（繁中 vs 英文）、撰寫程式碼或文件時，都必須參照此技能。
  觸發詞：「依照規範」、「commit 怎麼寫」、「/plan」、「ADO work item」、
  「語言規範」、「工作追蹤」、「繁體中文」、「寫文件」、「寫程式」。
---

# 專案指南與標準

## 1. 語言要求

| 情境 | 語言 |
|---|---|
| Claude 回覆與計畫 | **繁體中文**（台灣用語） |
| README.md、技術文件、CLAUDE.md | **繁體中文** |
| 程式碼識別子（函式、變數、類別） | 英文 |
| 程式碼行內 / 區塊註解 | **繁體中文**（優先） |
| Git commit 訊息 | **英文 Conventional Commits**（見第 2 節） |
| ADO work item 描述 | **繁體中文**，HTML 格式（見第 4 節） |
| 錯誤訊息（面向使用者） | **繁體中文** |

技術術語（OAuth、Token、DataFrame、FastMCP 等）保留英文原文，不翻譯。

### 程式碼行內註解

```python
# ✅ 載入環境變數（用於本機開發）
load_dotenv()

# ✅ 繁體中文錯誤訊息
return "錯誤: 必須設定 DATABRICKS_HOST 環境變數。"

# ❌ 英文錯誤訊息
return "Error: DATABRICKS_HOST must be set."
```

### ADO 描述格式（HTML）

`System.Description` 是 HTML 欄位，不要用 Markdown 語法：

```html
<p>任務摘要。</p>
<h3>執行步驟</h3>
<ol>
  <li>步驟 1</li>
  <li>步驟 2</li>
</ol>
<h3>驗收條件</h3>
<ul>
  <li>條件 1</li>
</ul>
```

詳細詞彙對照請參閱 [references/vocabulary.md](references/vocabulary.md)。

---

## 2. Git 規範

### Commit 訊息（English Conventional Commits）

格式：`<type>(<scope>): <description>`

```
feat(outlook-email): add M2M caller role grant module
fix(apim): set APIM OAuth AS issuer to McpOAuthBaseUrl
docs(outlook-email): retro — add skills, fill auth-deployment gaps
test(outlook-email): add Roslyn analyzer and 28-test coverage suite
chore: bump SDK version
```

| Type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | Bug 修復 |
| `docs` | 文件 |
| `refactor` | 重構（不改行為） |
| `test` | 測試 |
| `chore` | 建置 / 維運 |
| `style` | 格式 |

### Git Flow

- 新功能與 bug fix 先到 `develop`，再 merge 到 `main`
- Merge 到 `main` 使用 `--no-ff`（保留 feature branch commit 歷史）

---

## 3. 工作規劃與追蹤

### 開始新工作前

1. 確認 ADO work item 清單或建立需求基線
2. 切成可獨立交付的小片段，每片段具備：編號、English Title、繁中說明、狀態、預估工時
3. 先釐清依賴關係，避免前置條件未完成時並行推進互相阻塞的工作
4. 優先做低成本可快速驗證的工作（local 驗證、文件、輸入防呆），再進入雲端或高成本施工
5. 雲端網路 / 安全施工前，先完成架構決策（APIM、Private Endpoint、VNet 形態）

### 文件分工

| 檔案 | 負責內容 |
|---|---|
| `plan.md` | 範圍、待辦、依賴、執行順序 |
| `README.md` | 操作者 / 使用者主操作手冊 |
| `CLAUDE.md` | Agent 導航：scope、重要檔案、常用命令 |

同一件事只保留一個主來源，避免多份文件重複維護相同步驟。

### `/plan` 固定格式

```markdown
## 問題陳述
- 目前要解決什麼問題 / 本輪範圍 / 不在本輪範圍

## 需求基線
| Work Item | Title | Remaining Work | 備註 |
| --- | --- | --- | --- |

## 排序原則
1. ...

## 未完成項目
| No. | Todo ID | English Title | 中文說明 | Status | Ready | Depends On | Estimated Hours |
| --- | --- | --- | --- | --- | --- | --- | --- |

## 已完成項目
| No. | Todo ID | English Title | 中文摘要 | Status | Completed At | Actual Hours | Hours Note |
| --- | --- | --- | --- | --- | --- | --- | --- |

## 後續交付
- ADO 回寫: ...
- Develop delivery: ...
```

工時單位：hours，最小粒度 0.25h。
已完成項補 `actual_hours`、`completed_at`；回填值標示 `hours_note: estimated`。

### ADO 回寫

所有回寫 ADO 的內容先整理 draft 給使用者確認，再執行。
回寫內容至少包含：進度摘要、已完成項、未完成項、剩餘工作，以及相關 commit / PR。

---

## 4. Azure DevOps Work Item 規範

### Task 狀態轉換（強制順序）

```
New → To Do → In Progress → Done
```

**禁止行為：**

- ❌ 使用 `wit_add_child_work_items`（Area Path 權限問題，必 403，無 workaround）
- ❌ 直接 New → Done（跳過 In Progress）
- ❌ 更新時帶 `RemainingWork=0`（ADO 回 `InvalidNotEmpty`）

**正確流程：**

```
1. wit_create_work_item（帶 System.AreaPath）
2. wit_work_items_link（批次建立 parent 連結）
3. wit_update_work_item → State = In Progress
4. wit_update_work_item → State = Done + CompletedWork（略過 RemainingWork）
```

`wit_update_work_items_batch` 可在同一批次完成 State + CompletedWork 更新。

### PBI 狀態

```
New → Approved → Committed → Done
```

- `Effort` 在 Done 狀態下唯讀，需在 New / Approved 階段設定
- Task 完成只填 `CompletedWork`，不填 `Effort`

### ADO 描述注意事項

- 只用常見繁體中文字（Unicode ≤ U+9FFF），避免罕用 / 異體字
- 若收到 `MCP error -32602: Expected array, received string`，先檢查描述有無非標準字元

---

## 5. 程式撰寫標準

### 通用原則

- 不硬編碼 secrets；使用 `os.environ` / `os.getenv`；新增變數記錄在 `.env.example`
- 不向使用者顯示原始 stack trace；完整錯誤記錄到 logger；以繁體中文回傳使用者友善訊息

### Python

- 遵循 PEP 8；使用 type hinting（`typing` module）；輸出用 `logger`，不用 `print`
- I/O 密集操作優先 async；不在 async 流程中混入阻塞式呼叫（`time.sleep()`、同步 `requests`）

**Docstrings（Google Style，繁體中文）：**

```python
def fetch_data(user_id: str) -> dict:
    """
    從 Genie API 取得使用者資料。

    參數:
        user_id (str): 使用者的唯一識別碼。

    回傳:
        dict: 包含使用者資料的字典。

    引發:
        ValueError: 如果 user_id 無效。
    """
```

**Import 排序：**

```python
import os          # 1. 標準函式庫

import aiohttp     # 2. 第三方套件

from config import DefaultConfig  # 3. 本地
```

### 測試

- 核心商業邏輯應有自動化測試；若無則記錄手動驗證方式
- 單元測試用 mock，不發真實網路呼叫
- 整合 / E2E 測試與單元測試分開管理

---

## 6. 建議目錄結構（Python 專案示例）

```
.
├── .claude/             # Agent 技能
├── .github/             # CI/CD
├── src/
│   ├── main.py
│   ├── api/             # 路由
│   ├── core/            # 組態
│   ├── services/        # 商業邏輯
│   └── models/          # Pydantic models
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/
├── .env                 # 機密（gitignored）
└── requirements.txt
```

---

## 參考檔案

| 檔案 | 內容 |
|---|---|
| [references/vocabulary.md](references/vocabulary.md) | 中英詞彙對照表 |
| [references/translation-examples.md](references/translation-examples.md) | 程式碼繁中化前後對照 |
