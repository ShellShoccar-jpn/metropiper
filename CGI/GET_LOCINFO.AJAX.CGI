#! /bin/sh

######################################################################
#
# GET_LOCINFO.AJAX.CGI
# 接近情報を返す
# Written by Rich Mikan(richmikan@richlab.org) at 2014/09/17
#
# [入力]
#    HTTP POSTで次のCGI変数を与える
#      from_snum : 「知りたい駅」の駅ナンバー
#      to_snum   : 「行きたい駅」の駅ナンバー
# [出力]
#    接近情報テキストを返す
#
# [備考]
#    「知りたい駅」と「行きたい駅」は同じ路線でなければならない
#
######################################################################


######################################################################
# 初期設定
######################################################################

# === エラー終了関数定義 =============================================
errorcode_exit() {
  cat <<-__HTTP_HEADER
	Status: 500 Internal Server Error
	Content-Type: text/plain

	500 Internal Server Error
	($@)
__HTTP_HEADER
  exit 1
}
error400_exit() {
  cat <<-__HTTP_HEADER
	Status: 400 Bad request
	Content-Type: text/plain

	400 Bad Request
	($@)
__HTTP_HEADER
  exit 1
}
dyingmessage() {
  printf 'Content-Type: text/plain\n\n'
  echo "$@"
  exit
}

# === このシステムのホームディレクトリー =============================
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"

# === その他初期ディレクトリー等定義 =================================
# 1)コマンドパスの追加
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)一時ファイル格納先
Tmp=/tmp/${0##*/}.$$
# 3)終了時の一時ファイル削除設定
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM
# 4)エスケープ文字設定
ACK=$(printf '\006')


######################################################################
# CGI変数取得
######################################################################

# === CGI変数(GETまたはPOST)を取得 -----------------------------------
case "${REQUEST_METHOD:-}" in                            #
  POST) dd bs=${CONTENT_LENGTH:-0} count=1 2>/dev/null;; #
  *)    printf '%s' "${QUERY_STRING:-}"               ;; #
esac                                                     |
cgi-name                                                 > $Tmp-cgivars

# === 正当性確認 =====================================================
s=$(nameread from_snum $Tmp-cgivars)
echo "_$s" | grep -q '^_[A-Za-z][0-9][0-9]$'
[ $? -eq 0 ] || { error400_exit 'Invalid station number on from_snum'; }
from_snum=$s
s=$(nameread to_snum $Tmp-cgivars)
echo "_$s" | grep -q '^_[A-Za-z][0-9][0-9]$'
[ $? -eq 0 ] || { error400_exit 'Invalid station number on to_snum'; }
to_snum=$s


######################################################################
# HTTPレスポンス
######################################################################

# === HTTPヘッダー出力 ===============================================
cat <<-HTTP_RESHDR
	Content-Type: text/plain; charset=UTF-8
	
HTTP_RESHDR

# === 在線情報テーブル取得 ===========================================
# --- 1) コマンド実行 ------------------------------------------------
$Homedir/SHELL/GET_LOCTBL.SH $from_snum $to_snum >$Tmp-loctbl 2>$Tmp-errmsg
#<1行目>…概要
#  1:3桁駅ナンバー(x000 or x999) 2:路線コード 3:路線名
#  3:知りたい駅コード 4:知りたい駅名 5:発表日時(YYYY/MM/DD-hh:mm:ss)
#  6:アクセス日時(YYYY/MM/DD-hh:mm:ss) 7:次回更新日時(YYYY/MM/DD-hh:mm:ss)
#  8:更新間隔秒数 9:"-"(予約) 10:"-"(予約) 11:"-"(予約)
#<2行目以降>…実際の位置
#  1:3桁駅ナンバー 2:駅コード 3:駅名 4:種別コード 5:種別名
#  6:目的駅コード 7:目的駅名 8:車両所有業者コード 9:車両所有会社名
#  10:標準到着時間(分) 11(NF):知りたい駅なら0以外
#  ※ 在線していない場合、空欄として"-"が来る
# --- 2) エラー処理 --------------------------------------------------
case "$?" in
  1) s='内部エラーが発生しました、申し訳ありません。'                ;;
  2) s=$(cat $Tmp-errmsg | sed 's/^[^[:blank:]]\{1,\}[[:blank:]]*//');;
  *) s=''                                                            ;;
esac
case "$s" in
  '') :                                           ;;
  *)  echo '<div id="result">'"$s"'</div>'; exit 0;;
esac

# === HTTPボディー出力 ===============================================
# --- 1) テーブルボディーハメ ----------------------------------------
cat $Tmp-loctbl                                                            |
tail -n +2                                                                 |
# 1:3桁駅ナンバー 2:駅コード 3:駅名 4:種別コード 5:種別名                  #
# 6:目的駅コード 7:目的駅名 8:車両所有業者コード 9:車両所有会社名          #
# 10:標準到着時間(分) 11(NF):知りたい駅からの±距離(3桁駅numで)            #
# ※ 在線していない場合、空欄として"-"が来る                               #
awk '{# レコード種別("current_station","station","between")を決める        #
      if      ($NF==0        ) {rectyp = "current_station";}               #
      else if (match($1,/0$/)) {rectyp = "station"        ;}               #
      else                     {rectyp = "between"        ;}               #
      distance = ($NF<-35||15<$NF) ? "further" : "near";                   #
      # 東京メトロ駅情報URLを生成                                          #
      if($2!="-") {                                                        #
        s=$2;                                                              #
        sub(/^.+\./,"",s);                                                 #
        gsub(/[A-Z]/,"-&",s);                                              #
        s=tolower(substr(s,2));                                            #
        url=sprintf("http://www.tokyometro.jp/station/%s/index.html",s);   #
      } else {                                                             #
        url="#";                                                           #
      }                                                                    #
      print rectyp,distance,$1,$3,$4,$5,$7,$9,$10,url;                  }' |
# 1:レコード種別 2:2駅より離れていれば"further"、なければ"near"            #
# 3:3桁駅ナンバー 4:駅名 5:種別コード 6:種別名 7:目的駅名                  #
# 8:車両所有会社名 9:標準到着時間(分) 10:公式サイト駅URL(駅間の場合は"#")  #
awk '{# 同じ3桁駅numと駅名が連続する場合は2つ目以降は空欄"-"にする         #
      if($3==snum0){$3="-";$4="-";}                                        #
      else         {snum0=$3;     }                                        #
      # 各種単語の修飾                                                     #
      if($7!="-"){$7=sprintf("%s行",$7);}                                  #
      if($8!="-"){$8=sprintf("(%s)",$8);}                                  #
      if($9!="-"){if       ($9>0){$9=sprintf("約%s分後", $9);              #
                  } else if($9<0){$9=sprintf("約%s分前",-$9);              #
                  } else         {$9="到着";                 }}            #
      # 2桁駅ナンバーに戻して出力                                          #
      if(match($3,/5$/)){$3="-";}                                          #
      print $1,$2,substr($3,1,3),$4,$5,$6,$7,$8,$9,$10;}'                  |
sed 's/\\_/'"$ACK"'/g'                                                     | # mojihameコマンドエンコード
sed 's/\\/\\\\/g'                                                          | # |
sed 's/_/\\_/g'                                                            | # |
sed 's/'"$ACK"'/\\\\_/g'                                                   | # V
sed 's/ - / _ /g'                                                          | # null列エンコード
sed 's/ - / _ /g'                                                          | # |
sed 's/ -$/ _/g'                                                           | # V
mojihame -hLC_ITERATION $Homedir/TEMPLATE.HTML/LOCTABLE_PART.HTML          > $Tmp-loctblhtml0
# --- 2) テーブルヘッダー追ハメ --------------------------------------
cat $Tmp-loctbl                                                              |
head -n 1                                                                    |
# 1:3桁駅ナンバー(x000 or x999) 2:路線コード 3:路線名                        #
# 4:知りたい駅コード 5:知りたい駅名 6:発表日時(YYYYMMDDhhmmss)               #
# 7:アクセス日時(YYYYMMDDhhmmss) 8:次回更新日時(YYYYMMDDhhmmss)              #
# 9:更新間隔秒数 10:"-"(予約) 11:"-"(予約)                                   #
sed 's/\\_/'"$ACK"'/g'                                                       | # mojihameコマンドエンコード
sed 's/\\/\\\\/g'                                                            | # |
sed 's/_/\\_/g'                                                              | # |
sed 's/'"$ACK"'/\\\\_/g'                                                     | # V
calclock 6 7 8                                                               |
# 1:3桁駅ナンバー(X000 or X999) 2:路線コード 3:路線名                        #
# 4:知りたい駅コード 5:知りたい駅名                                          #
# 6:発表日時(YYYYMMDDhhmmss) 7:発表日時(UNIX時間)                            #
# 8:アクセス日時(YYYYMMDDhhmmss) 9:アクセス日時(UNIX時間)                    #
# 10:次回更新日時(YYYYMMDDhhmmss) 11:次回更新日時(UNIX時間)                  #
# 12:更新間隔秒数 13:"-"(予約) 14:"-"(予約)                                  #
awk '{# 表示用の日付フォーマット列を生成                                     #
      s=$6 ;gsub(/[0-9][0-9]/,"& ",s);split(s,a);                            #
      pdate=sprintf("%s%s年%s月%s日_%s:%s",a[1],a[2],a[3],a[4],a[5],a[6]);   #
      s=$8 ;gsub(/[0-9][0-9]/,"& ",s);split(s,a);                            #
      adate=sprintf("%s%s年%s月%s日_%s:%s",a[1],a[2],a[3],a[4],a[5],a[6]);   #
      s=$10;gsub(/[0-9][0-9]/,"& ",s);split(s,a);                            #
      ndate=sprintf("%s%s年%s月%s日_%s:%s",a[1],a[2],a[3],a[4],a[5],a[6]);   #
      # 路線コードの末尾の単語を求める                                       #
      rwcs=$2;                                                               #
      sub(/^.*\./,"",rwcs);                                                  #
      # 路線名から"東京メトロ"をトル                                         #
      rwns=$3;                                                               #
      sub(/東京メトロ/,"",rwns);                                             #
      # 何秒前の情報か計算                                                   #
      sec=$9-$7;                                                             #
      # 列を選んで出力                                                       #
      print rwcs,rwns,$4,$5,$6,$7,pdate,$8,$9,adate,$10,$11,ndate,sec,$12;}' |
# 1:路線コード(最後の単語のみ) 2:路線名("東京メトロ"文字列なし)              #
# 3:知りたい駅コード 4:知りたい駅名                                          #
# 5,6,7:発表日時(YYYYMMDDhhmmss,UNIX時間,可読形式)                           #
# 8,9,10:アクセス日時(YYYYMMDDhhmmss,UNIX時間,可読形式)                      #
# 11,12,13:次回更新日時(YYYYMMDDhhmmss,UNIX時間,可読形式)                    #
# 14:何秒前の情報か 15:更新間隔秒数                                          #
mojihame -lLOC_TABLE $Tmp-loctblhtml0


######################################################################
# 正常終了
######################################################################

exit 0
