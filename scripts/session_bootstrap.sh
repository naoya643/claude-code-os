#!/bin/bash
# session_bootstrap.sh — Claude Code セッション起動時の最低限のチェック
#
# CLAUDE.md が「セッション開始時に必ず最初に実行すること」として参照するスクリプト。
# 何をやるか:
#   1. main を最新化（rebase）
#   2. CLAUDE.md の直近変更を表示
#   3. WORKING.md の現在着手中タスクを表示
#   4. 並走違反チェック（[Code] 行が 2 件以上なら ERROR）
#   5. WORKING.md の stale 行を削除（8 時間以上前の行）
#
# 使い方:
#   bash scripts/session_bootstrap.sh
#
# 自プロジェクトに合わせて成長させる:
#   stale TTL を変えたい場合は STALE_HOURS を編集
#   並走上限を変えたい場合は MAX_CODE_SESSIONS を編集
#   追加チェック（CI failure / open PR 一覧 等）を入れたい場合は本ファイル末尾に追記

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "❌ ここは git リポジトリではありません。先に 'git init' してください。"
  exit 1
}
cd "$REPO_ROOT"

STALE_HOURS="${STALE_HOURS:-8}"
MAX_CODE_SESSIONS="${MAX_CODE_SESSIONS:-1}"
BOOTSTRAP_EXIT=0

echo "=== 起動チェック開始 ($(date '+%Y-%m-%d %H:%M JST')) ==="

# ---- 1. main を最新化 ----
echo ""
echo "--- git pull --rebase origin main ---"
if git remote get-url origin >/dev/null 2>&1; then
  if ! git pull --rebase origin main 2>&1; then
    echo "⚠️  git pull --rebase origin main に失敗しました"
    BOOTSTRAP_EXIT=1
  fi
else
  echo "(origin remote 未設定 — skip)"
fi

# ---- 2. CLAUDE.md の直近変更 ----
if [ -f CLAUDE.md ]; then
  echo ""
  echo "--- CLAUDE.md 直近の変更 ---"
  git log --oneline -3 -- CLAUDE.md 2>/dev/null || echo "（履歴なし）"
fi

# ---- 3. WORKING.md 着手中 ----
if [ -f WORKING.md ]; then
  echo ""
  echo "--- WORKING.md 現在着手中 ---"
  awk '/## 現在着手中/{p=1; next} /^## /{p=0} p' WORKING.md \
    | grep "^|" | grep -vE "タスク名|---" \
    || echo "（着手中タスクなし）"
fi

# ---- 4. 並走違反チェック ----
if [ -f WORKING.md ]; then
  # grep -c は no-match 時に "0" を出して exit 1 になるので || true で吸収。
  # 念のため数字以外を除去して整形。
  CODE_COUNT=$(awk '/## 現在着手中/{p=1; next} /^## /{p=0} p' WORKING.md \
    | grep -cE "^\| \[Code\]" 2>/dev/null || true)
  CODE_COUNT=$(printf '%s' "$CODE_COUNT" | tr -dc '0-9' | head -c 4)
  CODE_COUNT="${CODE_COUNT:-0}"
  if [ "$CODE_COUNT" -gt "$MAX_CODE_SESSIONS" ]; then
    echo ""
    echo "⚠️  ERROR: [Code] 行が ${CODE_COUNT} 件あります。同時起動上限は ${MAX_CODE_SESSIONS} 件です。"
    echo "   前セッションの完了を確認するか、必要なら手動で WORKING.md から削除してください。"
    BOOTSTRAP_EXIT=1
  fi
fi

# ---- 5. stale 行の削除（${STALE_HOURS} 時間以上前）----
if [ -f WORKING.md ] && command -v python3 >/dev/null 2>&1; then
  STALE_BEFORE="$STALE_HOURS" python3 - <<'PY'
import os, re
from datetime import datetime, timedelta, timezone

JST = timezone(timedelta(hours=9))
hours = int(os.environ.get("STALE_BEFORE", "8"))
threshold = datetime.now(JST) - timedelta(hours=hours)

with open("WORKING.md", encoding="utf-8") as f:
    lines = f.readlines()

removed = []
kept = []
in_section = False
for line in lines:
    stripped = line.rstrip("\n")
    if stripped.startswith("## 現在着手中"):
        in_section = True
        kept.append(line)
        continue
    if in_section and stripped.startswith("## "):
        in_section = False
    if not in_section or not stripped.startswith("|"):
        kept.append(line)
        continue
    m = re.search(r"(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s*JST", stripped)
    if not m:
        kept.append(line)
        continue
    try:
        start = datetime.strptime(m.group(1).strip(), "%Y-%m-%d %H:%M").replace(tzinfo=JST)
    except ValueError:
        kept.append(line)
        continue
    if start < threshold:
        removed.append(stripped)
    else:
        kept.append(line)

if removed:
    with open("WORKING.md", "w", encoding="utf-8") as f:
        f.writelines(kept)
    print(f"\n--- WORKING.md stale 削除 ({hours}h TTL) ---")
    for r in removed:
        print(f"  removed: {r[:120]}")
PY
fi

# ---- 完了サマリ ----
echo ""
echo "─────────────────────────────────────────"
if [ "$BOOTSTRAP_EXIT" -eq 0 ]; then
  echo "✅ 起動チェック完了 ($(date '+%Y-%m-%d %H:%M JST'))"
else
  echo "❌ 起動チェック異常終了 ($(date '+%Y-%m-%d %H:%M JST')) — exit ${BOOTSTRAP_EXIT}"
  echo "   詳細は ⚠️ 行を参照"
fi
echo "─────────────────────────────────────────"

exit "$BOOTSTRAP_EXIT"
