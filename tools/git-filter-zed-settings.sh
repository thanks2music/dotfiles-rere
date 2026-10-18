#!/bin/sh
#
# git の clean フィルタ（割り当ては .gitattributes、登録は setup.sh の phase_zed）。
# Zed はエージェントパネルで effort などを切り替えるたびに config/zed/settings.json を書き換え、
# 設定を分割する仕組みも無い。そこで agent_servers.*.default_config_options の値を、コミットに
# 入る内容だけ下の %d の既定値に揃える。作業ツリーのファイルは書き換えない。
#
# 既定値を変えるとき（次のどちらか）:
#   - %d を書き換えてから `git add --renormalize config/zed/settings.json` を実行し、一緒にコミットする
#     （stat が変わらないと git はフィルタをかけ直さない）
#   - 今回だけフィルタを外して追加する: `git -c filter.zed-agent-defaults.clean=cat add config/zed/settings.json`
#
# 知っておくこと:
#   - UI で切り替えた後は `git status` に M が出るが `git diff` は空。`git add` で消える。M のままだと rebase が止まる
#   - smudge が無いので、stash・checkout・restore でこのファイルを書き戻すと、UI で選んだ値は既定値に戻る
#   - 未登録の端末やこのスクリプトの失敗時は、git が素通しにする（差分にノイズが出るだけで内容は壊れない）
#
# 入力はコメント付きの JSON なので jq は使えない。default_config_options の { の直後から次の { か } までの
# 範囲で、// で始まらない行だけを置き換える。範囲が短くなる書き方（ネスト、コメント中の括弧）では差分が残るだけ。

exec perl -0777 -pe '
	my %d = (effort => q("high"), fast => "false", mode => q("auto"), model => q("default"));
	s{("default_config_options"\s*:\s*\{)([^{}]*)}{
		my ($head, $body) = ($1, $2);
		$body =~ s{^(?!\s*//).*$}{ my $l = $&; $l =~ s/"(effort|fast|mode|model)"(\s*:\s*)(?:"[^"]*"|true|false)/"$1"$2$d{$1}/g; $l }gme;
		$head . $body;
	}ge;
'
