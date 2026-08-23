# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS (Apple Silicon) based on [shiwano's dotfiles](https://github.com/shiwano/dotfiles). It manages shell configuration, development tools setup, and environment configurations through symbolic linking.

## Installation & Setup

### Initial Setup
```bash
# Fresh installation (clone first, then run — do NOT pipe curl into bash)
git clone https://github.com/thanks2music/dotfiles-rere.git ~/dotfiles
bash ~/dotfiles/setup.sh

# Local setup (if repository already exists)
cd ~/dotfiles
./setup.sh
```

The setup script performs:
1. Clones repository to `~/dotfiles`
2. Creates symbolic links for `~/bin` executables
3. Links `~/.config` directory contents
4. Symlinks all `dot.*` files to home directory (as `.filename`)
5. Copies `dot.*.example` files if they don't exist
6. Sets up Neovim configuration
7. Installs vim-plug for Vim/Neovim
8. Installs Homebrew (macOS only)

### Package Management
```bash
# setup.sh installs the core Brewfile automatically. The other two are opt-in:
brew bundle install --file=~/dotfiles/Brewfile            # core (both machines)
brew bundle install --file=~/dotfiles/Brewfile.desktop    # heavy / desktop-only
brew bundle install --file=~/dotfiles/Brewfile.vscode     # VS Code extensions (needs `code` on PATH)

# Update Homebrew packages
brew update && brew upgrade
```

## File Structure & Naming Convention

- `dot.*` → Symlinked to `~/.*` (e.g., `dot.zshrc` → `~/.zshrc`)
- `dot.*.example` → Template files copied to `~/.{filename}` if not exists
- `dot.*.local` → Local overrides (not tracked in git)
- `bin/` → Executable scripts symlinked to `~/bin`
- `config/` → Configuration files symlinked to `~/.config`

### Configuration Layers

The shell configuration is split into multiple layers (loaded in order):

**ZSH:**
1. `.zshenv` - Read on **every** zsh invocation (interactive, non-interactive, scripts).
   Sources `.airc` then `.airc.local`, so Claude Code settings and API keys reach
   child processes such as MCP servers. Keep it silent and cheap.
2. `.zprofile` - Login shells only. Holds `brew shellenv` (the only place it lives).
3. `.zshrc` - Main interactive configuration
4. `.aliasrc` - Shared aliases
5. `.aliasrc.local` - Local aliases
6. `.cloudrc` - Cloud provider configs (AWS, GCP)
7. `.cloudrc.local` - Local cloud configs
8. `.zshrc.local` - Local overrides (**last**, so it wins over everything above)

Note: `.airc` / `.airc.local` moved from `.zshrc` to `.zshenv`. `.zshrc` is only read by
interactive shells, so anything defined there never reaches a fresh non-interactive zsh
(cron, `#!/bin/zsh` scripts, `ssh host cmd`).

**Bash:**
1. `.bash_profile` - Login shell configuration
2. `.bashrc` - Interactive shell configuration

## Key Development Tools

### Version Managers
- **asdf** - The only version manager. Scoped to language runtimes
  (Node.js, Ruby, Python, Java, Go, Bun, Rust) via `dot.tool-versions`.
  Run `bash tools/asdf.sh` to install plugins and pinned versions.
- CLI tools (kubectl, helm, jq, yq, direnv, terraform) come from Homebrew, not asdf.
- rbenv / anyenv were removed: they layered shims on top of asdf and changed
  the resolution order.

### Package Managers
- **Homebrew** - macOS package manager (`/opt/homebrew` for Apple Silicon)
- **pnpm** - Node.js package manager. Note asdf shims come FIRST in PATH, so
  asdf-managed runtimes win; pnpm global tools (vercel etc.) are still reachable
  because asdf does not manage them
- **Composer** - PHP package manager

### Shell & Terminal
- **zsh** - Default shell with Powerlevel10k theme
- **tmux** - Terminal multiplexer with custom keybindings
- **neovim** - Primary editor (aliased as `vi`, `vim`)

## Common Commands & Workflows

### Tmux Sessions
```bash
# Create new session
tn session-name

# Attach to session (or create if doesn't exist)
ta session-name

# Attach or create new
tan

# Kill session
tk session-name

# List sessions
tls

# Tmux keybindings (prefix: Ctrl-t)
Ctrl-t , - Split into 4 panes
Ctrl-t . - Split into 4 panes with AI tools (Gemini + Claude)
Ctrl-t ; - Split into 4 panes with monitoring tools
Ctrl-t n - New window with current directory
Ctrl-t e - New window with nvim
Ctrl-t v - Vertical split
Ctrl-t h - Horizontal split
```

### Git Workflows (with fzf integration)
```bash
# Interactive git file operations
a              # Add files (fzf selection)
r              # Restore files (fzf selection)
edit-git-file  # Edit git tracked files (fzf)
edit-git-changed-file  # Edit changed files (fzf)

# Git aliases
g    # git
ga   # git add -A
gg   # git grep
s    # git status
st   # git status -s
d    # git diff
```

### LLM/AI Tools
```bash
# Claude CLI
cl                    # claude
claude-cost           # Check Claude API usage (bunx ccusage)
csid "keyword"        # Search Claude session IDs
claude-find "keyword" # Find Claude sessions with timestamp

# The dotfiles include AI configurations in ~/.airc and ~/.airc.local
```

### Cloud Provider Management
```bash
# AWS
aws-t2m       # Switch to thanks2music profile
aws-t4v       # Switch to thanks4ven profile
aws-tokyo     # AWS Tokyo region
aws-us        # AWS US East region

# Google Cloud
gcloud-default      # Activate default configuration
gcloud-personal     # Activate personal configuration
gcloud-thanks4ven   # Activate business configuration
gcloud-company      # Activate company configuration
gcloud-current      # Show current active configuration
```

### Development Shortcuts
```bash
# Navigate
dotf        # cd ~/dotfiles
..          # cd ../
...         # cd ../../
....        # cd ../../../

# Editor
o           # Open with $EDITOR
vi/vim      # neovim (aliased)

# Package managers
pn/pm       # pnpm

# Utilities
cat         # bat (with syntax highlighting)
reload      # Reload shell configuration
```

### Search & File Operations
```bash
# FZF-based functions
move-to-ghq-directory      # Navigate to ghq managed repository
grep-git-files "pattern"   # Ripgrep with pager

# File compression/extraction
compress file.txt          # Create tar.gz
extract archive.tar.gz     # Auto-detect and extract
```

## Environment Variables

### Critical Paths
- `GOPATH`: `$HOME/code`
- `PNPM_HOME`: `$HOME/Library/pnpm` (appended after asdf shims, so asdf wins)
- `BREW_PREFIX`: `/opt/homebrew` (Apple Silicon)
- `ANDROID_SDK_ROOT`: `$HOME/Library/Android/sdk`
- `JAVA_HOME`: Set from Homebrew OpenJDK (the Android Studio branch was removed
  because it silently differed between machines)

### PATH Priority
1. `$BREW_PREFIX/opt/openjdk/bin` (JAVA_HOME)
2. `$HOME/.bun/bin`
3. `$HOME/.asdf/shims` (asdf-managed runtimes — these win over pnpm)
4. `$PNPM_HOME` (pnpm global packages)
2. `$HOME/bin`
3. Homebrew bins
4. asdf shims (Node.js, Ruby, Python, etc.)
5. System bins

## Vim/Neovim Configuration

- Main config: `dot.vimrc` (symlinked to `~/.config/nvim/init.vim`)
- Plugin manager: vim-plug
- Notable plugins: yankround, vim-surround, nerdcommenter, vim-prettier, vim-goimports

## Shell Features

### FZF Configuration
- Exact matching by default
- Uses ripgrep as default command
- Custom keybindings: Tab/Shift-Tab navigation, Ctrl-a select all
- Integrated with git operations, history search, and file navigation

### History
- Shared across all zsh sessions
- Size: 100,000 entries
- Deduplication enabled
- Ctrl-r for fzf-based history search

### Auto-completion
- zsh-completions via Homebrew
- GitHub Copilot CLI alias integration
- Case-insensitive matching
- Enhanced completion for make, git, etc.

## Platform-Specific Notes

### macOS (Apple Silicon)
- Homebrew prefix: `/opt/homebrew`
- Uses GNU coreutils/sed (prefer GNU versions over BSD)
- Includes reattach-to-user-namespace for tmux clipboard integration
- MySQL client installed via Homebrew

### Darwin-Specific Tmux Config
Additional config loaded from `~/.tmux.darwin.conf` when on macOS

## Editing Configuration Files

```bash
# Quick edit aliases
vimrc     # ~/.vimrc
zshrc     # ~/.zshrc
aliasrc   # ~/.aliasrc
cloudrc   # ~/.cloudrc
tmuxrc    # ~/.tmux.conf
sshrc     # ~/.ssh/config
zshlog    # ~/.zsh_history
```

## Important Considerations

1. **Local Overrides**: Always use `.local` files for machine-specific configurations (API keys, local paths, etc.)
2. **PATH Management**: asdf shims take priority over pnpm global packages.
   pnpm tools like the vercel CLI still resolve because asdf does not manage them
3. **Version Managers**: asdf only, and only for language runtimes. rbenv/anyenv were removed
4. **Shell Integration**: Amazon Q and VS Code shell integrations are loaded automatically
5. **Security**: Never commit `.local` files - they contain sensitive information
