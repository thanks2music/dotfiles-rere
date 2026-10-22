# dotfiles

> *"Insanity is doing the same thing over and over and expecting different results."*
>
> `setup.sh` is idempotent: run it over and over and you get the same result. So we're sane.
> (Einstein never said it, by the way.)

macOS (Apple Silicon) dotfiles by [@thanks2music](https://github.com/thanks2music), maintained since 2011.
Originally based on [shiwano/dotfiles](https://github.com/shiwano/dotfiles).

## What's inside

| Path | Goes to | What |
|---|---|---|
| `dot.*` | `~/.*` (symlink) | zsh, git, tmux, Vim / Neovim, ... |
| `dot.*.example` | `~/.*` (copied if missing) | Templates for machine-specific files |
| `config/*` | `~/.config/*` (symlink) | Alacritty, fish, Zed, ... |
| `bin/*` | `~/bin/*` (symlink) | Small helper scripts |
| `Brewfile*` | — | Homebrew bundles: core (installed by `setup.sh`), desktop, VS Code, App Store |

Machine-specific settings and secrets go in `dot.*.local` files, which git ignores.

## Install

Clone first, then run the script.

```
git clone https://github.com/thanks2music/dotfiles-rere.git ~/dotfiles
bash ~/dotfiles/setup.sh
```

Piping through `curl` is intentionally not documented here. You cannot inspect the
script before it runs, and `setup.sh` clones this repository anyway — so cloning
first is strictly better. See the note at the top of `setup.sh`.

`setup.sh` is idempotent: phases that already completed report `ok`. It exits
non-zero if any phase failed **or was skipped**, so read the summary rather than
treating a non-zero exit as a failure on its own.

## More

Shell config layers, PATH order and version managers are covered in [CLAUDE.md](CLAUDE.md).
