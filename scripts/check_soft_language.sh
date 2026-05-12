#!/usr/bin/env bash
# check_soft_language.sh — 「気を付ける」「注意する」等のソフト言語が
# 「仕組み的対策」セクションに混入していないか物理検査する。
#
# Why:
#   「気をつける」「注意する」「意識する」「確認する」はルールではない（願いだ）。
#   LLM はプレッシャー下でこれを忘れる。人間もオンコール対応で忘れる。
#   仕組み的対策は CI / hook / metric / SLI / scripts のいずれかで物理化する必要がある。
#
# 使い方:
#   bash scripts/check_soft_language.sh
#   bash scripts/check_soft_language.sh CLAUDE.md docs/rules/global-baseline.md
#
# 終了コード:
#   0: 混入なし
#   1: 混入あり (CI block)
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
cd "$ROOT"

# 引数指定なしの場合のデフォルト対象。自プロジェクトでルール文書を増やしたら追記する。
if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  FILES=(
    "CLAUDE.md"
    "docs/rules/global-baseline.md"
    "docs/rules/bug-prevention.md"
    "docs/rules/design-mistakes.md"
    "docs/failure-records/lessons-learned.md"
  )
fi

TOKENS=("気を付ける" "気をつける" "注意する" "意識する" "確認する")

check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "  SKIP: $file (not found)"
    return 0
  fi

  python3 - "$file" "${TOKENS[@]}" <<'PY'
import sys, re

path = sys.argv[1]
tokens = sys.argv[2:]

# 引用 / メタ言及 / 否定文脈は除外する
EXCLUDES = [
    "「気を付ける」", "「気をつける」", "「注意する」", "「意識する」", "「確認する」",
    "禁止", "書かない", "答えではない", "ではない", "NG", "混入", "形骸化",
    "ふんわり", "**思想",
]

with open(path, encoding="utf-8") as f:
    lines = f.readlines()

in_section = False
violations = []
header_re = re.compile(r"^(#{1,6}\s|---\s*$|\| Why|\| 観点|\| 規則|\| ID|\| ルール)")
section_open_re = re.compile(r"^\*\*仕組み的対策")

for i, line in enumerate(lines):
    stripped = line.rstrip("\n")
    if section_open_re.match(stripped.lstrip("- ").lstrip()):
        in_section = True
        continue
    if in_section:
        if header_re.match(stripped):
            in_section = False
            continue
        if re.match(r"^\*\*[^*]+\*\*:?\s*$", stripped) and "仕組み的対策" not in stripped:
            in_section = False
            continue
        for tok in tokens:
            if tok in stripped:
                if any(ex in stripped for ex in EXCLUDES):
                    continue
                violations.append((i + 1, tok, stripped))
                break

if violations:
    print(f"  ❌ {path}")
    for ln, tok, text in violations:
        print(f"     L{ln} [{tok}] {text}")
    sys.exit(1)
print(f"  ✅ {path}")
sys.exit(0)
PY
}

echo "=== 形骸化検出 grep (soft-language in 仕組み的対策 section) ==="
echo "対象: 「仕組み的対策」セクション内のソフト言語混入検査"
echo "検出語: ${TOKENS[*]}"
echo ""

violations=0
for f in "${FILES[@]}"; do
  if ! check_file "$f"; then
    violations=$((violations + 1))
  fi
done

echo ""
if [ "$violations" -gt 0 ]; then
  echo "❌ ERROR: $violations ファイルでソフト言語混入"
  echo ""
  echo "→ 「仕組み的対策」は CI / hook / metric / SLI / scripts のいずれかで物理化する。"
  echo "   「気を付ける/注意する/意識する/確認する」では何も担保されない。"
  exit 1
fi

echo "✅ ソフト言語混入なし"
exit 0
