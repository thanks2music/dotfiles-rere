#!/bin/bash

set -eu

readonly local_bin_dir=$HOME/bin
readonly local_dotconfig_dir=$HOME/.config
readonly dotfiles_dir=$HOME/dotfiles

function topic {
	echo -en "\033[1;30m"
	echo "$*"
	echo -en "\033[0m"
}

topic 'Clone the repository'

if [ -d $dotfiles_dir ]; then
	echo 'dotfiles repository already exists'
else
	git clone --recursive https://github.com/thanks2music/dotfiles-rere.git $dotfiles_dir
fi

topic 'Setup bin directory'

mkdir -p $local_bin_dir

for bin in `find $dotfiles_dir/bin -type f -maxdepth 1 -mindepth 1`; do
	echo 'Linking' $bin '->' $local_bin_dir
	ln -sf $bin $local_bin_dir
done

topic 'Setup .config directory'

mkdir -p $local_dotconfig_dir

# NOTE: zed is handled file-level below (only settings.json), to avoid linking
# the whole ~/.config/zed dir which contains a runtime LMDB prompt DB.
for src in `find $dotfiles_dir/config -maxdepth 1 -mindepth 1 | grep -v '/zed$'`; do
	dest=$local_dotconfig_dir/`basename $src`
	echo 'Linking' $src '->' $dest
	ln -sfn $src $dest
done

topic 'Setup dotfiles'

for dotfile in `find $dotfiles_dir -maxdepth 1 -mindepth 1 -name 'dot.*' | grep -v 'example'`; do
	dest=$HOME/`basename $dotfile | sed -e 's/^dot\./\./'`
	echo 'Linking' $dotfile '->' $dest
	ln -sfn $dotfile $dest
done

for dotfile in `find $dotfiles_dir -maxdepth 1 -mindepth 1 -type f -name 'dot.*.example'`; do
	dest=$HOME/`basename $dotfile | sed -e 's/^dot\./\./' | sed -e 's/\.example//'`
	if [ ! -f $dest ]; then
		echo 'Copying' $dotfile '->' $dest
		cp $dotfile $dest
	fi
done

topic 'Setup Vim'

if [ ! -d $HOME/.config/nvim ]; then
	echo 'Linking neovim config'
	mkdir -p $HOME/.config
	ln -sfn $dotfiles_dir/dot.vim $HOME/.config/nvim
	ln -sfn $dotfiles_dir/dot.vimrc $HOME/.config/nvim/init.vim
fi

if [ -f $dotfiles_dir/dot.vim/autoload/plug.vim ]; then
	echo 'vim-plug is already installed'
else
	if type vim > /dev/null 2>&1; then
		echo 'Installing vim-plug'
		curl -fLo $dotfiles_dir/dot.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	else
		echo 'Vim is not found'
	fi
fi

# NOTE: ~/.claude (CLAUDE.md / companions / settings / secrets) は private リポ avengers が管理。
#       本 setup.sh 末尾の 'Setup avengers' で bootstrap.sh を呼び復元する（dotfiles からは扱わない）。

topic 'Setup Zed settings'

mkdir -p "$HOME/.config/zed"

zed_settings_src="$dotfiles_dir/config/zed/settings.json"
zed_settings_dest="$HOME/.config/zed/settings.json"

if [ -f "$zed_settings_dest" ] && [ ! -L "$zed_settings_dest" ]; then
	echo "Backing up existing $zed_settings_dest -> ${zed_settings_dest}.backup"
	mv "$zed_settings_dest" "${zed_settings_dest}.backup"
fi

echo "Linking $zed_settings_src -> $zed_settings_dest"
ln -sf "$zed_settings_src" "$zed_settings_dest"

topic 'Setup Homebrew'

if [ `uname` = "Darwin" ]; then
	if type brew > /dev/null 2>&1; then
		echo 'Homebrew is already installed'
	else
		echo 'Installing Homebrew'
		/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	fi
else
	echo 'This environment does not need Homebrew'
fi

topic 'Setup avengers (private AI config: ~/.claude rules / settings / secrets)'

avengers_dir="$HOME/work/dev/my-projects/avengers"
avengers_repo="git@github.com:thanks2music/avengers.git"

if [ ! -d "$avengers_dir" ]; then
	if command -v git > /dev/null 2>&1; then
		echo "Cloning avengers (private) -> $avengers_dir"
		mkdir -p "$(dirname "$avengers_dir")"
		git clone "$avengers_repo" "$avengers_dir" || \
			echo "  [manual] clone 失敗（SSH/GitHub 認証後に再実行）: git clone $avengers_repo $avengers_dir && bash $avengers_dir/bootstrap.sh"
	else
		echo "  [manual] git が無いため clone 不可。git 導入後に: git clone $avengers_repo $avengers_dir && bash $avengers_dir/bootstrap.sh"
	fi
fi

if [ -f "$avengers_dir/bootstrap.sh" ]; then
	echo 'Running avengers bootstrap'
	bash "$avengers_dir/bootstrap.sh"
else
	echo '  [info] avengers 未配置のため bootstrap を skip（上記手順で後ほど実行）'
fi
