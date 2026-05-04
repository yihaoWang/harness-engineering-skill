# Mode: evaluate

對某產出（UI / code diff / 文件 / 翻譯 / ...）跑**獨立 evaluator sub-agent**，按 rubric 評分。

> 核心：主 agent（generator）不能自評（[[過早完成宣告]]）。evaluator **必須**是另一個 sub-agent，它沒有「想完成這件事」的動機，能更客觀挑問題。

純 LLM judgment，沒有 script。

## 步驟

1. **解析參數**：`/harness-evaluate <kind>` — `kind` ∈ `ui` / `code` / `writing` / `i18n` / 自訂。
2. **讀 config**：`cat .harness/config.json` → 找 `evaluators.<kind>`，拿 `rubric` 路徑與 `inputs` 規格。
   - 沒有該 kind → 建議 user 先在 config 加 evaluator 條目（範例見下）。
3. **讀 rubric**：`cat <rubric>`。沒有 → 用內建 default（見下）並提示 user 之後寫專屬 rubric。
4. **收集 inputs**（依 kind）：
   - `ui` — `git diff` 的 `.tsx/.vue/...` 檔 + screenshot 路徑（若有 playwright，跑一輪）
   - `code` — `git diff HEAD` + 變動檔列表
   - `writing` — 指定 md 檔內容
   - `i18n` — locale 檔 diff
5. **起獨立 sub-agent**（Task tool, `subagent_type=general-purpose`），prompt 含：
   - rubric 全文
   - inputs（diff / 檔案內容 / screenshot 路徑）
   - 強制要求：**逐維度評分 + 每分附證據（檔名:行號 或 圖片區塊）+ 結論 Accept / Revise / Block**
   - 禁止籠統評語（「看起來不錯」一律不接受）
6. **寫報告**：`.harness/evaluations/<kind>-<ts>.md`（rubric 表 + 結論 + 建議）。
7. Audit trail：印 kind / verdict / 報告路徑。

## config schema

```json
{
  "evaluators": {
    "ui":      {"rubric": ".harness/rubrics/ui.md",      "inputs": ["diff", "screenshots"]},
    "code":    {"rubric": ".harness/rubrics/code.md",    "inputs": ["diff"]},
    "writing": {"rubric": ".harness/rubrics/writing.md", "inputs": ["files"]}
  }
}
```

## 內建 default rubric（無自訂 rubric 時的最小標準）

- **ui**：視覺一致 / 對比度 WCAG / 響應式 / 互動回饋 / 資料邊界 / 排版精緻
- **code**：正確性 / 邊界處理 / 命名 / 重複 / 對既有 pattern 的吻合度 / 測試覆蓋
- **writing**：論點清晰 / 結構 / 證據 / 冗餘 / 受眾匹配

## 反模式

- ❌ 主 agent 自評（這是整個 mode 存在的理由）
- ❌ rubric 籠統（「看起來好不好」→ 評分無證據）
- ❌ evaluator 只給結論不給檔名:行號
- ❌ Accept/Revise/Block 三檔位混淆（要強制三選一）

## TODO

- `lib/screenshot.sh` Playwright wrapper（ui kind 用）
- evaluator 校準流程（per [[沒儀表板的 agent 重試靠猜]]）
