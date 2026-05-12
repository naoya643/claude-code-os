# 着手中タスク（複数セッション間の作業競合管理）

> **このファイルのみで管理する。** タスク開始・完了のたびに即 `git add WORKING.md && git commit -m "wip/done: ..." && git push` する。
> ここに行が無いまま編集を始めるのは禁止（物理ルール）。

---

## 現在着手中

| タスク名 | 種別 | 変更予定ファイル | 開始 JST | needs-push |
|---|---|---|---|---|

---

## 記入フォーマット

```
| <タスクの 1 行要約> | [Code] <セッション名> | <変更予定ファイルをカンマ区切り> | YYYY-MM-DD HH:MM JST | yes / no |
```

| カラム | 役割 |
|---|---|
| タスク名 | 何を変えるかが一目で分かる 1 行（✅「fmtElapsed の境界値修正」 ❌「修正」「作業」） |
| 種別 | `[Code]` = コード編集セッション / `[Cowork]` = ドキュメント・運用セッション |
| 変更予定ファイル | パスをカンマ区切り（並行編集競合検知のキー）。事前に分かる範囲で正確に |
| 開始 JST | `YYYY-MM-DD HH:MM`（8h TTL の判定キー） |
| needs-push | `yes` = コード変更を含む（push 前に他セッションを起動しない）/ `no` = push 完了済 |

---

## セッション種別ルール

| プレフィックス | 意味 |
|---|---|
| `[Code]` | コードを編集するセッション（lambda / frontend / scripts / .github 等） |
| `[Cowork]` | ドキュメント・タスク管理・運用観測のみ（コード編集なし） |

`[Code]` 同士の同時起動は禁止。同じファイルを 2 つのセッションが踏み荒らす事故をゼロにするためのルール。
`guards/session/check-concurrent-sessions.sh`（BOOTH キット同梱）で物理的に検出される。

---

## エントリー自動失効ルール（恒久ルール）

**開始 JST から 8 時間を超えたエントリーは無効（stale）とみなす。**

- `bash scripts/session_bootstrap.sh` が起動時に自動削除する（手動不要）
- スクリプト失敗時のみ手動で行を削除して push する

> 理由: セッションがクラッシュ / タイムアウトした場合、完了処理が走らずエントリーが残り続ける。手動掃除に頼ると発見が遅れる。8 時間 TTL で自動的に解消する。

---

## needs-push カラム（恒久ルール）

**コードファイルを編集するセッションは `needs-push: yes` を立てる。**

- `lambda/` `frontend/` `scripts/` `.github/` 等を変更したら必ず `yes`
- push 完了後に行を消すか `no` に書き換える
- 起動チェックスクリプトが `needs-push.*yes` を grep して滞留警告を出す
- 文書だけの変更（`*.md`）では立てなくてよい

> 理由: 「実装 → push 失敗 → 次セッション起動まで滞留」の事故を物理ゲートで防ぐ。

---

## タスク開始前（毎回必須）

```bash
git pull --rebase origin main
cat WORKING.md                       # 競合チェック・stale エントリーは削除
```

重複なし → このファイルに追記 → 即 push して他セッションに宣言する。

## タスク完了後（毎回必須）

```bash
# 1. このファイルから自分の行を削除
# 2. 全変更を commit & push
git add -A && git commit -m "done: [タスク名]" && git push
```

---

## 並走宣言フォーマットの例

```markdown
| fmtElapsed 境界値修正 (0 / null / NaN) | [Code] task-fmtelapsed-fix | frontend/utils.js, tests/utils.test.js | 2026-01-15 14:30 JST | yes |
| README 更新 | [Cowork] docs-readme-update | README.md | 2026-01-15 15:00 JST | no |
```

---

## アーカイブ（完了履歴）

> 完了済みエントリーはここに残さない。`HISTORY.md` 等の別ファイルに移動する。
> このファイルは「今、誰が何を触っているか」だけを示す。
