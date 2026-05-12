# Claude OSS セットアップガイド

Claude Code を始めたばかりの人向け。このキットを自プロジェクトに組み込む手順を説明します。

---

## 0. 前提

このキットを使うには以下が必要です:

| ツール | 用途 | 入っていない場合 |
|---|---|---|
| **Claude Code** | これを動かす本体 | [公式ドキュメント](https://docs.claude.com/claude-code) から install |
| **git** | バージョン管理 | macOS なら `xcode-select --install`、Linux は `apt install git` |
| **GitHub CLI** (`gh`) | PR 作成・CI 確認 | `brew install gh`（macOS） |
| **AWS CLI**（任意） | done.sh で CloudWatch 確認をするなら | `brew install awscli`（AWS 使わないなら不要） |
| **Python 3**（任意） | CI 用スクリプトを動かすなら | macOS 標準で入っているはず |

GitHub リポジトリは事前に作成しておいてください。リポジトリ名は何でも OK です。

---

## 1. ファイルをコピーする

このリポジトリをまるごとダウンロードするか、`claude-os/` ディレクトリだけ自プロジェクトにコピーします。

```bash
# 例: 自プロジェクトが ~/myapp/ にある場合
cd ~/myapp
cp -r /path/to/claude-os/* .   # CLAUDE.md / WORKING.md / done.sh / docs/ が展開される
```

確認:

```bash
ls -1
# 期待される出力例:
# CLAUDE.md
# README.md          ← 任意（消して構わない）
# WORKING.md
# docs/
# done.sh
# (自プロジェクトの既存ファイル...)
```

---

## 2. プレースホルダーを置換する

すべてのファイルにある `{{YOUR_*}}` を実値に書き換えます。

### 2-1. 置換するプレースホルダー一覧

| プレースホルダー | 何に置き換えるか | 例 |
|---|---|---|
| `{{YOUR_PROJECT_NAME}}` | プロジェクト名（小文字・スペースなし） | `myapp` |
| `{{YOUR_APP_URL}}` | 本番 URL | `https://myapp.com` |
| `{{YOUR_PROJECT_ID}}` | プロジェクトの短い ID | `P001` |
| `{{YOUR_CLAUDE_IAM_ARN}}` | AWS で Claude が使う IAM ユーザーの ARN（AWS 使わないなら無視） | `arn:aws:iam::123456789012:user/Claude` |
| `{{YOUR_USERNAME}}` | OS のユーザー名（絶対パス用） | `alice` |
| `{{YOUR_AWS_REGION}}` | AWS リージョン（AWS 使わないなら無視） | `us-east-1` |

### 2-2. 一括置換コマンド

macOS の場合（BSD sed）:

```bash
# プロジェクト名
grep -rl "{{YOUR_PROJECT_NAME}}" . --include="*.md" --include="*.sh" | xargs sed -i '' 's/{{YOUR_PROJECT_NAME}}/myapp/g'

# 本番 URL
grep -rl "{{YOUR_APP_URL}}" . --include="*.md" --include="*.sh" | xargs sed -i '' 's|{{YOUR_APP_URL}}|https://myapp.com|g'

# プロジェクト ID
grep -rl "{{YOUR_PROJECT_ID}}" . --include="*.md" --include="*.sh" | xargs sed -i '' 's/{{YOUR_PROJECT_ID}}/P001/g'

# ユーザー名
grep -rl "{{YOUR_USERNAME}}" . --include="*.md" --include="*.sh" | xargs sed -i '' "s/{{YOUR_USERNAME}}/$(whoami)/g"

# AWS リージョン
grep -rl "{{YOUR_AWS_REGION}}" . --include="*.md" --include="*.sh" | xargs sed -i '' 's/{{YOUR_AWS_REGION}}/us-east-1/g'

# AWS IAM ARN（AWS 使う場合のみ）
grep -rl "{{YOUR_CLAUDE_IAM_ARN}}" . --include="*.md" | xargs sed -i '' 's|{{YOUR_CLAUDE_IAM_ARN}}|arn:aws:iam::123456789012:user/Claude|g'
```

Linux の場合（GNU sed）は `sed -i ''` を `sed -i` に変更してください。

### 2-3. 置換できているか確認

```bash
grep -r "{{YOUR_" . --include="*.md" --include="*.sh"
# 何も表示されなければ OK
```

---

## 3. done.sh を実行可能にする

```bash
chmod +x done.sh
```

確認:

```bash
ls -l done.sh
# -rwxr-xr-x  ... done.sh   ← 'x' が付いていれば OK
```

---

## 4. done.sh をカスタマイズする

`done.sh` 冒頭の設定変数を確認します:

```bash
# done.sh の 20-30 行目あたり
APP_URL="${APP_URL:-https://myapp.com}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PII_GREP_PATTERN="${PII_GREP_PATTERN:-}"
```

### 4-1. PII grep パターンを設定する（推奨）

セキュリティ系タスクで「本番のレスポンス本文に自分の名前やメールアドレスが漏れていないか」を物理的にチェックしたい場合、`PII_GREP_PATTERN` を設定します:

```bash
PII_GREP_PATTERN="myname\|my\.email@example\.com"
```

設定しなくても動きますが、セキュリティ系タスク（タスク ID に `security` や `pii` を含む）の検証が弱くなります。

### 4-2. プロジェクト固有の検証モードを追加する

`done.sh` の case 文に新しい検証パターンを追加できます。例: トピック ID を渡して「AI 処理済みか」を確認する場合:

```bash
# done.sh の case 文の末尾、 *) の手前に追加
my-check:*)
    ID=${VERIFY_TARGET#my-check:}
    echo "→ API /api/check/${ID} で status=ready 確認"
    STATUS=$(curl -s "https://myapp.com/api/check/${ID}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('status'))")
    if [ "$STATUS" = "ready" ]; then
        echo "  ✅ status=ready"
        VERIFIED_LINE="Verified: ${VERIFY_TARGET}:status=ready:${NOW_UTC}"
    else
        echo "  ❌ status=$STATUS"
        exit 1
    fi
    ;;
```

---

## 5. bootstrap スクリプトを作る（任意・推奨）

CLAUDE.md は `bash ~/myapp/scripts/session_bootstrap.sh` を起動時に呼びます。最低限の雛形:

```bash
# scripts/session_bootstrap.sh （新規作成）
mkdir -p scripts
cat > scripts/session_bootstrap.sh <<'EOF'
#!/bin/bash
# 起動チェックスクリプト（最低限版）
set -e
cd "$(git rev-parse --show-toplevel)"

echo "=== 起動チェック開始 ==="

# 1. main を最新化
git pull --rebase origin main || { echo "git pull failed"; exit 1; }

# 2. CLAUDE.md の最近 commit を表示
echo ""
echo "--- CLAUDE.md 直近の変更 ---"
git log --oneline -3 -- CLAUDE.md

# 3. WORKING.md の着手中タスク一覧
echo ""
echo "--- WORKING.md 着手中 ---"
awk '/## 現在着手中/{p=1} p' WORKING.md | grep "^|" | grep -v "タスク名" || echo "（着手中タスクなし）"

# 4. 並走違反チェック (Code セッション 2 件以上は ERROR)
CODE_COUNT=$(grep -c "^| \[Code\]" WORKING.md 2>/dev/null || echo 0)
if [ "$CODE_COUNT" -gt 1 ]; then
    echo ""
    echo "⚠️ ERROR: [Code] 行が ${CODE_COUNT} 件あります。同時起動上限は 1 件です。"
    exit 1
fi

echo ""
echo "✅ 起動チェック完了"
EOF
chmod +x scripts/session_bootstrap.sh
```

stale 自動削除や salvage 機能を後から足していけます。

---

## 6. git hook を入れる（任意・強く推奨）

「完了の物理化」を CI / hook で守るための雛形:

```bash
# .githooks/commit-msg （新規作成）
mkdir -p .githooks
cat > .githooks/commit-msg <<'EOF'
#!/bin/bash
# feat/fix/perf には Verified: 行を必須化する
MSG_FILE=$1
TYPE=$(head -1 "$MSG_FILE" | grep -oE '^(feat|fix|perf):' | tr -d ':')
if [ -z "$TYPE" ]; then
    exit 0   # wip/docs/chore はスキップ
fi
if ! grep -q "^Verified:" "$MSG_FILE"; then
    echo "❌ ${TYPE}: commit には 'Verified: <url>:<status>:<timestamp>' 行が必須です"
    echo "   done.sh を使えば自動付与されます: bash done.sh <task_id> url:https://your-app.com/"
    exit 1
fi
EOF
chmod +x .githooks/commit-msg

# git に hook の場所を教える
git config core.hooksPath .githooks
```

---

## 7. CI で行数上限を守る（GitHub Actions の例）

`.github/workflows/claude-md-line-limit.yml`:

```yaml
name: CLAUDE.md 行数上限チェック

on: [pull_request]

jobs:
  line-limit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 250 行を超えていないか確認
        run: |
          LINES=$(wc -l < CLAUDE.md)
          if [ "$LINES" -gt 250 ]; then
            echo "❌ CLAUDE.md が ${LINES} 行です。250 行を超えています。"
            echo "詳細ルールは docs/rules/*.md に移してください。"
            exit 1
          fi
          echo "✅ CLAUDE.md は ${LINES} 行です。"
```

---

## 8. 動作確認

セットアップが終わったら、ダミータスクで動作を確認します:

```bash
# 1. WORKING.md にダミー行を追記
echo "| [Code] TEST-001 setup test | Code | none | $(date '+%Y-%m-%d %H:%M') JST | no |" >> WORKING.md

# 2. 適当に commit
git add WORKING.md
git commit -m "wip: setup test"

# 3. done.sh を試す
bash done.sh TEST-001 url:https://your-app.com/
# → 本番 URL で 200 が返れば「✅ HTTP 200」が出る
```

---

## 9. よくある詰まりポイント

### Q1. `done.sh` を実行すると「現在の HEAD は origin/main に含まれていない」エラーが出る

**A**. これは仕様です。`done.sh` は「main にマージ済みかつ deploy 完了」を「完了」の定義にしています。

- まだ feature branch 上の場合: PR を作って merge してから再実行してください
- main マージ済みなのにエラーが出る場合: `git fetch origin main` してから再実行

### Q2. macOS で `sed -i ''` が「extra characters after command」エラーになる

**A**. GNU sed と BSD sed の違いです:
- macOS（BSD sed）: `sed -i '' 's/foo/bar/' file`
- Linux（GNU sed）: `sed -i 's/foo/bar/' file`

このガイドのコマンドは macOS 用です。Linux で実行する場合は `-i ''` を `-i` に変えてください。

### Q3. Claude Code が CLAUDE.md を読まない

**A**. CLAUDE.md は**リポジトリのルート**に置く必要があります。
```bash
ls CLAUDE.md   # ./CLAUDE.md として存在することを確認
```
サブディレクトリ（`docs/CLAUDE.md` など）は読まれません。

### Q4. WORKING.md の stale 行が削除されない

**A**. `session_bootstrap.sh` の stale 削除ロジックを実装していないからです。最初は手動削除で運用し、慣れたら bootstrap スクリプトに自動削除ロジックを足してください。

参考実装（8 時間 TTL）:

```bash
# session_bootstrap.sh に追加
python3 <<'PY'
import re
from datetime import datetime, timedelta, timezone

JST = timezone(timedelta(hours=9))
now = datetime.now(JST)
threshold = now - timedelta(hours=8)

with open("WORKING.md", encoding="utf-8") as f:
    lines = f.readlines()

out = []
for line in lines:
    m = re.search(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s*JST", line)
    if m:
        try:
            start = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M").replace(tzinfo=JST)
            if start < threshold:
                continue  # skip stale row
        except ValueError:
            pass
    out.append(line)

with open("WORKING.md", "w", encoding="utf-8") as f:
    f.writelines(out)
PY
```

### Q5. PR は作ったが auto-merge にならない

**A**. PR 作成時にフラグを付けるのを忘れていませんか:

```bash
gh pr create --title "..." --body "..." 
gh pr merge --auto --squash   # ← これ
```

または GitHub Actions で `auto-merge.yml` を作って自動化することもできます。

### Q6. 「気をつける」だけのルールを追加していいですか

**A**. ダメです。Claude Code は「気をつけて」を半分の確率で忘れます。代わりに:

- CI ジョブ（`.github/workflows/*.yml`）
- git hook（`.githooks/commit-msg` など）
- スクリプト（`done.sh`、`session_bootstrap.sh`）

のいずれかに**物理化**してください。物理化できない場合は、そのルールを採用するメリットを再考します。

---

## 10. 次のステップ

セットアップが終わったら:

1. **最初の 1 週間**: 普段の開発で `WORKING.md` 追記 → `done.sh` 実行 のフローを馴染ませる
2. **最初の 1 ヶ月**: バグを直すたびに `docs/rules/bug-prevention.md` に 1 行追加
3. **3 ヶ月**: 「物理化できる思想ルール」を 1 件ずつ CI / hook に落とす
4. **半年**: `bug-prevention.md` / `design-mistakes.md` が 30 行を超えてくる頃。Claude が「実装前にこれを見る」のがフローに乗る

何か詰まったら README の「How to grow this」を読み返してください。

---

## 関連リソース

- [README.md](../README.md) — このキット全体の概要
- [docs/rules/global-baseline.md](rules/global-baseline.md) — 全プロダクト共通ルール
- [Claude Code 公式ドキュメント](https://docs.claude.com/claude-code)
