#! /bin/sh

######################################################################
#
# GET_SNUM_HTMLPART.AJAX.CGI
# 駅ナンバー一覧部分HTML生成
# Written by Rich Mikan(richmikan@richlab.org) at 2014/09/17
#
# [入力]
#    HTTP POSTで次のCGI変数を与える
#      [rwletter] : 「知りたい駅」の路線文字
#    DATA/SNUM2RWSN_MST.TXT …… 駅ナンバーマスターファイル
#    TEMPLATE.HTML/MAIN.HTML…… 表示用HTMLテンプレートファイル
# [出力]
#    駅ナンバーと駅名を埋め込んだ<option>タグ
#
# [備考]
#    rwletterを省略した場合は、全駅が返される。
#
######################################################################


######################################################################
# 初期設定
######################################################################

# --- エラー終了関数定義 ---------------------------------------------
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

# --- このシステムのホームディレクトリー -----------------------------
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"

# --- その他初期ディレクトリー等定義 ---------------------------------
# 1)コマンドパスの追加
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)一時ファイル格納先
Tmp=/tmp/${0##*/}.$$
# 3)終了時の一時ファイル削除設定
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM


######################################################################
# 事前チェック
######################################################################

# --- 駅ナンバーマスターファイル存在確認 -----------------------------
if [ ! -f "$Homedir/DATA/SNUM2RWSN_MST.TXT" ]; then
  error500_exit 'Station name master file is not found'
fi

# --- テンプレートHTMLファイル存在確認 -------------------------------
if [ ! -f "$Homedir/TEMPLATE.HTML/MAIN.HTML" ]; then
  error500_exit 'Template HTML file is not found'
fi


######################################################################
# CGI変数取得
######################################################################

# --- CGI変数(GETまたはPOST)を取得 -----------------------------------
case "${REQUEST_METHOD:-}" in                            #
  POST) dd bs=${CONTENT_LENGTH:-0} count=1 2>/dev/null;; #
  *)    printf '%s' "${QUERY_STRING:-}"               ;; #
esac                                                     |
cgi-name                                                 > $Tmp-cgivars

# --- 正当性確認 -----------------------------------------------------
s=$(nameread rwletter $Tmp-cgivars)
echo "_$s" | grep -qE '^_([A-Za-z]|)$'
[ $? -eq 0 ] || { error400_exit 'Invalid Railway letter on rwletter'; }
rwletter=$s


######################################################################
# 部分HTML出力
######################################################################

# --- HTTPヘッダーを出力 ---------------------------------------------
cat <<-HTTP_HDR
	Content-Type: text/plain; charset=UTF-8
	
HTTP_HDR

# --- 部分HTMLのテンプレート抽出 -------------------------------------
cat "$Homedir/TEMPLATE.HTML/MAIN.HTML"        |
sed -n '/FROM_SELECT_BOX/,/FROM_SELECT_BOX/p' |
sed 's/―/選んでください/'                    > $Tmp-htmltmpl

# --- HTML本体を出力 -------------------------------------------------
cat "$Homedir/DATA/SNUM2RWSN_MST.TXT"     |
# 1:駅ナンバー(sorted) 2:路線コード 3:路線名 4:路線駅コード
# 5:駅名 6:方面コード(方面駅でない場合は"-")
grep -i "^$rwletter"                      |
awk '{print substr($1,1,1),$0}'           |
sort -k1f,1 -k2,2                         |
awk '{print $2,$4,$6}'                    |
uniq                                      |
# 1:駅ナンバー(sorted) 2:路線名 3:駅名    #
mojihame -lFROM_SNUM_LIST $Tmp-htmltmpl -


######################################################################
# 正常終了
######################################################################

exit 0
