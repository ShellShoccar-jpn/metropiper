# メトロパイパー

偉大なる秘密結社シェルショッカーに捧ぐ!

シェルスクリプトのパイプ駆使し、東京メトロのパイプ(=路線)の中身を覗いてしまえ!

## これは何だ?

最近開示された[東京メトロオープンデータ](https://developer.tokyometroapp.jp/)のWebAPIのデータから、今現在の列車の**接近情報**を表示するプログラムである。接近情報というのは、駅の電光掲示板にある

> 前々駅 -◆- 前駅 --- 当駅

というアレだ。しかし、今まではその駅のホームに行かないと見ることが出来なかったし、2つよりも前の駅の接近情報はわからなかった。

* あ、特急ロマンスカーが霞ヶ関駅に来てる。じゃあそろそろ表参道駅へ行くか。
* あー、南栗橋行間に合わなかった! えぇと次の東武線直通電車は今どのあたりに……? うーんもうしばらく後か、じゃあトイレに行っとくか。

という具合に、今いる駅から**もっと手前の駅の接近情報**や、あるいは駅にいなくても**これから行く予定の駅の接近情報**は知りたいもの。そんなアナタの願いを叶えるのがこのコマンドだ。


# つかいかた

## 0. 必要なもの

なぁに、大したものは要らん。UNIX環境と少々の追加コマンドがあれば動く。
レンタルサーバーなら大抵全部初めから揃っていることだろう。

| 必要なもの                           | 備考                                                          |
|:-------------------------------------|:--------------------------------------------------------------|
| POSIX準拠シェル(/bin/sh)とコマンド群 | FreeBSDやLinuxも勿論OK(BashやGNU拡張機能等は一切不要)         |
| curlコマンド                         | インストールしておく(主要Linuxディストリには大抵ある)         |

シェルスクリプトはPOSIX準拠で書いているつもりなので、curlコマンドさえどうにか用意することができればおそらくどこのUNIX環境でも動くはずだ。


## 1. 準備作業

シェルスクリプトで書いてあるからコンパイルなど一切不要。このプログラム一式をコピーして、最初にマスターデータを生成するシェルスクリプトを動かせば完了だ。

あ、[ユーザー登録](https://developer.tokyometroapp.jp/users/sign_up)をして、アクセストークンを貰ってくるのを忘れんようにな。それがないとこのアプリは動かせないぞ。

### 1) 開発者サイトにサインアップ

サインアップがまだならサインアップをすること。サイトは[ここ](https://developer.tokyometroapp.jp/users/sign_up)だ。なお、サインアップにはメールアドレスと、少々の時間(最長2日くらいらしいが、私は2時間くらいだった)が必要だ。

### 2) アクセストークンを発行する

アクセストークンとは、Twitterで言うところのApplication IDみたいなものだ。東京メトロのWebAPIにおいても、自作のWebアプリケーションを使いたければ発行しなければならない。残念ながらこれは公開してなならないので、このアプリ「メトロパイパー」を動かしたいなら各自取ってくること。

発行を受け付けている場所は[ここ](https://developer.tokyometroapp.jp/oauth/applications)だ。ただし、サインアップしたらデフォルトで1個生成されているので、それを使ってもよいのだが。

### 3) 「メトロパイパー」をダウンロード

[ZIPでダウンロード](https://github.com/ShellShoccar-jpn/metropiper/archive/master.zip)して展開してもよいが、gitコマンドが使えるなら下記のようにしてgit cloneするのが手っ取り早いぞ。

```sh:gitコマンド一発でメトロパイパー一式を取得
$ git clone https://github.com/ShellShoccar-jpn/metropiper.git
$ cd metropiper # ←メトロパイパーのホームディレクトリーに移動しておく
```

### 4) アクセストークンを設定

CONFというディレクトリーの中にある`ACCESSTOKEN.TXT`というファイルに、2)で取得してきたアクセストークンを書き込む。私が取得した時は**64桁の16進数**だったので、そうでなかったらそれはアクセストークンではないかもしれんぞ。

### 5) マスターファイルを作る準備

駅名や路線名など、最初に一回だけ入手しておけばよい情報を取得して、各種マスターファイルを作る作業を行う。

しかし一部はWebAPIではなくて、Web上に公開されているドキュメントページのHTMLをスクレイピングしなければならない。そこで、下記に指定するWebページのHTMLソースコードをどこかに保存しておくこと。

**[https://developer.tokyometroapp.jp/documents/odpt](https://developer.tokyometroapp.jp/documents/odpt)**

このページはログインしていないと表示されないので、Webブラウザーでログインしてからソースを表示し、コピペするというのが現実的ではないかと思う。そしてここでは説明の都合で、DATAディレクトリーの中に`metro_vocabulary.html`という名前で保存したものとする。

### 6) マスターファイルを生成

最後にコマンドを一発実行して、各種マスターファイルを生成する。インターネットに繋がっていれば5秒もかからずに生成できるだろう。下記のコマンドを実行せよ。

```sh:マスターファイルを生成する
$ SHELL/MK_METRO_MST.SH DATA/metro_vocabulary.html
```

## 2. 普段の使い方

### コマンド版

今現在のどこかの駅の接近情報が知りたいなーと思ったら、SHELLディレクトリーにある`VIEW_METROLOC.SH`コマンドを実行すればよい。ただしこのコマンドは引数を2つとる。

* 第1引数…知りたい駅の駅ナンバー
* 第2引数…行きたい駅の駅ナンバー(ただし同一路線であること)

東京メトロ各線の駅ナンバーは、[駅ナンバリング路線図](http://www.tokyometro.jp/station/common/pdf/rosen_j.pdf)参照。

### Web版

こりゃ便利なので、誰でも使えるようにとWebインターフェースを追加した。

というわけで、**[メトロパイパーWeb版](http://lab-sakura.richlab.org/METROPIPER/)**をWebブラウザーで開く。使い方は、説明しなくてもわかるでしょ?

### コマンドの例と、ありし日・時刻の実行結果

例:「東陽町(T14)における西船橋方面(T23)の接近情報」を見る

```sh:使用例(東陽町駅における中野方面の接近情報)
$ SHELL/VIEW_METROLOC.SH T14 T01
2014/11/15 12:08:18発表

   T01 中野       各停 西船橋行     (JR東日本車両)     約28分後
   T01 中野       快速 東葉勝田台行 (東葉高速鉄道車両) 約28分後
   ｜
   T02 落合
   ｜           ↓各停 西船橋行     (東葉高速鉄道車両) 約23.5分後
   T03 高田馬場
   ｜
   T04 早稲田     快速 東葉勝田台行 (東葉高速鉄道車両) 約19分後
   ｜
   T05 神楽坂
   ｜
   T06 飯田橋     各停 西船橋行     (東京メトロ車両)   約15分後
   ｜
   T07 九段下
   ｜
   T08 竹橋
   ｜
   T09 大手町     各停 西船橋行     (東京メトロ車両)   約9分後
   ｜
   T10 日本橋
   ｜
   T11 茅場町
   ｜           ↓快速 東葉勝田台行 (東京メトロ車両)   約4.5分後
   T12 門前仲町
   ｜
   T13 木場
   ｜
>> T14 東陽町     各停 西船橋行     (東京メトロ車両)   到着
   ｜
   T15 南砂町
   ｜
   T16 西葛西
   ｜           ↓各停 西船橋行     (JR東日本車両)     7分前
   T17 葛西
   ｜
   T18 浦安
   ｜
   T19 南行徳     各停 西船橋行     (東京メトロ車両)   12分前
   ｜
   T20 行徳
   ｜
   T21 妙典
   ｜           ↓快速 東葉勝田台行 (東葉高速鉄道車両) 12.5分前
   T22 原木中山
   ｜           ↓各停 西船橋行     (東京メトロ車両)   20.5分前
   T23 西船橋
$ 
```

「お、もうすぐ快速がくるじゃん！」


# 補遺

ここで出てくるA1とかA2というのは出口ではない。(知ってた?)

## A1. ディレクトリー構成

このプログラムのディレクトリー構成を記す。

```text:ディレクトリー構成
     metropiper/
     ├─ SHELL/                ・シェルコマンドとして呼び出されるプログラムの置き場所
     │   ├─ MK_METRO_MST.SH    - マスターファイル群生成スクリプト(最初に実行)
     │   ├─ MK_RWMINS.SH       - 路線内標準所要時間テーブル作成スクリプト
     │   │                      - (MK_METRO_MST.SHから呼び出される為、単独実行不要)
     │   ├─ VIEW_METROLOC.SH   - 接近情報表示コマンド
     │   │                      - (GET_LOCTBL.SHが出すデータをコンソール画面用に加工)
     │   ├─ GET_LOCTBL.SH      - 接近情報生成スクリプト(親。子のどれかをexec)
     │   ├─ GET_LOCTBL_0.SH    - 接近情報生成スクリプト(子。通常の分岐なし路線用)
     │   ├─ GET_LOCTBL_C.SH    - 接近情報生成スクリプト(子。千代田線専用)
     │   ├─ GET_LOCTBL_FY.SH   - 接近情報生成スクリプト(子。副都心線・有楽町線専用)
     │   ├─ GET_LOCTBL_M.SH    - 接近情報生成スクリプト(子。丸ノ内本線専用)
     │   ├─ GET_LOCTBL_mb.SH   - 接近情報生成スクリプト(子。丸ノ内支線専用)
     │   └─ GET_LOCTBL_N.SH    - 接近情報生成スクリプト(子。南北線専用)
     │                             (GET_LOCTBL.SHの内容をコンソール向けに加工)
     ├─ CONF/                 ・各種設定ファイル置き場
     │   └─ ACCESSTOKEN.TXT    - 取得したアクセストークンを設定するファイル
     ├─ DATA/                 ・各種マスターデータ等の置き場
     │   ├─ SNUM2RWSN_MST.TXT  - 駅ナンバーから各種情報を引くためのマスター
     │   ├─ RWC2RWN_MST.TXT    - 路線コードから路線名を引くためのマスター
     │   ├─ RWC2DIRC_MST.TXT   - 路線コードから路線の方面を引くためのマスター
     │   ├─ RWMINS_*.TXT       - 路線別・方面別、標準到着所要時間マスターファイル
     │   └─ METRO_VOC_MST.TXT  - その他各種コードから名称を引くためのマスター
     ├─ TMP/                  ・過密なAPIアクセス回避のためのキャッシュファイル置き場
     ├─ CGI/                  ・Webインターフェース用CGIプログラムの置き場所
     │   ├─ GET_SNUM_HTMLPART.AJAX.CGI
     │   │                      - 駅の一覧の<option>タグを生成する(Ajax)
     │   └─ GET_LOCINFO.AJAX.CGI
     │                           - VIEW_METROLOC.SHのWebインターフェース版(Ajax)
     ├─ HTML/                 ・Webディレクトリー
     │   ├─ MAIN.HTML          - メインページのテンプレートHTML
     │   │                        (TEMPLATE.HTMLの中にあるもののハードリンク)
     │   └─ JS/              ・Webインターフェースが用いるJavaScript置き場
     │        └─ SYSTEM.JS     - 本アプリのシステムJavaScript
     ├─ TEMPLATE.HTML/        ・Webインターフェース用のテンプレートHTMLの置き場所
     │   ├─ MAIN.HTML          - メインページのテンプレートHTML
     │   └─ LOCTABLE_PART.HTML - 結果表示用の部分HTMLテンプレート
     ├─ TOOL/                 ・シェルスクリプトアプリ開発を助けるコマンド群
     │                           ("Open usp Tukubai"という名で公開されているもの)
     │                           (ただしそれのシェルスクリプトによるクローン版)
     └─ UTL/                  ・その他、本システムで利用する汎用的なコマンド群
          └─ parsrj.sh          - シェルスクリプト製自作JSONパーサー
```

## A2. ライセンスとか

本アプリケーションは、個人利用・商業利用を問わず誰でも、無料で、使用することができる。この点に関しては変わらないが、収録しているファイルによって適用ライセンスが異なる。

### 自作プログラム

* 具体的には次のものが対象（ファイル名が全て大文字）
  * SHELL/ ディレクトリーの中にある全てのファイル
  * CGI/   ディレクトリーの中にある全てのファイル
  * TOOL/  ディレクトリーの中にある全てのファイル
  * UTL/   ディレクトリーの中にある全てのファイル
  * HTML/JS/SYSTEM.JS
* パブリックドメインとする。
  * 従って、無断の利用、改造、何でも可能。
* 備考
  * ソースコード中に書かれている"Written by"表記は、質問先を示すものであり著作権を主張するものではありませんのでご安心を。
  * TOOL/ディレクトリーの中にあるファイルは、MITライセンスで公開されているOpen usp Tukubaiというコマンド群の機能を、非公式に移植したものであることを一応認識しておいてもらいたい。

### 自作でないプログラム

* 具体的には次のものが対象
  * HTML/JS/respond.min.js
* これはRespond.jsというライブラリーであり、Scott Jehl氏によるMITライセンスのものである。ライセンスの詳細は、本プログラムの公式サイトを参照されたい。

> Copyright (c) 2012 Scott Jehl
> 
> Permission is hereby granted, free of charge, to any person
> obtaining a copy of this software and associated documentation
> files (the "Software"), to deal in the Software without
> restriction, including without limitation the rights to use,
> copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the
> Software is furnished to do so, subject to the following
> conditions:
> 
> The above copyright notice and this permission notice shall be
> included in all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
> EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
> OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
> NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
> HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
> WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
> FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
> OTHER DEALINGS IN THE SOFTWARE.

### HTML類

* 具体的には次のものが対象
  * HTML/ディレクトリーの中にある、上記プログラム以外のファイル（HTML、画像）
  * TEMPLATE.HTML/ディレクトリーの中にある、上記プログラム以外のファイル（部分的HTML）
* これらは意匠を含んでいるため、全ての権利は我々メトロパイパー開発者が保有する。
* 個人・商業利用に関わらず利用可能。
* 著作人格権を侵害するような「著しい改変」は加えないこと。
  * 制作者名だけをすげかえるなど、よほどひどい改変でなければ一向に構わない。不安な場合は相談されたし。
  * オリジナリティーのある改変を加えたうえで、制作者表示を変えたり消したりするのも構わない。

> Copyright 2014 Metropiper Developer, All rights reserved.

### その他

* 東京メトロのWebAPIが出力するデータ構造等、東京メトロの仕様に関しては東京メトロに権利があるので注意すること。
