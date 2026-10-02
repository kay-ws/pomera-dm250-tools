# pomera-dm250-tools

Small scripts, systemd units and keymaps for using the Pomera DM250 as a Linux terminal (Debian, kernel 3.10).

ポメラ DM250 を Linux 端末として使うために作った、小さなスクリプト・systemd の unit・キーマップの置き場です。電池の表示、Bluetooth のマウスとスピーカー、USB ホストの給電、起動の高速化、キー配列の追加などが入っています。

Linux 化そのものは [ichinomoto さんの配布物](https://www.ekesete.net/log/?p=9504)を使わせてもらっています。ここにあるのは、その上で使うための道具です。

## 動作を確認した環境

- ポメラ DM250
- ichinomoto さんの rootfs（`pomera_dm2x0_debian_20220816`）を Debian 12 bookworm に上げたもの
- カーネル 3.10.0

DM200 では試していません。`usb_vbus` のように、DM250 の電源チップ（RK818）を前提にしたものもあります。

## 中身

置き場所は、DM250 の上でのパスと同じにしてあります。

### コマンド

| パス | 役割 | 使うもの |
|---|---|---|
| `home/pomera/.local/bin/batt` | 電池の残量・状態・電流と、残り時間の見込みを1行で出す | なし |
| `usr/local/bin/bl` | バックライトの明るさを見る・変える | なし |
| `usr/local/bin/bt-mouse` | Bluetooth を立ち上げて、ペアリング済みの LE マウスに繋ぐ | キットの `bt_switch`・`brcm_patchram_plus` |
| `usr/local/bin/bt-speaker` | Bluetooth を立ち上げて、ペアリング済みのスピーカーに繋ぎ、既定の出力にする | 同上、PulseAudio |
| `opt/bin/usb_vbus` | USB ホストの 5V（VBUS）を入れる・切る | キットの `usb_host` |
| `opt/bin/usb_probe` | USB と充電の状態をまとめて表示・記録する（切り分け用） | なし |
| `usr/local/bin/battlog.sh` | 電池の状態を5分ごとに記録する | なし |

`usb_vbus` と `usb_probe` を `/opt/bin` に置いているのは、`sudo` で呼ぶためです。キットの `/opt/bin` は、`sudo` の PATH（`secure_path`）に入っています。

### systemd の unit と設定

| パス | 役割 |
|---|---|
| `etc/systemd/system/keychecker.service` | キットの Fn キー処理（`fnkey`）を正しく起動する。キットの SysV スクリプトのままだと、起動の完了が5分遅れる |
| `etc/systemd/system/keymap-zenkaku.service` | 半角／全角キーで uim-fep の入力を切り替えられるようにする |
| `etc/systemd/system/dm250-keymap.service` ＋ `etc/console-setup/dm250-nav.map` | `menu/help` キーを AltGr にして、`menu`＋矢印で Home/End/PageUp/PageDown、`menu`＋F1/F2 で F11/F12 を出す（コンソール・fbterm 用） |
| `home/pomera/.config/xkb/` | 上と同じキー配列の weston 用 |
| `etc/systemd/system/printk-quiet.service` ＋ `etc/sysctl.d/20-quiet-console.conf` | カーネルのメッセージが画面に割り込まないようにする |
| `etc/systemd/system/backlight-default.service` | 起動時のバックライトを決める |
| `etc/systemd/system/battlog.service` | `battlog.sh` を動かす |

## 導入

### コマンド

```sh
sudo install -m 755 usr/local/bin/* /usr/local/bin/
sudo install -m 755 opt/bin/* /opt/bin/
install -D -m 755 home/pomera/.local/bin/batt ~/.local/bin/batt
```

### unit

```sh
sudo install -m 644 etc/systemd/system/*.service /etc/systemd/system/
sudo install -m 644 etc/console-setup/dm250-nav.map /etc/console-setup/
sudo install -m 644 etc/sysctl.d/20-quiet-console.conf /etc/sysctl.d/
sudo systemctl daemon-reload
sudo systemctl enable keychecker keymap-zenkaku dm250-keymap printk-quiet backlight-default battlog
```

`keychecker.service` を使う場合は、先にキットの SysV スクリプトを外してください。

```sh
sudo update-rc.d -f keychecker remove
sudo rm /etc/init.d/keychecker
sudo systemctl daemon-reload
```

SysV スクリプトが残っていても、同じ名前の unit のほうが優先されるので、いったんは動きます。ただ、その状態だと `systemctl enable` が `Default-Start contains no runlevels` で失敗し、**再起動したときに Fn キーが効かなくなります**。

### weston のキー配列

`home/pomera/.config/xkb/` を `~/.config/xkb/` に置き、`~/.config/weston.ini` の `[keyboard]` に次の1行を足します。

```ini
keymap_options=custom:dm250nav
```

## 使い方

### batt

```console
$ batt
65%  charging  [USB power]   3.931V +60mA 0.24W
$ batt --short
65% +USB
```

`--short` は、狭い場所（端末マルチプレクサのステータス欄など）に出すための短い形です。給電が AC 扱いか USB 扱いかを区別して表示します。

残り時間は、実際に 100% から 0% まで放電したときの記録から、残量 1% あたりの容量を 10% ごとに求めた表で計算しています。残量計の目盛りは等間隔ではないので、単純な比例計算よりずれが小さくなります。

### bl

```sh
bl        # 今の値
bl 150    # 値を指定
bl +20    # 明るく
bl -20    # 暗く
```

weston の fbdev バックエンドでは `Alt+F9`／`Alt+F10` の明るさ変更が効かないので、sysfs に直接書いています。

### bt-mouse / bt-speaker

```sh
bt-mouse "マウスの名前"
bt-speaker "スピーカーの名前"
```

ペアリング済みの機器に繋ぐためのコマンドです。いつも同じ機器を使うなら、`~/.profile` などで環境変数に名前を入れておくと、引数を省けます。

```sh
export BT_MOUSE="マウスの名前"
export BT_SPEAKER="スピーカーの名前"
```

名前を渡さずに実行すると、使い方とペアリング済みの機器の名前を表示して終わります。

カーネル 3.10 の Bluetooth 管理インターフェース（mgmt 1.3）には自動で再接続する仕組みがないので、切れたらもう一度打ちます。`hci0` が無い状態から始めると、電源投入後の準備（UART を一度開く手順）が入るので約10秒かかります。

Bluetooth のファームウェアは、UART を 1.5Mbps にして読み込みます。キットの設定のままの 115200bps だと、送信が約 92kbps で頭打ちになり、スピーカーの音が途切れます。キットの `bt_switch` にも同じ変更を[提案しています](https://github.com/ichinomoto/dm200_tools/pull/5)。

`bt-speaker` のコーデックは、既定で `sbc` です。`BT_SPEAKER_CODEC=sbc_xq_453` にすると音質は上がりますが、途切れがやや増えます。

**LE のマウスを使うには、BlueZ にパッチが必要です。** [pomera-bluez-patches](https://github.com/kay-ws/pomera-bluez-patches) を見てください。

初回のペアリングは、このコマンドの範囲外です。手順の要点は次のとおりです。

1. `bluetoothctl pairable on` を**先に**実行する。これが無いと `Bonded: no` になり、切断するたびに鍵が消えます
2. `bluetoothctl scan on` を止めないまま、`pair`・`trust`・`connect` まで進める。スキャンが終わると、見つけた機器の情報が消えて `not available` になります

### usb_vbus

```sh
sudo usb_vbus on       # 5V を出す
sudo usb_vbus off      # 止める
sudo usb_vbus status   # 状態と、繋がっている機器
```

DM250 のカーネルには、USB ホストの 5V を出す経路がありません。電源チップ RK818 のレジスタ（`0x23` の bit7）を i2c で直接書いて、昇圧を入れます。

**注意**

- 5V を出している間は、Type-C から充電できません
- 自動では止まりません。使い終わったら `off` にしてください。消し忘れると電池が減り続けます
- **PD 入力（充電器を挿す口）付きの USB-C ハブを使うときは、`on` にしないでください。** ハブが下流の機器に給電するので不要です。`on` にすると、外からの給電を受けるのをやめて電池からハブへ流す側に回り、機器は同じように動いたまま電池だけが減ります
- 電源チップのレジスタを直接書く道具です。使うのは自己責任でお願いします

PD 入力付きハブで「充電しながら USB 機器を使う」話は、[こちらの記事](https://zenn.dev/kay1974/articles/4f084f3a6a5a0b)に書きました。

### usb_probe

```sh
sudo usb_probe              # 今の状態を表示し、/home/pomera/usb_probe.log に1行残す
sudo usb_probe mark LABEL   # 試行の区切りを記録する
sudo usb_probe events       # 区切り以降のカーネルのイベントだけを出す
sudo usb_probe watch N M    # N 秒ごとに M 回、1行ずつ記録する
```

USB の機器の数・充電の状態と電流の向き・カーネルのイベントの順番を、まとめて取るための道具です。`vbus_status` や `dwc_otg_conn_en` は実態を表さないので、参考として出すだけにしています。

### battlog

`battlog.service` を有効にすると、`/home/pomera/battlog.tsv` に5分ごとに1行ずつ記録します。サスペンドから復帰すると時計がずれることがあるので、あとで集計するときは、時刻の飛びを除いてください。

## 関連する記事

- [ポメラDM250をClaude Codeの操作端末にしてみて、踏んだ罠12選](https://zenn.dev/kay1974/articles/b617594c41fb4f)
- [続・罠10選](https://zenn.dev/kay1974/articles/12aa06307899bc)
- [インストール編](https://zenn.dev/kay1974/articles/edd42b9a9be874)
- [bookworm 化](https://zenn.dev/kay1974/articles/ec2904545cd79d)
- [環境の変化(1) Wayland 編](https://zenn.dev/kay1974/articles/ba9aa4c51d5749)
- [環境の変化(2) 周辺機器編](https://zenn.dev/kay1974/articles/aa3143bed8f17d)
- [後日談 USB-C ハブ編](https://zenn.dev/kay1974/articles/4f084f3a6a5a0b)

## ライセンス

MIT。無保証です。動作を確認したのは、上に書いた環境だけです。
