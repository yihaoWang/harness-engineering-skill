# Mode: handoff

寫 session 收尾交接。

## 步驟

1. 跑 `~/.claude/skills/harness/lib/handoff.sh`（collect mode）→ 拿到 JSON：head / recent_commits / dirty_files / test_result / next_step_hint。
2. 從**會話脈絡**抽「本輪目標」（一句話，user 開頭給的任務或推論出的）。這是 LLM 必要的部分，script 沒辦法做。
3. 組裝 YAML frontmatter block：
   ```yaml
   session: <ISO timestamp from JSON>
   goal: <本輪目標>
   commits: [<hashes>]
   dirty_files: [<list>]
   test_status: "<exit code or pass/fail>"
   next_step: <next_step_hint or refined>
   ```
4. 跑：
   ```bash
   ~/.claude/skills/harness/lib/handoff.sh --append "<yaml block>"
   ```
5. （可選）如 config `handoff.run_clean_state_check: true` → 跑 `lib/clean-state-check.sh`，failed_dims 追加到 frontmatter。
6. 印一行 audit trail。

## 自動觸發（hook）

Stop hook 呼叫此 mode 時帶 `--auto`——略過步驟 2（沒會話脈絡可抽），goal 留 `(auto-captured)`，其他全照常。
