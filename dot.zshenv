# ~/.zshenv — zsh の **すべての** 起動で読まれる（対話・非対話・スクリプトを問わない）。
#
# ここに置く理由（因果を正確に）:
#   MCP サーバーへ届かなかった主因は **export の欠落**である。8 変数のうち 5 個に
#   export が無く、子プロセスの環境に渡っていなかった。実測:
#
#                              対話シェルの子プロセス   新規の非対話 zsh -c
#     .zshrc + export あり            ✅ 見える              ❌
#     .zshrc + export なし            ❌ 見えない             ❌
#     .zshenv                         ✅                     ✅
#
#   ターミナルから claude を起動する限り MCP サーバーは対話シェルの子プロセスなので、
#   export さえ付いていれば .zshrc のままでも届いていた。
#
#   .zshenv へ移す意義は「到達範囲の拡大」である。cron / #!/bin/zsh のスクリプト /
#   ssh host cmd のような **新規の非対話 zsh** にも届くようになる。
#
# トレードオフ（意図的に受け入れている）:
#   GITHUB_PAT を含む 8 個の秘密が「すべての zsh とその全子孫」に載る。
#   ps eww やクラッシュレポートから読める範囲が広がる。到達範囲と露出範囲は
#   同じコインの裏表であり、ここでは利便性を選んでいる。
#
# 注意:
#   .zshenv は zsh のあらゆる起動で読まれるため、重い処理や出力を書いてはいけない。
#   これは **source 先のファイルにも及ぶ**（.airc / .airc.local に echo を書くと
#   scp や rsync のような非対話セッションを壊す）。
#   PATH の構築や補完の設定は dot.zshrc 側に置く。
#
#   ZDOTDIR が設定されている環境では ~/.zshenv ではなく $ZDOTDIR/.zshenv が読まれる
#   （実測で確認）。本リポジトリは ZDOTDIR を設定しない前提。
#
# 既知の限界:
#   GUI（Finder / Dock）から起動したアプリは launchd の環境を継承し、シェルの
#   rc ファイルを一切読まない。デスクトップアプリ版 Claude Code から MCP を使う場合は
#   本ファイルでも解決しないため、別途確認が必要。

# AI/LLM 関連の設定。base → local の順に読む（他の *rc と同じく local が後で勝つ）。
#
#   .airc       — CLAUDE_CODE_MAX_OUTPUT_TOKENS 等。Claude Code とその子プロセス向けなので
#                 .zshrc ではなくここに置く（.zshrc だと非対話に届かない）
#   .airc.local — API キー。sops + age で暗号化された avengers から
#                 bootstrap.sh が復号して配置する
[ -f "$HOME/.airc" ]       && source "$HOME/.airc"
[ -f "$HOME/.airc.local" ] && source "$HOME/.airc.local"
