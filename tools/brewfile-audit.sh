#!/bin/bash
#
# tools/brewfile-audit.sh — Brewfile の各エントリが `brew bundle install` を
#                           落とさないか事前に検査する。
#
#   使い方:
#     bash tools/brewfile-audit.sh                      # Brewfile（core）を検査
#     bash tools/brewfile-audit.sh Brewfile.desktop
#     bash tools/brewfile-audit.sh Brewfile 30          # 30 日以内の失効だけ警告
#
#   検査する 3 つの破損モード（いずれも過去に実害が出た）:
#     1. disabled       — 既に無効。brew bundle が**ハード失敗**する（qblocker で実証）
#     2. 存在しない     — homebrew から消滅。同じくハード失敗（skitch で実証）
#     3. disable_date   — 将来無効になる。**今日は通るが、その日を境に落ちる**
#                         （chromium: 2026-09-01。8 日前に発見できた）
#
#   ⚠️ 3 は閾値を切らないと狼少年になる。python@3.14 のようなバージョン付き formula は
#      常に遠い将来（2031 年など）の disable_date を持つため、全部を「問題」として
#      非ゼロ終了させると誰も見なくなる。既定 90 日以内のみ失敗扱いとし、
#      それより先は参考表示（exit 0）にとどめる。
#
#   ⚠️ 「存在するか」を結果セットの有無で判定してはいけない（実測で判明）。
#      `brew info --cask --json=v2 skitch` は **exit 0 で skitch のエントリを返す**。
#      これは skitch がこのマシンに**ローカルインストール済み**で、brew が receipt から
#      情報を組み立てるためである。定義自体は homebrew-cask から消滅しているので、
#      素のマシンでは `brew bundle install` が "No Cask with this name exists" で落ちる。
#
#      → 判定は **`tap` フィールドが null かどうか**で行う。どの tap にも定義が無い
#        = 新しいマシンでは入らない。`ruby_source_path` も同時に null になる。
#
#      これは 2 台運用で最も危険な種類の盲点である。**主機での検証は、長年蓄積した
#      ローカルインストールに騙される。** 2026-08-24 に Air の初回構築で skitch が
#      失敗し、Pro 側の事前検査が通っていた理由がこれだった。
#   このツールが検出**できない**もの（別途注意が必要）:
#     - installer の実行時失敗。例: adobe-digital-editions は Rosetta 2 を要求するため
#       素の Apple Silicon 機で落ちるが、metadata 上は正常なので本ツールは通す。
#     - tap trust の警告。消費者ゼロの tap 宣言は Homebrew 6.0 で警告を出すが、
#       Brewfile の tap 行と formula/cask の対応は本ツールの検査対象外。
#     - 容量。core だけで数十 GB になりうる。
#
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
FILE="${1:-$ROOT/Brewfile}"
WITHIN="${2:-90}"          # disable_date を「失敗」として扱う日数の閾値
[ -f "$FILE" ] || { echo "ERROR: $FILE が無い" >&2; exit 1; }
case "$WITHIN" in ''|*[!0-9]*) echo "ERROR: 閾値は日数（整数）で指定する: $WITHIN" >&2; exit 2 ;; esac
command -v brew > /dev/null 2>&1 || { echo "ERROR: brew が無い" >&2; exit 1; }

python3 - "$FILE" "$WITHIN" <<'PY'
import io, json, re, subprocess, sys, datetime
path = sys.argv[1]
within = int(sys.argv[2])
src = io.open(path, encoding='utf-8').read()
later = []          # 閾値より先の失効。参考表示のみで exit code に影響させない
groups = {
    'cask':    re.findall(r'^cask "([^"]+)"', src, flags=re.M),
    'formula': re.findall(r'^brew "([^"]+)"', src, flags=re.M),
}
today = datetime.date.today()
problems = 0

for kind, names in groups.items():
    if not names:
        continue
    print("==> %s %d 件" % (kind, len(names)))
    r = subprocess.run(['brew', 'info', '--%s' % kind, '--json=v2'] + names,
                       capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except ValueError:
        print("    ERROR: 一括問い合わせが JSON を返さなかった")
        print("    %s" % (r.stderr.strip().splitlines() or [''])[0])
        problems += 1
        continue

    key = 'casks' if kind == 'cask' else 'formulae'
    entries = data.get(key, [])
    seen = set()
    for e in entries:
        t = e.get('token') or e.get('name')
        seen.add(t)
        seen.add(str(t).split('/')[-1])
        # tap が null = どの tap にも定義が無い。ローカルに入っていても新機では失敗する。
        if not e.get('tap'):
            extra = ' (このマシンには %s が入っているため in-place では気づけない)' % e['installed'] \
                    if e.get('installed') else ''
            print("    ✗ どの tap にも定義が無い: %-22s → 新しいマシンでハード失敗する%s"
                  % (t, extra))
            problems += 1

    # 問い合わせ結果に現れなかった名前（タイポ等。receipt も無い場合はここに来る）
    for n in names:
        if n not in seen and n.split('/')[-1] not in seen:
            print("    ✗ 解決できない名前: %s → brew bundle がハード失敗する" % n)
            problems += 1

    for e in entries:
        t = e.get('token') or e.get('name')
        if e.get('disabled'):
            print("    ✗ disabled: %-28s (%s) → ハード失敗する"
                  % (t, e.get('disable_reason') or e.get('disable_date') or '理由不明'))
            problems += 1
            continue
        d = e.get('disable_date')
        if not d:
            continue
        try:
            when = datetime.date.fromisoformat(d)
        except ValueError:
            print("    ⚠ disable_date が解釈できない: %s (%s)" % (t, d))
            problems += 1
            continue
        days = (when - today).days
        reason = e.get('deprecation_reason') or e.get('disable_reason') or '理由不明'
        if days < 0:
            print("    ✗ %s に disabled 済み: %-22s (%s)" % (d, t, reason))
            problems += 1
        elif days <= within:
            print("    ⚠ あと %3d 日で disabled: %-22s (%s, %s) → その日から落ちる"
                  % (days, t, d, reason))
            problems += 1
        else:
            later.append((when, kind, t, reason))

print()
if later:
    print("参考: %d 日より先に失効するもの（今は落ちない。バージョン付き formula は通常ここに入る）" % within)
    for when, kind, t, reason in sorted(later):
        print("    · %s  %-8s %-22s (%s)" % (when.isoformat(), kind, t, reason))
    print()
if problems:
    print("問題 %d 件。上記を解消してから brew bundle install してください。" % problems)
    sys.exit(1)
print("問題なし。brew bundle install が落ちる要因は見つからなかった。")
PY
