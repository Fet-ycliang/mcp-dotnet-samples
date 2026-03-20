---
name: skill-creator
description: 建立 Agent Skills 的指引，特別是針對 Azure SDK 和 Microsoft Foundry 服務。在建立新技能或更新現有技能時使用。
---

# Skill Creator

建立技能以擴充 Agent 能力的指引，重點在於 Azure SDK 和 Microsoft Foundry。

## 關於技能 (About Skills)

技能是模組化的知識套件，將通用 Agent 轉變為專門的專家：

1. **程序性知識** — 特定領域的多步驟工作流程
2. **SDK 專業知識** — Azure 服務的 API 模式、身份驗證、錯誤處理
3. **領域 Context** — 架構、業務邏輯、公司特定模式
4. **隨附資源** — 用於複雜任務的腳本、參考資料、範本

---

## 核心原則

### 1. 簡潔為要 (Concise is Key)

Context window 是共享資源。質疑每一部分：「這值得它的 token 成本嗎？」

**預設假設：Agent 已經有能力了。** 只新增它們不知道的內容。

### 2. 新文件優先 (Fresh Documentation First)

**Azure SDK 經常變更。** 技能應指示 Agent 驗證文件：

```markdown
## 實作前

搜尋 `microsoft-docs` MCP 以取得目前 API 模式：

- 查詢："[SDK name] [operation] python"
- 驗證：參數符合你安裝的 SDK 版本
```

### 3. 自由度 (Degrees of Freedom)

將具體性與任務脆弱性相匹配：

| 自由度     | 何時使用                         | 範例             |
| ---------- | -------------------------------- | ---------------- |
| **高**     | 多種有效方法                     | 文字指引         |
| **中**     | 帶有變化的首選模式               | 虛擬碼 (Pseudocode) |
| **低**     | 必須完全準確                     | 特定腳本         |

### 4. 漸進式揭露 (Progressive Disclosure)

技能分三層載入：

1. **中繼資料** (~100 字) — 始終在 context 中
2. **SKILL.md 本文** (<5k 字) — 當技能觸發時
3. **參考資料** (無限制) — 依需求

**保持 SKILL.md 在 500 行以下。** 當接近此限制時拆分為參考檔案。

---

## 技能結構

```
skill-name/
├── SKILL.md (必要)
│   ├── YAML frontmatter (名稱, 描述)
│   └── Markdown 指令
└── Bundled Resources (選填)
    ├── scripts/      — 可執行程式碼
    ├── references/   — 依需求載入的文件
    └── assets/       — 輸出資源 (範本, 圖片)
```

### SKILL.md

- **Frontmatter**: `name` 和 `description`。描述是觸發機制。
- **Body**: 僅在觸發後載入的指令。

### 隨附資源 (Bundled Resources)

| 類型          | 用途                     | 何時包含                           |
| ------------- | ------------------------ | ---------------------------------- |
| `scripts/`    | 確定性操作               | 相同的程式碼被重複編寫             |
| `references/` | 詳細模式                 | API 文件、架構、詳細指南           |
| `assets/`     | 輸出資源                 | 範本、圖片、樣板                   |

**不要包含**：README.md, CHANGELOG.md, 安裝指南。

---

## 建立 Azure SDK 技能

建立 Azure SDK 技能時，請一致地遵循這些模式。

### 技能章節順序

遵循此結構 (基於現有的 Azure SDK 技能)：

1. **標題** — `# SDK Name`
2. **安裝** — `pip install`, `npm install` 等
3. **環境變數** — 必要的設定
4. **身份驗證** — 總是 `DefaultAzureCredential`
5. **核心工作流程** — 最小可行範例
6. **功能表** — 用戶端、方法、工具
7. **最佳實踐** — 編號列表
8. **參考連結** — 連結到 `/references/*.md` 的表格

### 身份驗證模式 (所有語言)

總是使用 `DefaultAzureCredential`：

```python
# Python
from azure.identity import DefaultAzureCredential
credential = DefaultAzureCredential()
client = ServiceClient(endpoint, credential)
```

**絕不硬編碼憑證。使用環境變數。**

### 標準動詞模式

Azure SDK 在所有語言中使用一致的動詞：

| 動詞     | 行為                         |
| -------- | ---------------------------- |
| `create` | 建立新項目；若存在則失敗     |
| `upsert` | 建立或更新                   |
| `get`    | 檢索；若遺失則錯誤           |
| `list`   | 回傳集合                     |
| `delete` | 即使遺失也成功               |
| `begin`  | 開始長時間運行的操作         |

### 語言特定模式

請參閱 `references/azure-sdk-patterns.md` 以取得詳細模式，包括：

- **Python**: `ItemPaged`, `LROPoller`, context managers, Sphinx docstrings
- **.NET**: `Response<T>`, `Pageable<T>`, `Operation<T>`, mocking support
- **Java**: Builder pattern, `PagedIterable`/`PagedFlux`, Reactor types
- **TypeScript**: `PagedAsyncIterableIterator`, `AbortSignal`, browser considerations

### 範例：Azure SDK 技能結構

```markdown
---
name: skill-creator
description: |
  Azure AI Example SDK for Python. Use for [specific service features].
  Triggers: "example service", "create example", "list examples".
---

# Azure AI Example SDK

## Installation

\`\`\`bash
pip install azure-ai-example
\`\`\`

## Environment Variables

\`\`\`bash
AZURE_EXAMPLE_ENDPOINT=https://<resource>.example.azure.com
\`\`\`

## Authentication

\`\`\`python
from azure.identity import DefaultAzureCredential
from azure.ai.example import ExampleClient

credential = DefaultAzureCredential()
client = ExampleClient(
endpoint=os.environ["AZURE_EXAMPLE_ENDPOINT"],
credential=credential
)
\`\`\`

## Core Workflow

\`\`\`python

# Create

item = client.create_item(name="example", data={...})

# List (pagination handled automatically)

for item in client.list_items():
print(item.name)

# Long-running operation

poller = client.begin_process(item_id)
result = poller.result()

# Cleanup

client.delete_item(item_id)
\`\`\`

## Reference Files

| File                                               | Contents                 |
| -------------------------------------------------- | ------------------------ |
| [references/tools.md](references/tools.md)         | Tool integrations        |
| [references/streaming.md](references/streaming.md) | Event streaming patterns |
```

---

## 技能建立流程

1. **理解** — 收集具體使用範例
2. **規劃** — 識別可重複使用的資源
3. **初始化** — 執行 `init_skill.py`
4. **實作** — 建立資源，撰寫 SKILL.md
5. **打包** — 執行 `package_skill.py`
6. **迭代** — 根據實際使用進行優化

### 步驟 1：理解技能

收集具體範例：

- "此技能應涵蓋哪些 SDK 操作？"
- "哪些觸發器應啟動此技能？"
- "開發者通常會遇到什麼錯誤？"

### 步驟 2：規劃可重複使用的內容

| 範例任務                   | 可重複使用的資源               |
| -------------------------- | ------------------------------ |
| 每次都相同的 auth 程式碼   | SKILL.md 中的程式碼範例        |
| 複雜的串流模式             | `references/streaming.md`      |
| 工具設定                   | `references/tools.md`          |
| 錯誤處理模式               | `references/error-handling.md` |

### 步驟 3：初始化

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

### 步驟 4：實作

**對於 Azure SDK 技能：**

1. 搜尋 `microsoft-docs` MCP 以取得目前 API 模式
2. 驗證已安裝的 SDK 版本
3. 遵循上述的章節順序
4. 在範例中包含清理程式碼
5. 新增功能比較表

**先撰寫隨附資源**，然後是 SKILL.md。

**Frontmatter:**

```yaml
---
name: skill-creator
description: |
  What the skill does AND when to use it.
  Include trigger phrases: "Use when [scenario]".
---
```

### 步驟 5：打包

```bash
scripts/package_skill.py <path/to/skill-folder>
```

### 步驟 6：迭代

在實際使用後，識別 Agent 掙扎的地方並相應更新。

---

## 漸進式揭露模式

### 模式 1：帶有參考的高階指南

```markdown
# SDK Name

## Quick Start

[Minimal example]

## Advanced Features

- **Streaming**: See [references/streaming.md](references/streaming.md)
- **Tools**: See [references/tools.md](references/tools.md)
```

### 模式 2：語言變體

```
azure-service-skill/
├── SKILL.md (overview + language selection)
└── references/
    ├── python.md
    ├── dotnet.md
    ├── java.md
    └── typescript.md
```

### 模式 3：功能組織

```
azure-ai-agents/
├── SKILL.md (core workflow)
└── references/
    ├── tools.md
    ├── streaming.md
    ├── async-patterns.md
    └── error-handling.md
```

---

## 設計模式參考

| 參考                               | 內容                                 |
| ---------------------------------- | ------------------------------------ |
| `references/workflows.md`          | 順序和條件工作流程                   |
| `references/output-patterns.md`    | 範本和範例                           |
| `references/azure-sdk-patterns.md` | 語言特定的 Azure SDK 模式            |

---

## 反模式 (Anti-Patterns)

| 不要 (Don't)                | 為什麼 (Why)                   |
| --------------------------- | ------------------------------ |
| 將「何時使用」放在內文中    | 內文在觸發後才會載入           |
| 硬編碼憑證                  | 安全風險                       |
| 跳過身份驗證章節            | Agent 會拙劣地即興發揮         |
| 使用過時的 SDK 模式         | API 會變更；先搜尋文件         |
| 包含 README.md              | Agent 不需要 meta-docs         |
| 深層嵌套參考                | 保持一層深度                   |

---

## 檢查清單

在打包技能之前：

- [ ] 描述包含什麼以及何時使用 (觸發語句)
- [ ] SKILL.md 在 500 行以下
- [ ] 身份驗證使用 `DefaultAzureCredential`
- [ ] 範例中包含清理/刪除
- [ ] 參考資料按功能組織
- [ ] 沒有重複內容
- [ ] 指示搜尋 `microsoft-docs` MCP 以取得目前 API
- [ ] 所有腳本已測試
