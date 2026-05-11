#!/bin/bash
# done.sh — タスク完了処理スクリプト（冪等 + 動作確認内蔵）
#
# このスクリプトの目的:
#   CLAUDE.md「完了 = 動作確認済み」ルールを物理化する。
#   verify_target 省略時は git push のみ（verification なし）。
#   verification 失敗 → exit 1 で「完了」として扱わない。
#
# 使い方:
#   bash done.sh TASK-123                                — 管理ファイル更新のみ
#   bash done.sh TASK-123 lambda:my-function             — CloudWatch 直近5分エラー検出
#   bash done.sh TASK-123 url:https://your-app.com/      — 本番URL HTTP 200確認
#
# セットアップ前に変更すべき変数:
#   APP_URL          本番URL（デフォルト動作確認先）
#   AWS_REGION       CloudWatch を引く AWS リージョン
#   PII_GREP_PATTERN セキュリティ系タスクで本番レスポンス本文を grep する正規表現
#                    （自分の名前・メールアドレスなど。漏洩確認用）
#
# セキュリティ系タスク（TASK_ID または VERIFY_TARGET に security/pii を含む）の場合、
# url: 検証時に curl で取得したレスポンス本文を PII grep し、マッチ 0 件でない限り exit 1。

set +e

# ============================================================================
# 設定（プロジェクトごとに書き換える）
# ============================================================================
# APP_URL: 本番URLを環境変数またはここに直接書く（例: https://yourapp.com/）
# 未設定のまま url: 検証を実行するとエラーになります
APP_URL="${APP_URL:-}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
# 自分の名前・メールなど、本番レスポンスに絶対漏れてはいけない文字列を grep -i パターンで列挙
# 例: "myname\|my\.email@example\.com"
PII_GREP_PATTERN="${PII_GREP_PATTERN:-}"

# ============================================================================
# 引数
# ============================================================================
TASK_ID=${1:?タスクIDを指定してください（例: bash done.sh TASK-123 url:https://your-app.com/）}
VERIFY_TARGET=${2:-}

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== ${TASK_ID} 完了処理開始 ==="

# セキュリティ系タスクかどうか判定
IS_SECURITY=0
case "$(echo "${TASK_ID} ${VERIFY_TARGET}" | tr '[:upper:]' '[:lower:]')" in
  *security*|*pii*) IS_SECURITY=1 ;;
esac

# 最新を取得
git pull --rebase origin main 2>/dev/null || echo "pull failed, continuing"

# WORKING.md と TASKS.md から該当行を削除
# macOS BSD sed 互換のため -i '' を使用。Linux sed の場合は -i に置き換える
[ -f WORKING.md ] && sed -i '' "/${TASK_ID}/d" WORKING.md
[ -f TASKS.md ] && sed -i '' "/| ${TASK_ID} /d" TASKS.md

# 削除後の状態確認
echo ""
echo "--- WORKING.md 現在着手中 ---"
[ -f WORKING.md ] && awk '/## 現在着手中/{p=1} p' WORKING.md | grep "^|" | grep -v "タスク名" || echo "（なし）"

echo ""
echo "--- TASKS.md 残タスク ---"
[ -f TASKS.md ] && grep "^| " TASKS.md | head -10 || echo "（なし or TASKS.md 未作成）"

# Verified 行を保持する変数（検証成功時に追記）
VERIFIED_LINE=""

# ============================================================================
# main マージ確認 (「完了 = main マージ済み + deploy 完了」の物理化)
# ============================================================================
echo ""
echo "=== main ブランチマージ確認 ==="
git fetch origin main 2>/dev/null || echo "fetch failed, continuing"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CURRENT_HASH=$(git rev-parse HEAD 2>/dev/null)

if [ "$CURRENT_BRANCH" = "main" ] || git merge-base --is-ancestor "$CURRENT_HASH" origin/main 2>/dev/null; then
    MAIN_HEAD=$(git log origin/main --oneline | head -3)
    echo "  ✅ Verified-Deploy: git log main shows ${CURRENT_HASH:0:7} @ $(date '+%Y-%m-%d %H:%M JST')"
    echo "  main 直近 3 件:"
    echo "$MAIN_HEAD" | sed 's/^/     /'
else
    echo "  ❌ 現在の HEAD (${CURRENT_HASH:0:7}) は origin/main に含まれていない"
    echo "  現在ブランチ: $CURRENT_BRANCH"
    echo ""
    echo "  → feature branch push のみ。main へのマージ + deploy 完了後に done.sh を再実行してください。"
    echo "  確認コマンド: git log origin/main --oneline | head -5"
    echo ""
    echo "  ⚠️  CLAUDE.md「完了 = main マージ済み + deploy 完了」未達 — 完了として扱わない。"
    exit 1
fi

# ============================================================================
# 動作確認ステージ (「完了 = 動作確認済み」の物理化)
# ============================================================================
if [ -n "$VERIFY_TARGET" ]; then
    echo ""
    echo "=== 動作確認: $VERIFY_TARGET ==="
    NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    case "$VERIFY_TARGET" in
        lambda:*)
            FN=${VERIFY_TARGET#lambda:}
            echo "→ CloudWatch 直近 5 分のエラーログ確認 ($FN)"
            START=$(($(date +%s) - 300))000
            LOG_GROUP="/aws/lambda/$FN"
            ERRORS=$(aws logs filter-log-events \
                --log-group-name "$LOG_GROUP" \
                --start-time $START \
                --filter-pattern '?ERROR ?Error ?Traceback ?NameError ?TypeError' \
                --query 'events[*].message' \
                --output text \
                --max-items 5 \
                --region "$AWS_REGION" 2>/dev/null | head -20)
            if [ -z "$ERRORS" ]; then
                echo "  ✅ 直近 5 分にエラーなし"
                VERIFIED_LINE="Verified: ${VERIFY_TARGET}:no-recent-errors:${NOW_UTC}"
            else
                echo "  ❌ エラー検出:"
                echo "$ERRORS" | sed 's/^/     /'
                echo ""
                echo "  ⚠️  完了として扱わない方が良い。CloudWatch を再確認すること。"
                exit 1
            fi
            ;;
        url:*)
            URL=${VERIFY_TARGET#url:}
            # url: のみ指定でデフォルトURLを使う場合
            if [ "$URL" = "" ] || [ "$URL" = "url:" ]; then
                if [ -z "$APP_URL" ]; then
                    echo "  ❌ APP_URL が未設定です。"
                    echo "     done.sh の APP_URL= に本番URLを設定するか、"
                    echo "     環境変数 APP_URL=https://yourapp.com/ を指定してください。"
                    echo "     例: APP_URL=https://yourapp.com/ bash done.sh TASK-123 url:"
                    exit 1
                fi
                URL="$APP_URL"
            fi
            echo "→ 本番 URL 200 OK 確認: $URL"
            BODY_FILE="$(mktemp)"
            CODE=$(curl -s -o "$BODY_FILE" -w "%{http_code}" --max-time 10 "$URL")
            if [ "$CODE" != "200" ]; then
                echo "  ❌ HTTP $CODE — 本番に反映されていない可能性"
                rm -f "$BODY_FILE"
                exit 1
            fi
            echo "  ✅ HTTP $CODE"

            # セキュリティ系タスクのときは PII grep で内容も検証する
            if [ "$IS_SECURITY" = "1" ] && [ -n "$PII_GREP_PATTERN" ]; then
                echo "  → セキュリティ系: レスポンス本文の PII grep を実行"
                PII_HITS=$(grep -ic "$PII_GREP_PATTERN" "$BODY_FILE" || true)
                if [ "${PII_HITS:-0}" -gt 0 ]; then
                    echo "  ❌ PII 検出: ${PII_HITS} 件"
                    grep -in "$PII_GREP_PATTERN" "$BODY_FILE" | head -5 | sed 's/^/     /'
                    rm -f "$BODY_FILE"
                    exit 1
                fi
                echo "  ✅ レスポンス本文に PII なし"
                VERIFIED_LINE="Verified: ${VERIFY_TARGET}:HTTP200+pii-free:${NOW_UTC}"
            else
                VERIFIED_LINE="Verified: ${VERIFY_TARGET}:HTTP${CODE}:${NOW_UTC}"
            fi
            rm -f "$BODY_FILE"
            ;;
        *)
            echo "  ⚠️  unknown verify_target format: $VERIFY_TARGET"
            echo "     supported: lambda:<function-name> / url:<https-url>"
            echo "     プロジェクト固有の検証モード（例: API 状態確認・特定 record 検証）を"
            echo "     追加する場合はこの case 文に新しいパターンを足してください。"
            ;;
    esac
fi

# ============================================================================
# コミット & プッシュ
# ============================================================================
COMMIT_MSG="done: ${TASK_ID} 管理ファイル更新"
if [ -n "$VERIFIED_LINE" ]; then
    COMMIT_MSG="${COMMIT_MSG}

${VERIFIED_LINE}"
fi
git add WORKING.md TASKS.md 2>/dev/null
git commit -m "$COMMIT_MSG" 2>/dev/null || echo "nothing to commit"
git push 2>/dev/null || echo "push failed"

echo ""
echo "✅ ${TASK_ID} 完了。HISTORY.md への詳細記録を忘れずに。"
