# ~/.zshenv — zsh の **すべての** 起動で読まれる（対話・非対話・スクリプトを問わない）。
#
# ここに置く理由:
#   API キー等を保持する ~/.airc.local は以前 dot.zshrc から source していたが、
#   .zshrc は **対話シェルでしか読まれない**。そのため Claude Code が spawn する
#   MCP サーバーや hook からは 1 つも見えていなかった（実測で確認）。
#   .zshenv へ移すことで、非対話の子プロセスにも届く。
#
#   なお ~/.airc.local 側の変数に `export` が付いていることも必要条件。
#   source されても export が無ければ子プロセスの環境には渡らない。
#
# 注意:
#   .zshenv は zsh のあらゆる起動で読まれるため、重い処理や出力を書いてはいけない。
#   PATH の構築や補完の設定は dot.zshrc 側に置く。
#
# 既知の限界:
#   GUI（Finder / Dock）から起動したアプリは launchd の環境を継承し、シェルの
#   rc ファイルを一切読まない。デスクトップアプリ版 Claude Code から MCP を使う場合は
#   本ファイルでも解決しないため、別途確認が必要。

# API キー（sops + age で暗号化された avengers から bootstrap.sh が復号して配置する）
[ -f "$HOME/.airc.local" ] && source "$HOME/.airc.local"
