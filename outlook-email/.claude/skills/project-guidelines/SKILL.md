---
name: project-guidelines
description: 專案核心規範、工作規劃與撰寫標準。產生程式碼、註解、文件、報表或 bot 回覆時，用於確保整體一致性。
---

# 專案指南與標準

本專案的所有變更都必須遵循以下規範。

## 1. 語言要求

**所有人類可讀文字一律嚴格使用繁體中文（台灣用語）。**

### 何時使用繁體中文

**必須使用繁體中文的情境：**

- ✅ 建立新專案的 `README.md`
- ✅ 撰寫技術文件（`quickstart.md`、`deployment.md` 等）
- ✅ 新增程式碼註解（Python、TypeScript、JavaScript 等）
- ✅ 撰寫 Dockerfile 與設定檔註解
- ✅ 建立專案文件結構
- ✅ 撰寫 commit 訊息
- ✅ 錯誤訊息與面向使用者的文字
- ✅ API 文件與使用說明

**例外情況（保留英文）：**

- 程式碼本身（變數名稱、函式名稱、類別名稱）
- 技術術語（保留原文，如 FastMCP、Next.js、Docker、OAuth、Token）
- 國際開源專案的貢獻內容
- 需要與國際團隊協作的專案

### 產出物與規劃

- **規則**：Agent 產生的所有實作計畫、操作說明與推理產出物，都必須使用繁體中文。

### 程式碼註解

- **規則**：所有程式碼註解都必須使用繁體中文。

#### Python

**單行與行內註解：**

```python
# 載入環境變數（用於本機開發）
load_dotenv()

# ✅ 正確：計算總收入
total_revenue = calculate_total()

# ❌ 錯誤：Calculate total revenue
```

**區塊說明註解：**

```python
# --- 進入點 ---
if __name__ == "__main__":
    # 1. 動態載入 Skills
    load_skills()

    # 2. 啟動伺服器（預設 port 8000）
    start_server()
```

**錯誤訊息與日誌（面向使用者的文字必須是繁中）：**

```python
# ✅ 正確
return "錯誤: 必須設定 DATABRICKS_HOST 環境變數。"
logger.warning(f"⚠️ Skills 目錄不存在: {skills_path}")

# ❌ 錯誤
return "Error: DATABRICKS_HOST must be set."
```

#### TypeScript / JavaScript

```typescript
// 為 Node.js 環境提供 EventSource polyfill
global.EventSource = EventSource;

/**
 * 取得所有可用的技能列表
 *
 * @returns 包含工具與提示的物件
 * @throws 當連線失敗時拋出錯誤
 */
export async function getSkills() {
  // 平行取得 Tools 和 Prompts
  const [tools, prompts] = await Promise.all([
    client.listTools(),
    client.listPrompts(),
  ]);
}
```

#### Dockerfile 與設定檔

```dockerfile
# 階段 1：使用 UV 的建置階段
FROM python:3.12-slim AS builder

# 安裝 UV
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 複製依賴檔案並建立虛擬環境
COPY pyproject.toml README.md ./
RUN uv pip install --system --no-cache .
```

### 文件

- **規則**：`README.md`、`*.md` 檔案與 docstrings 都必須使用繁體中文。
- **例外**：特定技術術語若英文更通行，可保留原文（例如 `OAuth`、`Token`、`DataFrame`）。

#### Markdown 文件規範

**標題、段落、清單：** 一律使用繁體中文，技術名詞保留英文。

**HTML 維護註解：**

```markdown
<!-- 這是給維護者的註解，使用者看不到 -->
<!-- TODO: 補充 Azure 部署的詳細步驟 -->
<!-- 注意: 以下指令需要管理員權限 -->
```

**表格：**

```markdown
| 變數名稱 | 說明 | 範例值 |
| --- | --- | --- |
| `DATABRICKS_HOST` | Databricks 工作區 URL | `https://adb-xxx.azuredatabricks.net` |
| `DATABRICKS_TOKEN` | 個人存取權杖 | `dapixxxxx` |
```

**引用與警示區塊：**

```markdown
> **注意:** 切勿將 `.env` 檔案提交到版本控制系統。
> **重要:** 生產部署請使用 Service Principal，而非個人存取權杖。
```

**連結（內部連結請使用繁中描述）：**

```markdown
詳細說明請參閱 [部署指南](./docs/deployment.md)。
```

### 不翻譯的內容

- **函式名稱、類別名稱、變數名稱、常數名稱**：保留英文識別子，僅在右側加上繁中行內註解。
- **檔案路徑與 URL**：保持原始格式。

```python
# ✅ 正確 - 只翻譯註解，保留識別子
def load_skills(skills_dir: str = "skills"):
    """載入指定目錄下的技能"""

DEFAULT_TIMEOUT_MINUTES = 20  # 預設逾時時間（分鐘）

# ❌ 錯誤 - 不要翻譯函式名稱或變數名稱
def 載入技能(技能目錄: str = "skills"):
    pass

預設逾時分鐘數 = 20
```

### Bot 回覆

- **規則**：所有傳送給使用者的文字（Activity text、Adaptive Cards、Error messages）都必須是繁體中文（台灣用語）。
- **語氣**：專業、樂於協助且有禮貌。

### Git commit 訊息

- **規則**：所有 git commit 訊息都必須使用 **繁體中文**。
- **格式**：`type: description`（例如 `feat: 新增登入功能`、`fix: 修復 Teams 連線問題`）。
- **類型**：`feat`、`fix`、`docs`、`style`、`refactor`、`test`、`chore`。

### Git Flow 與分支策略

- **規則**：所有新功能與 bug fix 都必須先 commit 或 merge 到 `develop` 分支。
- **規則**：`main` 或 `master` 分支保留給可上線的程式碼，只能接收來自 `develop` 分支的 merge。

### Git 合併策略

- **規則**：所有合併到 `main` 分支的操作都必須使用 `--no-ff`（no fast-forward）選項。
- **原因**：即使可以 fast-forward，也要保留 feature branch 的 commit 歷史，讓變更脈絡更清楚。
- **指令**：`git merge --no-ff <branch_name>`

## 2. 工作規劃、追蹤與交付

### 工作切片與執行順序

- **規則**：新工作開始前，先建立需求基線或 work item 基線，再切成可交付的小片段。
- **規則**：每個待辦至少應具備：
  - 流水號
  - 英文 `Title`
  - 繁體中文說明
  - 狀態
  - 預估工時
- **規則**：若有 Azure DevOps、Jira 或其他工作系統，先整理 `title`、`description`、`Remaining Work`、`Assigned To` 與未完成編號，再決定切片與依賴。
- **規則**：依賴關係必須先明確，避免在前置條件未完成時並行推進互相阻塞的工作。
- **順序原則**：優先做低成本、可快速驗證的工作（例如 local 驗證、文件、輸入防呆），確認方向後再進入雲端資源或高成本施工。
- **順序原則**：雲端網路、安全或部署施工前，必須先完成入口模型與架構決策（例如是否使用 APIM、Private Endpoint、VNet 形態）。

### 文件分工

- **規則**：`plan.md` 只負責範圍、待辦、依賴與執行順序。
- **規則**：`README.md` 是給操作者或使用者的主操作手冊。
- **規則**：`CLAUDE.md` 是給 agent 的導航文件，放 scope、重要檔案、常用命令與協作規則。
- **規則**：同一件事只保留一個主要來源，避免多份文件重複維護相同步驟或限制。

### `/plan` 的參考來源

- **規則**：撰寫 `/plan` 時，不可只憑當前對話臨時整理；應依下列順序整合資訊：
  1. **目前 session 的 `plan.md`**：承接這一輪已確認的範圍、依賴與前次決策。
  2. **`.claude\project-guidelines\SKILL.md`**：作為 `/plan` 內容格式、欄位與報表要求的**主規範來源**。
  3. **sample 的 `README.md`**：提供操作者視角的限制、部署方式、驗證方式與環境前提。
  4. **sample 的 `CLAUDE.md`**：提供 agent 視角的檔案入口、技能入口與協作邊界。
  5. **SQL 追蹤資料**：`todos`、`todo_deps`、`todo_metrics`，作為待辦狀態、依賴與工時欄位的結構化來源。
- **規則**：若上述來源互相衝突：
  - `/plan` 的**格式與欄位要求**以 `project-guidelines` 為準
  - 操作步驟與使用限制以 `README.md` 為準
  - agent 協作與檔案導航以 `CLAUDE.md` 為準
  - 本輪已確認的決策與排序，以當前 `plan.md` + SQL 為準

### `/plan` 的固定內容格式

- **規則**：之後每次 `/plan` 至少必須包含以下章節，且不可省略工時與完成時間欄位。

#### 1. 問題陳述與邊界
- 目前要解決什麼問題
- 本輪範圍 / 不在本輪範圍
- 重要限制、假設與既有決策

#### 2. 需求 / work item 基線
- 若有 Azure DevOps、Jira 或其他工作系統：
  - 列出目前已知的 work item 編號
  - 補 `Title`、`Description`、`Remaining Work`、`Assigned To`
  - 標示哪些是 active backlog、哪些只是歷史背景

#### 3. 執行順序與依賴
- 說明排序原則
- 列出 ready / blocked / deferred 的項目
- 清楚標示依賴關係與前置條件

#### 4. 未完成項目表（必填）
- **規則**：未完成項目一律使用 Markdown table，至少包含下列欄位：

| 欄位 | 說明 |
| --- | --- |
| `No.` | 流水號 |
| `Todo ID` | 英文識別子，需可對應 SQL `todos.id` |
| `English Title` | 英文標題 |
| `中文說明` | 可獨立理解的繁中說明 |
| `Status` | `pending` / `in_progress` / `blocked` |
| `Ready` | `yes` / `no` |
| `Depends On` | 依賴的 todo 或前置決策 |
| `Estimated Hours` | 預估工時，單位固定為 hours |

#### 5. 已完成項目表（必填）
- **規則**：已完成項目一律使用 Markdown table，至少包含下列欄位：

| 欄位 | 說明 |
| --- | --- |
| `No.` | 流水號 |
| `Todo ID` | 英文識別子 |
| `English Title` | 英文標題 |
| `中文摘要` | 完成內容摘要 |
| `Status` | 固定為 `done` |
| `Completed At` | 完成時間 |
| `Actual Hours` | 實際工時，單位固定為 hours |
| `Hours Note` | 是否為估算 / 回填 / 異常說明 |

#### 6. 後續交付與回寫
- 是否需要 Azure DevOps draft
- 是否需要回寫 `Remaining Work`
- 是否需要交付到 `develop`

### `/plan` 與 SQL 工時欄位的對應

- **規則**：`plan.md` 是人類可讀版；工時與完成時間的**結構化來源**應同步落在 `todo_metrics`。
- **規則**：每個 todo 第一次出現在 `/plan` 的未完成項目表時，就應補上 `estimated_hours`。
- **規則**：todo 狀態改為 `done` 時，必須同步補上：
  - `actual_hours`
  - `completed_at`
  - `hours_note`（若為回填或估算）
- **規則**：若 `plan.md` 與 `todo_metrics` 不一致，以 **先修正資料，再更新文件** 為原則，不可長期放任雙方漂移。

### `/plan` 最小模板

```markdown
## 問題陳述
- ...

## 範圍與邊界
- In scope: ...
- Out of scope: ...

## 需求 / work item 基線
| Work Item | Title | Remaining Work | Assigned To | 備註 |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... |

## 排序原則
1. ...
2. ...

## 未完成項目
| No. | Todo ID | English Title | 中文說明 | Status | Ready | Depends On | Estimated Hours |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | ... | ... | ... | pending | yes | ... | 1.5 |

## 已完成項目
| No. | Todo ID | English Title | 中文摘要 | Status | Completed At | Actual Hours | Hours Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | ... | ... | ... | done | 2026-04-04 10:30 | 0.75 | actual |

## 後續交付
- Azure DevOps draft: ...
- Develop delivery: ...
```

### Azure DevOps 與工作系統回寫限制

- **規則**：所有回寫到 Azure DevOps 或其他工作系統的內容，都必須先整理成 draft 給使用者審閱，得到明確確認後才能執行。
- **規則**：回寫內容至少應包含進度摘要、已完成項、未完成項、剩餘工作，以及相關 commit / PR / 交付資訊（若適用）。
- **規則**：若目前找到的 work item 與實際範圍不完全對應，必須先標記不確定性，不可直接回寫到可能錯誤的 work item。

### 狀態報告與工時欄位

- **規則**：狀態報告優先使用 Markdown table。
- **規則**：未完成項至少應包含：流水號、Title、中文說明、狀態、可開工性、預估工時。
- **規則**：工時單位一律使用 **小時（hours）**，建議最小粒度為 `0.25` 小時。
- **規則**：已完成項應補上：實際工時、完成時間；若為回填值，必須明確標示為估算或回填。
- **規則**：調整施工順序時，`plan.md` 與追蹤資料必須同步更新，避免文件與報表不一致。

### Copilot CLI 協作衡量

- **規則**：若平台能提供正式 usage data，可記錄 token 使用量、模型費用或其他真實成本。
- **規則**：若平台無法提供正式 usage data，不得捏造 token 或費用；必須明確標示資料不可得，並改用 proxy 指標。
- **規則**：專案開始時先定義「進階需求母集合」，作為跨項目比較的共同基線。
- **規則**：進階需求母集合應由本輪最重要的高層需求組成，通常建議控制在 `5-10` 項，並在整個階段內維持一致。
- **定義**：`進階需求覆蓋率 = 此項目直接碰觸的進階需求數 / 進階需求母集合總數`
- **定義**：`Copilot CLI 貢獻值 = 工時 × (1 + 進階需求覆蓋率)`
- **規則**：已完成項目使用 `actual_hours`，未完成項目使用 `estimated_hours`。
- **規則**：對外報表命名優先使用「貢獻值」，避免使用較主觀的「努力點數」。

### Azure DevOps Work Item 管理規範

#### Task 狀態轉換流程（強制執行）

所有 Task 的狀態變更必須遵循以下順序，**禁止跳過中間狀態**：

```
New → To Do → In Progress → Done
```

| 步驟 | 狀態 | 說明 |
| --- | --- | --- |
| 1 | New | Task 剛建立時的初始狀態（系統自動） |
| 2 | **To Do** | 確認進入 Sprint，準備開始 |
| 3 | **In Progress** | 正在進行開發／測試／部署 |
| 4 | **Done** | 工作完全完成，驗收通過 |

**禁止行為：**

- ❌ 建立 Task 時直接設為 Done（ADO 不支援，且違反流程）
- ❌ 從 To Do 直接跳到 Done（必須經過 In Progress）
- ❌ 使用 `wit_add_child_work_items`（Area Path 權限問題，必然 403，無 workaround）
- ❌ 更新 Task 時帶入 `RemainingWork=0`（ADO 視為無效值，回傳 `InvalidNotEmpty`）

**正確的 Task 建立與完成流程：**

```
步驟 1：wit_create_work_item（帶 System.AreaPath，不指定 State，預設 To Do）
步驟 2：wit_work_items_link（批次建立 parent 連結）
步驟 3：wit_update_work_item → State = In Progress
步驟 4：wit_update_work_item → State = Done，填入 CompletedWork（略過 RemainingWork）
```

`wit_update_work_items_batch` 可在同一批次陣列對同一 work item 傳多個 path，一次呼叫完成 State + CompletedWork 更新。

#### PBI（Product Backlog Item）狀態

```
New → Approved → Committed → Done
```

- PBI 的 `Effort`（故事點數）欄位在 **Done 狀態下為唯讀**，須在 New / Approved 階段設定，不得在建立時同時設 `State=Done` 與 `Effort`。
- Task 完成時只填 `CompletedWork`，**不填 `Effort`**。

#### ADO 描述注意事項

- 描述文字只使用**常見繁體中文字**，避免罕用／異體字（Unicode > U+9FFF）。
- 若 `wit_create_work_item` 收到 `MCP error -32602: Input validation error: Expected array, received string`，先檢查描述內容是否含非標準字元。

## 3. 程式撰寫標準

### Python

- 遵循 PEP 8 風格指南。
- 函式簽名使用 type hinting（`typing` module）。
- 輸出請使用 `logger`，不要使用 `print`。

### 錯誤處理

- 不要向使用者顯示原始 stack trace。
- 將完整錯誤記錄到 console / Application Insights。
- 以繁體中文回傳對使用者友善的錯誤訊息。

## 4. 環境變數

- 絕不可硬編碼 secrets。
- 一律使用 `os.environ` 或 `os.getenv`。
- 新增變數時要記錄在 `.env.example`。

## 5. 進階程式撰寫標準

### Async/Await（非阻塞 I/O）

- **規則**：I/O 密集或需要高併發的操作，應優先使用非同步方式。
- **規則**：若專案本身是同步 CLI、批次或一次性工具，可採同步實作，但不得在 async 流程中混入阻塞式呼叫。
- **Python 範例**：避免在 async code 使用 `time.sleep()`、同步版 `requests`；改用 `asyncio.sleep()`、`aiohttp` 或其他 async client。

### Docstrings（文件字串）

- **規則**：所有函式與類別都必須有 **繁體中文** docstrings。
- **樣式**：Google Style，欄位標籤一律使用繁體中文。
- **內容**：說明、參數 (Args)、回傳 (Returns)、引發 (Raises)。

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

### Import 排序

- **順序**：標準函式庫 -> 第三方套件 -> 本地應用程式。
- **範例**：

  ```python
  import os
  import json

  import aiohttp
  from botbuilder.core import TurnContext

  from config import DefaultConfig
  ```

### 測試

- **規則**：核心商業邏輯應具備自動化測試；若專案現階段沒有測試框架，至少要記錄手動驗證方式與已知風險。
- **單元測試**：外部服務應以 mock 或 stub 取代；單元測試中不可發出真實網路呼叫。
- **整合測試 / E2E**：可依專案需求使用真實或測試環境，但應與單元測試分開管理，避免互相污染。

## 6. 建議目錄結構（Python Web / Bot 專案示例）

以下結構為 **Python Web / Bot 專案示意**。若專案使用其他語言或框架，應保留相同分層概念（設定、商業邏輯、模型、測試、文件），再替換成對應生態系的檔名與目錄。

```
.
├── .claude/             # Agent 技能或協作規則
├── .github/             # CI/CD 工作流程
├── src/                 # 主要應用程式
│   ├── __init__.py
│   ├── main.py          # 應用程式進入點
│   ├── api/             # API 路由
│   │   ├── routes.py
│   │   └── bot.py       # Bot 專案可選的路由或處理常式
│   ├── core/            # 組態與設定
│   │   └── config.py
│   ├── services/        # 商業邏輯
│   │   └── example_service.py
│   └── models/          # Pydantic Models 與 Schemas
├── bot/                 # Bot 專案可選的專屬內容
│   ├── dialogs/         # ComponentDialogs
│   ├── cards/           # Adaptive Cards
│   └── handlers/        # ActivityHandlers
├── tests/               # 測試套件
│   ├── unit/            # 單元測試
│   ├── integration/     # 整合測試
│   └── e2e/             # 端到端測試
├── docs/                # 文件
│   ├── api/             # API 規格
│   └── architecture/    # 設計文件
├── logs/                # Log 檔案（gitignored）
├── .env                 # 機密資訊（gitignored）
├── .gitignore
└── requirements.txt
```

## 7. 詞彙對照表

| 英文 | 繁體中文 | 使用情境 |
| --- | --- | --- |
| server | 伺服器 | 一般用途 |
| client | 用戶端／客戶端 | 一般用途 |
| endpoint | 端點 | API 相關 |
| request | 請求 | HTTP 相關 |
| response | 回應 | HTTP 相關 |
| error | 錯誤 | 錯誤處理 |
| warning | 警告 | 警示訊息 |
| timeout | 逾時 | 時間相關 |
| install | 安裝 | 套件管理 |
| deploy | 部署 | DevOps |
| build | 建置 | 編譯相關 |
| container | 容器 | Docker |
| image | 映像 | Docker |
| environment variable | 環境變數 | 設定 |
| configuration | 設定／組態 | 設定檔 |
| dependency | 依賴 | 套件管理 |
| virtual environment | 虛擬環境 | Python |
| function | 函式 | 程式碼 |
| parameter | 參數 | 函式相關 |
| argument | 引數／參數 | 函式呼叫 |
| return | 回傳 | 函式回傳值 |
| import | 匯入 | 模組載入 |
| export | 匯出 | 模組匯出 |
| load | 載入 | 資料讀取 |
| save | 儲存 | 資料寫入 |
| query | 查詢 | 資料庫／API |
| fetch | 取得 | 資料擷取 |
| create | 建立 | CRUD |
| update | 更新 | CRUD |
| delete | 刪除 | CRUD |
| validate | 驗證 | 資料檢查 |
| parse | 解析 | 資料處理 |
| register | 註冊 | 系統註冊 |
| initialize | 初始化 | 系統啟動 |
| cleanup | 清理 | 資源釋放 |
| connection | 連線 | 網路相關 |
| authentication | 認證 | 安全性 |
| permission | 權限 | 存取控制 |
| log | 日誌／記錄 | 除錯 |
| exception | 例外 | 錯誤處理 |
| thread | 執行緒 | 並行處理 |
| process | 程序 | 系統層級 |
| pipeline | 管線 | 資料流／CI/CD |
| cluster | 叢集 | 分散式系統 |
| worker | 工作節點 | 分散式／佇列 |
| scheduler | 排程器 | 任務排程 |
| trigger | 觸發器 | 事件驅動 |
| payload | 承載資料 | API／訊息 |
| token | 權杖（Token 可保留） | 認證 |

## 8. 翻譯範例（前後對照）

### 前（英文原始碼）

```python
# Load environment variables from .env file
load_dotenv()

def start_conversation(space_id: str, question: str) -> str:
    """
    Start a new conversation with Databricks Genie.

    Args:
        space_id: The Genie Space ID
        question: Natural language question to ask

    Returns:
        JSON string containing the conversation result
    """
    try:
        # Initialize workspace client
        w = WorkspaceClient()

        # Start conversation and wait for completion
        response = w.genie.start_conversation_and_wait(
            space_id=space_id,
            content=question
        )

        return response.content

    except Exception as e:
        return f"Error starting conversation: {str(e)}"
```

### 後（符合繁體中文規範）

```python
# 載入 .env 環境變數
load_dotenv()

def start_conversation(space_id: str, question: str) -> str:
    """
    啟動與 Databricks Genie 的新對話。

    參數:
        space_id: Genie Space ID
        question: 要詢問的自然語言問題

    回傳:
        包含對話結果的 JSON 字串

    引發:
        Exception: 當 API 呼叫失敗時
    """
    try:
        # 初始化 workspace client
        w = WorkspaceClient()

        # 啟動對話並等待完成
        response = w.genie.start_conversation_and_wait(
            space_id=space_id,
            content=question
        )

        return response.content

    except Exception as e:
        return f"啟動對話時發生錯誤: {str(e)}"
```

