# claude-code-os — Claude Code 用の物理ガード集

> Claude Code に「気をつけて」と書いても効かない。
> このリポジトリは「書けなくする」「触れなくする」「実行できなくする」を実装したテンプレート集。

---

## これは何か

Claude Code（Anthropic の AI コーディング CLI）を 2〜3 週間使っていると、同じ種類の事故を繰り返し踏むことになる。

- 「気をつけてください」と CLAUDE.md に書いても、次のセッションでは忘れている
- 「本番確認してから完了報告」と書いても、CI が green なだけで完了報告される
- 「同じファイルを 2 セッションで触らない」と書いても、別の worktree から普通に踏み荒らされる

これは Claude が悪いのではなく、**「テキストで縛る」設計が壊れている**。LLM はインストラクションを文字通り狭く解釈する性質を持つので、ルールは「読まれる前提」ではなく「物理的に違反不能にする前提」で書く必要がある。

このリポジトリは、その物理ガードの最小セット（3 ファイル）を無料で配布する。

---

## 物理ガードとは何か

「気をつける」を「物理的に書けなくする / 実行できなくする」に変換するもの。

| ソフト規律（壊れる） | 物理ガード（壊れない） |
|---|---|
| 「『気をつける』『注意する』は書かない」と CLAUDE.md に書く | `pre-commit` hook で「気をつける」「注意する」を検出 → コミット reject |
| 「同じファイルを 2 セッションで触らない」とルールに書く | `WORKING.md` 宣言なしの編集を `pre-commit` hook で reject |
| 「本番確認してから完了報告」とルールに書く | `done.sh` が curl で本番 URL を叩き 200 以外なら exit 1 |
| 「`main` に直 push しない」とルールに書く | `pre-push` hook で `refs/heads/main` への push を物理 reject |

物理ガードは、Claude が CLAUDE.md を読み忘れても、ルールが古くても、別セッションが暴走しても、機械的に効く。
「Claude を信頼する」のではなく「Claude を信頼できる状態に物理的に保つ」設計。

---

## なぜ必要か

Claude Code を実際に運用していると、次の 3 つが必ず起きる。

1. **同じファイルが 2 セッションから踏み荒らされる** — 別タブで起動した別 worktree が同じファイルを編集 → コンフリクト・上書き
2. **「気をつける」と書いた瞬間に守られなくなる** — CLAUDE.md に「気をつけて」と書くと Claude も人間も「書いた = 対策済」と錯覚する。実際は何の対策にもなっていない
3. **CI が green でも本番が壊れている** — テストは通るが、本番の URL が 5xx を返している / データが古いまま / Lambda が timeout している

このリポジトリの 3 ファイル（`CLAUDE.md` / `WORKING.md` / `done.sh`）は、この 3 つを物理的に防ぐ最小セット。

---

## 3 ファイルで始める手順

### 1. 3 ファイルをコピー

```bash
cd /path/to/your/project
curl -O https://raw.githubusercontent.com/naoya643/claude-code-os/main/CLAUDE.md
curl -O https://raw.githubusercontent.com/naoya643/claude-code-os/main/WORKING.md
curl -O https://raw.githubusercontent.com/naoya643/claude-code-os/main/done.sh
chmod +x done.sh
```

> 公開リポジトリ: `https://github.com/naoya643/claude-code-os`

### 2. プレースホルダーを置換

`CLAUDE.md` の冒頭の `{{YOUR_PROJECT_NAME}}` 等を自分のプロジェクト名で置換する。

| プレースホルダー | 例 |
|---|---|
| `{{YOUR_PROJECT_NAME}}` | `my-app` |
| `{{PROJECT_ROOT}}` | `~/work/my-app` |
| `{{ONE_LINE_PURPOSE}}` | `個人ブログの記事配信` |
| `{{LANGUAGE_PREFERENCE}}` | `日本語で対応` |

### 3. 最初のセッションで効果を体験する

Claude Code を起動して、何でもいいから 1 つタスクを完了させる。

- `WORKING.md` に行を追加せずに編集を始めると、何も止めない（このリポジトリだけでは pre-commit hook がインストールされていないため）
- 本気で物理ガードを効かせたい場合は、次の「BOOTH フルキット」を参照

---

## BOOTH フルキットには何が入っているか

3 ファイル版は「最小限の体験」。実際に物理ガードを効かせるには CI workflow と git hook が必要。
フルキットには以下が追加される。

| 追加物 | 役割 |
|---|---|
| `docs/rules/global-baseline.md` | 全プロダクト共通の前提（PO 宣言・なぜなぜ・完了の定義） |
| `docs/rules/bug-prevention.md` | バグ再発防止ルール 20+ 件 |
| `docs/rules/design-mistakes.md` | 過去の設計ミスパターン 10+ 件 |
| `docs/lessons-learned-abstracted.md` | 実失敗を汎用化した教訓集 12+ 件 |
| `guards/commit/check-soft-language.sh` | 「気をつける」「注意する」等を検出してコミットを物理 reject |
| `guards/commit/check-deleted-refs.sh` | 削除されたファイルへの残参照を検出して reject |
| `guards/session/check-concurrent-sessions.sh` | 2 セッション以上の並走を物理ブロック |
| `scripts/session_bootstrap.sh` | セッション開始時の標準手順（sync / stale 行削除 / 並走チェック） |
| `scripts/done.sh` | TODO/FIXME・テスト・本番確認の完全版 |
| `.github/workflows/check-soft-language.yml` | check-soft-language.sh を CI でも実行 |
| `SETUP.md` | 30 分セットアップ手順書 |
| `INVENTORY.md` | 同梱ファイル一覧 |

→ [BOOTH 販売ページ](https://claude-code-os.booth.pm/items/8350012)

---

## 関連記事（Zenn）

実際の運用ノウハウを連載で公開している。

- 記事①: 「Claude Code が instructions を無視する感覚は正しい」
- 記事②: 「『気をつける』と書いても意味がない理由と、物理的に書けなくする方法」
- 記事③: 「同じファイルを 2 つのセッションが踏み荒らす事故をゼロにした」

→ [Zenn の連載ページ](https://zenn.dev/naoya643)

---

## ライセンス

MIT License. 詳細は [LICENSE.md](LICENSE.md) を参照。

商用利用・改変・再配布いずれも自由。フォークもどうぞ。
ただし「物理ガード」というカテゴリ名が広がるほうが嬉しいので、フォークした際は出典を残してもらえると助かる。

---

## 思想

このリポジトリの設計思想は [MANIFESTO.md](MANIFESTO.md) を参照。
要約すると「Claude を信頼する」のではなく「Claude を信頼できる状態に物理的に保つ」。
