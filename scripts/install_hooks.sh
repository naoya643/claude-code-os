#!/bin/bash
# install_hooks.sh — Claude OS の物理ガード（git hook）を当該リポジトリにインストールする。
#
# 何が入るか:
#   .git/hooks/pre-commit   →  PII / secret / deploy.sh 直接実行 / git エラー黙殺 / CLAUDE.md 250 行 をチェック
#   .git/hooks/commit-msg   →  feat:/fix:/perf: の commit に Verified: 行を必須化
#   .git/hooks/pre-push     →  main への直接 push を reject
#
# 冪等: 何度実行しても OK。実行ごとに上書きされる。
#
# 使い方:
#   bash scripts/install_hooks.sh
#
# カスタマイズ:
#   PII grep パターンは .claude-os.env に PII_GREP_PATTERN として書く（任意）。
#   ファイルが存在しない場合は PII チェックは skip される（false positive を出さないため）。
#   例:
#       echo 'PII_GREP_PATTERN="myname\\|my\\.email@example\\.com"' > .claude-os.env
#
# bypass（緊急時のみ）:
#   git commit --no-verify  / git push --no-verify

set -e

# --- worktree 対応 -----------------------------------------------------------
# 通常 clone: $REPO_ROOT/.git/hooks
# worktree:   $REPO_ROOT/.git は file。GIT_DIR は別ディレクトリ。
#             共通 hook は --git-common-dir 配下に置く必要がある。
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null) || {
  echo "❌ ここは git リポジトリではありません。先に 'git init' してください。"
  exit 1
}
if [[ "$GIT_COMMON_DIR" != /* ]]; then
  GIT_COMMON_DIR="$(pwd)/$GIT_COMMON_DIR"
fi
HOOK_DIR="$GIT_COMMON_DIR/hooks"
mkdir -p "$HOOK_DIR"

# --- pre-commit --------------------------------------------------------------
cat > "$HOOK_DIR/pre-commit" <<'HOOK'
#!/bin/bash
# AUTO-INSTALLED by claude-os/scripts/install_hooks.sh
# Blocks commits that introduce: PII / live secrets / deploy.sh direct call /
# git error suppression / CLAUDE.md 250-line overrun.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ---- (1) PII (owner identity) を直書きしていないか ----
# .claude-os.env に PII_GREP_PATTERN が定義されていれば使う。無ければ skip。
PII_PATTERN=""
if [ -f "$REPO_ROOT/.claude-os.env" ]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.claude-os.env"
  PII_PATTERN="${PII_GREP_PATTERN:-}"
fi
if [ -n "$PII_PATTERN" ]; then
  PII_HITS=$(git diff --cached --name-only --diff-filter=ACMR \
    | xargs -I{} sh -c "grep -lE \"$PII_PATTERN\" \"{}\" 2>/dev/null" 2>/dev/null \
    | grep -v "^\.claude-os\.env$" \
    || true)
  if [ -n "$PII_HITS" ]; then
    echo "❌ pre-commit blocked: PII pattern ($PII_PATTERN) を含むファイルが staged されています"
    echo "$PII_HITS" | sed 's/^/   /'
    echo ""
    echo "   対処: 該当箇所をプレースホルダー (<owner-email> 等) に置換してから commit"
    echo "   bypass (緊急時のみ): git commit --no-verify"
    exit 1
  fi
fi

# ---- (2) Live secret pattern scan ----
# よくある live secret のプレフィクスを検出。誤検知より検出漏れを許容しないスタンス。
SECRET_HITS=$(git diff --cached -U0 --diff-filter=ACMR \
  | grep -E '^\+[^+]' \
  | grep -oE '(ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|xoxb-[0-9]+-[0-9]+-[A-Za-z0-9]+|sk-ant-[A-Za-z0-9_-]{30,}|AKIA[0-9A-Z]{16}|hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+)' \
  | head -3 || true)
if [ -n "$SECRET_HITS" ]; then
  echo "❌ pre-commit blocked: live secret パターンを検出"
  echo "$SECRET_HITS" | sed 's/^/   /'
  echo ""
  echo "   検出パターン: GitHub PAT / Slack token / OpenAI key / Anthropic key / AWS key / Slack webhook"
  echo "   対処: secret を git 履歴に入れず、環境変数 or secret manager 経由にする"
  echo "   既に commit / push してしまった場合は rotate してから git history rewrite"
  echo "   bypass (緊急時のみ): git commit --no-verify"
  exit 1
fi

# ---- (3) deploy.sh 直接実行禁止 ----
# CLAUDE.md「deploy.sh 直接実行禁止」の物理ガード。
# *.md / .github/workflows/ / install_hooks.sh は除外（参照・説明する側）
DEPLOY_HITS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "$f" | grep -qE '\.md$|^\.github/workflows/|install_hooks\.sh$' && continue
  hits=$(git diff --cached -U0 -- "$f" 2>/dev/null \
    | grep -E '^\+[^+]' \
    | grep -E '(bash|sh|\./)[[:space:]]*deploy\.sh' \
    || true)
  DEPLOY_HITS="${DEPLOY_HITS}${hits}"
done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
if [ -n "$DEPLOY_HITS" ]; then
  echo "❌ pre-commit blocked: deploy.sh の直接実行は禁止"
  echo "$DEPLOY_HITS" | head -5 | sed 's/^/   /'
  echo ""
  echo "   理由: 「完了 = 動作確認済」を担保するには、deploy は GitHub Actions に集約する"
  echo "   代替: git push → CI が deploy workflow を発火"
  echo "   bypass (緊急時のみ): git commit --no-verify"
  exit 1
fi

# ---- (4) git pull/push の || true 黙殺禁止 ----
GIT_SILENCE_HITS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "$f" | grep -qE '\.sh$' || continue
  echo "$f" | grep -qE '(^|/)test|install_hooks\.sh$' && continue
  hits=$(git diff --cached -U0 -- "$f" 2>/dev/null \
    | grep -E '^\+[^+]' \
    | grep -E 'git[[:space:]]+(pull|push)[[:space:]]*(\|\||&&)[[:space:]]*(true|:)' \
    || true)
  GIT_SILENCE_HITS="${GIT_SILENCE_HITS}${hits}"
done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
if [ -n "$GIT_SILENCE_HITS" ]; then
  echo "❌ pre-commit blocked: 'git pull/push || true' の終了コード黙殺は禁止"
  echo "$GIT_SILENCE_HITS" | head -5 | sed 's/^/   /'
  echo ""
  echo "   正しい方法:"
  echo "     if ! git pull; then echo 'pull failed'; exit 1; fi"
  echo "   bypass (緊急時のみ): git commit --no-verify"
  exit 1
fi

# ---- (5) CLAUDE.md 250 行上限 ----
if git diff --cached --name-only | grep -q '^CLAUDE\.md$'; then
  LINES=$(git show :CLAUDE.md 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$LINES" ] && [ "$LINES" -gt 250 ]; then
    echo "❌ pre-commit blocked: CLAUDE.md が ${LINES} 行 (上限 250 行)"
    echo ""
    echo "   超過分を docs/rules/*.md へ外出ししてから commit してください"
    echo "   理由: LLM は長文の指示ファイルを後半ほど守らない（実測）"
    echo "   bypass (緊急時のみ): git commit --no-verify"
    exit 1
  fi
fi

exit 0
HOOK

# --- commit-msg --------------------------------------------------------------
cat > "$HOOK_DIR/commit-msg" <<'MSGHOOK'
#!/bin/bash
# AUTO-INSTALLED by claude-os/scripts/install_hooks.sh
# Require `Verified: <url>:<status>:<JST_timestamp>` line on feat:/fix:/perf: commits.
# Skips: wip:, docs:, chore:, test:, refactor:, style:, build:, ci:, revert:

MSG_FILE="$1"
[ -z "$MSG_FILE" ] && exit 0
[ ! -f "$MSG_FILE" ] && exit 0

FIRST_LINE=$(grep -v '^#' "$MSG_FILE" | head -n 1)

SKIP_RE='^[[:space:]]*(wip|docs|chore|test|refactor|style|build|ci|revert):'
if echo "$FIRST_LINE" | grep -qiE "$SKIP_RE"; then
  exit 0
fi

REQUIRE_RE='^[[:space:]]*(feat|fix|perf):'
if ! echo "$FIRST_LINE" | grep -qiE "$REQUIRE_RE"; then
  exit 0
fi

if ! grep -qE '^Verified: ' "$MSG_FILE"; then
  echo "❌ commit-msg blocked: '$FIRST_LINE' には 'Verified:' 行が必須です"
  echo "   format: Verified: <url>:<http_status>:<JST_timestamp>"
  echo "   helper: bash done.sh <task_id> url:https://your-app.com/"
  echo "   skip prefixes: wip docs chore test refactor style build ci revert"
  echo "   bypass (緊急時のみ): git commit --no-verify"
  exit 1
fi

# 2xx でなければ warn のみ
if ! grep -qE '^Verified: .*:2[0-9]{2}:' "$MSG_FILE"; then
  echo "⚠️  Verified: 行はあるが HTTP status が 2xx ではありません。要再確認。"
fi

exit 0
MSGHOOK

# --- pre-push ----------------------------------------------------------------
cat > "$HOOK_DIR/pre-push" <<'PUSHOOK'
#!/bin/bash
# AUTO-INSTALLED by claude-os/scripts/install_hooks.sh
# Reject direct push to main / master.
# Escape: ALLOW_MAIN_PUSH=1 git push  (for bootstrap-sync commits only)

ZERO="0000000000000000000000000000000000000000"
while read -r local_ref local_sha remote_ref remote_sha; do
  case "$remote_ref" in
    refs/heads/main|refs/heads/master) ;;
    *) continue ;;
  esac
  [ "$local_sha" = "$ZERO" ] && continue  # branch deletion

  if [ "${ALLOW_MAIN_PUSH:-0}" = "1" ]; then
    if [ "$remote_sha" = "$ZERO" ]; then
      RANGE="${local_sha}~1..${local_sha}"
    else
      RANGE="${remote_sha}..${local_sha}"
    fi
    NON_BOOTSTRAP=$(git log --format='%s' "$RANGE" 2>/dev/null \
      | grep -vE '^chore:[[:space:]]*bootstrap sync' | head -3 || true)
    if [ -z "$NON_BOOTSTRAP" ]; then
      continue
    fi
    echo "❌ pre-push blocked: ALLOW_MAIN_PUSH=1 escape は 'chore: bootstrap sync' commit にのみ有効" >&2
    echo "$NON_BOOTSTRAP" | sed 's/^/   /' >&2
    exit 1
  fi

  echo "❌ pre-push blocked: main / master への直接 push は禁止です" >&2
  echo "   実コード変更は feature branch + PR 経由で行ってください:" >&2
  echo "     git checkout -b feature/<task>; git push origin feature/<task>; gh pr create ..." >&2
  echo "   bypass (緊急時のみ): git push --no-verify" >&2
  exit 1
done

exit 0
PUSHOOK

chmod +x "$HOOK_DIR/pre-commit" "$HOOK_DIR/commit-msg" "$HOOK_DIR/pre-push"

echo "✅ installed: $HOOK_DIR/pre-commit"
echo "✅ installed: $HOOK_DIR/commit-msg"
echo "✅ installed: $HOOK_DIR/pre-push"
echo ""
echo "From now on, commits/pushes in this clone will fail if:"
echo "  - PII pattern (.claude-os.env の PII_GREP_PATTERN) が staged された"
echo "  - live secret pattern (GitHub PAT / Slack token / API key 等) が staged された"
echo "  - deploy.sh の直接実行コードが staged された"
echo "  - 'git pull/push || true' のエラー黙殺が staged された"
echo "  - CLAUDE.md が 250 行を超えた"
echo "  - feat:/fix:/perf: の commit に 'Verified:' 行が無い"
echo "  - main / master へ直接 push しようとした"
echo ""
echo "Bypass (real emergency only): git commit --no-verify / git push --no-verify"
