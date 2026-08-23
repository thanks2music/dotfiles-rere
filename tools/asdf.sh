#!/bin/bash
#
# tools/asdf.sh — dot.tool-versions を単一情報源として asdf の plugin を導入し、
#                 pin されたバージョンをインストールする。
#
#   使い方:
#     bash tools/asdf.sh --dry-run   # 何をするか表示するだけ
#     bash tools/asdf.sh --plugins   # plugin 追加だけ（ビルドは走らせない）
#     bash tools/asdf.sh             # plugin 追加 + asdf install
#
#   ⚠️ ruby / python はソースビルドのため初回は 10〜30 分かかる。
#      setup.sh の主経路からは意図的に外している（1 個の失敗で全体が止まるのを避けるため）。
#
#   以前はここに plugin 名をハードコードしていたが dot.tool-versions と食い違い、
#   言語ランタイム 8 個の plugin 追加行が存在しなかった（= 新しい Mac では 1 つも入らない）。
#   pin から導出する形にして二重管理をなくす。
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
VERSIONS="$ROOT/dot.tool-versions"

DRY=0
PLUGINS_ONLY=0
while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) DRY=1 ;;
		--plugins) PLUGINS_ONLY=1 ;;
		-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
	shift
done

command -v asdf > /dev/null 2>&1 || {
	echo "ERROR: asdf が無い。'brew bundle install --file=$ROOT/Brewfile' を先に実行してください。" >&2
	exit 1
}
[ -f "$VERSIONS" ] || { echo "ERROR: $VERSIONS が無い" >&2; exit 1; }

# plugin 名 → git URL の上書き表。
#   公式は短縮名リポジトリへの依存を避けるため URL 指定を推奨しているが、
#   現在の対象はすべて plugin index に存在するので短縮名で足りる。
#   index に無い plugin を足す時だけここに 1 組追加する。
declare -a OVERRIDE_NAME=()
declare -a OVERRIDE_URL=()
# 例: OVERRIDE_NAME+=("jq"); OVERRIDE_URL+=("https://github.com/AZMCode/asdf-jq.git")

url_for() {
	local want="$1" i=0
	while [ "$i" -lt "${#OVERRIDE_NAME[@]}" ]; do
		if [ "${OVERRIDE_NAME[$i]}" = "$want" ]; then
			printf '%s' "${OVERRIDE_URL[$i]}"
			return
		fi
		i=$((i + 1))
	done
	printf ''
}

# dot.tool-versions を読む（# 始まりと空行を無視）
declare -a TOOLS=()
while IFS= read -r line || [ -n "$line" ]; do
	case "$line" in ''|\#*) continue ;; esac
	# shellcheck disable=SC2086
	set -- $line
	[ -n "${1:-}" ] && TOOLS+=("$1")
done < "$VERSIONS"

if [ "${#TOOLS[@]}" -eq 0 ]; then
	echo "ERROR: $VERSIONS からツールを 1 つも読み取れなかった" >&2
	exit 1
fi

echo "==> dot.tool-versions から ${#TOOLS[@]} 件を読み取った"
for t in "${TOOLS[@]}"; do
	printf '     %-10s %s\n' "$t" "$(grep "^$t " "$VERSIONS" | awk '{print $2}')"
done

if [ "$DRY" = 1 ]; then
	echo
	echo "これは --dry-run です。実行する内容:"
	for t in "${TOOLS[@]}"; do
		printf '  asdf plugin add %s %s\n' "$t" "$(url_for "$t")"
	done
	[ "$PLUGINS_ONLY" = 0 ] && echo "  asdf install   # ← ruby/python のソースビルドを含む"
	exit 0
fi

echo
echo "==> plugin を追加する（既に在るものは skip）"
installed="$(asdf plugin list 2>/dev/null | tr '\n' ' ')"
fails=0
for t in "${TOOLS[@]}"; do
	if echo " $installed " | grep -q " $t "; then
		printf '     ok    %s (既に追加済み)\n' "$t"
		continue
	fi
	# shellcheck disable=SC2046
	if asdf plugin add "$t" $(url_for "$t") > /dev/null 2>&1; then
		printf '     add   %s\n' "$t"
	else
		printf '     FAIL  %s (plugin index に無い？ OVERRIDE_URL の追加を検討)\n' "$t"
		fails=$((fails + 1))
	fi
done

if [ "$PLUGINS_ONLY" = 1 ]; then
	echo
	echo "==> --plugins のため install はしない"
	[ "$fails" -gt 0 ] && exit 1
	exit 0
fi

echo
echo "==> asdf install（dot.tool-versions の全件。ruby/python はソースビルドで時間がかかる）"
cd "$HOME" || exit 1
if ! asdf install; then
	echo
	echo "FAIL: asdf install が失敗した。個別に 'asdf install <tool> <version>' で切り分けてください。" >&2
	exit 1
fi

echo
echo "==> 結果"
asdf current
[ "$fails" -gt 0 ] && exit 1
exit 0
