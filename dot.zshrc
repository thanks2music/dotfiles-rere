export TERM=xterm-256color
export LANG=ja_JP.UTF-8
export XDG_CONFIG_HOME=$HOME/.config
export LS_COLORS='di=01;36'

export GOPATH=$HOME/code
export GO15VENDOREXPERIMENT=1
export GO111MODULE=on

bindkey -e
bindkey '^]'   vi-find-next-char
bindkey '^[^]' vi-find-prev-char

if type brew > /dev/null; then
  export BREW_PREFIX=$(brew --prefix)
else
  export BREW_PREFIX='/usr/local'
fi

# Completion -------------------------------------------------------------------

zstyle ':completion:*:*:make:*' tag-order 'targets'

if [ -d $BREW_PREFIX/share/zsh/zsh-completions ]; then
  FPATH=$BREW_PREFIX/share/zsh/zsh-completions:$FPATH
fi

if [ -d $BREW_PREFIX/share/zsh/site-functions ]; then
  FPATH=$BREW_PREFIX/share/zsh/site-functions:$FPATH
fi

autoload -Uz compinit
compinit

# Envs -------------------------------------------------------------------------
export PATH="$PATH:/opt/homebrew/bin/"
export PATH=$HOME/bin:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$GOPATH/bin:$PATH
export MANPATH=$BREW_PREFIX/share/man:$BREW_PREFIX/man:/usr/share/man

if [ -d $BREW_PREFIX/Cellar/coreutils ]; then
  export PATH="$BREW_PREFIX/opt/coreutils/libexec/gnubin:$PATH"
  export MANPATH="$BREW_PREFIX/opt/coreutils/libexec/gnuman:$MANPATH"
fi

if [ -d $BREW_PREFIX/Cellar/gnu-sed ]; then
  export PATH="$BREW_PREFIX/opt/gnu-sed/libexec/gnubin:$PATH"
  export MANPATH="$BREW_PREFIX/opt/gnu-sed/libexec/gnuman:$MANPATH"
fi

if [ -d $BREW_PREFIX/Cellar/openssl ]; then
  export PATH="$BREW_PREFIX/opt/openssl/bin:$PATH"
fi

if [ -d $BREW_PREFIX/Caskroom/google-cloud-sdk ]; then
  source "$BREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
  source "$BREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
fi

if [ -d ${HOME}/.anyenv ] ; then
  export PATH="$HOME/.anyenv/bin:$PATH"
  eval "$(anyenv init -)"
  for D in `find $HOME/.anyenv/envs -maxdepth 1 -type d`; do
    PATH="$D/shims:$PATH"
  done
fi

if [ -d ${HOME}/.local ] ; then
  export PATH="$HOME/.local/bin:$PATH"
fi

if [ -d ${HOME}/.pub-cache ] ; then
  export PATH="$HOME/.pub-cache/bin:$PATH"
fi

if type fzf > /dev/null; then
  export FZF_DEFAULT_OPTS="--exact --layout=reverse --info hidden --ansi --cycle --filepath-word --marker='X' --history-size=5000 --tiebreak=index
    --bind=tab:down
    --bind=shift-tab:up
    --bind=ctrl-a:select-all
    --bind=ctrl-l:toggle
    --bind=ctrl-h:toggle
    --bind=ctrl-w:backward-kill-word
    --bind=ctrl-u:word-rubout
    --bind=up:preview-page-up
    --bind=down:preview-page-down
    --bind=ctrl-u:half-page-up
    --bind=ctrl-d:half-page-down"
  export FZF_DEFAULT_COMMAND="rg --files --hidden -g '!.git' --sort path"
fi

# Powerlevel10k ----------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# for Alfred
export DIR_HOME="/Users/yoshi/Dropbox"

# asdf -------------------------------------------------------------------------
## Git Ver
. "$HOME/.asdf/asdf.sh"

## Brew Ver
if [ -e $BREW_PREFIX/opt/asdf/libexec/asdf.sh ]; then
  . $BREW_PREFIX/opt/asdf/libexec/asdf.sh
fi

## for Java
. ~/.asdf/plugins/java/set-java-home.zsh

## for GO
. ~/.asdf/plugins/golang/set-env.zsh

# Nix --------------------------------------------------------------------------

if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
  . $HOME/.nix-profile/etc/profile.d/nix.sh;
fi

# fvm --------------------------------------------------------------------------

if type fvm > /dev/null; then
  alias flutter="fvm flutter"
  alias dart="fvm dart"
fi

# Android Studio and Android SDK -----------------------------------------------

if [ -d '/Applications/Android Studio.app/Contents/jre/Contents/Home' ]; then
  export JAVA_HOME='/Applications/Android Studio.app/Contents/jre/Contents/Home'
  export PATH=$JAVA_HOME/bin:$PATH
else
  if [ -d $BREW_PREFIX/opt/openjdk ]; then
    export JAVA_HOME="$BREW_PREFIX/opt/openjdk"
    export PATH=$JAVA_HOME/bin:$PATH
  fi
fi

if [ -d "$HOME/Library/Android/sdk" ]; then
  export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
fi

# rbenv ------------------------------------------------------------------------

[[ -d ~/.rbenv  ]] && \
  export PATH=${HOME}/.rbenv/bin:${PATH} && \
  eval "$(rbenv init -)"

# Vim --------------------------------------------------------------------------

if type nvim > /dev/null; then
  if [ -n "${NVIM_LISTEN_ADDRESS}" ]; then
    alias vi='echo "already open nvim"'
    alias vim='echo "already open nvim"'
    alias nvim='echo "already open nvim"'
  else
    alias vi='nvim'
  fi
  alias vimdiff='nvim -d'
  export EDITOR='nvim'
else
  alias vi='vim'
  export EDITOR='vim'
fi

# Functions --------------------------------------------------------------------

function find-grep {
  find . -name $1 -type f -print | xargs grep -n --binary-files=without-match $2
}

function find-sed {
  find . -name $1 -type f | xargs gsed -i $2
}

function compress {
  if [ -f $1 ] ; then
    tar -zcvf $1.tar.gz $1
  elif [ -d $1 ] ; then
    tar -zcvf $1.tar.gz $1
  else
    echo "'$1' is not a valid file or directory!"
  fi
}

function extract {
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xvjf $1    ;;
      *.tar.gz)    tar xvzf $1    ;;
      *.tar.xz)    tar xvJf $1    ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar x $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xvf $1     ;;
      *.tbz2)      tar xvjf $1    ;;
      *.tgz)       tar xvzf $1    ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *.lzma)      lzma -dv $1    ;;
      *.xz)        xz -dv $1      ;;
      *)           echo "don't know how to extract '$1'..." ;;
    esac
  else
    echo "'$1' is not a valid file!"
  fi
}

function static-httpd {
  if type python > /dev/null; then
    if python -V 2>&1 | grep -qm1 'Python 3\.'; then
      python -m http.server ${1-5000}
    else
      python -m SimpleHTTPServer ${1-5000}
    fi
  fi
}

function fzf-preview-file() {
  echo 'f() {
    if [ -d $@ ]; then
      ls -la $@
    else
      bat --style=numbers --color=always --line-range :500 $@
    fi
  }; f {}'
}

function fzf-preview-git-file() {
  echo 'f() {
    local args="$(echo $@ | cut -c4-)"
    if [ "$(git diff --name-only $args)" ]; then
      git diff --color $args
    elif [ "$(git diff --cached --name-only $args)" ]; then
      git diff --color --cached $args
    elif [ -d $args ]; then
      ls -la $args
    else
      bat --style=numbers --color=always --line-range :500 $args
    fi
  }; f {}'
}

function grep-git-files {
  rg --hidden -g '!.git' -n -p "$@" | less -R --no-init --quit-if-one-screen
}

function move-to-ghq-directory {
  local p="$(ghq list | fzf -1)"
  [ $p ] && cd $(ghq root)/$p
}

function edit-git-grepped-file {
  local s="$(git ls-files . | fzf -1 --preview "$(fzf-preview-file)")"
  [ $s ] && shift $# && vi +"$(echo $s | cut -d : -f2)" "$(echo $s | cut -d : -f1)"
}

function edit-git-file {
  local dir=${1-.}
  local s="$(git ls-files $dir | fzf -1 --preview "$(fzf-preview-file)")"
  [ $s ] && shift $# && vi $s
}

function edit-git-changed-file {
  local s1="$(git status -s -u --no-renames | grep -v -E '^D ')"
  if [ $s1 ]; then
    local s2="$(echo -e $s1 | fzf -1 --preview "$(fzf-preview-git-file)" | cut -c4-)"
    [ $s2 ] && shift $# && vi $s2
  fi
}

function add-git-files() {
  local s="$(git status -s -u --no-renames | grep -v -E "^M ")"
  [ $s ] && echo -e $s | fzf -m --preview "$(fzf-preview-git-file)" | cut -c4- | tr '\n' ' ' | xargs -n1 git add
}

function restore-git-files() {
  local s="$(git status -s -u --no-renames | grep -v -E "^[MA] ")"
  [ $s ] && echo -e $s | fzf -m --preview "$(fzf-preview-git-file)" | cut -c4- | tr '\n' ' ' | xargs -n1 git restore
}

function unstage-git-files() {
  local s="$(git status -s -u --no-renames | grep -E "^[MA] ")"
  [ $s ] && echo -e $s | fzf -m --preview "$(fzf-preview-git-file)" | cut -c4- | tr '\n' ' ' | xargs -n1 git reset HEAD
}

function select-history() {
  BUFFER=$(history -n -r 1 | fzf --no-sort +m --query "$LBUFFER" --prompt="History > ")
  CURSOR=$#BUFFER
}

function goimports-all() {
  local files=($(go list -f '{{$p := .}}{{range $f := .GoFiles}}{{$p.Dir}}/{{$f}} {{end}} {{range $f := .TestGoFiles}}{{$p.Dir}}/{{$f}} {{end}}' ./... | xargs))
  test -z "$(goimports -w $files | tee /dev/stderr)"
}

function count() {
  echo -n "${1-.}" | wc -m
}

# Aliases ----------------------------------------------------------------------
## Shell
alias ls='ls --color=auto'
alias ll='ls -l --block-size=KB'
alias la='ls -A'
alias lal='ls -l -A --block-size=KB'
alias tmux='tmuxx'
alias lsof-listen='lsof -i -P | grep "LISTEN"'
alias reload-shell='exec $SHELL -l'
alias dotfiles='cd ~/dotfiles'
## Git
alias g= 'git'
alias a='add-git-files'
alias d='git diff'
alias s='git status'
alias st='git status -s'
alias gm= 'git co master'
alias ga='git add -A'
alias gg='git grep'
alias r='restore-git-files' # hide 'r' which is zsh's built-in command
alias t='tmux'
alias reload='source ~/.zshrc && exec $SHELL'

# rc
alias vimrc='vi ~/.vimrc'
alias zshrc='vi ~/.zshrc'
alias tmuxrc='vi ~/.tmux.conf'

autoload zmv
alias zmv='noglob zmv -W'
alias zcp='noglob zmv -C'
alias zln='noglob zmv -L'
alias zsy='noglob zmv -Ls'

if type go > /dev/null; then
  alias go-get='GO111MODULE=off go get -u'
  alias go-build-all='go test -run=^$ ./... 1>/dev/null'
fi

if type docker > /dev/null; then
  alias docker-rm-all='docker rm $(docker ps -a -q)'
  alias docker-rmi-all='docker rmi $(docker images -q)'
  alias docker-run-sh='docker run -it --entrypoint sh'
fi

if type bazelisk > /dev/null; then
  alias bazel='bazelisk'
fi

if type ibazel > /dev/null; then
  alias ibazel-go-test='ibazel --run_output_interactive=false -nolive_reload test :go_default_test'
fi

if type bat > /dev/null; then
  alias cat='bat'
fi

# Prompt -----------------------------------------------------------------------

autoload -Uz vcs_info
zstyle ':vcs_info:*' formats '%b'
zstyle ':vcs_info:*' actionformats '%b|%a'

PREEXEC_START_TIME=`date +%s`

function preexec {
  PREEXEC_START_TIME=`date +%s`jjj
}

## コマンド補完
# zinit ice wait'0'; zinit light zsh-users/zsh-completions
# zinitのpathが通らないので一旦コメントアウト
# => https://qiita.com/obake_fe/items/c2edf65de684f026c59c#2-ログインシェルの変更
# autoload -Uz compinit && compinit
# 
# ## 補完で小文字でも大文字にマッチさせる
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# 
# ## 補完候補を一覧表示したとき、Tabや矢印で選択できるようにする
# zstyle ':completion:*:default' menu select=1 

# History ----------------------------------------------------------------------

HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end

zle -N select-history
bindkey '^r' select-history

# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# zsh-autosuggestions
# NOTE: 試験的にAmazon-Qを使用するため、zsh-autosuggestionsを無効化する
# source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Utilities --------------------------------------------------------------------

# シェルのプロセスごとに履歴を共有
setopt share_history

# 余分なスペースを削除してヒストリに記録する
setopt hist_reduce_blanks

# ヒストリにhistoryコマンドを記録しない
setopt hist_no_store

# ヒストリを呼び出してから実行する間に一旦編集できる状態になる
setopt hist_verify

# 行頭がスペースで始まるコマンドラインはヒストリに記録しない
setopt hist_ignore_space

# 直前と同じコマンドラインはヒストリに追加しない
setopt hist_ignore_dups

# 重複したヒストリは追加しない
setopt hist_ignore_all_dups

# 補完するかの質問は画面を超える時にのみに行う｡
LISTMAX=0

# sudo でも補完の対象
zstyle ':completion:*:sudo:*' command-path $BREW_PREFIX/bin /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin

# cdのタイミングで自動的にpushd
setopt auto_pushd

# 複数の zsh を同時に使う時など history ファイルに上書きせず追加
setopt append_history

# 補完候補が複数ある時に、一覧表示
setopt auto_list

# auto_list の補完候補一覧で、ls -F のようにファイルの種別をマーク表示しない
setopt no_list_types

# 保管結果をできるだけ詰める
setopt list_packed

# 補完キー（Tab, Ctrl+I) を連打するだけで順に補完候補を自動で補完
setopt auto_menu

# カッコの対応などを自動的に補完
setopt auto_param_keys

# ディレクトリ名の補完で末尾の / を自動的に付加し、次の補完に備える
setopt auto_param_slash

# ビープ音を鳴らさないようにする
setopt no_beep

# コマンドラインの引数で --prefix=/usr などの = 以降でも補完できる
setopt magic_equal_subst

# ファイル名の展開でディレクトリにマッチした場合末尾に / を付加する
setopt mark_dirs

# 8 ビット目を通すようになり、日本語のファイル名を表示可能
setopt print_eight_bit

# Ctrl+wで､直前の/までを削除する｡
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# ファイルリスト補完でもlsと同様に色をつける｡
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# cd をしたときにlsを実行する
function chpwd() { ls }

# ディレクトリ名だけで､ディレクトリの移動をする｡
setopt auto_cd

# C-s, C-qを無効にする。
setopt no_flow_control

# コマンドライン引数のグロッビング
setopt nonomatch

# Change open files limit and user processes limit.
# See: https://gist.github.com/tombigel/d503800a282fcadbee14b537735d202c
ulimit -n 200000
ulimit -u 2000

# .zshrc.local -----------------------------------------------------------------

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
typeset -U path PATH # Remove duplicated PATHs.

# direnv -----------------------------------------------------------------------

if type direnv > /dev/null; then
  eval "$(direnv hook zsh)"
fi
source ~/.config/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
