# Mac 移行時の HHKB / Karabiner-Elements トラブルと教訓

Time Machine と移行アシスタントで新しい Mac へ環境を引き継いだあと、
Karabiner-Elements のキー変換と HHKB の入力がどちらも効かなくなった。
解決までに分かったことを、次回同じ失敗を繰り返さないためのチェックリストとしてまとめる。

## 前提となる構成

| 項目 | 内容 |
|---|---|
| OS | macOS 26 (Tahoe) |
| キーボード | HHKB Professional HYBRID Type-S（英語配列）を USB 有線で接続 |
| DIP スイッチ | SW2 のみ ON（Mac モード） |
| Karabiner-Elements | 16.3.0（VirtualHIDDevice driver 1.8.0） |
| Karabiner のルール | 左右の ⌘ を単独で押したときに英数 / かなを送る |

HHKB の機種によって必要なドライバやツールが異なる。以下は **HYBRID 系（HYBRID / HYBRID Type-S）** を前提とする。

---

## 教訓（先に結論）

1. **移行アシスタントの後は「動いているように見える」状態を信用しない。** システム機能拡張の承認や入力監視の許可は引き継がれない。表示上は有効でも、実際にはドライバが起動していないことがある。
2. **HYBRID 系に PFU の Mac 用ドライバは不要。** あれは旧型 Professional シリーズ専用。移行で持ち込まれていたら無効化する。
3. **キーボードが反応しないときは、まず Fn キーの位置を疑う。** HHKB の Fn は**右 Shift の右隣**にある。右 ◇ や右 Option と間違えると、接続先の切り替え操作がすべて空振りする。今回いちばん時間を失った原因はこれだった。

---

## チェックリスト（新しい Mac にしたら上から順に）

### Karabiner-Elements

- [ ] Karabiner-Elements Settings → **Setup** を開き、全項目にチェックが付くまで進める。
- [ ] ドライバ機能拡張の許可は、システム設定 → 一般 → ログイン項目と機能拡張 の**一番下にある「機能拡張」→ カテゴリ別 →「ドライバ機能拡張」の (i)** で行う。上半分のログイン項目一覧ではない。
- [ ] 許可がうまくいかないときは、Setup 画面の **Deactivate driver → macOS を再起動 → 許可** の順でやり直す。
- [ ] `systemextensionsctl list | grep Karabiner` で、行頭が `*  *`、末尾が `[activated enabled]` になっていることを確認する。
- [ ] **動作中のドライバをトグルでオフにしない。** 使用中に無効化すると `terminating_for_disable_but_still_running` の状態で止まり、再起動するまで戻らない。
- [ ] Karabiner の Devices で HHKB の **Modify events** をオンにし、左右の ◇ で英数 / かなが切り替わるか確認する。

### HHKB（HYBRID 系）

- [ ] PFU の Mac 用ドライバ（`HHKB Pro ドライバ.app` / `jp.co.pfu.HHKBPro.driver`）は**入れない**。持ち込まれていたら下記「旧 PFU ドライバの止め方」で無効化する。
- [ ] キーマップ変更ツールは **「HHKB Professional キーマップ変更ツール」** を使う。「HHKB Studio キーマップ変更ツール」は Studio 専用で、HYBRID は認識しない（「HHKB Studio の読取りに失敗しました」と出る）。
- [ ] USB 機器一覧（`system_profiler SPUSBDataType`）に HHKB が出ないときは、**USB ハブやポートを変える**。ハブとの相性で認識しないことがある。
- [ ] USB で認識しているのに入力できないときは、**キーボードが Bluetooth で旧 Mac に入力を送り続けている**可能性がある。正しい Fn で **`Fn` + `Ctrl` + `0`** を押して USB 接続に切り替える。
- [ ] Bluetooth で新しい Mac を登録するときは 2 段階で操作する：**`Fn` + `Q` → `Fn` + `Ctrl` + `1`〜`4`**。旧 Mac の登録を残したい場合は、旧 Mac が使っていない番号を選ぶ。ペアリング待ちの取り消しは `Fn` + `X`。
- [ ] 入力できるようになったら、システム設定 → キーボード →「キーボードの種類を変更…」で **ANSI** を選ぶ。

### 移行前にやっておくとよいこと

- [ ] 旧 Mac が手元にあるうちに、HHKB のキーマップ（Fn の位置など）を Professional キーマップ変更ツールで確認し、スクリーンショットを残しておく。
- [ ] Karabiner の設定（`~/.config/karabiner/karabiner.json`）を dotfiles で管理しておく。現状は未登録で、移行時に手で復元する必要がある。

---

## 何が起きていたか

### Karabiner-Elements：⌘ による英数 / かなの切り替えが効かない

- **症状**: ルールは有効なのに切り替わらない。ログに `virtual_hid_keyboard is not ready` が 5 秒ごとに出続ける。
- **原因**: 仮想キーボードのドライバ（`org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`）が実際には動いていなかった。移行直後は `activated enabled` と表示されていたが、持ち込まれたドライバの承認状態が壊れていた。さらに途中で設定画面のトグルを操作したため、停止しようとしても使用中で止まらない状態になった。
- **対処**:
  1. Karabiner Settings → Setup → **Deactivate driver**（管理者パスワードを求められる）
  2. macOS を再起動する。古いドライバが削除され、新しく登録し直される（状態は `activated waiting for user`）
  3. システム設定のドライバ機能拡張でオンにする → `[activated enabled]` になり解決

### HHKB：認識しない → 認識するが入力できない

複数の原因が重なっていた。

| 段階 | 症状 | 原因 | 対処 |
|---|---|---|---|
| 1 | USB 機器一覧に HHKB が出ない | USB ハブとの相性 | 別のハブにつなぎ替えたら認識した |
| 2 | 認識されるが、何を打っても反応しない（Karabiner-EventViewer にも出ない） | キーボードが Bluetooth で旧 Mac に入力を送り続けていた | 正しい Fn で `Fn` + `Q` → `Fn` + `Ctrl` + 番号 を押したら、USB 経由で入力できるようになった |
| 3 | `Fn` + `Ctrl` + `0` などが効かない | **Fn のつもりで別のキーを押していた** | 右 Shift の右隣が正しい Fn |
| 4 | （副次的）旧 PFU ドライバが有効のまま | 移行で持ち込まれた旧型 Professional 用ドライバ | 無効化した（下記） |
| 5 | キーマップ変更ツールが「接続してください」と出る | Studio 用のツールを入れていた | Professional 用のツールを入れ直した |

段階 2 で USB 側に入力が流れるようになった内部の仕組みは推測であり、確認していない。根本原因は Fn キーの押し間違いで、正しい切り替え操作がずっとできていなかったことにある。

### 旧 PFU ドライバの止め方（`jp.co.pfu.HHKBPro.driver`）

アプリをゴミ箱に入れるだけでは止まらない。

1. HHKB の USB を抜く（使用中だと止まらずに固まりやすい）
2. システム設定 → 一般 → ログイン項目と機能拡張 → 機能拡張 → カテゴリ別 → ドライバ機能拡張 (i) → `jp.co.pfu.HHKBPro.driver` を**オフ**にする
3. macOS を再起動する
4. `systemextensionsctl list | grep -i pfu` が `[activated disabled]`（行頭の `*` が 1 つだけ）になっていることを確認する

---

## 調査に使えるコマンド

```bash
# システム機能拡張の状態（Karabiner / PFU）
systemextensionsctl list | grep -i -E 'karabiner|pfu'

# HHKB が USB 機器として見えているか（PFU のベンダー ID は 1278）
ioreg -p IOUSB -w0 -l | grep -i -E '"USB Product Name" = "HHKB|"idVendor" = 1278'

# HHKB の HID の接続方式（USB / Bluetooth）
ioreg -r -c IOHIDDevice -l | grep -A40 '"VendorID" = 1278' | grep -E '"(Product|Transport)" ='

# Bluetooth 側に HHKB がいるか
system_profiler SPBluetoothDataType | grep -i -A4 hhkb

# ドライバ機能拡張の設定画面を直接開く
open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
```

## 参考リンク

- [HHKB ダウンロード（キーマップ変更ツール・ファームウェア）](https://happyhackingkb.com/jp/download/) — キーマップ変更ツールは Professional 用（HYBRID Type-S / HYBRID / Classic 用）と Studio 用に分かれている。ファームウェアもここから入手する
- [Mac 用ドライバ](https://happyhackingkb.com/jp/download/macdownload.html) — 対象は旧型 Professional シリーズのみ。HYBRID 系は macOS 標準ドライバで動作すると明記されている
- [PFU FAQ：macOS 26 Tahoe への対応](https://faq.pfu.jp/faq/show/7462?category_id=181&site_domain=hhkb)
