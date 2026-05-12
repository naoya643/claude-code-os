#!/bin/bash
# タスク完了処理スクリプト（プレースホルダー版）
#
# 使い方:
#   bash done.sh <TASK_ID>                          — 管理ファイル更新のみ
#   bash done.sh <TASK_ID> url:https://example.com/ — 本番 URL の HTTP 200 確認
#   bash done.sh <TASK_ID> log:<path>               — ログファイルにエラー行が無いか確認
#
# 「完了 = 動作確認済」ルールを物理化するため verification を組み込む。
# verification 失敗 → exit 1 で done として扱わない。
#
# プレースホルダー（自分のプロジェクトで埋めること）:
#   {{PROD_URL}}      — 本番 URL のデフォルト値
#   {{TEST_COMMAND}}  — テスト実行コマンド（例: `pytest -q` / `npm test --silent`）
#   {{LOG_GREP_CMD}}  — ログ収集コマンド（例: aws / gcloud / kubectl logs ...）

set +e

TASK_ID=${1:?タスク ID を指定してください（例: bash done.sh T028 url:https://example.com/）}
VERIFY_TARGET=${2:-}

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/{{YOUR_PROJECT_NAME}}")"

echo "=== ${TASK_ID} 完了処理開始 ==="

# 1. 最新を取得
git pull --rebase origin main 2>/dev/null || echo "pull failed, continuing"

# 2. WORKING.md と TASKS.md から該当行を削除
if [ -f WORKING.md ]; then
  sed -i.bak "/${TASK_ID}/d" WORKING.md && rm -f WORKING.md.bak
fi
if [ -f TASKS.md ]; then
  sed -i.bak "/| ${TASK_ID} /d" TASKS.md && rm -f TASKS.md.bak
fi

echo ""
echo "--- WORKING.md 現在着手中 ---"
awk '/## 現在着手中/{p=1} p' WORKING.md 2>/dev/null | grep "^|" | grep -v "タスク名" || echo "（なし）"

echo ""
echo "--- TASKS.md 残タスク ---"
grep "^| T" TASKS.md 2>/dev/null || echo "（なし）"

# 3. TODO / FIXME チェック（diff 範囲のみ）
echo ""
echo "--- TODO / FIXME チェック ---"
TODO_HITS=$(git diff origin/main..HEAD -- '*.py' '*.js' '*.ts' '*.tsx' '*.sh' 2>/dev/null \
  | grep -E '^\+.*(TODO|FIXME|XXX)' || true)
if [ -n "$TODO_HITS" ]; then
  echo "⚠️  新規 TODO / FIXME が含まれている:"
  echo "$TODO_HITS"
  echo "  → これらが意図的な保留である場合は本タスクに含めず、別タスク化することを推奨"
fi

# 4. テスト実行（プロジェクトに合わせて埋める）
echo ""
echo "--- テスト実行 ---"
# 例: pytest -q || { echo "❌ テスト失敗"; exit 1; }
# 例: npm test --silent || { echo "❌ テスト失敗"; exit 1; }
# {{TEST_COMMAND}} を埋めるか、テスト不要なら以下をコメントアウト
echo "（テストコマンド未設定: done.sh の {{TEST_COMMAND}} を埋めてください）"

# 5. 動作確認（VERIFY_TARGET が指定された場合のみ）
VERIFIED_LINE=""
case "$VERIFY_TARGET" in
  url:*)
    URL="${VERIFY_TARGET#url:}"
    echo ""
    echo "--- URL 確認: $URL ---"
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || echo "000")
    if [ "$STATUS" = "200" ]; then
      JST_TS=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')
      VERIFIED_LINE="Verified: ${URL}:${STATUS}:${JST_TS}"
      echo "✅ $VERIFIED_LINE"
    else
      echo "❌ HTTP $STATUS （200 を期待）"
      exit 1
    fi
    ;;
  log:*)
    LOG_PATH="${VERIFY_TARGET#log:}"
    echo ""
    echo "--- ログ確認: $LOG_PATH ---"
    if grep -qE "(ERROR|FATAL|Exception)" "$LOG_PATH" 2>/dev/null; then
      echo "❌ ログにエラー行が含まれている"
      grep -E "(ERROR|FATAL|Exception)" "$LOG_PATH" | head -5
      exit 1
    fi
    JST_TS=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')
    VERIFIED_LINE="Verified: ${LOG_PATH}:no-errors:${JST_TS}"
    echo "✅ $VERIFIED_LINE"
    ;;
  "")
    echo "（verify_target 未指定: 実機確認をスキップ）"
    ;;
  *)
    echo "未対応の verify_target: $VERIFY_TARGET"
    echo "対応形式: url:<URL> / log:<path>"
    exit 1
    ;;
esac

# 6. CI 確認（PR 番号が分かる場合のみ）
echo ""
echo "--- CI 確認 ---"
if command -v gh > /dev/null 2>&1; then
  PR_NUM=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number' 2>/dev/null || echo "")
  if [ -n "$PR_NUM" ]; then
    if [ -x guards/session/done-ci-check.sh ]; then
      bash guards/session/done-ci-check.sh "$PR_NUM" || {
        echo "❌ CI が green になっていない。修正してから再度 done.sh を実行する"
        exit 1
      }
    else
      echo "（guards/session/done-ci-check.sh が見つからない: BOOTH キットを参照）"
    fi
  else
    echo "（PR が見つからない: ローカル完了処理のみ）"
  fi
else
  echo "（gh CLI 未インストール: CI 確認スキップ）"
fi

# 7. commit / push
echo ""
echo "--- commit / push ---"
git add -A
COMMIT_MSG="done: ${TASK_ID}"
if [ -n "$VERIFIED_LINE" ]; then
  COMMIT_MSG="${COMMIT_MSG}

${VERIFIED_LINE}"
fi
git commit -m "$COMMIT_MSG" 2>/dev/null || echo "（commit する変更なし）"
git push 2>&1 | tail -3

echo ""
echo "=== ${TASK_ID} 完了処理終了 ==="
echo ""
echo "次のセッションで TASKS.md の次タスクに進む。"
