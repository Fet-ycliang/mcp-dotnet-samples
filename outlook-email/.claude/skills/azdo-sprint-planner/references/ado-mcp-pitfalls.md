# ADO MCP 實戰踩坑筆記

以下為實際操作中踩過的坑。

## 坑 1：`wit_add_child_work_items` 觸發 403（Area Path 不繼承）

**症狀**：`TF237111: The work item does not have permissions to save work items under the specified area path`

**根因**：此工具不會從父工項繼承 area path，會以 ADO 帳號的預設根路徑建立，若 team 設定的 area path 不在根路徑下就會 403。

**解法**：棄用此工具，改為：
1. `wit_create_work_item`（每筆帶 `System.AreaPath`）
2. `wit_work_items_link`（批次掛 parent）

**本專案的正確 AreaPath**：`FET-Delivery\\PJT-1375-DataOps-Assistant`

---

## 坑 2：描述含罕用字元觸發 JSON 解析失敗

**症狀**：`MCP error -32602: Input validation error: Expected array, received string`

**根因**：描述文字含罕用 Unicode 字元（如 `囬`），導致 MCP 工具的 JSON 序列化將整個 `fields` array 誤解為字串型別。

**解法**：
- 只使用 BMP 範圍的常見繁體中文字（U+0000–U+9FFF 以內）
- 若收到此錯誤，立刻檢查描述有無非常規字元並重新撰寫

---

## 坑 3：批次連結的正確語法

`wit_work_items_link` 接受 `updates` array，可在一次呼叫中連結多個 children 到同一個 parent：

```json
{
  "project": "FET-Delivery",
  "updates": [
    {"id": 159437, "linkToId": 159426, "type": "parent"},
    {"id": 159438, "linkToId": 159426, "type": "parent"},
    {"id": 159439, "linkToId": 159426, "type": "parent"}
  ]
}
```

每筆回傳 `code: 200` 表示成功。若全批次只有部分成功，會回傳混合的 200/4xx。

---

## 坑 4：描述欄位格式（HTML vs Markdown）

ADO 的 `System.Description` 欄位預設為 **HTML 格式**，有兩個常犯錯誤必須避免：

### 錯誤一：使用純文字 Markdown 語法

`##`、`- [x]`、反引號等 Markdown 符號在 ADO description 中**不會被渲染**，會原樣顯示。

### 錯誤二：把所有句子塞進單一 `<p>` 標籤

ADO 的 RTE 看到單一 `<p>` 不會自動換行，所有句子連成一牆文字。

### 正確寫法

**每個邏輯點獨立一個 `<p>` 標籤**，章節用 `<h3>`，條列用 `<ul>/<ol>`：

```html
<p>任務摘要說明。</p>
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

`Microsoft.VSTS.Common.AcceptanceCriteria` 同樣是 HTML 欄位，適用相同規則。

---

## 坑 5：`wit_get_work_items_batch_by_ids` 容易 timeout

**症狀**：`MCP error -32001: Request timed out`，無論批次大小（3 筆或 6 筆）都可能觸發。

**根因**：此工具走的是 ADO batch API，對 MCP bridge 來說偶爾因 server-side 延遲或網路抖動而逾時，且重試無法自動恢復。

**解法**：改用逐筆 `wit_get_work_item`（單一 ID），雖然來回次數多，但每筆 timeout 機率大幅降低；若要一次取多筆，先用 `wit_query_by_wiql` 撈 ID 清單，再逐筆展開。

**How to apply**：retro 或需要展示工作項目詳情時，**優先** `wit_get_work_item`，不要預設用 batch API。

---

## 坑 6：`wit_query_by_wiql` 帶過多欄位也會 timeout

**症狀**：`MCP error -32001: Request timed out`，即使只是一次 WIQL 查詢也可能觸發。

**根因**：SELECT 子句帶了 `[System.AssignedTo]` 等展開欄位，在 ADO MCP 尖峰時段會超時。

**解法**：只選必要欄位（`[System.Id]`、`[System.Title]`、`[System.State]`、`[System.WorkItemType]`）；精簡後通常一次重試即可成功。坑 5 建議的「先 WIQL 取 ID 清單」本身不能保證不 timeout，欄位精簡同樣適用。

**How to apply**：WIQL 查詢一律只選最少必要欄位，拿到 ID 後再視需要逐筆展開詳情。
