# Mode: bootstrap

為 project 建立 `.harness/` 4 件套 + `CLAUDE.md` harness 段。一次性。

**設計**：偵測由 LLM 做（看得懂 monorepo / 非主流 stack / 工具鏈），script 只做 scaffold 寫檔。

## 步驟

1. `cd` 到 project root（`git rev-parse --show-toplevel`）。
2. **LLM 偵測**——讀以下檔案推斷 stack：
   - root manifest：`package.json` / `pnpm-workspace.yaml` / `Cargo.toml` / `pyproject.toml` / `go.mod` / `Gemfile` / `mix.exs` / `deno.json` / 其他
   - `ls -la` 看整體結構（monorepo？多 stack 混合？）
   - 必要時讀 `README` 找 dev/test/build 命令
3. 組裝 detection JSON（給 bootstrap.sh 用）：
   ```json
   {
     "root": "/abs/path",
     "stack": "node|python|rust|go|...|monorepo",
     "package_manager": "npm|pnpm|yarn|bun|cargo|uv|...",
     "commands": {
       "install": "...",
       "test": "...",
       "lint": "...",
       "build": "...",
       "dev": "..."
     },
     "ui": {"framework": "react|vue|...|null"} 
   }
   ```
   monorepo 時 stack 可填 `"monorepo"`，commands 用 root-level 命令（如 `pnpm -r test`）。
4. 把 detection JSON + 推斷理由給 user 看，重點問 `commands` 和 `ui.framework` 是否正確。
5. user 確認 → 跑乾跑：
   ```bash
   ~/.claude/skills/harness/lib/bootstrap.sh --config '<json>'
   ```
   檢查 `would_create` / `would_modify`。
6. 跑 apply：
   ```bash
   ~/.claude/skills/harness/lib/bootstrap.sh --apply --config '<json>'
   ```
7. 印 audit trail（從 JSON `written` list）+ 建議下一步：
   - `git add .harness/ CLAUDE.md && git commit -m "chore: bootstrap harness"`
   - `/update-config` 加 Stop hook（自動 handoff）

## 規則

- **不覆蓋** progress/features/lessons/init（只覆蓋 config）——script 已實作
- 偵測不確定時**直接問 user**，不要猜（commands 寫錯後續每個 mode 都會中招）
