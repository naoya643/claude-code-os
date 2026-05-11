# Claude OSS — Operating System for Claude Code

> A battle-tested starter kit of rules, workflows, and physical guardrails for shipping production software with Claude Code.

Claude Code is powerful, but raw. Drop it into a real project and you'll hit the same wall every team hits: it forgets the rules. It declares "done" without verifying. It edits files another session is already editing. It says "I'll be careful next time" instead of installing a guardrail.

**Claude OSS** is the layer that sits above Claude Code and makes those failures impossible — not by asking nicely, but by physicalizing every rule into a script, hook, or CI check.

This kit was extracted from a year of running 3–4 Claude Code sessions in parallel on a live AI news service. Every rule in here exists because something broke.

---

## Why this exists

### The problem

| Symptom | Root cause |
|---|---|
| Claude says "done" but production is broken | "Done" is defined as "I wrote code", not "I verified it works" |
| Two sessions edit the same file and overwrite each other | No declaration mechanism for in-flight work |
| Same bug gets re-introduced 3 weeks later | No append-only memory of bugs already fixed |
| Rule violations only caught at code review | Rules live in prose, not in CI / hooks / scripts |
| Context window blows out mid-task | Rules sprawl across 20 docs that all get loaded |

### The fix — four layers

```
┌─────────────────────────────────────────────┐
│  Rule Layer      CLAUDE.md (≤250 lines)     │  — what to read on boot
│                  docs/rules/*.md            │
├─────────────────────────────────────────────┤
│  Workflow Layer  WORKING.md (in-flight)     │  — who's editing what
│                  TASKS.md / HISTORY.md      │
├─────────────────────────────────────────────┤
│  CI Layer        done.sh (verification)     │  — physicalize "done"
│                  git hooks (rule enforcer)  │
├─────────────────────────────────────────────┤
│  Security Layer  IAM Deny (AWS)             │  — make destructive ops impossible
│                  branch protection (git)    │
└─────────────────────────────────────────────┘
```

The top three layers ship in this repo. The bottom layer (AWS IAM / branch protection) is documented but project-specific.

---

## Quick start

```bash
# 1. Copy claude-os/ into your project root
cp -r claude-os/ /path/to/your-repo/

# 2. cd into your repo
cd /path/to/your-repo/

# 3. Move CLAUDE.md to the repo root (Claude Code reads it on boot)
mv claude-os/CLAUDE.md .
mv claude-os/WORKING.md .
mv claude-os/done.sh .

# 4. Replace placeholders (see "Placeholders" below)
#    Use your editor's find-and-replace, or:
grep -rl "{{YOUR_PROJECT_NAME}}" . | xargs sed -i '' 's/{{YOUR_PROJECT_NAME}}/myapp/g'

# 5. Make done.sh executable
chmod +x done.sh

# 6. Start a Claude Code session — it will read CLAUDE.md and follow the rules
```

For a step-by-step guide in Japanese, see [docs/setup-guide.md](docs/setup-guide.md).

---

## What's in the kit

| File | Role |
|---|---|
| `CLAUDE.md` | Boot file Claude Code reads on every session. Hard cap: 250 lines. Points to the rule docs. |
| `WORKING.md` | Live registry of which session is editing which files. Prevents parallel-edit collisions. |
| `done.sh` | Script that physicalizes "done" — verifies prod URL, CloudWatch errors, etc. before flipping a task to done. |
| `docs/rules/global-baseline.md` | Cross-project rules: completion definition, boot checks, session concurrency caps, model selection. |
| `docs/rules/ci-and-merge-workflow.md` | Who confirms CI? Who merges? Hand-off between Code and Dispatch sessions. |
| `docs/rules/cowork-aws-policy.md` | How to wire git + AWS MCP with defense-in-depth (CI on git side, IAM Deny on AWS side). |
| `docs/rules/bug-prevention.md` | **Empty template.** Grow this with bugs your project keeps re-introducing. |
| `docs/rules/design-mistakes.md` | **Empty template.** Grow this with design assumptions that turned out wrong. |
| `docs/setup-guide.md` | Step-by-step setup in Japanese. |

---

## The big ideas

### 1. Physicalize "done"

The most expensive bug in any Claude Code workflow: Claude says "done" before verifying. The fix is `done.sh`:

```bash
bash done.sh TASK-123 url:https://your-app.com/
# → curls the URL, fails on non-200, refuses to commit "done" until it passes
```

`done.sh` knows three verification modes:
- `url:<https url>` — HTTP 200 from production
- `lambda:<function-name>` — no errors in CloudWatch over the last 5 minutes
- `topic-ai:<id>` — domain-specific check (example included)

Add your own modes for your project's "done" signals.

### 2. Manage parallel edits with WORKING.md

When you run multiple Claude Code sessions (or one Claude Code + one Cowork mobile session), they will eventually edit the same file at the same time and one will win, silently. `WORKING.md` makes this impossible:

```
| Task | Kind | Files | Start (JST) | needs-push |
|------|------|-------|-------------|------------|
| [Code] FOO-1 add login | Code | src/auth/* | 2026-05-11 10:00 | yes |
```

Every session **declares before editing**, **removes when done**. Stale rows (>8h) auto-removed by `session_bootstrap.sh` (you build this script — pattern in `docs/setup-guide.md`).

### 3. Append-only learning

Two files, never deleted, only added to:
- `bug-prevention.md` — every bug you fix becomes one row, so the same bug never gets re-introduced
- `design-mistakes.md` — every assumption that turned out wrong becomes one row

After a year these are the most valuable files in the repo.

### 4. Tables, not prose

LLMs follow tabular rules better than prose. Every rule doc in this kit is **structured as tables** for that reason. When you add new rules, keep the format.

---

## Placeholders

Search and replace these before using:

| Placeholder | Replace with | Example |
|---|---|---|
| `{{YOUR_PROJECT_NAME}}` | Your project's name (lowercase, no spaces) | `myapp` |
| `{{YOUR_APP_URL}}` | Production URL | `https://myapp.com` |
| `{{YOUR_PROJECT_ID}}` | Short project ID | `P001` |
| `{{YOUR_CLAUDE_IAM_ARN}}` | IAM ARN for the user Claude assumes | `arn:aws:iam::123456789012:user/Claude` |
| `{{YOUR_USERNAME}}` | Your OS username (for absolute paths) | `alice` |
| `{{YOUR_AWS_REGION}}` | Your AWS region | `us-east-1` |

If you're not using AWS, leave AWS-related rules as-is or delete the AWS sections.

---

## How to grow this

Claude OSS is a **seed**, not a finished product. The two empty templates (`bug-prevention.md`, `design-mistakes.md`) are designed to grow with your project.

**Every time you fix a bug**, add one row to `bug-prevention.md` with:
- The pattern (1 phrase)
- The rule (1 sentence — what to do instead)
- Optional: the past incident link

**Every time a design assumption turns out wrong**, add one row to `design-mistakes.md` with:
- The feature
- The assumption (what you believed)
- The reality (what actually happened)

After 3 months your kit will be 10× more valuable than what you started with.

---

# 日本語版

## Claude OSS とは

Claude Code は強力だが、生のままだ。実プロジェクトに投入すると必ず同じ壁にぶつかる: ルールを忘れる。確認なしで「完了」と宣言する。別セッションが編集中のファイルを上書きする。「次から気をつけます」と言うだけで再発防止策を入れない。

**Claude OSS** は、Claude Code の上に乗ってこれらの失敗を「お願い」ではなく「不可能化」するレイヤー。すべてのルールを script・hook・CI チェックに**物理化**する。

このキットは、AIニュースサービスを Claude Code 3〜4 並走で 1 年運用した実体験から抽出したもの。**ここにあるルールはすべて、過去に何かが壊れたから存在する**。

## 解決する問題

| 症状 | 根本原因 |
|---|---|
| Claude が「完了」と言うが本番が壊れている | 「完了」が「コードを書いた」になっており、「動作確認した」になっていない |
| 2 つのセッションが同じファイルを編集して上書きする | 着手中作業の宣言メカニズムがない |
| 3 週間前に直したバグがまた発生する | 「修正済みバグ」の append-only メモリがない |
| ルール違反が code review でしか捕まらない | ルールが散文で書かれていて CI / hook / script に物理化されていない |
| タスク途中でコンテキストが溢れる | ルールが 20 個のドキュメントに散らばっていて、毎回全部ロードされる |

## 4 層構造

```
ルール層       CLAUDE.md (≤250 行) ＋ docs/rules/*.md
ワークフロー層 WORKING.md (着手中宣言) ＋ TASKS.md / HISTORY.md
CI 層          done.sh ＋ git hooks
セキュリティ層 IAM Deny ＋ branch protection
```

上 3 層がこのキットに含まれる。最下層（AWS IAM / branch protection）は**プロジェクト固有**なので、ドキュメントだけ提供している。

## クイックスタート

```bash
# 1. claude-os/ をプロジェクトに展開
cp -r claude-os/ /path/to/your-repo/
cd /path/to/your-repo/

# 2. ルートに配置（Claude Code が起動時に読む）
mv claude-os/CLAUDE.md .
mv claude-os/WORKING.md .
mv claude-os/done.sh .

# 3. プレースホルダー置換
grep -rl "{{YOUR_PROJECT_NAME}}" . | xargs sed -i '' 's/{{YOUR_PROJECT_NAME}}/myapp/g'

# 4. 実行権限付与
chmod +x done.sh
```

詳細手順は [docs/setup-guide.md](docs/setup-guide.md) を参照。

## 各ファイルの役割

| ファイル | 役割 |
|---|---|
| `CLAUDE.md` | 起動時必読。**250 行ハードキャップ**。詳細はリンク先へ |
| `WORKING.md` | 着手中宣言レジストリ。並行編集衝突を物理的に防ぐ |
| `done.sh` | 「完了」を物理化。本番 URL HTTP 200 確認・CloudWatch エラー検証なしには commit させない |
| `docs/rules/global-baseline.md` | 完了の定義・起動チェック・セッション並走上限・モデル選択 |
| `docs/rules/ci-and-merge-workflow.md` | CI 確認役・マージ役・Code/Dispatch セッション間ハンドオフ |
| `docs/rules/cowork-aws-policy.md` | git × AWS MCP の多重防御設計（CI 側 + IAM Deny 側） |
| `docs/rules/bug-prevention.md` | **空テンプレ**。自プロジェクトのバグパターンを育てる |
| `docs/rules/design-mistakes.md` | **空テンプレ**。自プロジェクトの設計ミスを育てる |
| `docs/setup-guide.md` | 日本語セットアップ手順 |

## 育て方

このキットは**種**であって、完成品ではない。空テンプレ 2 つ（`bug-prevention.md` / `design-mistakes.md`）は、自プロジェクトで育てる前提。

- **バグを直したら 1 行追加**: パターン・対処ルール・過去事例リンク
- **設計の前提が崩れたら 1 行追加**: 機能名・想定・実際

3 ヶ月で開始時より 10 倍価値あるリポジトリになる。

## ライセンス / 利用について

MIT。商用利用可。フィードバック歓迎。
