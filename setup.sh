#!/bin/bash
#
# setup.sh — 新しい Mac に開発環境を構築する
#
#   使い方: git clone https://github.com/thanks2music/dotfiles-rere.git ~/dotfiles
#           bash ~/dotfiles/setup.sh
#
#   NOTE: パイプ実行 (curl | bash) は推奨しない。実行前に中身を確認できず、
#         本スクリプト自身が clone するので clone 先行の方が厳密に優位。
#
# 設計:
#   - `set -e` は使わない。1 個の失敗が以降の phase を黙って切り捨てるのを防ぐため、
#     phase 単位で失敗を集約し最後に非ゼロ終了する。
#   - 各 phase 関数は 0=成功 / 2=手動ゲート(SKIP) / その他=失敗(FAIL) を返す。
#     `set -e` に頼れないので、関数内の失敗しうるコマンドは明示的に `|| return 1` する。
set -uo pipefail

readonly local_bin_dir="$HOME/bin"
readonly local_dotconfig_dir="$HOME/.config"
readonly dotfiles_dir="$HOME/dotfiles"
readonly dotfiles_repo="https://github.com/thanks2music/dotfiles-rere.git"
readonly stamp="$(date +%Y%m%d%H%M%S)"

declare -a FAILED=()
declare -a SKIPPED=()

function topic { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
function ok    { printf '     ok    %s\n' "$*"; }
function info  { printf '     ..    %s\n' "$*"; }
function warn  { printf '\033[1;33m     warn  %s\033[0m\n' "$*"; }
function fail  { printf '\033[1;31m     FAIL  %s\033[0m\n' "$*"; }

# phase <label> <function>
function phase {
	local label="$1" fn="$2" rc=0
	topic "$label"
	"$fn" || rc=$?
	case "$rc" in
		0) ;;
		2) SKIPPED+=("$label") ;;
		*) FAILED+=("$label") ;;
	esac
	return 0
}

# link <src> <dest> — 既存の実体は退避してから symlink を張る。
#   `ln -sfn` は使わない。dest が「実ディレクトリ」の場合、BSD ln は -n/-h を
#   symlink にしか適用しないため dest の *中* に入れ子リンク (dest/basename) を作る。
#   実測: ~/.config/fish は実ディレクトリなので、再実行で ~/.config/fish/fish ができる。
function link {
	local src="$1" dest="$2"
	if [ -L "$dest" ]; then
		if [ "$(readlink "$dest")" = "$src" ]; then
			ok "$dest"
			return 0
		fi
		rm -- "$dest" || return 1
	elif [ -e "$dest" ]; then
		mv -- "$dest" "$dest.backup.$stamp" || return 1
		info "backup  $dest -> $(basename "$dest").backup.$stamp"
	fi
	ln -s -- "$src" "$dest" || return 1
	info "link    $dest"
}

# ---------------------------------------------------------------- phases

function phase_clone {
	if [ -d "$dotfiles_dir/.git" ]; then
		ok "dotfiles は既に clone 済み"
		return 0
	fi
	# --recursive は付けない。.gitmodules は削除済み（index に gitlink が無く無言の no-op だった）。
	git clone "$dotfiles_repo" "$dotfiles_dir" || return 1
	ok "clone 完了"
}

function phase_bin {
	mkdir -p "$local_bin_dir" || return 1
	local src rc=0
	while IFS= read -r src; do
		[ -n "$src" ] || continue
		link "$src" "$local_bin_dir/$(basename "$src")" || rc=1
	done < <(find "$dotfiles_dir/bin" -maxdepth 1 -mindepth 1 -type f)
	return $rc
}

function phase_config {
	mkdir -p "$local_dotconfig_dir" || return 1
	# NOTE: zed は下の phase_zed でファイル単位に扱う。
	#       ~/.config/zed には LMDB のランタイム DB があり、ディレクトリ単位で
	#       symlink すると git 作業ツリーに巻き込むため。
	local src rc=0
	while IFS= read -r src; do
		[ -n "$src" ] || continue
		case "$(basename "$src")" in zed) continue ;; esac
		link "$src" "$local_dotconfig_dir/$(basename "$src")" || rc=1
	done < <(find "$dotfiles_dir/config" -maxdepth 1 -mindepth 1)
	return $rc
}

function phase_dotfiles {
	local src dest name rc=0
	while IFS= read -r src; do
		[ -n "$src" ] || continue
		name="$(basename "$src")"
		case "$name" in *example*) continue ;; esac
		dest="$HOME/$(printf '%s' "$name" | sed -e 's/^dot\./\./')"
		link "$src" "$dest" || rc=1
	done < <(find "$dotfiles_dir" -maxdepth 1 -mindepth 1 -name 'dot.*')
	return $rc
}

function phase_examples {
	# *.example は「無ければコピー」。実体はマシン固有 or 秘密を含むため symlink にしない。
	local src dest name rc=0
	while IFS= read -r src; do
		[ -n "$src" ] || continue
		name="$(basename "$src")"
		dest="$HOME/$(printf '%s' "$name" | sed -e 's/^dot\./\./' -e 's/\.example$//')"
		if [ -e "$dest" ]; then
			ok "$dest (既存を保護)"
		else
			cp "$src" "$dest" || { rc=1; continue; }
			info "copy    $dest"
		fi
	done < <(find "$dotfiles_dir" -maxdepth 1 -mindepth 1 -type f -name 'dot.*.example')
	return $rc
}

function phase_vim {
	link "$dotfiles_dir/dot.vim" "$HOME/.config/nvim" || return 1
	link "$dotfiles_dir/dot.vimrc" "$HOME/.config/nvim/init.vim" || return 1

	if [ -f "$dotfiles_dir/dot.vim/autoload/plug.vim" ]; then
		ok "vim-plug は既に導入済み"
		return 0
	fi
	curl -fsSLo "$dotfiles_dir/dot.vim/autoload/plug.vim" --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || {
		warn "vim-plug の取得に失敗（後で :PlugInstall 前に再取得してください）"
		return 0
	}
	info "vim-plug 導入"
}

function phase_zed {
	mkdir -p "$HOME/.config/zed" || return 1
	link "$dotfiles_dir/config/zed/settings.json" "$HOME/.config/zed/settings.json"
}

function phase_homebrew {
	if [ "$(uname)" != "Darwin" ]; then
		info "macOS ではないため skip"
		return 0
	fi

	if command -v brew > /dev/null 2>&1; then
		ok "Homebrew は既に導入済み"
	else
		# IMPORTANT: installer は必ず一時ファイルへ落としてから実行する。
		#   `/bin/bash -c "$(curl -fsSL URL)"` の形は使わない。curl が 404 で失敗しても
		#   `-f` が本文を捨てて空文字を返し、bash が空スクリプトを exit 0 で実行するため、
		#   「何もインストールせず成功扱い」になる。しかも引数位置のコマンド置換なので
		#   `set -e` でも捕まらない（実測: macOS 26.5.1 で確認）。
		local installer
		installer="$(mktemp "${TMPDIR:-/tmp}/brew-install.XXXXXX")" || return 1
		if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
			rm -f "$installer"
			fail "Homebrew installer の取得に失敗（URL/ネットワークを確認）"
			return 1
		fi
		if [ ! -s "$installer" ]; then
			rm -f "$installer"
			fail "Homebrew installer が空だった"
			return 1
		fi
		info "Homebrew を導入する"
		NONINTERACTIVE=1 /bin/bash "$installer" || {
			rm -f "$installer"
			fail "Homebrew の導入に失敗"
			return 1
		}
		rm -f "$installer"
	fi

	# brew を「このプロセスの」PATH に載せる。~/.zprofile はここでは読まれないため、
	# 後続の phase_brew_bundle が brew を見つけられるようにするのに必須。
	local p
	for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [ -x "$p" ]; then
			eval "$("$p" shellenv)"
			break
		fi
	done
	command -v brew > /dev/null 2>&1 || {
		fail "brew が PATH に載らなかった"
		return 1
	}
	ok "$(brew --version | head -1)"
}

function phase_brew_bundle {
	command -v brew > /dev/null 2>&1 || {
		warn "brew が無いため skip"
		return 2
	}
	local core="$dotfiles_dir/Brewfile"
	[ -f "$core" ] || {
		warn "Brewfile が無い"
		return 2
	}
	info "brew bundle install (core)"
	brew bundle install --file="$core" --no-upgrade || {
		fail "brew bundle が失敗（brew bundle check --file=$core で詳細確認）"
		return 1
	}
	ok "core パッケージ導入完了"

	# desktop 側は任意。重量級（Xcode / Adobe CC / IDE / ゲーム / メディア系）を含むため
	# 自動では入れない。持ち運び機には core だけで足りる。
	if [ -f "$dotfiles_dir/Brewfile.desktop" ]; then
		info "任意: brew bundle install --file=$dotfiles_dir/Brewfile.desktop"
	fi
	if [ -f "$dotfiles_dir/Brewfile.vscode" ]; then
		info "任意: brew bundle install --file=$dotfiles_dir/Brewfile.vscode  (code が PATH に必要)"
	fi
}

function phase_brewfile_global {
	# `brew bundle --global` は ~/.Brewfile を読む。repo の Brewfile への symlink にして
	# 「--global と --file= が別の内容を見る」状態を構造的になくす。
	link "$dotfiles_dir/Brewfile" "$HOME/.Brewfile"
}

function phase_avengers {
	local dir="${AVENGERS_DIR:-$HOME/work/dev/my-projects/avengers}"
	local ssh_url="git@github.com:thanks2music/avengers.git"
	local https_url="https://github.com/thanks2music/avengers.git"

	if [ -d "$dir/.git" ]; then
		ok "avengers は既に clone 済み"
	else
		mkdir -p "$(dirname "$dir")" || return 1
		# `ssh -T git@github.com` は認証成功でも exit 1 を返すので、終了コードでは判定できない。
		# メッセージで判定する。accept-new で新規 Mac のホスト鍵プロンプト待ちを防ぎ、
		# BatchMode でパスワード入力待ちも防ぐ（どちらも stdin を掴んで停止する経路）。
		#
		# IMPORTANT: パイプで grep に渡してはいけない。本スクリプトは set -o pipefail なので
		#   `ssh ... | grep -q ...` はパイプ全体が ssh の exit 1 を採用し、認証が成功していても
		#   常に false になる（実測で確認）。出力を変数に取ってから判定する。
		#   `|| true` は exit 1 で $ssh_msg の代入自体が失敗扱いになるのを防ぐため。
		local ssh_msg
		ssh_msg="$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes \
			-T git@github.com 2>&1 || true)"
		case "$ssh_msg" in
		*'successfully authenticated'*)
			info "SSH 認証 OK。clone する"
			git clone "$ssh_url" "$dir" || { fail "avengers の clone に失敗"; return 1; }
			;;
		*)
			if command -v gh > /dev/null 2>&1 && gh auth status > /dev/null 2>&1; then
				info "gh 認証を使って HTTPS で clone する"
				gh auth setup-git > /dev/null 2>&1 || true
				git clone "$https_url" "$dir" || { fail "avengers の clone に失敗"; return 1; }
			else
				warn "avengers (private) の認証がありません"
				cat <<-EOS
				       次のいずれかを行ってから本スクリプトを再実行してください:
				         a) ~/.ssh の秘密鍵を復元して chmod 600 する
				         b) gh auth login
				EOS
				return 2
			fi
			;;
		esac
	fi

	if [ ! -f "$dir/bootstrap.sh" ]; then
		warn "bootstrap.sh が無いため skip"
		return 2
	fi
	info "avengers/bootstrap.sh を実行（~/.claude を復元）"
	bash "$dir/bootstrap.sh" || { fail "bootstrap.sh が失敗"; return 1; }
}

# ---------------------------------------------------------------- main

phase 'Clone the repository'                 phase_clone
phase 'Setup bin directory'                  phase_bin
phase 'Setup .config directory'              phase_config
phase 'Setup dotfiles'                       phase_dotfiles
phase 'Setup dotfiles (.example)'            phase_examples
phase 'Setup Vim'                            phase_vim
phase 'Setup Zed settings'                   phase_zed
phase 'Setup Homebrew'                       phase_homebrew
phase 'Install packages (Brewfile)'          phase_brew_bundle
phase 'Link ~/.Brewfile'                     phase_brewfile_global
phase 'Setup avengers (private AI config)'   phase_avengers

topic 'summary'
if [ ${#SKIPPED[@]} -gt 0 ]; then
	for x in "${SKIPPED[@]}"; do printf '\033[1;33m  SKIP  %s\033[0m\n' "$x"; done
fi
if [ ${#FAILED[@]} -gt 0 ]; then
	for x in "${FAILED[@]}"; do printf '\033[1;31m  FAIL  %s\033[0m\n' "$x"; done
fi

if [ ${#FAILED[@]} -eq 0 ] && [ ${#SKIPPED[@]} -eq 0 ]; then
	printf '\033[1;32m  すべて完了しました\033[0m\n'
	printf '  次: bash %s/tools/asdf.sh  (言語ランタイム。30〜60 分かかる)\n' "$dotfiles_dir"
	exit 0
fi

printf '\n  未完了の phase があります。上記を解消して本スクリプトを再実行してください。\n'
printf '  （本スクリプトは冪等です。完了済みの phase は ok と表示されます）\n'
exit 1
