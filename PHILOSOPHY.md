# The Philosophy of AI-Driven Development

*By a developer who spent a year building with Claude — and made every mistake possible.*

---

## Part I — English

### The problem with "being careful"

When I started building with AI, I made a rule: *be careful when editing shared files.*

It didn't work.

Six months later I had a different rule: every file being edited must be declared in `WORKING.md` before a single character changes. Violations are rejected — not by a warning, not by a note in the docs, but by the system itself refusing to proceed.

Same goal. Radically different outcome.

The distance between those two rules is the entire philosophy in this document.

---

### Thesis 1: "Done" is a physical state, not a feeling

The most dangerous word in software development is *done*.

Done means the feature works in production, confirmed by a human browser session on the live URL, with the timestamp and HTTP status committed to git. Done means CloudWatch shows no new errors. Done means a scheduler has been registered to verify the deploy in N minutes.

Done does not mean:
- The code was written
- The PR was merged
- CI turned green
- The tests passed locally

Each of those is a checkpoint on the way to done. None of them is done.

This sounds obvious. It isn't. Under pressure, "CI is green" becomes "it's shipped." That slide from evidence to assumption is where production breaks live.

The solution isn't vigilance. Vigilance is not a countermeasure — it's a wish. The solution is to make "done" impossible to declare without evidence. In this system, commits that carry `feat:`, `fix:`, or `perf:` are rejected by a git hook unless they contain a `Verified: <url>:<status>:<timestamp>` line. The completion script (`done.sh`) requires a production URL. The word "done" cannot be spoken by the system until the system has seen proof.

**Done is not declared. Done is confirmed.**

---

### Thesis 2: Mindfulness is not a countermeasure

After every incident, there is a temptation to write a rule that says *pay attention to X.* 

In this project, that temptation is forbidden.

"Be careful," "pay attention," "don't forget" — these are not countermeasures. They are wishes dressed as rules. LLMs ignore them. Humans ignore them under stress. The rule might as well not exist.

This project runs a CI job (`check_soft_language.sh`) that literally greps the rule files for phrases like "be careful" or "pay attention" and fails the build if it finds them. If a countermeasure cannot be expressed as a CI gate, a git hook, a metric threshold, or a scheduled verification — it is not a countermeasure. It is decoration.

A real countermeasure is observable and enforceable. The system sees it or it doesn't count.

The discipline this demands is uncomfortable. When something breaks, the instinct is to add a note. The right response is: *what physical mechanism would have caught this?* And then to build that mechanism.

**Every rule that exists only as text will eventually be violated.**

---

### Thesis 3: Roles must be explicit and enforced

AI systems fail in predictable ways when roles are ambiguous. When the same agent can both write code and merge it, can both run operations and modify infrastructure, the boundary between "doing the task" and "doing something irreversible" dissolves.

In this system, roles are not described — they are enforced:

- **Code sessions** write code. They do not merge. They do not deploy. They open a PR and exit.
- **Dispatch (coordination)** confirms CI, merges, and queues the next task. It does not write code.
- **Scheduler** verifies post-deploy behavior and files new tasks if something is wrong. It does not make decisions.
- **AWS MCP** is read-only for operations. It cannot execute `lambda:UpdateFunctionCode`. An IAM Deny makes this physically impossible, not just discouraged.

The model for each role is also specified: Haiku for mechanical coordination tasks, Sonnet for implementation, Opus only when explicitly justified. Role confusion wastes money and creates invisible risk.

This isn't micromanagement. It's the difference between a kitchen where anyone can touch any knife and one where the prep chef, the line cook, and the expediter each have a defined station. Output is better. Accidents are fewer.

**Clarity of role is not bureaucracy. It is the foundation of reliable collaboration.**

---

### Thesis 4: Five whys, not one patch

When something breaks, the first instinct is to fix the symptom. Add a null check. Catch the exception. Increase the retry count.

This project requires something harder: five consecutive whys, until you reach a structural cause — and then three countermeasures, each of which must be physically implementable.

The test is simple: *could the same failure happen again even with this fix in place?* If yes, the fix is a band-aid and the analysis is incomplete.

But there's a more insidious failure mode: writing the analysis and not implementing the fixes. Rules that are written but never implemented are worse than no rules, because they give the false impression of safety while providing none.

This project runs `check_lessons_landings.sh` — a CI job that reads the "structural countermeasures" section of every incident analysis and verifies that the referenced implementation files actually exist in the repository. A countermeasure that points to a nonexistent file fails CI. You cannot fossilize a fix.

**Analysis without implementation is fiction. Implementation without verification is hope.**

---

### Thesis 5: Rules that aren't read don't exist

The main instruction file (`CLAUDE.md`) has a hard line limit of 250 lines, enforced by CI. If you exceed it, the build fails. This is not arbitrary.

An AI agent that receives a 2,000-line instruction file will not read all of it consistently. It will weight the top, drift on the middle, and miss the bottom. Rules buried in prose disappear. The format of a rule determines whether it will be followed.

This project has specific formatting requirements for rules:
- Tables over prose (LLMs comply more reliably with tabular formats)
- Every rule has a "do this instead" column, not just a prohibition
- Abstract rules always carry one concrete example — a ✅ and an ❌
- The same rule never appears in two files (duplication causes drift)

The bootstrap script (`session_bootstrap.sh`) loads context from exactly four files at session start, no more. The startup summary is one line. The goal is zero friction between "session started" and "agent understands its constraints."

**A rule that cannot be read in context is a rule that will not be followed.**

---

### The architecture underneath

These five theses are not independent ideas. They form a system:

```
Physical completion gate  ─────────── prevents "done" drift
Physical countermeasures  ─────────── prevents rule theater
Explicit role enforcement  ─────────── prevents boundary violations
Five-why structural fixes  ─────────── prevents recurring failures
Readable, enforced rules   ─────────── prevents invisible decay
```

Each element reinforces the others. A five-why analysis is useless if the countermeasures exist only as text. Physical countermeasures are useless if the roles are so blurred that nobody knows who is responsible for enforcing them. Explicit roles are useless if "done" can be declared before the system has seen proof.

This is a philosophy of feedback loops. Every rule either closes a loop or it doesn't belong in the system.

---

### A note on the word "physical"

Throughout this document, I use "physical" to mean: *enforced by the system, not by intention.*

A physical gate is a git hook that rejects a commit. A physical boundary is an IAM Deny that makes an action impossible. A physical completion is a CI job that verifies a file exists. These things happen whether or not anyone remembers to check.

The opposite of physical is *soft*: a guideline, a note, a reminder, a "we should." Soft rules have their place in early exploration. They have no place in a production system operated in part by AI agents.

The shift from soft to physical is the central discipline of this development practice. Everything else follows from it.

---

## Part II — 日本語訳

### 「気をつける」という問題

AIと開発を始めた頃、私はこんなルールを作った。*共有ファイルを編集するときは気をつける。*

うまくいかなかった。

半年後、ルールは変わっていた。編集する前に `WORKING.md` への宣言が必要。宣言なしで同名ファイルを触ると、システムが処理を拒否する。警告でも、ドキュメントのメモでもなく、システム自体が拒む。

目的は同じだった。結果はまったく違った。

この2つのルールの距離が、このドキュメントの哲学のすべてだ。

---

### テーゼ1：「完了」は感覚ではなく、物理的な状態だ

ソフトウェア開発で最も危険な言葉は「完了」だ。

完了とは、本番URLをブラウザで確認し、HTTPステータスとタイムスタンプをgitにコミットした状態だ。CloudWatchに新しいエラーがない状態だ。デプロイ後の動作確認をスケジューラーに登録した状態だ。

完了ではないもの：
- コードが書けた
- PRがマージされた
- CIがグリーンになった
- ローカルテストが通った

これらはすべて、完了に至るためのチェックポイントだ。どれも完了ではない。

当たり前に聞こえる。当たり前ではない。プレッシャーの下で、「CIがグリーン」は「リリースした」になる。その証拠から思い込みへのスライドが、本番障害の住処だ。

解決策は注意力ではない。注意力は対策ではなく、願いだ。解決策は、証拠なしに「完了」を宣言できなくする仕組みだ。このシステムでは、`feat:`/`fix:`/`perf:` のコミットは `Verified: <url>:<status>:<timestamp>` 行がなければgitフックに弾かれる。完了スクリプト（`done.sh`）は本番URLを要求する。システムが証拠を見るまで、「完了」という言葉はシステムから出てこない。

**完了は宣言するものではなく、確認するものだ。**

---

### テーゼ2：「気をつける」は対策ではない

インシデントのたびに、「Xに気をつける」というルールを書きたくなる衝動がある。

このプロジェクトでは、その衝動は禁止されている。

「気をつける」「注意する」「忘れない」── これらは対策ではない。ルールの形をした願いだ。LLMはそれを無視する。人間もストレス下では無視する。そのルールはないも同然だ。

このプロジェクトにはCI（`check_soft_language.sh`）がある。ルールファイルを文字通りgrepして「気を付ける」「注意する」「確認する」といった言葉を見つけたらビルドを落とす。CIゲート、gitフック、メトリクス閾値、スケジュール検証のいずれかで表現できない対策は、対策ではない。装飾だ。

本物の対策は観測可能で強制可能だ。システムがそれを見るか、カウントされない。

この規律が求めるのは不快な問いだ。何かが壊れたとき、本能はメモを追加することだ。正しい対応は：*これを防ぐ物理的な仕組みは何か？* そして、その仕組みを作ることだ。

**テキストだけで存在するルールは、いつか必ず破られる。**

---

### テーゼ3：役割は明文化され、強制されなければならない

役割が曖昧なとき、AIシステムは予測可能な方法で失敗する。コードを書くエージェントがそれをマージもでき、運用観測もでき、インフラも変更できる環境では、「タスクをこなす」と「不可逆な操作をする」の境界が消える。

このシステムでは、役割は「説明される」のではなく「強制される」：

- **Codeセッション**はコードを書く。マージしない。デプロイしない。PRを開いてexitする。
- **Dispatch（調整役）**はCIを確認し、マージし、次のタスクをキューする。コードを書かない。
- **Scheduler**はデプロイ後の動作を検証し、問題があれば新しいタスクを積む。判断しない。
- **AWS MCP**は観測専用だ。`lambda:UpdateFunctionCode` は実行できない。IAM Denyがこれを物理的に不可能にしている。

役割の境界は思想ではなく、仕組みだ。

**役割の明確さは官僚主義ではない。信頼できる協働の基盤だ。**

---

### テーゼ4：パッチではなく、なぜなぜ5回

何かが壊れたとき、最初の本能は症状を修正することだ。nullチェックを追加する。例外をキャッチする。リトライ回数を増やす。

このプロジェクトはもっと難しいことを要求する：構造的な原因に達するまで5回連続のなぜなぜ、そして物理化できる対策を3つ以上。

テストは単純だ：*この修正があっても、同じ失敗が再び起きうるか？* もしYesなら、修正は応急処置で分析は不完全だ。

しかしより陰湿な失敗パターンがある：分析を書いて、修正を実装しないことだ。書かれたが実装されないルールは、ルールがないより悪い。安全の幻想を与えながら、実際には何も守らない。

このプロジェクトには`check_lessons_landings.sh`がある。過去のインシデント分析の「仕組み的対策」セクションを読み、参照された実装ファイルがリポジトリに実際に存在するかCIで物理検査する。存在しないファイルを指す対策はCIを落とす。対策を化石化できない。

**分析なき実装はギャンブルだ。実装なき分析はフィクションだ。検証なき実装は希望だ。**

---

### テーゼ5：読まれないルールは存在しない

主要な指示ファイル（`CLAUDE.md`）には250行のハード上限があり、CIで強制される。超えるとビルドが落ちる。これは恣意的ではない。

2,000行の指示ファイルを受け取ったAIエージェントは、一貫して全部を読まない。冒頭に重みをかけ、中盤で漂い、末尾を見逃す。散文に埋まったルールは消える。ルールの形式が、そのルールが守られるかどうかを決める。

ルールには特定のフォーマット要件がある：散文より表形式。禁止だけでなく「代わりにこれをする」列が必ず存在する。抽象ルールには必ず1つの具体例（✅と❌のペア）。同じルールは2つのファイルに書かない（重複はdriftを生む）。

起動スクリプトはセッション開始時に正確に4ファイルだけを読む。起動サマリは1行だ。目的はゼロ摩擦、つまり「セッション開始」から「制約を理解している」への距離をゼロにすることだ。

**文脈の中で読めないルールは、守られないルールだ。**

---

### この哲学の使い方

これは実装手順書ではない。実装は各プロジェクトに依存する。

これは問いかけだ。

あなたのシステムで「完了」は何を意味するか？ それは証明可能か？  
あなたのルールに「気をつける」は含まれていないか？  
あなたのAIエージェントの役割は、テキストで書かれているだけか、強制されているか？  
あなたの最後のインシデント分析は、実装された対策を持つか？  
あなたの指示ファイルは、エージェントが実際に読める長さか？

これらの問いに「はい」と答えられるとき、あなたはAIと開発している。それ以外のとき、AIにコードを書かせているが、AIとともに開発はしていない。

---

*"Be careful" is not a system. This is.*
