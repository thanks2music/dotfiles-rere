# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## リポジトリ概要

このリポジトリは、macOS (Apple Silicon) 用の個人dotfiles設定です。[shiwanoのdotfiles](https://github.com/shiwano/dotfiles)をベースにしています。シンボリックリンクを通じて、シェル設定、開発ツールのセットアップ、環境設定を管理します。

## インストール & セットアップ

### 初回セットアップ
```bash
# 新規インストール（clone してから実行する。curl をパイプで bash に渡さない）
git clone https://github.com/thanks2music/dotfiles-rere.git ~/dotfiles
bash ~/dotfiles/setup.sh

# ローカルセットアップ（リポジトリが既に存在する場合）
cd ~/dotfiles
./setup.sh
```

セットアップスクリプトの処理内容：
1. リポジトリを`~/dotfiles`にクローン
2. `~/bin`の実行ファイルのシンボリックリンクを作成
3. `~/.config`ディレクトリの内容をリンク
4. すべての`dot.*`ファイルをホームディレクトリにシンボリックリンク（`.filename`として）
5. `dot.*.example`ファイルが存在しない場合はコピー
6. Neovim設定をセットアップ
7. Vim/Neovim用のvim-plugをインストール
8. Homebrewをインストール（macOSのみ）

### パッケージ管理
```bash
# core は setup.sh が自動導入する。残り 2 つは任意:
brew bundle install --file=~/dotfiles/Brewfile            # core（両方の Mac）
brew bundle install --file=~/dotfiles/Brewfile.desktop    # 重量級・据置専用
brew bundle install --file=~/dotfiles/Brewfile.vscode     # VS Code 拡張（code が PATH に必要）

# Homebrewパッケージを更新
brew update && brew upgrade
```

## ファイル構造と命名規則

- `dot.*` → `~/.*`にシンボリックリンク（例：`dot.zshrc` → `~/.zshrc`）
- `dot.*.example` → テンプレートファイル。存在しない場合は`~/.{filename}`にコピー
- `dot.*.local` → ローカル上書き設定（gitで追跡しない）
- `bin/` → `~/bin`にシンボリックリンクされる実行スクリプト
- `config/` → `~/.config`にシンボリックリンクされる設定ファイル

### 設定の階層構造

シェル設定は複数の層に分割されています（読み込み順）：

**ZSH:**
1. `.zshrc` - メイン設定
2. `.zshrc.local` - ローカル上書き設定
3. `.aliasrc` - 共有エイリアス
4. `.aliasrc.local` - ローカルエイリアス
5. `.cloudrc` - クラウドプロバイダー設定（AWS、GCP）
6. `.cloudrc.local` - ローカルクラウド設定
7. `.airc` - AI/LLM CLI設定
8. `.airc.local` - ローカルAI設定（APIキー）

**Bash:**
1. `.bash_profile` - ログインシェル設定
2. `.bashrc` - インタラクティブシェル設定

## 主要な開発ツール

### バージョンマネージャー
- **asdf** - 唯一のバージョンマネージャー。`dot.tool-versions` により
  言語ランタイム（Node.js / Ruby / Python / Java / Go / Bun / Rust）に限定する。
  `bash tools/asdf.sh` で plugin と pin されたバージョンを導入する。
- CLI ツール（kubectl / helm / jq / yq / direnv / terraform）は asdf ではなく Homebrew 側。
- rbenv / anyenv は削除した。asdf の shim の上に重なって解決順を変えるため。

### パッケージマネージャー
- **Homebrew** - macOSパッケージマネージャー（Apple Siliconでは`/opt/homebrew`）
- **pnpm** - Node.js パッケージマネージャー。PATH では asdf shims が先に来るため
  asdf 管理のランタイムが勝つ。pnpm のグローバルツール (vercel 等) は asdf が
  管理していないため引き続き参照できる
- **Composer** - PHPパッケージマネージャー

### シェル & ターミナル
- **zsh** - デフォルトシェル（Powerlevel10kテーマ）
- **tmux** - カスタムキーバインディング付きターミナルマルチプレクサ
- **neovim** - プライマリエディタ（`vi`、`vim`としてエイリアス設定）

## よく使うコマンド & ワークフロー

### Tmuxセッション
```bash
# 新規セッション作成
tn session-name

# セッションにアタッチ（存在しない場合は作成）
ta session-name

# アタッチまたは新規作成
tan

# セッションを終了
tk session-name

# セッション一覧
tls

# Tmuxキーバインディング（プレフィックス: Ctrl-t）
Ctrl-t , - 4分割
Ctrl-t . - AIツール付き4分割（Gemini + Claude）
Ctrl-t ; - 監視ツール付き4分割
Ctrl-t n - カレントディレクトリで新規ウィンドウ
Ctrl-t e - nvimで新規ウィンドウ
Ctrl-t v - 縦分割
Ctrl-t h - 横分割
```

### Gitワークフロー（fzf統合）
```bash
# インタラクティブなgitファイル操作
a              # ファイルを追加（fzf選択）
r              # ファイルを復元（fzf選択）
edit-git-file  # git管理ファイルを編集（fzf）
edit-git-changed-file  # 変更ファイルを編集（fzf）

# Gitエイリアス
g    # git
ga   # git add -A
gg   # git grep
s    # git status
st   # git status -s
d    # git diff
```

### LLM/AIツール
```bash
# Claude CLI
cl                    # claude
claude-cost           # Claude API使用量確認（bunx ccusage）
csid "keyword"        # ClaudeセッションIDを検索
claude-find "keyword" # タイムスタンプ付きでClaudeセッションを検索

# dotfilesには~/.aircと~/.airc.localにAI設定が含まれています
```

### クラウドプロバイダー管理
```bash
# AWS
aws-t2m       # thanks2musicプロファイルに切り替え
aws-t4v       # thanks4venプロファイルに切り替え
aws-tokyo     # AWS東京リージョン
aws-us        # AWS米国東部リージョン

# Google Cloud
gcloud-default      # デフォルト設定を有効化
gcloud-personal     # 個人設定を有効化
gcloud-thanks4ven   # 個人事業用設定を有効化
gcloud-company      # 仕事用設定を有効化
gcloud-current      # 現在のアクティブな設定を表示
```

### 開発ショートカット
```bash
# ナビゲーション
dotf        # cd ~/dotfiles
..          # cd ../
...         # cd ../../
....        # cd ../../../

# エディタ
o           # $EDITORで開く
vi/vim      # neovim（エイリアス）

# パッケージマネージャー
pn/pm       # pnpm

# ユーティリティ
cat         # bat（シンタックスハイライト付き）
reload      # シェル設定をリロード
```

### 検索 & ファイル操作
```bash
# FZFベースの関数
move-to-ghq-directory      # ghq管理リポジトリに移動
grep-git-files "pattern"   # ページャー付きripgrep

# ファイル圧縮/展開
compress file.txt          # tar.gzを作成
extract archive.tar.gz     # 自動検出して展開
```

## 環境変数

### 重要なパス
- `GOPATH`: `$HOME/code`
- `PNPM_HOME`: `$HOME/Library/pnpm`（asdf shims より後ろに追加されるため asdf が優先）
- `BREW_PREFIX`: `/opt/homebrew`（Apple Silicon）
- `ANDROID_SDK_ROOT`: `$HOME/Library/Android/sdk`
- `JAVA_HOME`: Homebrew の OpenJDK から設定（Android Studio 分岐はマシン間で
  黙って差分が出るため削除した）

### PATH優先順位
1. `$BREW_PREFIX/opt/openjdk/bin`（JAVA_HOME）
2. `$HOME/.bun/bin`
3. `$HOME/.asdf/shims`（asdf 管理のランタイム。pnpm より優先される）
4. `$PNPM_HOME`（pnpm グローバルパッケージ）
2. `$HOME/bin`
3. Homebrew bins
4. asdf shims（Node.js、Ruby、Pythonなど）
5. システムbins

## Vim/Neovim設定

- メイン設定：`dot.vimrc`（`~/.config/nvim/init.vim`にシンボリックリンク）
- プラグインマネージャー：vim-plug
- 主なプラグイン：yankround、vim-surround、nerdcommenter、vim-prettier、vim-goimports

## シェル機能

### FZF設定
- デフォルトで完全一致
- デフォルトコマンドとしてripgrepを使用
- カスタムキーバインディング：Tab/Shift-Tabナビゲーション、Ctrl-aで全選択
- git操作、履歴検索、ファイルナビゲーションと統合

### ヒストリ
- 全zshセッション間で共有
- サイズ：100,000エントリ
- 重複排除有効
- Ctrl-rでfzfベースの履歴検索

### 自動補完
- Homebrew経由のzsh-completions
- GitHub Copilot CLIエイリアス統合
- 大文字小文字を区別しないマッチング
- make、gitなどの強化された補完

## プラットフォーム固有の注意点

### macOS（Apple Silicon）
- Homebrewプレフィックス：`/opt/homebrew`
- GNU coreutils/sedを使用（BSD版よりGNU版を優先）
- tmuxクリップボード統合のためreattach-to-user-namespaceを含む
- MySQLクライアントはHomebrew経由でインストール

### Darwin固有のTmux設定
macOS上では`~/.tmux.darwin.conf`から追加設定が読み込まれます

## 設定ファイルの編集

```bash
# クイック編集エイリアス
vimrc     # ~/.vimrc
zshrc     # ~/.zshrc
aliasrc   # ~/.aliasrc
cloudrc   # ~/.cloudrc
tmuxrc    # ~/.tmux.conf
sshrc     # ~/.ssh/config
zshlog    # ~/.zsh_history
```

## 重要な考慮事項

1. **ローカル上書き**：マシン固有の設定（APIキー、ローカルパスなど）には常に`.local`ファイルを使用してください
2. **PATH 管理**：asdf shims が pnpm グローバルパッケージより優先されます。
   vercel CLI などの pnpm ツールは asdf が管理していないため引き続き解決されます
3. **バージョンマネージャー**：asdf のみ、かつ言語ランタイム専用です。rbenv/anyenv は削除しました
4. **シェル統合**：Amazon QとVS Codeのシェル統合が自動的に読み込まれます
5. **セキュリティ**：`.local`ファイルは決してコミットしないでください - 機密情報が含まれています
