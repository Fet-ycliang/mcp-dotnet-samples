---
name: azdo-sprint-planner
description: |
  Azure DevOps Sprint 規劃助手。自動化工作項目創建、Epic 拆解、容量規劃。
  觸發詞: "規劃 sprint", "創建工作項目", "拆解 epic", "generate work items", "sprint planning", "capacity planning"
---

# Azure DevOps Sprint Planner

自動化 Sprint 規劃工作流程，包含工作項目創建、Epic 拆解、任務估算和容量規劃。

## 核心功能

### 1. Epic 拆解為 Work Items

將大型 Epic 拆解為結構化的 Product Backlog Items (PBIs) 和 Tasks。

**基本工作流程：**

```python
# 範例：Epic 拆解
# 需使用的 MCP 工具：
# - mcp_microsoft_azu_wit_get_work_item
# - mcp_microsoft_azu_wit_create_work_item
# - mcp_microsoft_azu_wit_add_child_work_items
# - mcp_microsoft_azu_wit_work_items_link

async def breakdown_epic_to_user_stories(
    project,
    epic_id,
    breakdown_criteria="feature"
):
    """
    將 Epic 拆解為 User Stories 和 Tasks
    
    Args:
        project: 專案名稱
        epic_id: Epic 的 work item ID
        breakdown_criteria: 拆解標準（feature, module, user-role）
    
    Returns:
        創建的 work items 列表
    """
    # 1. 取得 Epic 詳細資訊
    epic = get_work_item(project, epic_id)
    epic_title = epic.fields['System.Title']
    epic_description = epic.fields.get('System.Description', '')
    
    # 2. 分析 Epic 並設計拆解結構
    breakdown_structure = analyze_and_design_breakdown(
        epic_title, 
        epic_description,
        breakdown_criteria
    )
    
    # 3. 批次創建 Product Backlog Items (User Stories)
    created_pbis = []
    for pbi_spec in breakdown_structure['pbis']:
        pbi = create_work_item(
            project,
            work_item_type="Product Backlog Item",
            title=pbi_spec['title'],
            description=pbi_spec['description'],
            acceptance_criteria=pbi_spec['acceptance_criteria'],
            tags=pbi_spec.get('tags', [])
        )
        
        # 連結到 Epic
        link_work_items(
            pbi.id, 
            epic_id, 
            link_type="System.LinkTypes.Hierarchy-Reverse"
        )
        
        # 4. 為每個 PBI 創建 Tasks
        for task_spec in pbi_spec['tasks']:
            task = create_work_item(
                project,
                work_item_type="Task",
                title=task_spec['title'],
                description=task_spec['description'],
                estimated_hours=task_spec.get('estimated_hours', 0)
            )
            
            # 連結到 PBI
            link_work_items(
                task.id,
                pbi.id,
                link_type="System.LinkTypes.Hierarchy-Reverse"
            )
        
        created_pbis.append(pbi)
    
    return {
        "epic": epic,
        "pbis": created_pbis,
        "summary": generate_breakdown_summary(created_pbis)
    }
```

**拆解範例：**

```
Epic: 會員管理系統
├── PBI-1: 會員註冊功能
│   ├── Task-1.1: 設計註冊表單 UI (4h)
│   ├── Task-1.2: 實作後端 API (8h)
│   ├── Task-1.3: 整合郵件驗證 (4h)
│   └── Task-1.4: 撰寫單元測試 (4h)
├── PBI-2: 會員登入功能
│   ├── Task-2.1: 實作登入 UI (3h)
│   ├── Task-2.2: 實作認證 API (6h)
│   ├── Task-2.3: 整合 OAuth (8h)
│   └── Task-2.4: 安全性測試 (4h)
└── PBI-3: 會員資料管理
    ├── Task-3.1: 個人資料編輯頁面 (6h)
    ├── Task-3.2: 資料驗證邏輯 (4h)
    └── Task-3.3: 資料庫 schema 更新 (3h)
```

### 2. 批次創建工作項目

使用範本快速創建標準化的工作項目。

**工作流程：**

```python
# 範例：批次創建工作項目
# 需使用的 MCP 工具：
# - mcp_microsoft_azu_wit_create_work_item
# - mcp_microsoft_azu_wit_update_work_items_batch

async def batch_create_work_items(
    project,
    template_name,
    base_data,
    quantity=1
):
    """
    使用範本批次創建工作項目
    
    Args:
        project: 專案名稱
        template_name: 範本名稱（如：'feature-template', 'bug-template'）
        base_data: 基礎資料（標題、描述等）
        quantity: 創建數量
    
    Returns:
        創建的 work items 列表
    """
    # 1. 載入範本
    template = load_template(template_name)
    
    # 2. 批次創建
    created_items = []
    for i in range(quantity):
        # 合併範本和基礎資料
        work_item_data = merge_template_data(template, base_data, index=i)
        
        # 創建 work item
        work_item = create_work_item(
            project,
            work_item_type=template['type'],
            **work_item_data
        )
        
        created_items.append(work_item)
    
    return created_items
```

**常用範本：**

| 範本名稱 | 用途 | 包含欄位 |
|---------|------|---------|
| `feature-template` | 新功能開發 | Title, Description, Acceptance Criteria, Tags |
| `bug-template` | Bug 修復 | Title, Repro Steps, Expected/Actual Result, Severity |
| `task-template` | 一般任務 | Title, Description, Estimated Hours |
| `spike-template` | 技術調研 | Title, Research Goal, Time Box, Findings |
| `test-case-template` | 測試案例 | Title, Test Steps, Expected Result |

### 3. Sprint 容量規劃

根據團隊容量和速度規劃 Sprint。

**工作流程：**

```python
# 範例：Sprint 容量規劃
# 需使用的 MCP 工具：
# - mcp_microsoft_azu_work_get_team_capacity
# - mcp_microsoft_azu_work_list_iterations
# - mcp_microsoft_azu_wit_list_backlog_work_items

async def plan_sprint_capacity(
    project,
    team,
    iteration_path,
    target_velocity=None
):
    """
    執行 Sprint 容量規劃
    
    Args:
        project: 專案名稱
        team: 團隊名稱
        iteration_path: 迭代路徑
        target_velocity: 目標速度（Story Points）
    
    Returns:
        規劃建議
    """
    # 1. 取得團隊容量
    team_capacity = get_team_capacity(project, team, iteration_path)
    
    # 2. 計算可用工時
    total_capacity = sum(
        member['capacity_per_day'] * member['days_off']
        for member in team_capacity
    )
    
    # 3. 根據歷史速度估算
    if not target_velocity:
        historical_velocity = calculate_historical_velocity(project, team)
        target_velocity = historical_velocity['average']
    
    # 4. 取得 Backlog
    backlog_items = list_backlog_work_items(project, team)
    
    # 5. 根據優先級和估算選擇項目
    selected_items = select_items_for_sprint(
        backlog_items,
        target_velocity,
        total_capacity
    )
    
    # 6. 生成規劃報告
    plan = {
        "iteration": iteration_path,
        "team_capacity": {
            "total_hours": total_capacity,
            "members": len(team_capacity),
            "avg_per_member": total_capacity / len(team_capacity)
        },
        "target_velocity": target_velocity,
        "selected_items": selected_items,
        "estimated_completion": calculate_completion_probability(
            selected_items, 
            total_capacity
        ),
        "recommendations": generate_planning_recommendations(
            selected_items,
            total_capacity,
            target_velocity
        )
    }
    
    return format_capacity_plan(plan)
```

**容量規劃報告範例：**

```markdown
# Sprint 10 容量規劃

## 團隊容量
- **總工時**: 320 小時
- **團隊人數**: 5 人
- **平均每人**: 64 小時
- **Sprint 時長**: 2 週

## 目標速度
- **目標 Story Points**: 25
- **歷史平均速度**: 23 points
- **信心水平**: 85%

## 建議納入項目
1. [PBI #12345] 會員登入功能 - 8 points (32 hours)
2. [PBI #12346] 訂單查詢優化 - 5 points (20 hours)
3. [PBI #12347] 報表匯出功能 - 8 points (32 hours)
4. [Bug #12348] 修復支付流程 - 3 points (12 hours)
5. [PBI #12349] API 文檔更新 - 2 points (8 hours)

**總計**: 26 points, 104 hours

## 風險評估
⚠️ **警告**: 估算工時 (104h) 低於總容量 (320h)
建議: 保留緩衝時間處理突發問題和會議
```

### 4. 工作項目依賴管理

識別和管理工作項目之間的依賴關係。

**工作流程：**

```python
# 範例：依賴管理
# 需使用的 MCP 工具：
# - mcp_microsoft_azu_wit_get_work_item
# - mcp_microsoft_azu_wit_work_items_link

async def manage_work_item_dependencies(
    project,
    work_item_ids,
    auto_link=True
):
    """
    分析和管理工作項目的依賴關係
    
    Args:
        project: 專案名稱
        work_item_ids: 工作項目 ID 列表
        auto_link: 是否自動建立依賴連結
    
    Returns:
        依賴關係圖
    """
    # 1. 取得所有 work items
    work_items = get_work_items_batch(project, work_item_ids)
    
    # 2. 分析依賴關係
    dependencies = analyze_dependencies(work_items)
    
    # 3. 識別關鍵路徑
    critical_path = find_critical_path(dependencies)
    
    # 4. 檢測循環依賴
    circular_deps = detect_circular_dependencies(dependencies)
    
    # 5. 自動建立連結（如啟用）
    if auto_link and not circular_deps:
        for dep in dependencies:
            link_work_items(
                dep['source_id'],
                dep['target_id'],
                link_type="System.LinkTypes.Dependency-Forward"
            )
    
    return {
        "dependencies": dependencies,
        "critical_path": critical_path,
        "circular_dependencies": circular_deps,
        "visualization": generate_dependency_graph(dependencies)
    }
```

### 5. Sprint 目標設定

為 Sprint 設定明確且可衡量的目標。

**目標範本：**

```markdown
# Sprint {number} 目標

## 主要目標
{描述本 Sprint 要達成的主要業務目標}

## 關鍵成果 (Key Results)
1. {可衡量的結果 1}
2. {可衡量的結果 2}
3. {可衡量的結果 3}

## 成功指標
- [ ] {指標 1}: {目標值}
- [ ] {指標 2}: {目標值}
- [ ] {指標 3}: {目標值}

## 範圍
### 包含在內
- {項目 1}
- {項目 2}

### 不包含
- {項目 1}
- {項目 2}

## 風險與依賴
- {風險或依賴項目}
```

## 工作項目範本庫

### Feature 範本

```json
{
  "type": "Product Backlog Item",
  "fields": {
    "System.Title": "[功能名稱]",
    "System.Description": "**使用者故事**: 身為 [角色]，我想要 [功能]，以便 [價值]\n\n**背景**: [為什麼需要此功能]\n\n**範圍**: [功能範圍說明]",
    "Microsoft.VSTS.Common.AcceptanceCriteria": "- [ ] 條件 1\n- [ ] 條件 2\n- [ ] 條件 3",
    "Microsoft.VSTS.Scheduling.StoryPoints": 5,
    "System.Tags": "feature; sprint-{number}"
  }
}
```

### Bug 範本

```json
{
  "type": "Bug",
  "fields": {
    "System.Title": "[簡短描述問題]",
    "Microsoft.VSTS.TCM.ReproSteps": "**重現步驟**:\n1. 步驟 1\n2. 步驟 2\n3. 步驟 3",
    "Microsoft.VSTS.Common.ExpectedResult": "[預期結果]",
    "Microsoft.VSTS.Common.ActualResult": "[實際結果]",
    "Microsoft.VSTS.Common.Severity": "3 - Medium",
    "Microsoft.VSTS.Common.Priority": 2,
    "System.Tags": "bug; need-triage"
  }
}
```

### Task 範本

```json
{
  "type": "Task",
  "fields": {
    "System.Title": "[任務描述]",
    "System.Description": "**目標**: [任務目標]\n\n**步驟**:\n1. 步驟 1\n2. 步驟 2\n\n**完成定義**: [如何判斷任務完成]",
    "Microsoft.VSTS.Scheduling.RemainingWork": 8,
    "System.Tags": "task"
  }
}
```

## 最佳實踐

1. **適當粒度** - PBI 應該在 1-2 個 Sprint 內完成，Task 應該在 1-2 天內完成
2. **INVEST 原則** - User Stories 應該是 Independent, Negotiable, Valuable, Estimable, Small, Testable
3. **接受標準** - 每個 PBI 都應該有明確的接受標準
4. **估算一致性** - 使用 Planning Poker 確保團隊對估算的共識
5. **容量緩衝** - 保留 20-30% 的容量處理突發問題
6. **依賴管理** - 優先處理有依賴關係的項目
7. **定期回顧** - 每個 Sprint 結束後回顧和調整估算
8. **範本標準化** - 使用標準範本確保一致性
9. **標籤管理** - 使用標籤便於篩選和報告
10. **持續優化** - 根據實際執行情況持續優化規劃流程

## 參考文件

| 文件 | 內容 |
|------|------|
| [references/work-item-templates.md](references/work-item-templates.md) | 完整的工作項目範本集合 |
| [references/estimation-guide.md](references/estimation-guide.md) | 工作估算指南和技巧 |
| [references/capacity-planning.md](references/capacity-planning.md) | 容量規劃詳細方法 |

## 使用範例

### 範例 1：拆解新功能 Epic

```plaintext
User: 我有一個 Epic #12345 "電商結帳系統"，請幫我拆解成 User Stories

Agent 執行流程：
1. 取得 Epic 詳細資訊
2. 分析功能範圍
3. 設計拆解結構（購物車、結帳流程、付款整合、訂單管理）
4. 創建 4 個 PBIs，每個包含 3-5 個 Tasks
5. 建立階層連結
6. 提供初步估算建議
7. 生成拆解摘要報告
```

### 範例 2：規劃下一個 Sprint

```plaintext
User: 幫我規劃 Sprint 15，團隊有 6 個人

Agent 執行流程：
1. 取得團隊容量資訊
2. 計算可用工時和目標速度
3. 從 Backlog 選擇優先級高的項目
4. 檢查工時和速度是否匹配
5. 識別依賴關係
6. 生成 Sprint 規劃建議
7. 提供風險評估
```

### 範例 3：批次創建測試任務

```plaintext
User: 為 PBI #12346 創建完整的測試任務

Agent 執行流程：
1. 取得 PBI 資訊
2. 使用測試任務範本
3. 創建多個測試任務：
   - 單元測試撰寫
   - 整合測試
   - UI 測試
   - 效能測試
   - 安全性測試
4. 估算每個任務的工時
5. 連結到 PBI
6. 返回創建的任務列表
```

### 範例 4：分析 Sprint 容量

```plaintext
User: 分析 Sprint 15 的容量使用情況

Agent 執行流程：
1. 取得 Sprint 中的所有 work items
2. 計算已分配的 Story Points 和工時
3. 對比團隊容量
4. 識別過度分配或分配不足
5. 提供調整建議
6. 生成視覺化報告
```

## 自動化建議

- **週期性任務** - 自動創建每個 Sprint 的標準任務（code review, testing, documentation）
- **估算提醒** - 對未估算的 work items 自動提醒
- **容量警報** - 當 Sprint 分配超過容量時發送警報
- **依賴檢查** - 在 Sprint Planning 時自動檢查依賴關係
- **範本更新** - 根據團隊反饋定期更新範本
- **回溯數據** - 自動收集速度和準確度數據用於改進估算

## 整合建議

- **與 Calendar 整合** - 考慮假期和會議時間
- **與 Capacity API 整合** - 自動同步團隊容量數據
- **與 Analytics 整合** - 使用歷史數據改進估算
- **與 Git 整合** - 從 commits 自動更新任務進度
- **與 Teams/Slack 整合** - Sprint Planning 完成後自動通知團隊
