# pomera-dm250-tools

Small scripts, systemd units and key settings for using the Pomera DM250 as a Linux terminal (Debian 13, kernel 6.18).

ポメラ DM250 を Linux 端末として使うために作った、小さなスクリプト・systemd の unit・キー設定の置き場です。電池の表示と記録、バックライト、Bluetooth のスピーカーとマウス、USB ホストの給電、キーの追加が入っています。

Linux 化そのものは [ichinomoto さんの SD イメージ](https://www.ekesete.net/log/?p=9565)（kernel 6.18 + Debian 13 trixie）を使わせてもらっています。ここにあるのは、その上で使うための道具です。

`main` ブランチは、kernel 6.18 のイメージ向けです。kernel 3.10 のキット（`pomera_dm2x0_debian_20220816`）向けの版と説明は、タグ [`kernel-3.10`](https://github.com/kay-ws/pomera-dm250-tools/tree/kernel-3.10) にあります。3.10 の実機で動作を確認したのは、このタグの版までです。

## 動作を確認した環境

- ポメラ DM250
- ichinomoto さんの SD イメージ 20261002 版（kernel 6.18.41、Debian 13 trixie）
- sway + foot

DM200 と DM250US では試していません。`usb_vbus` のように、DM250 の電源チップ（RK818）を前提にしたものもあります。

## 中身

置き場所は、DM250 の上でのパスと同じにしてあります。

### コマンド

| パス | 役割 | 6.18 での確認 |
|---|---|---|
| `home/pomera/.local/bin/batt` | 電池の残量・状態・電流と、残り時間の見込みを1行で出す | 動作を確認。残り時間は 2 回の通し放電の記録で補正 |
| `usr/local/bin/bl` | バックライトの明るさを見る・変える | 動作を確認 |
| `usr/local/bin/battlog.sh` | 電池の状態を5分ごとに記録する | 動作を確認 |
| `usr/local/bin/bt-speaker` | ペアリング済みのスピーカーに繋ぎ、既定の出力にする | 動作を確認（PipeWire） |
| `usr/local/bin/bt-mouse` | ペアリング済みの LE マウスに繋ぐ | 接続まで。マウスは動かない（下記） |
| `usr/local/bin/usb_vbus` | USB ホストの 5V（VBUS）を入れる・切る | 動作を確認（USB マウスの直挿し） |

`bl`・`batt`・`battlog.sh`・`usb_vbus` は sysfs のパスを見て、`bt-mouse`・`bt-speaker` は `/opt/bin/bt_switch` の有無を見て、kernel 3.10 と 6.18 を切り替えます。3.10 側の処理は残してありますが、この変更を入れた後の版を 3.10 の実機では動かしていません。

### 設定と unit

| パス | 役割 |
|---|---|
| `etc/keyd/pomera.conf` | イメージ付属の keyd 設定に、`menu`＋矢印で Home/End/PageUp/PageDown、`menu`＋F1/F2 で F11/F12 を出すレイヤを足したもの |
| `etc/systemd/system/battlog.service` | `battlog.sh` を動かす |

### kernel 3.10 専用のもの

次のファイルは 3.10 のキット用で、6.18 のイメージでは使いません。

| パス | 6.18 で使わない理由 |
|---|---|
| `etc/systemd/system/backlight-default.service` | 明るさの保存と復元は systemd-backlight がやる |
| `etc/systemd/system/keychecker.service` | キットの `fnkey` が無い。キーの処理は keyd |
| `etc/systemd/system/keymap-zenkaku.service` | uim-fep 用 |
| `etc/systemd/system/dm250-keymap.service` ＋ `etc/console-setup/dm250-nav.map` | 同じ割り当てを `etc/keyd/pomera.conf` でやる |
| `home/pomera/.config/xkb/` | weston 用 |
| `etc/systemd/system/printk-quiet.service` ＋ `etc/sysctl.d/20-quiet-console.conf` | イメージの設定のままで、カーネルのメッセージは画面に割り込まない |
| `opt/bin/usb_probe` | 3.10 の USB ドライバのパスとログを読む |

## 導入

```sh
sudo install -m 755 usr/local/bin/* /usr/local/bin/
install -D -m 755 home/pomera/.local/bin/batt ~/.local/bin/batt

sudo install -m 644 etc/systemd/system/battlog.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now battlog
```

### キーの設定

イメージ付属の `/etc/keyd/pomera.conf` を置き換えます。元のファイルを退避してから入れてください。退避先は `/etc/keyd/` の外にします。

```sh
sudo cp -p /etc/keyd/pomera.conf /etc/keyd-pomera.conf.orig
sudo install -m 644 etc/keyd/pomera.conf /etc/keyd/pomera.conf
sudo keyd.rvaiya reload
```

Debian の keyd は、実行ファイルの名前が `keyd.rvaiya` です。trixie の版（2.5.0）には設定を検査するコマンドが無いので、読み込み直した後に `journalctl -u keyd -n 6` でエラーが出ていないかを見ます。

## 使い方

### batt

```console
$ batt
95%  discharging  about 11.8h left   4.041V -468mA 1.89W
$ batt --short
95% 11.7h
```

`--short` は、狭い場所（端末マルチプレクサのステータス欄など）に出すための短い形です。給電中は、AC 扱いか USB 扱いかを区別して表示します。

kernel 6.18 では、残量計が出す `charge_now`（残りの電荷量）を電流で割って、残り時間を出します。100% 付近から電源が落ちるまでの放電を 2 回記録し（負荷は 450〜540mA）、その結果で次の 4 点を補正しています。

- 残量計は、電池が空になる 15〜40 分前に 0 になります。予備として 130mAh を足します。2 回の記録で小さかったほうの値なので、残り時間は短めに出ます。
- 残量計が 0 を下回ると、ドライバは `charge_now` を約 1,797,057mAh から不足分を引いた値で、`capacity` を 100 で返します。この値は負の残量として読み直し、0% と表示します。
- 電圧が 3.55V を下回ったら、残量計でなく電圧から残り時間を出します。2 回の記録で、電圧と残り時間の対応が 5 分以内で一致したためです。負荷が 500mA 前後から大きく外れると合いません。
- 電流は、`battlog.tsv` にある直近 35 分の放電中の記録と今の値の平均を使います。`battlog` を動かしていなければ今の値だけで計算します。

この 2 回の記録に当てはめ直すと、残り 2 時間以内での誤差は中央値 3 分、最悪で 20 分短く出ます。2 時間より前は、その後の使い方で負荷が変わるので、中央値で 15 分ほどずれます。

残り 1 時間を切ると、`about 24min left` のように分で表示します。

kernel 3.10 には `charge_now` が無いので、実際に 100% から 0% まで放電したときの記録から作った表で計算します。

### bl

```sh
bl        # 今の値
bl 150    # 値を指定
bl +20    # 明るく
bl -20    # 暗く
```

kernel 6.18 のイメージでは、`video` グループのユーザーなら `sudo` なしで変えられます。下限は、イメージ付属の `backlight` コマンドと同じ 41 です。

イメージ付属の keyd 設定には、「無変換＋F1／F2」で明るさを1ずつ変える割り当てがあります。`bl` は、値を指定したいときや、大きく変えたいときに使います。

### bt-speaker

```sh
bt-speaker "スピーカーの名前"
```

kernel 6.18 では、Bluetooth はカーネルが起動時に立ち上げます。ペアリング済みのスピーカーは、電源を入れるだけで繋がり、既定の出力にもなります。ふだん `bt-speaker` を打つ必要はありません。

使うのは、`bluetooth_power off` で止めた Bluetooth を戻すときや、自動で繋がらなかったときです。Bluetooth を戻すときだけ `sudo` を使います。

いつも同じ機器を使うなら、`~/.profile` などで環境変数に名前を入れておくと、引数を省けます。名前を渡さずに実行すると、使い方とペアリング済みの機器の名前を表示して終わります。

```sh
export BT_SPEAKER="スピーカーの名前"
export BT_MOUSE="マウスの名前"
```

コーデックは PipeWire（WirePlumber）が選びます。確認したスピーカーでは SBC でした。`BT_SPEAKER_CODEC` は kernel 3.10（PulseAudio）のときだけ効きます。

### bt-mouse

```sh
bt-mouse "マウスの名前"
```

**kernel 6.18 のイメージ（20261002 版、20261003 版）では、Bluetooth LE のマウスは動きません。** ペアリングと接続は成功しますが、カーネルに UHID が入っていないので、入力デバイスが作られません。[ichinomoto/dm200_tools#11](https://github.com/ichinomoto/dm200_tools/issues/11) で報告しています。

kernel 3.10 で必要だった BlueZ のパッチ（[pomera-bluez-patches](https://github.com/kay-ws/pomera-bluez-patches)）は、6.18 では要りません。

### 初回のペアリング

`bt-speaker` と `bt-mouse` の範囲外です。手順の要点は次のとおりです。

1. `bluetoothctl` を対話で起動し、`agent NoInputNoOutput`、`default-agent`、`pairable on` を先に打つ。`bluetoothctl pair アドレス` を単発で実行すると、エージェントが登録されず `AuthenticationFailed` になることがあります
2. `scan on` を止めないまま、`pair`・`trust`・`connect` まで進める

### usb_vbus

```sh
sudo usb_vbus on       # 5V を出す
sudo usb_vbus off      # 止める
sudo usb_vbus status   # 状態と、繋がっている機器
```

電源チップ RK818 のレジスタ（`0x23` の bit7）を i2c で直接書いて、USB ホストの 5V の昇圧を入れます。

kernel 6.18 では、使い方によって要る・要らないが分かれます。

- ハブを使わずに機器を直接挿すときは、`on` が要ります。USB マウスを直挿しして試したところ、挿しただけでは認識されず、`on` の1秒後に認識され、`off` と同時に切断されました
- PD 入力（充電器を挿す口）付きの USB-C ハブを使うなら、`usb_vbus` は要りません。ハブを挿すだけで機器が認識され、DM250 も充電されました（2回試して2回とも）
- kernel 6.18 では、同じビットをカーネルの rk808 ドライバが `OTG_SWITCH` というレギュレータとして持っています。`usb_vbus` はドライバを通さずに書くので、`on` の間も sysfs のレギュレータの状態は `disabled` のままです。ドライバがこのレジスタを更新したときに、立てたビットが消えることがあります。試した約2分間では消えませんでした
- イメージ付属の `usb_host` は、VBUS を操作しない作りです

**注意**

- kernel 3.10 では、5V を出している間は Type-C から充電できませんでした。6.18 でどうなるかは確かめていません
- 自動では止まりません。使い終わったら `off` にしてください
- 電源チップのレジスタを直接書く道具です。使うのは自己責任でお願いします

### battlog

`battlog.service` を有効にすると、`/home/pomera/battlog.tsv` に5分ごとに1行ずつ記録します。列は、時刻・状態・残量（%）・電圧・電流・温度・`charge_now` です。kernel 6.18 には温度の値が無いので `-` が入ります。

サスペンドから復帰すると時計がずれることがあるので、あとで集計するときは、時刻の飛びを除いてください。

### キー

`etc/keyd/pomera.conf` を入れると、次の組み合わせが使えます。この機種のキーボードには、どれも単独のキーがありません。

| 押すキー | 出るキー |
|---|---|
| `menu`＋← / → | Home / End |
| `menu`＋↑ / ↓ | PageUp / PageDown |
| `menu`＋F1 / F2 | F11 / F12 |

`menu` キーは、それ以外のキーと一緒に押すと、これまでどおり Meta（sway の `$mod`）として働きます。

`menu`＋矢印を Home などに使うので、sway の `$mod`＋矢印（フォーカスの移動）は届かなくなります。`$mod`＋`h`／`j`／`k`／`l` を使ってください。

イメージ付属の「無変換＋矢印」の割り当ては、そのまま残してあります。

どの組み合わせも、出るキーには Meta が付きません。

## 関連する記事

- [DM250 を kernel 6.18 + Debian 13 (trixie) の SD イメージへ移行した作業メモ](https://zenn.dev/kay1974/articles/6457215826fd32)

kernel 3.10 のころの記事です。

- [ポメラDM250をClaude Codeの操作端末にしてみて、踏んだ罠12選](https://zenn.dev/kay1974/articles/b617594c41fb4f)
- [続・罠10選](https://zenn.dev/kay1974/articles/12aa06307899bc)
- [インストール編](https://zenn.dev/kay1974/articles/edd42b9a9be874)
- [bookworm 化](https://zenn.dev/kay1974/articles/ec2904545cd79d)
- [環境の変化(1) Wayland 編](https://zenn.dev/kay1974/articles/ba9aa4c51d5749)
- [環境の変化(2) 周辺機器編](https://zenn.dev/kay1974/articles/aa3143bed8f17d)
- [後日談 USB-C ハブ編](https://zenn.dev/kay1974/articles/4f084f3a6a5a0b)

## ライセンス

MIT。無保証です。動作を確認したのは、上に書いた環境だけです。
