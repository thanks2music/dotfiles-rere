#!/bin/bash
#
# tools/brewfile-usage.sh — Brewfile のアプリ（cask / mas）を最後に使った時期を推定し、
#                           棚卸しで外す候補を挙げる。
#
#   使い方:
#     bash tools/brewfile-usage.sh                    # Brewfile（core）を調べる
#     bash tools/brewfile-usage.sh Brewfile.desktop
#     bash tools/brewfile-usage.sh Brewfile.mas 180   # 180 日より前を「古い」とする（既定 365）
#
#   何も入れない・消さない（読むだけ）。結果は参考情報なので、判定の結果では失敗にしない（exit 0）。
#   tools/brewfile-audit.sh のように brew bundle を止める問題を検出するものではない。
#   引数の誤りや前提の不足（Brewfile が無い・macOS でない・brew が無い）だけ exit 1 / 2 で止める。
#   .app の場所は `brew info --json=v2` の artifacts の target から取るため、Homebrew 5.1.13 以降が要る
#   （それより前の brew には target が無く、.app のある cask が「判定不可」になる）。
#   外すかどうかは、結果を見て人が決める。
#
#   判定に使う痕跡（いちばん新しいものを採る）:
#     1. Spotlight の kMDItemLastUsedDate（mdls）
#     2. ~/Library 配下にある、その bundle id の設定（Preferences）・終了時の状態
#        （Saved Application State）・データ（Application Support / Caches / HTTPStorages）の更新日時。
#        サンドボックスのアプリは ~/Library/Containers/<bundle id> の中を見る
#     3. brew 上はインストール済みなのに .app が無い → 手で消した = 使っていない強い根拠。
#        pkg で入る cask は、pkgutil の receipt から .app の場所を割り出す
#
#   ⚠️ macOS には、アプリの起動を 1 年分残すログが無い。上の痕跡はどれも近似で、それぞれ穴がある:
#     - kMDItemLastUsedDate は LaunchServices 経由で開いた時だけ更新される。Apple の定義:
#       "updated automatically by LaunchServices every time a file is opened by double
#        clicking, or by asking LaunchServices to open a file"
#       https://developer.apple.com/library/archive/documentation/CoreServices/Reference/MetadataAttributesRef/Reference/CommonAttrs.html
#       CLI から本体を直接起動した場合（draw.io の export など）は記録されない。
#       Spotlight のインデックスを作り直すと消える。2026-10 時点の Pro には 2026-09 以降の分しか無かった。
#     - 設定ファイルは、常駐ヘルパーや自動更新が書き換えることがある。2026-10 の棚卸しでは、
#       TeamViewer のアプリデータは 2025-09 で止まっていたのに、設定は 2026-08 に更新されていた。
#       データも同じで、Cursor は画面を 2025-12 から開いていないのに、cursor コマンドが書く
#       cli.log で 2026-09 になった。他のアプリが書き込む NativeMessagingHosts は見ない。
#     - CLI だけの cask（.app が無いもの）は「判定不可」とし、本体の atime を参考に出すだけにする。
#       atime は brew upgrade で入れ替わった時点に戻るうえ、Spotlight が読んでも更新される
#       （flutter の dart は一度も実行していないのに、Spotlight が多数のアプリを登録し直した日の atime だった）。
#     - ディレクトリは自身と直下の子までしか見ない（Chrome のプロファイルのような巨大な木を辿らないため）。
#       深い階層のファイルだけを書き換えるアプリは、実際より古く見えることがある。
#     - mas のアプリと pkg の .app は Spotlight（mdfind）で探す。索引が使えないと見つからないので、
#       その場合は冒頭に警告を出す。
#     - formula と VS Code 拡張には使った記録が無いため対象外にし、件数だけ表示する。
#     - 他のアプリの Containers を読むため、macOS がターミナルに「他のアプリのデータへのアクセス」の許可を求めることがある。
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
FILE="${1:-$ROOT/Brewfile}"
DAYS="${2:-365}"           # これより前の痕跡しか無いものを「古い」とする日数
[ -f "$FILE" ] || { echo "ERROR: $FILE が無い" >&2; exit 1; }
case "$DAYS" in ''|*[!0-9]*) echo "ERROR: 日数は整数で指定する: $DAYS" >&2; exit 2 ;; esac
[ "$(uname)" = Darwin ] || { echo "ERROR: macOS 専用（Spotlight と ~/Library を読む）" >&2; exit 1; }
command -v brew > /dev/null 2>&1 || { echo "ERROR: brew が無い" >&2; exit 1; }

python3 - "$FILE" "$DAYS" <<'PY'
import datetime, io, json, os, plistlib, re, subprocess, sys

path = sys.argv[1]
days = int(sys.argv[2])
src = io.open(path, encoding='utf-8').read()
casks = re.findall(r'^cask "([^"]+)"', src, flags=re.M)
mas_apps = re.findall(r'^mas "([^"]+)", id: (\d+)', src, flags=re.M)
n_brew = len(re.findall(r'^brew "', src, flags=re.M))
n_vscode = len(re.findall(r'^vscode "', src, flags=re.M))

LIB = os.path.expanduser('~/Library')
# 他のアプリ（Claude や 1Password の拡張連携）が Chromium 系ブラウザのデータに書き込むため、本人の使用を示さない
IGNORE = {'NativeMessagingHosts'}
cutoff = (datetime.datetime.now() - datetime.timedelta(days=days)).timestamp()


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()


def newest(p):
    """ファイルならその mtime、ディレクトリなら自身と直下の子の mtime の最大値。無ければ 0。"""
    try:
        best = os.stat(p).st_mtime
    except OSError:
        return 0
    if os.path.isdir(p):
        try:
            for e in os.scandir(p):
                if e.name in IGNORE:
                    continue
                try:
                    best = max(best, e.stat(follow_symlinks=False).st_mtime)
                except OSError:
                    pass
        except OSError:
            pass
    return best


def spotlight(app):
    v = run('mdls', '-raw', '-name', 'kMDItemLastUsedDate', app)
    try:
        return datetime.datetime.strptime(v, '%Y-%m-%d %H:%M:%S %z').timestamp()
    except ValueError:
        return 0        # "(null)" = Spotlight に記録が無い


def bundle_id(app):
    try:
        with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
            return plistlib.load(f).get('CFBundleIdentifier')
    except (OSError, ValueError, plistlib.InvalidFileException):
        return None


def app_signals(app):
    """.app の痕跡を (時刻, 根拠) の一覧で返す。時刻 0 は痕跡なし。"""
    out = [(spotlight(app), 'Spotlight')]
    bid = bundle_id(app)
    if not bid:
        return out
    name = os.path.basename(app)[:-len('.app')]
    box = os.path.join(LIB, 'Containers', bid, 'Data', 'Library')
    out.append((max(newest(os.path.join(LIB, 'Preferences', bid + '.plist')),
                    newest(os.path.join(box, 'Preferences', bid + '.plist'))), '設定'))
    out.append((max(newest(os.path.join(LIB, 'Saved Application State', bid + '.savedState')),
                    newest(os.path.join(box, 'Saved Application State', bid + '.savedState'))),
                '終了時の状態'))
    out.append((max(newest(os.path.join(LIB, 'Application Support', bid)),
                    newest(os.path.join(LIB, 'Application Support', name)),
                    newest(os.path.join(box, 'Application Support')),
                    newest(os.path.join(LIB, 'Caches', bid)),
                    newest(os.path.join(LIB, 'HTTPStorages', bid))), 'データ'))
    return out


def flat(v):
    if isinstance(v, str):
        return [v]
    return [x for i in (v or []) for x in flat(i)]


def pkg_apps(pkgids):
    """pkgutil の receipt から、pkg が置いた .app（の最上位）のパスを返す。

    receipt の location は、インストーラが後から .app を動かすと実際の場所とずれる
    （hhkb は tmp/ に展開してから移す。microsoft-teams は自動更新の複製先を指す）。
    そのため /Applications 直下の同名と、/Applications・~/Applications の下にある同名も候補に入れる。
    範囲を絞るのは、Parallels が ~/Applications (Parallels) に作る同名の別物を拾わないため。
    """
    out = []
    for pid in pkgids:
        meta = dict(l.split(': ', 1) for l in run('pkgutil', '--pkg-info', pid).splitlines()
                    if ': ' in l)
        if 'volume' not in meta:
            continue                    # receipt が無い
        base = os.path.join(meta['volume'], meta.get('location', ''))
        for f in run('pkgutil', '--only-dirs', '--files', pid).splitlines():
            if f.endswith('.app') and '.app/' not in f:
                name = os.path.basename(f)
                out += [os.path.join(base, f), os.path.join('/Applications', name)]
                out += run('mdfind', '-onlyin', '/Applications', '-onlyin', os.path.expanduser('~/Applications'),
                           'kMDItemFSName == "%s"' % name).splitlines()
    return out


def cask_targets(c):
    """cask の artifacts から (.app の候補, CLI 本体のリンク, フォントか) を取り出す。"""
    apps, bins, pkgids, font = [], [], [], False
    for a in c.get('artifacts', []):
        if 'app' in a and a.get('target'):
            apps.append(a['target'])
        if 'binary' in a and a.get('target'):
            bins.append(a['target'])
        if 'font' in a:
            font = True
        for d in a.get('uninstall', []):
            if isinstance(d, dict):
                pkgids += flat(d.get('pkgutil'))
    return apps + pkg_apps(pkgids), bins, font


def installed_casks():
    """このマシンに入っている cask を {token: JSON} で返す。

    名前を並べて問い合わせると、1 件でも引けない cask があるだけで exit 1・stdout 空になり、
    全部が判定できなくなる。--installed なら名前に依存せず 1 回で済む（約 2 秒）。
    """
    r = subprocess.run(['brew', 'info', '--cask', '--json=v2', '--installed'],
                       capture_output=True, text=True)
    try:
        return {c['token']: c for c in json.loads(r.stdout).get('casks', [])}
    except ValueError:
        print("ERROR: brew info --installed が JSON を返さなかった: %s"
              % (r.stderr.strip().splitlines() or [''])[0])
        return {}


def day(ts):
    return datetime.date.fromtimestamp(ts).isoformat()


rows = []       # (区分, 日付, 根拠, 名前)


def judge(name, signals, note=''):
    ts, why = max(signals) if signals else (0, '')
    if not ts:
        rows.append(('痕跡なし', '-', note or '設定・データ・Spotlight のどれにも無い', name))
    elif ts < cutoff:
        rows.append(('古い', day(ts), why, name))
    else:
        rows.append(('最近', day(ts), why, name))


if casks:
    info = installed_casks()
    for full in casks:
        c = info.get(full.split('/')[-1])
        if not c:
            rows.append(('未導入', '-', 'このマシンに入っていない', full))
            continue
        apps, bins, font = cask_targets(c)
        found = [a for a in dict.fromkeys(apps) if os.path.isdir(a)]
        if apps and not found:      # cask 側で .app 名が変わった場合（zen: Zen Browser.app → Zen.app）
            found = [a for a in ('/Applications/%s.app' % n for n in c.get('name', []))
                     if os.path.isdir(a)]
        if font:
            rows.append(('判定不可', '-', 'フォント（設定から参照されているかを見る）', full))
        elif apps and not found:
            rows.append(('.app 削除済み', '-', 'brew はインストール済みとしているのに .app が無い', full))
        elif found:
            judge(full, [s for a in found for s in app_signals(a) if s[0]])
        else:
            atimes = []
            for b in bins:
                try:
                    atimes.append(os.stat(os.path.realpath(b)).st_atime)
                except OSError:
                    pass
            rows.append(('判定不可', day(max(atimes)) if atimes else '-',
                         'CLI だけの cask（日付は本体の atime。参考値）' if bins
                         else '.app の場所が分からない', full))

for name, adam in mas_apps:
    hits = run('mdfind', '-onlyin', '/Applications', 'kMDItemAppStoreAdamID == %s' % adam).splitlines()
    if not hits:
        rows.append(('未導入', '-', 'このマシンに入っていない', name))
        continue
    judge(name, [s for s in app_signals(hits[0]) if s[0]])

order = ['.app 削除済み', '痕跡なし', '古い', '判定不可', '未導入', '最近']
title = {
    '.app 削除済み': '.app 削除済み（外す候補）',
    '痕跡なし': '痕跡なし（外す候補。CLI からしか起動しないものは除く）',
    '古い': '%d 日以上前の痕跡しか無い（外す候補）' % days,
    '判定不可': '判定不可（人が判断する）',
    '未導入': 'このマシンに入っていない',
    '最近': '%d 日以内に痕跡あり' % days,
}
if run('mdfind', '-onlyin', '/Applications', '-count',
       "kMDItemContentType == 'com.apple.application-bundle'") in ('', '0'):
    print("⚠ Spotlight の索引が使えない（/Applications のアプリが 1 件も見つからない）。"
          "mas の判定と Spotlight の痕跡は当てにならない。\n")
print("%s — cask %d 件 / mas %d 件（基準: %s より前）"
      % (os.path.basename(path), len(casks), len(mas_apps), day(cutoff)))
for k in order:
    sel = sorted((r for r in rows if r[0] == k), key=lambda r: (r[1], r[3]))
    if not sel:
        continue
    print("\n==> %s: %d 件" % (title[k], len(sel)))
    for _, d, why, name in sel:
        print("    %-10s  %-34s %s" % (d, name, why))
if n_brew or n_vscode:
    print("\n対象外: formula %d 件 / VS Code 拡張 %d 件（使った記録が残らないため）" % (n_brew, n_vscode))
PY
