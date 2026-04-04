---
name: skill-creator
description: 建立 Agent 技能的指引，特別聚焦於 Azure SDK 與 Microsoft Foundry 服務。建立新技能或更新既有技能時使用。
---

# 技能建立指引

這份指引說明如何透過建立技能來擴充 Agent 能力，重點聚焦於 Azure SDK 與 Microsoft Foundry。

## 關於技能

技能是模組化的知識套件，可將通用 Agent 轉變為更專精的專家：

1. **程序性知識** — 特定領域的多步驟工作流程
2. **SDK 專業知識** — Azure 服務的 API 模式、身分驗證、錯誤處理
3. **領域脈絡** — 架構、商業邏輯、公司特定模式
4. **隨附資源** — 用於複雜任務的腳本、參考資料、範本

---

## 核心原則

### 1. 以精簡為優先

context window（上下文視窗）是共享資源。請質疑每一部分：「它真的值得這些 token 成本嗎？」

**預設假設：Agent 已具備基本能力。** 只補充它原本不知道的內容。

### 2. 優先查核最新文件

**Azure SDK 經常變動。** 技能應指示 Agent 先驗證文件：

```markdown
## 實作前

搜尋 `microsoft-docs` MCP 以取得目前 API 模式：

- 查詢："[SDK name] [operation] python"
- 驗證：參數是否符合你安裝的 SDK 版本
```

### 3. 自由度

具體程度應與任務脆弱性相符：

| 自由度 | 何時使用 | 範例 |
| --- | --- | --- |
| **高** | 有多種可行做法時 | 文字指引 |
| **中** | 有偏好的模式但仍有變化時 | 虛擬碼 |
| **低** | 必須完全準確時 | 特定腳本 |

### 4. 漸進式揭露

技能分成三層載入：

1. **中繼資料**（約 100 字）— 永遠保留在 context 中
2. **SKILL.md 本文**（少於 5k 字）— 技能觸發時載入
3. **參考資料**（不限長度）— 視需要載入

**請將 `SKILL.md` 控制在 500 行以下。** 接近上限時，請拆分成 reference 檔案。

---

## 技能結構

```
skill-name/
├── SKILL.md（必要）
│   ├── YAML frontmatter（名稱、描述）
│   └── Markdown 指令
└── 隨附資源（選填）
    ├── scripts/      — 可執行程式碼
    ├── references/   — 依需求載入的文件
    └── assets/       — 輸出資源（範本、圖片）
```

### SKILL.md

- **Frontmatter**：`name` 與 `description`。`description` 就是觸發機制。
- **內文（Body）**：僅在技能觸發後才會載入的指令。

### 隨附資源

| 類型 | 用途 | 何時納入 |
| --- | --- | --- |
| `scripts/` | 決定性操作 | 同一段程式碼會被一再撰寫時 |
| `references/` | 詳細模式 | API 文件、架構說明、進階指南 |
| `assets/` | 輸出資源 | 範本、圖片、樣板 |

**不要包含：** `README.md`、`CHANGELOG.md`、安裝指南。

---

## 建立 Azure SDK 技能

建立 Azure SDK 技能時，請一致遵循以下模式。

### 技能章節順序

請採用下列結構（以既有 Azure SDK 技能為基礎）：

1. **標題** — `# SDK 名稱`
2. **安裝** — `pip install`、`npm install` 等
3. **環境變數** — 必要設定
4. **驗證** — 一律使用 `DefaultAzureCredential`
5. **核心流程** — 最小可行範例
6. **功能清單** — 用戶端、方法、工具
7. **最佳實務** — 編號清單
8. **參考連結** — 連到 `/references/*.md` 的表格

### 驗證模式（所有語言）

一律使用 `DefaultAzureCredential`：

```python
# Python
from azure.identity import DefaultAzureCredential
credential = DefaultAzureCredential()
client = ServiceClient(endpoint, credential)
```

**絕對不要硬編碼憑證。請使用環境變數。**

### 標準動詞模式

Azure SDK 在所有語言中都傾向使用一致的動詞：

| 動詞 | 行為 |
| --- | --- |
| `create` | 建立新項目；若已存在則失敗 |
| `upsert` | 建立或更新 |
| `get` | 取得資料；若不存在則報錯 |
| `list` | 回傳集合 |
| `delete` | 即使不存在也視為成功 |
| `begin` | 啟動長時間執行的作業 |

### 各語言模式

請參閱 `references/azure-sdk-patterns.md` 以取得詳細模式，包括：

- **Python**：`ItemPaged`、`LROPoller`、context managers、Sphinx docstrings
- **.NET**：`Response<T>`、`Pageable<T>`、`Operation<T>`、mocking support
- **Java**：Builder pattern、`PagedIterable`/`PagedFlux`、Reactor types
- **TypeScript**：`PagedAsyncIterableIterator`、`AbortSignal`、browser considerations

### 範例：Azure SDK 技能結構

```markdown
---
name: skill-creator
description: |
  Python 版 Azure AI Example SDK。用於 [特定服務功能]。
  觸發詞："example service", "create example", "list examples"。
---

# Azure AI 範例 SDK

## 安裝

\`\`\`bash
pip install azure-ai-example
\`\`\`

## 環境變數

\`\`\`bash
AZURE_EXAMPLE_ENDPOINT=https://<resource>.example.azure.com
\`\`\`

## 驗證

\`\`\`python
from azure.identity import DefaultAzureCredential
from azure.ai.example import ExampleClient

credential = DefaultAzureCredential()
client = ExampleClient(
endpoint=os.environ["AZURE_EXAMPLE_ENDPOINT"],
credential=credential
)
\`\`\`

## 核心流程

\`\`\`python

# 建立

item = client.create_item(name="example", data={...})

# 列出（自動處理分頁）

for item in client.list_items():
print(item.name)

# 長時間執行的作業

poller = client.begin_process(item_id)
result = poller.result()

# 清理

client.delete_item(item_id)
\`\`\`

## 參考檔案

| 檔案 | 內容 |
| --- | --- |
| [references/tools.md](references/tools.md) | Tool 整合 |
| [references/streaming.md](references/streaming.md) | 事件串流模式 |
```

---

## 技能建立流程

1. **理解** — 收集具體使用範例
2. **規劃** — 找出可重複使用的資源
3. **初始化** — 執行 `init_skill.py`
4. **實作** — 建立資源並撰寫 `SKILL.md`
5. **打包** — 執行 `package_skill.py`
6. **迭代** — 根據實際使用情況持續優化

### 步驟 1：理解技能

先收集具體範例：

- 「這個技能應涵蓋哪些 SDK 操作？」
- 「哪些觸發詞應啟動這個技能？」
- 「開發者最常遇到哪些錯誤？」

### 步驟 2：規劃可重複使用的內容

| 範例任務 | 可重複使用的資源 |
| --- | --- |
| 每次都一樣的 auth 程式碼 | 放在 `SKILL.md` 中的程式碼範例 |
| 複雜的串流模式 | `references/streaming.md` |
| 工具設定 | `references/tools.md` |
| 錯誤處理模式 | `references/error-handling.md` |

### 步驟 3：初始化

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

### 步驟 4：實作

**針對 Azure SDK 技能：**

1. 搜尋 `microsoft-docs` MCP 以取得目前 API 模式
2. 驗證你安裝的 SDK 版本
3. 遵循前述章節順序
4. 在範例中加入清理程式碼
5. 補上功能比較表

**請先撰寫隨附資源，再撰寫 `SKILL.md`。**

**Frontmatter：**

```yaml
---
name: skill-creator
description: |
  說明技能做什麼，以及何時使用。
  包含觸發語句：「在 [情境] 時使用」。
---
```

### 步驟 5：打包

```bash
scripts/package_skill.py <path/to/skill-folder>
```

### 步驟 6：迭代

實際使用後，找出 Agent 容易卡住的地方，並據此更新內容。

---

## 漸進式揭露模式

### 模式 1：高階指南搭配參考檔案

```markdown
# SDK 名稱

## 快速開始

[最小可行範例]

## 進階功能

- **Streaming**：請參閱 [references/streaming.md](references/streaming.md)
- **Tools**：請參閱 [references/tools.md](references/tools.md)
```

### 模式 2：依語言拆分

```
azure-service-skill/
├── SKILL.md（總覽 + 語言選擇）
└── references/
    ├── python.md
    ├── dotnet.md
    ├── java.md
    └── typescript.md
```

### 模式 3：依功能組織

```
azure-ai-agents/
├── SKILL.md（核心流程）
└── references/
    ├── tools.md
    ├── streaming.md
    ├── async-patterns.md
    └── error-handling.md
```

---

## 設計模式參考

| 參考 | 內容 |
| --- | --- |
| `references/workflows.md` | 順序式與條件式工作流程 |
| `references/output-patterns.md` | 範本與範例 |
| `references/azure-sdk-patterns.md` | 各語言的 Azure SDK 模式 |

---

## 反模式

| 不要這樣做 | 原因 |
| --- | --- |
| 將「何時使用」寫在內文裡 | 內文只有在觸發後才會載入 |
| 硬編碼憑證 | 會造成安全風險 |
| 省略驗證章節 | Agent 容易自行臆測實作方式 |
| 使用過時的 SDK 模式 | API 會變動；請先查文件 |
| 納入 `README.md` | Agent 不需要 meta-docs |
| 使用深層巢狀的 references | 盡量維持一層深度 |

---

## 檢查清單

在打包技能之前，請確認：

- [ ] `description` 已說明技能做什麼以及何時使用（含觸發語句）
- [ ] `SKILL.md` 少於 500 行
- [ ] 驗證採用 `DefaultAzureCredential`
- [ ] 範例中包含清理 / 刪除流程
- [ ] 參考資料依功能組織
- [ ] 沒有重複內容
- [ ] 已指示搜尋 `microsoft-docs` MCP 以取得目前 API
- [ ] 所有腳本都已測試


