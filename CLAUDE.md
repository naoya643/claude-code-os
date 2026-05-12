<!--
このファイルの使い方:
  - Claude Code が起動時に最初に読むファイル。リポジトリの ROOT に置く。
  - 250 行ハードキャップ。詳細は docs/rules/*.md にリンクで逃がす。
  - プレースホルダー置換が必要:
      {{YOUR_PROJECT_NAME}}  プロジェクト名（例: myapp）
      {{YOUR_APP_URL}}       本番URL（例: https://myapp.com）
      {{YOUR_USERNAME}}      OS ユーザー名（絶対パス用）
  - bootstrap スクリプトを自作した場合、§セッション開始のコマンドを書き換える。
-->

# ⚡ セッション開始時に必ず最初に実行すること

```bash
bash ~/{{YOUR_PROJECT_NAME}}/scripts/session_bootstrap.sh
```

> bootstrap スクリプトをまだ作っていない場合は、最低限 `git pull --rebase` と `cat WORKING.md` を実行して着手中タスクを確認すること。

完了サマリが出たら「✅ 起動チェック完了」と報告して着手する。
起動後は `TASKS.md` から現フェーズのタスクを優先して実行する。
WORKING.md に自分の行を追記してからコード変更を始める（物理ルール：宣言なし編集禁止）。

---

## 優先順位（未知ケースの判断軸）

| 優先度 | 守るもの |
|---|---|
| 1 | 本番サービスの動作（{{YOUR_APP_URL}}） |
| 2 | データ整合性（DB · ストレージ） |
| 3 | CI/CD の安定（全 workflow が green） |
| 4 | アーキテクチャの一貫性（設計意図を維持） |
| 5 | タスクの完了 |

---

## 絶対禁止（物理ガードなし・行動で守る）

| 禁止 | 代わりに |
|---|---|
| 実機確認なしで「完了」と報告 | {{YOUR_APP_URL}} でブラウザ確認してから報告 |
| 不可逆操作（リソース削除 · force push · DB drop）を無確認実行 | オーナーに確認してから実行 |
| 同名ファイルを WORKING.md 宣言なしで編集 | WORKING.md に行を追記してから着手 |
| 効果検証待ちでセッションを開いたまま待機 | スケジューラーに渡して即クローズ（global-baseline §10） |
| コードセッションを同時 2 件以上起動 | 前セッション完了を確認してから次を起動（global-baseline §12） |
| 「気をつける」だけの対策を仕組み的対策と呼ぶ | CI / hook / SLI で物理化してから対策と記録する |

---

## 完了の定義

```
完了 = 本番 URL / モニタリング / 実機で動作確認済 + done.sh 実行済 + Verified: 行付き commit
```

「コードが書けた」「PR が merge された」は完了ではない。
PR 作成時は `gh pr merge --auto --squash` を付けて即 exit。CI green 後に auto-merge.yml が自動 squash merge する。

---

## 詳細ルールの場所

| カテゴリ | ファイル |
|---|---|
| 全プロダクト共通の前提・DO/DON'T | `docs/rules/global-baseline.md` |
| バグ防止パターン（自プロジェクトで育てる） | `docs/rules/bug-prevention.md` |
| 設計ミスパターン（自プロジェクトで育てる） | `docs/rules/design-mistakes.md` |
| CI / マージフロー | `docs/rules/ci-and-merge-workflow.md` |
| Cowork と AWS 操作・セッション並走・モデル選択 | `docs/rules/cowork-aws-policy.md` |

---

## このファイルを編集するときの原則

| 原則 | 内容 |
|---|---|
| 行数ハードキャップ | 250 行を超えそうになったら、詳細ルールを `docs/rules/*.md` へ移してリンクで参照する |
| 散文で書かない | 全ルールはテーブル 1 行形式に統一する（LLM の遵守率が高い） |
| 重複禁止 | 同じルールを CLAUDE.md と global-baseline.md の両方に書かない |
| 1 ルール 1 行 | 「A して B して C する」を 1 行に押し込まない |
| 物理化を優先 | 「気をつける」「忘れずに」と書きたくなったら、CI / hook / script のどれかに落とす |

---

