# pnpm の更新と、pnpm で入れたグローバルの CLI（Vercel CLI）

2026-10-11 に Vercel CLI を 54.9.1 から 63.1.2 へ上げるため、先に pnpm を 11.5.2 から 12.11.2 へ上げた。
途中で `vercel` が `Cannot find module` で動かなくなった。原因と、次に同じことをするときの手順をまとめる。

## 前提となる構成（2026-10-11 時点）

| 項目 | 内容 |
|---|---|
| pnpm の入れ方 | pnpm 自身が管理する（`pnpm self-update`）。npm / Homebrew / asdf では入れていない |
| `PNPM_HOME` | `~/Library/pnpm` |
| Node.js | asdf（`dot.tool-versions` の `nodejs 26.3.0`） |
| pnpm で入れたグローバルの CLI | `vercel`、`@usebruno/cli`（`bru`） |
| プロジェクトの pnpm | 各プロジェクトの `package.json` の `packageManager` で固定する（例: revolution は `pnpm@10.11.0`） |

## 方針: pnpm は asdf で管理しない

asdf で管理するのは言語ランタイムだけ（`dot.tool-versions` の冒頭のとおり）。pnpm は入れない。

- **プロジェクトごとの版は、pnpm 自身が切り替える。** `packageManager` を読んで、その版をダウンロードして使う。
  revolution の中で `pnpm --version` を実行すると `10.11.0` が返る。ダウンロードした版は `$PNPM_HOME/.tools/pnpm/<版>` に溜まる。
  asdf でも管理すると、pnpm の版の正本が `.tool-versions` と `packageManager` の 2 つになる。CI と Vercel が読むのは `packageManager` の方
- **pnpm 12 は Node.js の要らない単体の実行ファイル**（`pnpm self-update` で入れた場合。公式の [Compatibility](https://pnpm.io/installation#compatibility)）。
  asdf で Node.js の版を切り替えても pnpm には影響しない
- asdf の pnpm plugin（`jonathanmorley/asdf-pnpm`）は pnpm 公式のものではない。plugin は追加されているが、版は 1 つも入っていない。
  紛らわしければ `asdf plugin remove pnpm` で外してよい

> 2026-03-02 の報告書（下の「関連」）の環境表には「pnpm 10.11.0 (asdf 管理)」とある。2026-10-11 時点では asdf に pnpm の版は無く、上の方針に一本化している。

## pnpm 10 と 11 以降の配置の違い

| | pnpm 10 | pnpm 11 以降 |
|---|---|---|
| グローバルのパッケージ | `$PNPM_HOME/global/5/` に全部まとめて入る | `$PNPM_HOME/global/v11/<hash>/` にパッケージごとに分かれて入る |
| コマンドの入口 | `$PNPM_HOME` の直下 | `$PNPM_HOME/bin`（pnpm 本体も含む） |
| PATH に必要なもの | `$PNPM_HOME` | `$PNPM_HOME/bin` |

出典: [pnpm 11.0 release blog](https://pnpm.io/blog/releases/11.0)

---

## 教訓（先に結論）

1. **グローバルの CLI を上げる前に、pnpm を上げる。**
   `pnpm update -g` が pnpm 10 の置き場所（`global/5`）から新しい置き場所へ移すのは **v11.28.1 / v12.8.0 以降**。
   `$PNPM_HOME` の直下にハードリンクで置かれた実行ファイルを消すのは **v11.28.3 / v12.9.0 以降**。11.5.2 のままでは移行されない
2. **`pnpm setup` は使わず、`dot.zshrc` を手で直す。**
   `pnpm setup` は `dot.zshrc` の末尾に別のブロックを足す。そのブロックは asdf より後ろに来るので、`dot.zshrc` の PATH の設計（asdf を先にする）と合わない。
   さらに古い pnpm の `pnpm setup` には不具合がある。
   - 一度 PATH に入った `$PNPM_HOME/bin` を先頭に戻さない（v11.28.5 / v12.10.0 で修正）
   - `# pnpm` のコメントからブロックまでの間の行を消す（v12.7.0 で修正）
3. **移行の後、`$PNPM_HOME` の直下に古い入口が残る。**
   `global/5` は消えても、そこを指していた入口のファイル（シェルスクリプト。ハードリンクではないので、上の削除の対象にならなかった）は残った。
   PATH に `$PNPM_HOME` が残っていると、こちらが先に見つかって `Cannot find module '.../global/5/...'` で落ちる。**Node.js の版は関係ない**
4. **確認は新しいターミナルで行う。** `exec zsh` は今の PATH を引き継ぐので、順番が直ったかを確かめられない
5. **`pnpm self-update` はプロジェクトの外で実行する。** v12.7.0 より前は、版を固定したプロジェクトの中で実行すると、グローバルの pnpm を更新しない

---

## 手順（次に上げるとき）

```bash
cd ~                                   # プロジェクトの外で実行する
pnpm self-update                       # 最新へ。版を指定するなら pnpm self-update 12.11.2
type -a pnpm && pnpm --version         # $PNPM_HOME/bin/pnpm が先頭に来ていること

# メジャーを越えるときは --latest が要る
# (グローバルの package.json には ^63.1.2 のような範囲で記録されていて、範囲内でしか上がらない)
pnpm update -g --latest vercel
type -a vercel && vercel --version     # $PNPM_HOME/bin/vercel だけが出ること
```

`dot.zshrc` の pnpm の設定は 1 か所だけにする（asdf のブロックより前）。

```bash
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"
```

### 途中で聞かれるビルドスクリプトの承認

pnpm は依存のインストール時のスクリプトを既定で止め、グローバルの更新でも承認するかを聞いてくる。
承認しなかったものは `allowBuilds` に `false` で記録され、次からは聞かれない。

| パッケージ | 必要としているもの | スクリプトの中身（実物を読んだ） | 判断 |
|---|---|---|---|
| `protobufjs` 7.6.6 | `@usebruno/cli` の gRPC 関連（`@grpc/proto-loader` など） | 親の `package.json` の版の指定が `~` で始まっていないときに、警告を 1 行出すだけ | 承認しない |
| `esbuild` 0.27.0 | `vercel`（`@vercel/node`、`tsx` など） | 本体（`@esbuild/darwin-arm64`）があるかを確かめ、CLI の入口を本体へのリンクに差し替える。本体は別のパッケージとして入っていて、esbuild は実行時にそれを探して使うので、スクリプトなしで動く | 承認しない |

---

## 未解決: pnpm 12 が Node.js 経由で動いている

```text
pnpm is running through Node.js because the script that installs its native binary was skipped.
Reinstall pnpm with its build scripts allowed to run the binary directly.
```

- pnpm 12 は 11.5.2 の `self-update` で入れた。そのとき 11.5.2 が、本体を入れるスクリプトを止めたため、ネイティブの本体が使われていない
- 動作はする。遅くなるだけ
- pnpm 12 自身の `self-update` はネイティブの本体を直接入れる（公式の [self-update](https://pnpm.io/cli/self-update)）。次に `pnpm self-update` で上げれば解消する見込み。同じ版を入れ直す方法は確かめていない

---

## 2026-10-11 に行ったこと

1. `pnpm self-update 12.11.2`（11.5.2 → 12.11.2）
2. `pnpm update -g --latest vercel`
   - `global/5` から `@usebruno/cli` と `vercel` を移した
   - vercel は 54.9.1 → 63.1.2。bru は 2.15.1
   - 承認を聞かれた `protobufjs` と `esbuild` は承認しなかった
3. `$PNPM_HOME` の直下の、壊れた入口 11 個を削除した
   - `global/5` を指していたもの: `vercel` `vc` `bru` `acorn` `browserslist` `live-server` `tsc` `tsserver` `vm2`
   - `$PNPM_HOME/nodejs/23.11.0` を指していたもの: `npm` `npx`（2026-03-02 に `pnpm env remove` で消した Node.js の npm の入口）
4. `dot.zshrc`: PATH を `$PNPM_HOME/bin` にし、11.5.2 の `pnpm setup` が末尾に足したブロックを消した
5. 新しいログインシェルで確認した
   - `vercel` 63.1.2、`pnpm` 12.11.2、`bru` 2.15.1 が、どれも `$PNPM_HOME/bin` から実行される
   - `node` は asdf の v26.3.0（PATH の順番は asdf の shims → `$PNPM_HOME/bin`）

### プロジェクトへの影響

- `packageManager` で版を固定しているプロジェクトは、その版で動くので影響を受けない
- 固定していないプロジェクトは、グローバルの pnpm（12）で動く。2026-10-11 時点で `~/work` に 10 件あった（業務の repo を含む）。
  pnpm 12 は lockfile の作り方が変わる（依存を解決し直す最初の install で書き換わる）。チームの repo で `pnpm install` を実行する前に、チームの pnpm の版を確かめる

---

## 関連

- [report/2026-03-02-node-version-pnpm-path-and-claude-code-fix.md](report/2026-03-02-node-version-pnpm-path-and-claude-code-fix.md) — なぜ pnpm の PATH を asdf より前に書くのか（pnpm の Node.js が asdf の Node.js より先に使われていた件）

## 参照（一次情報）

- [pnpm 11.0 release blog](https://pnpm.io/blog/releases/11.0) — グローバルの置き場所と `$PNPM_HOME/bin`
- [pnpm self-update](https://pnpm.io/cli/self-update) / [pnpm update](https://pnpm.io/cli/update) / [Installation（Compatibility）](https://pnpm.io/installation)
- リリースノート: [v11.28.1](https://github.com/pnpm/pnpm/releases/tag/v11.28.1)（`global/5` からの移行）、
  [v11.28.3](https://github.com/pnpm/pnpm/releases/tag/v11.28.3)（ハードリンクの実行ファイルの削除）、
  [v12.7.0](https://github.com/pnpm/pnpm/releases/tag/v12.7.0)（`pnpm setup` が行を消す不具合の修正、プロジェクト内の `self-update`）、
  [v12.10.0](https://github.com/pnpm/pnpm/releases/tag/v12.10.0)（`pnpm setup` の PATH の順番）、
  [v12.0.0](https://github.com/pnpm/pnpm/releases/tag/v12.0.0)（pnpm 12 の破壊的変更）
