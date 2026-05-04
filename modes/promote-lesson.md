# Mode: promote-lesson

把一次教訓變成機械永久執行的防線。**判斷給 LLM，執行樣板給 script**（樣板 script 可後補，先用此 procedure）。

## 4 種 promotion 路徑（優先順序）

| 路徑 | 適用 | 力度 |
|---|---|---|
| **lint rule** | 程式結構性錯（不該 import X、命名、不該用某 API） | 最強 — CI 阻擋 |
| **test case** | 行為性錯（某輸入→某輸出） | 強 — CI 阻擋 |
| **pre-commit hook** | 跨檔一致性、敏感檔案守護、grep pattern | 中 — 本機阻擋 |
| **AGENTS.md / CLAUDE.md 條目** | 真的無法機械化的（架構意圖、convention 精神） | 弱 — 靠 agent 記得 |

**順序：lint > test > hook > docs**。docs 是最後手段。

## 步驟

1. 抽教訓資訊（user 或 conversation 脈絡）：規則描述、觸發條件、為什麼重要、上次錯誤具體例子。
2. **判斷路徑**——按上表逐項問「能不能用更高力度？」。不確定就問 user。
3. 執行對應路徑：
   - **lint**：找既有 lint config（`.eslintrc*` / `ruff.toml` / `clippy.toml`）→ 加規則 → 跑 `<commands.lint>` 確認 catch + 不誤報 → 列歷史違規讓 user 決定批次修 or ignore
   - **test**：寫紅色 test 重現錯誤 → 確認修法後變綠 → 加進 CI
   - **hook**：加 grep/regex check 到 `.husky/pre-commit` 或 `.git/hooks/pre-commit`，失敗訊息含「怎麼修」（[[單測對組件邊界系統性盲視]] 三要素）
   - **docs**：加進 CLAUDE.md「硬約束」段。先檢查既有硬約束 ≥ 15 條 → 先 audit 看能否升級到 lint/test
4. 追加索引到 `.harness/lessons.md`：
   ```markdown
   ## YYYY-MM-DD: <規則描述>
   - **強制方式**: lint|test|hook|docs
   - **位置**: <檔案 + 規則名/行號>
   - **來源**: <錯誤描述>
   - **歷史違規數**: <N>
   ```
5. Audit trail：印路徑、位置、CI 影響。

## 反模式

- ❌ 一律走 docs（最容易但最沒效）
- ❌ 不問 user 直接選路徑（trade-off user 要 own）
- ❌ 加完不驗證真的 catch 該錯誤
