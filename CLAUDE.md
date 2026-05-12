# ⚡ セッション開始時に必ず最初に実行すること

```bash
bash ~/ai-company/scripts/session_bootstrap.sh
```

完了サマリが出たら「✅ 起動チェック完了」と報告し、`projects/P006-claude-code-os/TASKS.md` から未着手タスクを選ぶ。**P001 ルートの `WORKING.md`**（`~/ai-company/WORKING.md`・会社共通）にタスク名先頭 `[P006]` 付きで宣言してから着手する。

> P001 共通ルール（優先順位／絶対禁止／完了の定義／タスク消化フロー）は `~/ai-company/CLAUDE.md` をそのまま継承する。本ファイルは差分のみ記載。

---

## このプロジェクトの役割

Claude Code OS は ai-company（P001）の会社 OS を**汎用パッケージとして外部に販売／公開する試み**。P001 内部で実証された仕組みを Claude Code 利用者向けに切り出して配布する。

| 項目 | パス／URL |
|---|---|
| 作業ディレクトリ | `projects/P006-claude-code-os/` |
| 戦略・WBS・設計書 | `projects/P006-claude-code-os/docs/` |
| 公開素材（OSS/BOOTH/Zenn 原稿） | `projects/P006-claude-code-os/product/` |
| 公開先リポ（GitHub public） | `<owner-handle>/claude-code-os` |
| 完了ログ | `projects/P006-claude-code-os/HISTORY.md` |

---

## P006 固有ルール（公開リスクへの物理対策）

| 禁止 | 代わりに |
|---|---|
| `product/` 配下に内部情報を書く（内部プロジェクト名 / AWS アカウント ID / 顧客 PII / 社内メールアドレス等） | 抽象化・匿名化してから記述。実例が必要なら "ある SaaS" 等の汎用表現に置換 |
| 公開チェックなしで公開リポへ同期 | `bash scripts/check-publish-safety.sh` で全項目 ✅ を確認してから `scripts/publish-to-claude-code-os.sh` |
| `<owner-handle>/claude-code-os`（公開）へ素の `git push` | 同期は `scripts/publish-to-claude-code-os.sh` 経由のみ（pre-push hook が `PUBLISH_VIA_SCRIPT=1` 以外を物理 reject） |
| `docs/rules/` `docs/meta/` を公開リポへ同期 | P001 内部用。allowlist 外なので自動除外される（allowlist を手で広げない） |
| P006 公開素材の動作確認を ai-company の worktree で完結 | `claude-code-os-dev` リポへ移動して実施（2026-05-12 インシデント対応） |

公開素材を触る PR は `scripts/check-publish-safety.sh` ✅ が P001 完了の定義に加えて追加条件となる。

---

## 詳細ルールの場所

| カテゴリ | ファイル |
|---|---|
| 戦略・WBS・製品設計 | `projects/P006-claude-code-os/docs/{strategy,wbs,product-design}.md` |
| 公開チェックリスト | `projects/P006-claude-code-os/product/publish-checklist.md` |
| P001 共通ルール | `~/ai-company/CLAUDE.md` および `docs/rules/global-baseline.md` |
