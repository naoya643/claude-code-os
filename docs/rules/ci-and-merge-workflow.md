<!--
このファイルの使い方:
  - PR 作成後の CI 確認・マージのフローを定義する。
  - Code セッション（実装者）と Dispatch セッション（PM 役）の責務分担を明確化。
  - プロジェクト固有: deploy 後の動作確認方法は CLAUDE.md / done.sh で補う。
  - プレースホルダー置換は不要（このまま使える）。
-->

# PR 作成後の CI 確認 + マージワークフロー

> このファイルが詳細。CLAUDE.md には要約のみ記載。

## ワークフロー全体

| ステップ | 実行者 | 内容 |
|---|---|---|
| 1. 実装 + PR 作成 | Code セッション | ブランチで実装 → PR 作成 → **即 exit** |
| 2. CI 確認 + マージ | Dispatch (Haiku) | `gh pr checks NNN` で green 確認 → `gh pr merge` → 報告 |

---

## Dispatch（Haiku セッション「PR #NNN CI 確認 + マージ」）の責務

**PR 完了報告を受け取ったら以下を実行:**

1. **状態確認**: `gh pr checks NNN` を実行
   - ✅ **green**: そのままマージへ
   - 🔴 **fail**: エラー分析 → Code セッション起動（修正は Code に委ねる）
   - ⏳ **pending**: 最大 2 分待機 → `gh pr checks NNN` 再確認（2 回まで）
     - 2 回の確認で pending が続く場合は Code セッション起動に handoff

2. **マージ実行**: `gh pr merge NNN --squash --admin`（green の場合のみ）
   - squash: ブランチのコミットを 1 つに統合
   - admin: branch protection override（admin 権限で push-to-merge）
   - PR 完了報告を出す

3. **禁止事項**:
   - ❌ Monitor ポーリング（実施コストが高い） → 直接 `gh pr checks` を 1〜2 回確認のみ
   - ❌ 「スケジューラーに任せる」「bootstrap に任せる」 → **誰が確認するのか不明**になり CI 失敗の検出が遅延

---

## 背景（なぜ Dispatch がやるのか）

**Code セッション（実装者）がやってはいけない理由:**
- PR 作成直後の「CI pending」を確認することはコンテキスト消費。実装と関係ない待機時間が増える
- 複数の Code セッションが同時に走っている場合、「誰が CI 確認するのか」が不明になる
- GitHub Actions が green になるまでの時間が不確定（2 分〜10 分）のため、Monitor ポーリングは禁止（コスト規律ルール）

**Dispatch（PM 役の Haiku）がやる理由:**
- PR 完成 → Report というワークフローの中で「CI 確認 + マージ」は自然な作業ステップ
- 複数の PR が待機している場合、Dispatch がキュー管理する
- モデル選択: Haiku で十分（やることは `gh pr checks` + `gh pr merge` という機械的操作）

---

## マージ後の実機確認（別の責務）

**ここからは実装者（Code）の責務:**
- アプリ変更: デプロイ完了後、本番 URL で動作確認
- 確認完了後: `bash done.sh <task_id> url:<本番URL>` を実行

詳細は `CLAUDE.md` の「完了の流れ」を参照。
