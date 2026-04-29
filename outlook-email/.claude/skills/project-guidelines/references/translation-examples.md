# 程式碼繁中化前後對照

## Python 函式（完整範例）

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

---

## TypeScript 函式（完整範例）

### 前

```typescript
// Provide EventSource polyfill for Node.js
global.EventSource = EventSource;

/**
 * Get all available skills
 *
 * @returns Object containing tools and prompts
 * @throws Error when connection fails
 */
export async function getSkills() {
  // Fetch Tools and Prompts in parallel
  const [tools, prompts] = await Promise.all([
    client.listTools(),
    client.listPrompts(),
  ]);
}
```

### 後

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

---

## Dockerfile 註解

### 前

```dockerfile
# Stage 1: Build stage using UV
FROM python:3.12-slim AS builder

# Install UV
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files and create virtual environment
COPY pyproject.toml README.md ./
RUN uv pip install --system --no-cache .
```

### 後

```dockerfile
# 階段 1：使用 UV 的建置階段
FROM python:3.12-slim AS builder

# 安裝 UV
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 複製依賴檔案並建立虛擬環境
COPY pyproject.toml README.md ./
RUN uv pip install --system --no-cache .
```

---

## 常見識別子保留規則

```python
# ✅ 正確 — 只翻譯註解，保留識別子
def load_skills(skills_dir: str = "skills"):
    """載入指定目錄下的技能"""

DEFAULT_TIMEOUT_MINUTES = 20  # 預設逾時時間（分鐘）

# ❌ 錯誤 — 不要翻譯函式名稱或變數名稱
def 載入技能(技能目錄: str = "skills"):
    pass

預設逾時分鐘數 = 20
```
