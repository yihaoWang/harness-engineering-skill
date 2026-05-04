---
name: harness
description: 為任意 code project 建立與維護 harness engineering（agent 可靠執行真實工程任務的工具/規則框架）。模式分派：bootstrap（初始化）、handoff（交接）、promote-lesson（把錯誤變永久防線）、evaluate（獨立 evaluator sub-agent 跑 rubric 評產出）。當使用者在 code project 裡說「初始化 harness / 收尾交接 / 這錯不要再犯 / 評估 UI 或 code 或文件」時使用。
---

# Harness — Code Project 可靠性工具

**設計信念**：harness 不是讓模型變聰明，是給模型建立閉環工作系統。一次寫好 skill，N 個 project 共用，改進自動傳播。詳見 [[Harness-Engineering]] 概念頁。

## 模式分派

收到觸發語 → **只 Read 對應的 mode 檔**，不要全部載入。

| 觸發語 | 模式 | 載入 |
|--------|------|------|
| 「初始化 harness / harness bootstrap / 為這 project 設計 harness」 | bootstrap | `modes/bootstrap.md` |
| 「收尾 / handoff / 寫 progress / 結束 session」（也由 Stop hook 自動觸發） | handoff | `modes/handoff.md` |
| 「這錯不要再犯 / 把這條規則永久執行 / promote」 | promote-lesson | `modes/promote-lesson.md` |
| 「評估 UI / 評估 code / 評估文件 / 跑 evaluator」（也可由 PostToolUse hook 自動觸發） | evaluate | `modes/evaluate.md` |

## 啟動檢查（每個新對話的第一次使用）

1. 檢查當前 project 是否已有 `.harness/config.json`
   - 沒有 → 提示 user 先跑 `/harness-bootstrap`（除非當前 mode 就是 bootstrap）
   - 有 → Read 它，後續 mode 用裡面的命令路徑
2. 檢查當前 project 是否有 `CLAUDE.md` 引用 harness skill
   - 沒有 → bootstrap 時補上

## 共用規則（所有模式都遵守）

- **語言**：跟 user 對話用繁體中文；寫到 `.harness/` 的檔案用 user 偏好（看 CLAUDE.md，沒指定就跟對話語言）
- **不寫死 project-specific**：所有 project 變數從 `.harness/config.json` 讀
- **可降級**：找不到 config / 命令失敗，退回問 user，**不要** crash session
- **audit trail**：每個 mode 結束印「做了什麼 / 寫到哪 / 為什麼」
- **不重新發明**：用 project 既有的 lint/test/build；skill 只 orchestrate
- **不取代 second-brain**：harness 管 code project；second-brain 管 wiki

## .harness/ 目錄約定（每個 project）

```
<project>/
├── CLAUDE.md                # 加一段「使用 harness skill」的指引
└── .harness/
    ├── config.json          # 此 project 的命令、路徑、規則
    ├── progress.md          # handoff 維護
    ├── feature_list.json    # 功能狀態三元組
    ├── lessons.md           # promote-lesson 累積的永久防線
    ├── rubrics/             # evaluate 用：ui.md / code.md / writing.md / ...
    └── evaluations/         # evaluate 報告 archive

```

`.harness/config.json` 的 minimal schema：

```json
{
  "stack": "node|python|rust|...",
  "commands": {
    "install": "...",
    "test": "...",
    "lint": "...",
    "build": "...",
    "dev": "..."
  },
  "ui": {
    "framework": "react|vue|..."
  },
  "evaluators": {
    "ui":      {"rubric": ".harness/rubrics/ui.md",      "inputs": ["diff", "screenshots"]},
    "code":    {"rubric": ".harness/rubrics/code.md",    "inputs": ["diff"]},
    "writing": {"rubric": ".harness/rubrics/writing.md", "inputs": ["files"]}
  }
}
```

各 mode 用到的欄位逐步擴充，不一次定死。

## 相關
- [[Harness-Engineering]] — 學科總覽
- [[Learn-Harness-Engineering]] — 來源課程
- [[Harness-Skills-設計-2026-05]] — 本 skill 的設計文件
