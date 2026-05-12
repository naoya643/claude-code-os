<!--
このファイルの使い方:
  - Cowork (スマホ/デスクトップアプリ) + AWS MCP + git の役割分離を定義。
  - AWS を使っていないプロジェクトは §1 / §3 / §4 を削除してよい。
  - プレースホルダー置換が必要:
      {{YOUR_CLAUDE_IAM_ARN}}   IAM ARN（例: arn:aws:iam::123456789012:user/Claude）
-->

# Cowork × AWS MCP × git ─ 役割分離と多重防御

> 結論: AWS MCP は **運用観測専用**・コード変更は **必ず git 経由**。
> 物理ガードは git 側 (CI / branch protection) と AWS 側 (IAM) の **多重防御** が正解。

---

## 1. AWS MCP は git の代替ではない（役割の明確な分離）

**AWS MCP** = MCP 経由で AWS CLI を直接実行できる仕組み。**運用観測・調査専用**として使う。

| 用途 | 例 | OK? |
|---|---|---|
| read 系 | `lambda get-function-configuration` / `cloudwatch get-metric-statistics` / `logs filter-log-events` / `events list-rules` / `s3 list-objects` | ✅ |
| 軽 write 系 | `lambda invoke` (冪等性確認後) / `dynamodb update-item` (運用データ修正) | ✅ |
| **コード書換** | `lambda update-function-code` | ❌ **絶対禁止** |
| **破壊操作** | `dynamodb delete-table` / `s3 rb` / `ec2 terminate-instances` | ❌ 絶対禁止 |
| **新規課金リソース** | `rds create-db-instance` / `ec2 run-instances` 等 | ❌ オーナー承認必須 |

**git** = ソースコードのバージョン管理。これは変わらない。
- すべてのコード変更は **PR → CI → GitHub Actions deploy workflow → Lambda 更新** の経路
- AWS MCP で「ぽちっ」とコード書き換えたら git に履歴残らず・ロールバック不能・誰が何変えたか不明
- 「AWS 直に行く」は調査だけ・**修正は必ず git 経由**

---

## 2. API 経由 commit と多重防御（cowork_commit.py を使う場合）

**前提**: GitHub API (`git/blobs` `git/trees` `git/commits` `git/refs`) で直接 commit を作るスクリプトを用意する場合、git CLI と同じ commit が main に積まれる（区別不可）。

| チェック | API 経由の挙動 |
|---|---|
| GitHub Actions CI (`.github/workflows/*.yml`) | ✅ 走る (push トリガー発火) |
| branch protection / required status checks | ✅ 適用 |
| auto-merge.yml | ✅ 動く |
| **ローカル `pre-commit` / `commit-msg` hook** | ❌ **スキップされる** (API は hook を呼ばない) |

**多重防御原則**: 必須チェック (PII / 行数上限 / Verified 行 等) は **必ず GitHub Actions CI に landing する**。ローカル hook だけに頼ると Cowork API 経由で抜ける。

- 新規物理ガード追加 PR は **CI ジョブと ローカル hook の両方** に実装（シングルポイント・オブ・フェイラー回避）

---

## 3. 物理ガード × 配置場所マトリクス

| 違反タイプ | git 側 (CI / branch protection) | AWS 側 (IAM / Resource Policy) | 最適配置 |
|---|---|---|---|
| コード変更前チェック (PII / 行数上限 等) | ✅ CI で強い | ❌ 無関係 | **GitHub Actions CI** + ローカル hook |
| main 直 push 禁止 | ✅ branch protection 100% | ❌ 無関係 | **branch protection** |
| Lambda コード書換 禁止 | ⚠️ 思想のみ | ✅ **IAM Deny で物理** | **AWS IAM (推奨)** |
| DB 破壊禁止 | ⚠️ 思想 | ✅ IAM Deny | **AWS IAM** |
| 新規課金リソース禁止 | ⚠️ 思想 | ✅ SCP / IAM | **AWS SCP / IAM** |
| Lambda runtime エラー | ✅ CI test | ✅ CloudWatch Alarm | **両方 (多重防御)** |

→ **結論: 思想ルールを思想のまま放置せず、CI / IAM / SCP で物理化できないか必ず検討する**。

---

## 4. AWS IAM Deny の物理化候補

Cowork ユーザー `{{YOUR_CLAUDE_IAM_ARN}}` のポリシーに以下の Deny を追加すれば、CLAUDE.md「思想ルール」を **物理化** できる:

```json
{
  "Effect": "Deny",
  "Action": [
    "lambda:UpdateFunctionCode",
    "lambda:DeleteFunction",
    "dynamodb:DeleteTable",
    "dynamodb:DeleteBackup",
    "s3:DeleteBucket",
    "ec2:TerminateInstances",
    "rds:DeleteDBInstance",
    "iam:DeletePolicy",
    "iam:CreateAccessKey"
  ],
  "Resource": "*"
}
```

**完了条件**: Cowork が `aws lambda update-function-code` を試して `AccessDenied` で reject されることを確認 → 思想ルールの物理化第一弾。

---

## 5. Dispatch 起動時チェック（毎回必須・行動前）

```
1. WORKING.md の「Dispatch継続性」セクションを読む（状態把握）
2. `cat WORKING.md | grep "\[Code\]"` で [Code] 行確認 → 1 件以上あれば新規コードセッション起動禁止
3. `gh run list --branch main --limit 3` で直近 CI がすべて green → 失敗があれば先に修正
4. 前セッション報告に ERROR/WARN 残存があれば先に解消
5. コードセッションへのプロンプトに「PR → CI → merge → done.sh」を必ず明記
6. 完了後: WORKING.md Dispatch継続性セクションを最新状態に書き換えて push
```

---

## 6. Dispatch 絶対禁止パターン

| 禁止行為 | 代わりにすること |
|---|---|
| 手動 invoke を提案する | スケジューラーに委ねる |
| コードを読まずにパラメータを埋めてプロンプトを送る | 該当ファイルを Read してから書く |
| 実機確認なしで「完了」と報告する | 本番 URL でブラウザ確認してから報告する |
| 効果検証なしで「完了」と報告する | SLI 数値の変化を確認するか、スケジューラーに委ねてから報告する |
| CI 失敗・ルール違反・stale エントリーに気づいて無視する | 気づいたら即対処または TASKS.md に積む |
| Dispatch セッションを長期継続して判断を続ける | 往復 20 回を超えたら WORKING.md に Dispatch 継続性を書き込みセッションを切り替える |

---

## 7. Code / Cowork 役割分担

**Code（Claude Code/CLI）**:
- `lambda/` `frontend/` `scripts/` `.github/` のコード変更
- ローカルテスト実行（pytest 等）
- デプロイ確認（GitHub Actions と連動）

**Cowork / Dispatch**:
- `CLAUDE.md` `WORKING.md` `TASKS.md` `HISTORY.md` のドキュメント更新
- AWS MCP 経由で Lambda / CloudWatch / DynamoDB / S3 / EventBridge の運用操作（read 系 + 軽 write 系）
- オーナーとの会話・分析・計画立案
- コードファイル編集も可（WORKING.md 明記してから）
- git 操作も可（FUSE 詰まり時は GitHub API 経由 PR スクリプトで迂回）
