#! /bin/sh

######################################################################
#
# MK_RWMINS.SH
# 路線別標準所要時間マスターファイルを生成する
# Written by Rich Mikan(richmikan@richlab.org) at 2014/11/11
#
# [入力]
# ・下記のファイルを用意しておく
#    1. CONF/ACCESSTOKEN.TXT
#       コンテストで与えられたアクセストークンを記述したテキスト
# ・引数で下記を指定
#   [$1] : WepAPIのrdf:type=odpt:Railwayで取得したJSONをparsrj.shで
#          パースしたテキストファイル
#          ・(注)指定されていなければWebから最新版を取ってくる。
# [出力]
# ・下記のマスターファイルを作る
#    RWMINS_<路線コード>_<方向(順なら0,逆なら1)>.TXT
#     1:<種別コード>/<3桁発車駅ナンバー>/<3桁停車駅ナンバー> 2:標準到着時間
#
# [備考]
# ・要curlコマンド
#
######################################################################


######################################################################
# 初期設定
######################################################################

# --- 使用法表示関数定義 ---------------------------------------------
print_usage_and_exit() {
  local s
  s=$(awk 'BEGIN{printf("%070d",0)}' | tr 0 '#')
  awk "f==1&&/^${s}\$/{print;exit} f==0&&/^${s}\$/{f=1} f==1{print;}" "$0" 1>&2
  exit 1
}

# --- このシステムのホームディレクトリー -----------------------------
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"

# --- アクセストークン・APIエンドポイントを設定 ----------------------
s=$Homedir/CONF/ACCESSTOKEN.TXT
[ -f "$s" ] || { echo "${0##*/}: ACCESSTOKEN.TXT not found" 1>&2; exit 1; }
appid=$(env - awk '/^[[A-Fa-f0-9]+$/' "$s")
[ -n "$appid" ] || { echo "${0##*/}: Invaid access token" 1>&2; exit 1; }
s=$Homedir/CONF/API_DATAPOINTS.TXT
[ -f "$s" ] || { echo "${0##*/}: API_DATAPOINTS.TXT not found" 1>&2; exit 1; }
urlbase=$(grep -E '^https?://[a-z0-9.-]+(/[!-~]*)?$' "$s")
[ -n "$urlbase" ] || { echo "${0##*/}: Invaid API datapoints" 1>&2; exit 1; }

# --- その他初期ディレクトリー等定義 ---------------------------------
# 1)コマンドパスの追加
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)一時ファイル格納先
Tmp=/tmp/${0##*/}.$$
# 3)終了時の一時ファイル削除設定
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM
# 4)その他
LF=$(printf '\\\n_');LF=${LF%_}  # sed内での改行を変数として扱うためのもの


######################################################################
# 引数確認・取得
######################################################################

# --- 引数が0または1であることの確認 ---------------------------------
[ $# -le 1 ] || print_usage_and_exit

# --- 引数1が正当なファイルであることの確認 --------------------------
[ \( -z "${1:-}" \) -o \( -f "${1:-}" \) ] || print_usage_and_exit

# --- WepAPIのrdf:type=odpt:Railwayで取得したJSONのparsrj.sh済file設定
file_Railway=$1


######################################################################
# APIからデータを取ってくる(引数で指定されていれば何もしない)
######################################################################

# --- ファイルがなければWebAPIから取得してくる -----------------------
case "$file_Railway" in
  '')
    # --- 与えられたアクセストークンを設定 ---------------------------
    File_token=$Homedir/CONF/ACCESSTOKEN.TXT
    if [ ! -f "$File_token" ]; then
      echo "${0##*/}: The file contains access token is not found." 1>&2
      exit 1
    fi
    # --- 呼び出しURLの設定 ------------------------------------------
    url="${urlbase}?rdf:type=odpt:Railway&acl:consumerKey=$appid"
    # --- 呼び出してファイルを生成する -------------------------------
    curl -s $url |
    parsrj.sh    > $Tmp-railway
    [ -s $Tmp-railway ] || {
      echo "${0##*/}: Failed to access the WebAPI." 1>&2
      exit 1
    }
    file_Railway=$Tmp-railway
    ;;
esac


######################################################################
# 標準所要時間マスターファイル作成1(路線毎にデータを分離)
######################################################################

# --- 路線・種別・方向毎の隣接駅標準所要分数ファイルを作成する -------
cat $file_Railway                                                            |
# 1:JSON位置 2:値                                                            #
grep -E '^\$\[[0-9]+\]\.(odpt:travelTime\[|owl:sameAs)'                      |
sed 's/^\$\[\([0-9]\{1,\}\)\]\./\1 /'                                        |
sed 's/owl:sameAs/1/'                                                        |
sed 's/odpt:travelTime\[\([0-9]\{1,\}\)\]\.odpt:/2 \1 /'                     |
awk '$4=="trainType"    {f4=1;                                               #
                         sub(/:/,":TokyoMetro.",$5);                         # # 列車ロケーション情報では種別コードの先頭に
                         sub(/TokyoMetro\.TokyoMetro\./,"TokyoMetro.",$5);}  # # "TokyoMetro."がついているため、補正する。
     $4=="fromStation"  {f4=2;                                            }  #
     $4=="toStation"    {f4=3;                                            }  #
     $4=="necessaryTime"{f4=4;                                            }  #
     {print $1,$2,$3,f4,$5;                                               }' |
sort -k1n,1 -k2n,2 -k3n,3 -k4n,4                                             |
# 1:路線番号 2:路線コード行なら1、所要時間行なら2                            #
# 3:(路線コード行なら)路線コード、(所要時間行なら)項目番号                   #
# 4:(所要時間行なら)フィールド種別番号 5:(所要時間行なら)標準所要分数        #
awk '$2==1{rwc=$3;next;} $2==2{print rwc,$3,$5}'                             |
yarr num=2                                                                   |
delf 2                                                                       |
# 1:路線コード 2:種別コード 3:発車駅コード 4:停車駅コード 5:標準所要分数     #
sort -k3,3                                                                   |
join -1 1 -2 3 -o 2.1,2.2,2.3,1.2,2.4,2.5 $Homedir/DATA/SC2SNUM.TXT -        |
delf 3                                                                       |
sort -k4,4                                                                   |
join -1 1 -2 4 -o 2.1,2.2,2.3,2.4,1.2,2.5 $Homedir/DATA/SC2SNUM.TXT -        |
delf 4                                                                       |
# 1:路線コード 2:種別コード 3:発車駅ナンバー 4:停車駅ナンバー 5:標準所要分数 #
awk '{f=substr($3,2);t=substr($4,2);print $1,(f>t),$2,$3,$4,$5;}'            |
sort -k1,1 -k2,2 -k3,3 -k4,4                                                 |
# 1:路線コード 2:方向(駅ナンバー順方向は0、逆方向は1) 3:種別コード           #
# 4:発車駅ナンバー 5:停車駅ナンバー 6:標準所要分数                           #
keycut $Tmp-RWMINS1_%1_%2_%3

# --- 丸ノ内支線の事前特別処理 ---------------------------------------
cat $Tmp-RWMINS1_odpt.Railway:TokyoMetro.MarunouchiBranch_0_odpt.TrainType:TokyoMetro.Local \
    $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Marunouchi_0_odpt.TrainType:TokyoMetro.Local       |
awk '$4~/^M0[1-5]$/{next;} {print;}'                                                        |
sed 's/ M\([0-9][0-9]\)/ m\1/g'                                                             |
sed 's/Marunouchi /MarunouchiBranch /g'                                                     |
sort                                                                                        > $Tmp-rwmins0
mv $Tmp-rwmins0 $Tmp-RWMINS1_odpt.Railway:TokyoMetro.MarunouchiBranch_0_odpt.TrainType:TokyoMetro.Local
cat $Tmp-RWMINS1_odpt.Railway:TokyoMetro.MarunouchiBranch_1_odpt.TrainType:TokyoMetro.Local \
    $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Marunouchi_1_odpt.TrainType:TokyoMetro.Local       |
awk '$5~/^M0[1-5]$/{next;} {print;}'                                                        |
sed 's/ M\([0-9][0-9]\)/ m\1/g'                                                             |
sed 's/Marunouchi /MarunouchiBranch /g'                                                     |
sort                                                                                        > $Tmp-rwmins0
mv $Tmp-rwmins0 $Tmp-RWMINS1_odpt.Railway:TokyoMetro.MarunouchiBranch_1_odpt.TrainType:TokyoMetro.Local

# --- 副都心線通勤急行を生成する事前特別処理 -------------------------
cat $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local   |
awk '$4~/^F0[1-5]$/{print;}'                                                            |
sed 's/\.Local/.CommuterExpress/'                                                       >  $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.CommuterExpress
cat $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Express |
awk '$4~/^F0[1-5]$/{next;} {print;}'                                                    |
sed 's/\.Express/.CommuterExpress/'                                                     >> $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.CommuterExpress
cat $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local   |
awk '$5~/^F0[1-5]$/{print;}'                                                            |
sed 's/\.Local/.CommuterExpress/'                                                       >  $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.CommuterExpress
cat $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Express |
awk '$5~/^F0[1-5]$/{next;} {print;}'                                                    |
sed 's/\.Express/.CommuterExpress/'                                                     >> $Tmp-RWMINS1_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.CommuterExpress


######################################################################
# 標準所要時間マスターファイル作成2(隣接してない駅・駅間のレコード補完)
######################################################################

ls -1 $Tmp-RWMINS1_*                       |
sed 's/_odpt.TrainType:/ odpt.TrainType:/' |
sed 's/_\([01]\)/ \1/'                     |
sed 's/_odpt.Railway:/ odpt.Railway:/'     |
while read -r filebase rwc dir typ; do
  cat "${filebase}_${rwc}_${dir}_${typ}"                              |
  # 1:路線コード 2:方向(駅ナンバー順方向なら0,逆なら1) 3:種別コード   #
  # 4:発車駅ナンバー 5:到着駅ナンバー 6:標準所要分数                  #
  # --- 3桁駅ナンバー化 ----------------------------------------------#
  awk '{print $1,$2,$3,$4 "0",$5 "0",$6;}'                            |
  # 1:路線コード 2:方向(駅ナンバー順方向なら0,逆なら1) 3:種別コード   #
  # 4:発車3桁駅ナンバー 5:到着3桁駅ナンバー 6:標準所要分数            #
  # --- 駅間,通過駅に対してもレコードのある隣接駅までのレコードを補完 #
  awk '                                                               #
    BEGIN {                                                           #
      fmt = "%s %s%03d %s%03d %.3f\n";                                #
      if (getline) {                                                  #
        rwc_dir_typ = $1 " " $2 " " $3;                               #
        rwl  = substr($4,1,1);                                        #
        f0   = substr($4,2)*1;                                        #
        t0   = substr($5,2)*1;                                        #
        d    = (t0>f0) ? 5 : -5;                                      #
        tim0 = $6;                                                    #
        if (d<0) {                                                    #
          for (i=t0-d; i<f0; i-=d) {                                  #
            printf(fmt,rwc_dir_typ,rwl,i,rwl,t0,tim0*(i-f0)/(t0-f0)); #
            printf(fmt,rwc_dir_typ,rwl,i,rwl,f0,tim0*(f0-i)/(t0-f0)); #
          }                                                           #
        }                                                             #
        print;                                                        #
      }                                                               #
    }                                                                 #
    {                                                                 #
      f   = substr($4,2)*1;                                           #
      t   = substr($5,2)*1;                                           #
      tim = $6;                                                       #
      if (d>0) {                                                      #
        for (i=f0+d; i<f; i+=d) {                                     #
          printf(fmt,rwc_dir_typ,rwl,i,rwl,f0,tim0*(f0-i)/(t0-f0));   #
          printf(fmt,rwc_dir_typ,rwl,i,rwl,t0,tim0*(t0-i)/(t0-f0));   #
        }                                                             #
      } else {                                                        #
        for (i=f0-d; i<f; i-=d) {                                     #
          printf(fmt,rwc_dir_typ,rwl,i,rwl,t ,tim *(t -i)/(t -f ));   #
          printf(fmt,rwc_dir_typ,rwl,i,rwl,f ,tim *(f -i)/(t -f ));   #
        }                                                             #
      }                                                               #
      f0   = f;                                                       #
      t0   = t;                                                       #
      tim0 = tim;                                                     #
      print;                                                          #
    }                                                                 #
    END {                                                             #
      if (NR<1) {exit;}                                               #
      if (d>0) {                                                      #
        for (i=f0+d; i<t; i+=d) {                                     #
          printf(fmt,rwc_dir_typ,rwl,i,rwl,f0,tim0*(f0-i)/(t0-f0));   #
          printf(fmt,rwc_dir_typ,rwl,i,rwl,t0,tim0*(t0-i)/(t0-f0));   #
        }                                                             #
      }                                                               #
    }'                                                                |
  # --- 始発駅-始発駅・終着駅-終着駅の所要時間0レコードを補完 --------#
  awk 'NR==1{s=($4<$5)?$4:$5;print $1,$2,$3,s,s,0;}                   #
            {print;                               }                   #
       END  {s=($4<$5)?$5:$4;print $1,$2,$3,s,s,0;}'                  |
  # --- 全駅・全通過駅・全駅間から各停車駅への所要時間レコードを補完 -#
  awk '                                                               #
    BEGIN {                                                           #
      split("", tim);                                                 #
      split("", fstn_no);                                             #
      split("", fstn_no_inv);                                         #
      n_fstn = 0;                                                     #
      split("", tstn_no);                                             #
      split("", tstn_no_inv);                                         #
      n_tstn = 0;                                                     #
      fmt = "%s %s%03d %s%03d %s\n";                                  #
    }                                                                 #
    {                                                                 #
      rwc_dir_typ = $1 " " $2 " " $3;                                 #
      rwl = substr($4,1,1);                                           #
      fno = substr($4,2)*1;                                           #
      tno = substr($5,2)*1;                                           #
      tim[fno,tno] =  $6;                                             #
      tim[tno,fno] = -$6;                                             #
      if (!(fno in fstn_no_inv)) {                                    #
        n_fstn++;                                                     #
        fstn_no[n_fstn] = fno;                                        #
        fstn_no_inv[fno] = 1;                                         #
      }                                                               #
      if (!(tno in tstn_no_inv)) {                                    #
        n_tstn++;                                                     #
        tstn_no[n_tstn] = tno;                                        #
        tstn_no_inv[tno] = 1;                                         #
      }                                                               #
    }                                                                 #
    END {                                                             #
      for (i=1; i<=n_fstn; i++) {                                     #
        fno = fstn_no[i];                                             #
        for (j=1; j<=n_tstn; j++) {                                   #
          tno = tstn_no[j];                                           #
          if (tno==fno) {                                             #
            tim[fno,tno] = 0;                                         #
            printf(fmt,rwc_dir_typ,rwl,fno,rwl,tno,0);                #
            continue;                                                 #
          }                                                           #
          d = (tno>fno) ? 10 : -10;                                   #
          # 例えば、T055→T010の所要時間情報が無い場合                #
          # まず、T055→T010は無いか、無ければT055→T020は無いか、    #
          # と探して、T055→T050に行き当たって見つかるので            #
          # それを変数minsに追加する。                                #
          # 次にT055→T010のうち、                                    #
          # まだ判明していないT050→T010区間を調べる。                #
          # 同様に、T050→T010、T050→T020という順番で探していく…    #
          mins = 0;                                                   #
          if (d>0) {                                                  #
            fno1 = fno;                                               #
            while (fno1 < tno) {                                      #
              for (tno1=tno; tno1>fno1; tno1=(int((tno1-d)/10))*10) { #
                s = fno1 SUBSEP tno1;                                 #
                if (s in tim) {mins+=tim[s]; break;}                  #
              }                                                       #
              if (tno1==tno) {break;}                                 #
              fno1 = tno1;                                            #
            }                                                         #
          } else {                                                    #
            fno1 = fno;                                               #
            while (fno1 > tno) {                                      #
              for (tno1=tno; tno1<fno1; tno1=(int((tno1-d)/10))*10) { #
                s = fno1 SUBSEP tno1;                                 #
                if (s in tim) {mins+=tim[s];break;}                   #
              }                                                       #
              if (tno1==tno) {break;}                                 #
              fno1 = tno1;                                            #
            }                                                         #
          }                                                           #
          s = fno SUBSEP tno;                                         #
          if (!(s in tim)) {tim[s]= mins;}                            #
          s = tno SUBSEP fno;                                         #
          if (!(s in tim)) {tim[s]=-mins;}                            #
          printf(fmt,rwc_dir_typ,rwl,fno,rwl,tno,mins);               #
        }                                                             #
      }                                                               #
    }'                                                                |
  # --- 標準所要分数を0.5単位に丸める --------------------------------#
  awk '{$6=($6>=0)?int($6*2+.5)/2:-int(-$6*2+.5)/2;print;}'           |
  # --- 目的のマスター形式にする -------------------------------------#
  awk '{print $3 "/" $4 "/" $5,$6;}'                                  > "$Tmp-RWMINS2_${rwc}_${dir}_${typ}"
  # 1:<種別コード>/<3桁発車駅ナンバー>/<3桁停車駅ナンバー> 2:標準到着時間
done

# --- 丸ノ内支線の事後特別処理 ---------------------------------------
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/\/m\(0[6-9]\)/\/M\1/g'     |
sed 's/\/m\([1-9][0-9]\)/\/M\1/g' > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_0_odpt.TrainType:TokyoMetro.Local.tmp"
mv "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_0_odpt.TrainType:TokyoMetro.Local.tmp" \
   "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_0_odpt.TrainType:TokyoMetro.Local"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/\/m\(0[6-9]\)/\/M\1/g'     |
sed 's/\/m\([1-9][0-9]\)/\/M\1/g' > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_1_odpt.TrainType:TokyoMetro.Local.tmp"
mv "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_1_odpt.TrainType:TokyoMetro.Local.tmp" \
   "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.MarunouchiBranch_1_odpt.TrainType:TokyoMetro.Local"


######################################################################
# 標準所要時間マスターファイル作成3(同等種別の複製)
######################################################################

# --- 千代田線 -------------------------------------------------------
# (準急=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (多摩急行=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/TamaExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.TamaExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/TamaExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.TamaExpress"
# (急行=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                              > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Express"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                              > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Express"
# (特急ロマンスカー=各停、停車駅は表参道、霞ヶ関、大手町、北千住のみ)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
awk '$1~/C(04|08|11|18)0$/{print;}'                                                  |
sed 's/Local/RomanceCar/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.RomanceCar"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
awk '$1~/C(04|08|11|18)0$/{print;}'                                                  |
sed 's/Local/RomanceCar/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.RomanceCar"

# --- 副都心線 -------------------------------------------------------
# (準急=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                             > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                             > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (快速=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                   > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Rapid"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                   > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Rapid"
# (快速急行=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.RapidExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.RapidExpress"
# (土休急行=急行、そもそも急行のマスターが土休急行になっている)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Express" |
sed 's/Express/HolidayExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.HolidayExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Express" |
sed 's/Express/HolidayExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.HolidayExpress"

# --- 南北線 ---------------------------------------------------------
# (急行=各停、目黒方面行のみ)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Namboku_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                              > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Namboku_1_odpt.TrainType:TokyoMetro.Express"

# --- 有楽町線 -------------------------------------------------------
# (準急=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (快速=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                  > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Rapid"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                  > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Rapid"
# (快速急行=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.RapidExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.RapidExpress"

# --- 半蔵門線 -------------------------------------------------------
# (準急=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (急行=各停)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                               > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.Express"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                               > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.Express"


######################################################################
# 標準所要時間マスターファイル作成4(方向別に同一路線ファイルを統合)
######################################################################

# --- 普通に統合 -----------------------------------------------------
echo $Tmp-RWMINS2*         |
tarr                       |
sed 's/_\([01]\)_.*$/_\1/' |
while read -r file_rwc_dir; do
  cat "$file_rwc_dir"* |
  sort                 > "$Homedir/DATA/RWMINS${file_rwc_dir##*-RWMINS2}.TXT"
done

# --- 副都心線・有楽町線は更に統合 -----------------------------------
cat "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Fukutoshin_0.TXT" \
    "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Yurakucho_0.TXT"  |
sort                                                                > "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.FY_0.TXT"
cat "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Fukutoshin_1.TXT" \
    "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Yurakucho_1.TXT"  |
sort                                                                > "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.FY_1.TXT"


######################################################################
# 正常終了
######################################################################

rm $Tmp-*
exit 0