# Pipeline 告警規則設定

## 告警規則範例

```python
ALERT_RULES = {
    "build_failure": {
        "condition": "consecutive_failures >= 3",
        "action": "notify_team",
        "severity": "high"
    },
    "long_duration": {
        "condition": "duration > avg_duration * 2",
        "action": "notify_owner",
        "severity": "medium"
    },
    "low_success_rate": {
        "condition": "success_rate_24h < 0.7",
        "action": "notify_leads",
        "severity": "high"
    },
    "deployment_failure": {
        "condition": "deployment_failed AND environment == 'production'",
        "action": "notify_oncall",
        "severity": "critical"
    }
}
```

## 監控儀表板範本

### 即時狀態面板

```markdown
# Pipeline 即時狀態

## 🔴 失敗的建置
- [Build #12345] main - feat/login-api (失敗於測試階段)
- [Build #12344] develop - fix/payment-bug (編譯錯誤)

## 🔵 進行中的建置
- [Build #12346] main - release/v2.1.0 (部署階段 - 3/5)
- [Build #12347] develop - chore/update-deps (測試階段 - 2/3)

## ✅ 最近成功
- [Build #12343] main - feat/dashboard (25 分鐘前)

## 📊 今日統計
- 總建置數: 47
- 成功率: 85% (40/47)
- 平均時長: 12.5 分鐘
```

### 趨勢分析（最近 7 天）

```
成功率趨勢：
Day 1: ████████░░ 80%
Day 2: ██████████ 100%
Day 3: █████████░ 90%

每日建置數：
Day 1: ████████████████ 48
Day 2: ███████████ 35
```
