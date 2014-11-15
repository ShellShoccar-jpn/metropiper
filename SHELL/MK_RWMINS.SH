#! /bin/sh

######################################################################
#
# MK_RWMINS.SH
# �H���ʕW�����v���ԃ}�X�^�[�t�@�C���𐶐�����
# Written by Rich Mikan(richmikan@richlab.org) at 2014/11/11
#
# [����]
# �E���L�̃t�@�C����p�ӂ��Ă���
#    1. CONF/ACCESSTOKEN.TXT
#       �R���e�X�g�ŗ^����ꂽ�A�N�Z�X�g�[�N�����L�q�����e�L�X�g
# �E�����ŉ��L���w��
#   [$1] : WepAPI��rdf:type=odpt:Railway�Ŏ擾����JSON��parsrj.sh��
#          �p�[�X�����e�L�X�g�t�@�C��
#          �E(��)�w�肳��Ă��Ȃ����Web����ŐV�ł�����Ă���B
# [�o��]
# �E���L�̃}�X�^�[�t�@�C�������
#    RWMINS_<�H���R�[�h>_<����(���Ȃ�0,�t�Ȃ�1)>.TXT
#     1:<��ʃR�[�h>/<3�����ԉw�i���o�[>/<3����ԉw�i���o�[> 2:�W����������
#
# [���l]
# �E�vcurl�R�}���h
#
######################################################################


######################################################################
# �����ݒ�
######################################################################

# --- �g�p�@�\���֐���` ---------------------------------------------
print_usage_and_exit() {
  local s
  s=$(awk 'BEGIN{printf("%070d",0)}' | tr 0 '#')
  awk "f==1&&/^${s}\$/{print;exit} f==0&&/^${s}\$/{f=1} f==1{print;}" "$0" 1>&2
  exit 1
}

# --- ���̃V�X�e���̃z�[���f�B���N�g���[ -----------------------------
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"

# --- ���̑������f�B���N�g���[����` ---------------------------------
# 1)�R�}���h�p�X�̒ǉ�
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)�ꎞ�t�@�C���i�[��
Tmp=/tmp/${0##*/}.$$
# 3)�I�����̈ꎞ�t�@�C���폜�ݒ�
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM
# 4)���̑�
LF=$(printf '\\\n_');LF=${LF%_}  # sed���ł̉��s��ϐ��Ƃ��Ĉ������߂̂���


######################################################################
# �����m�F�E�擾
######################################################################

# --- ������0�܂���1�ł��邱�Ƃ̊m�F ---------------------------------
[ $# -le 1 ] || print_usage_and_exit

# --- ����1�������ȃt�@�C���ł��邱�Ƃ̊m�F --------------------------
[ \( -z "${1:-}" \) -o \( -f "${1:-}" \) ] || print_usage_and_exit

# --- WepAPI��rdf:type=odpt:Railway�Ŏ擾����JSON��parsrj.sh��file�ݒ�
file_Railway=$1


######################################################################
# API����f�[�^������Ă���(�����Ŏw�肳��Ă���Ή������Ȃ�)
######################################################################

# --- �t�@�C�����Ȃ����WebAPI����擾���Ă��� -----------------------
case "$file_Railway" in
  '')
    # --- �^����ꂽ�A�N�Z�X�g�[�N����ݒ� ---------------------------
    File_token=$Homedir/CONF/ACCESSTOKEN.TXT
    if [ ! -f "$File_token" ]; then
      echo "${0##*/}: The file contains access token is not found." 1>&2
      exit 1
    fi
    appid=$(env - awk '/^[[:alnum:]]+$/' "$File_token")
    if [ -z "$appid" ]; then
      echo "${0##*/}: The access token is not valid." 1>&2
      exit 1
    fi
    # --- �Ăяo��URL�̐ݒ� ------------------------------------------
    url='https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Railway&acl:consumerKey='$appid
    # --- �Ăяo���ăt�@�C���𐶐����� -------------------------------
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
# �W�����v���ԃ}�X�^�[�t�@�C���쐬1(�H�����Ƀf�[�^�𕪗�)
######################################################################

# --- �H���E��ʁE�������̗אډw�W�����v�����t�@�C�����쐬���� -------
cat $file_Railway                                                            |
# 1:JSON�ʒu 2:�l                                                            #
grep -E '^\$\[[0-9]+\]\.(odpt:travelTime\[|owl:sameAs)'                      |
sed 's/^\$\[\([0-9]\{1,\}\)\]\./\1 /'                                        |
sed 's/owl:sameAs/1/'                                                        |
sed 's/odpt:travelTime\[\([0-9]\{1,\}\)\]\.odpt:/2 \1 /'                     |
awk '$4=="trainType"    {f4=1;                                               #
                         sub(/:/,":TokyoMetro.",$5);                         # # ��ԃ��P�[�V�������ł͎�ʃR�[�h�̐擪��
                         sub(/TokyoMetro\.TokyoMetro\./,"TokyoMetro.",$5);}  # # "TokyoMetro."�����Ă��邽�߁A�␳����B
     $4=="fromStation"  {f4=2;                                            }  #
     $4=="toStation"    {f4=3;                                            }  #
     $4=="necessaryTime"{f4=4;                                            }  #
     {print $1,$2,$3,f4,$5;                                               }' |
sort -k1n,1 -k2n,2 -k3n,3 -k4n,4                                             |
# 1:�H���ԍ� 2:�H���R�[�h�s�Ȃ�1�A���v���ԍs�Ȃ�2                            #
# 3:(�H���R�[�h�s�Ȃ�)�H���R�[�h�A(���v���ԍs�Ȃ�)���ڔԍ�                   #
# 4:(���v���ԍs�Ȃ�)�t�B�[���h��ʔԍ� 5:(���v���ԍs�Ȃ�)�W�����v����        #
awk '$2==1{rwc=$3;next;} $2==2{print rwc,$3,$5}'                             |
yarr num=2                                                                   |
delf 2                                                                       |
# 1:�H���R�[�h 2:��ʃR�[�h 3:���ԉw�R�[�h 4:��ԉw�R�[�h 5:�W�����v����     #
sort -k3,3                                                                   |
join -1 1 -2 3 -o 2.1,2.2,2.3,1.2,2.4,2.5 $Homedir/DATA/SC2SNUM.TXT -        |
delf 3                                                                       |
sort -k4,4                                                                   |
join -1 1 -2 4 -o 2.1,2.2,2.3,2.4,1.2,2.5 $Homedir/DATA/SC2SNUM.TXT -        |
delf 4                                                                       |
# 1:�H���R�[�h 2:��ʃR�[�h 3:���ԉw�i���o�[ 4:��ԉw�i���o�[ 5:�W�����v���� #
awk '{f=substr($3,2);t=substr($4,2);print $1,(f>t),$2,$3,$4,$5;}'            |
sort -k1,1 -k2,2 -k3,3 -k4,4                                                 |
# 1:�H���R�[�h 2:����(�w�i���o�[��������0�A�t������1) 3:��ʃR�[�h           #
# 4:���ԉw�i���o�[ 5:��ԉw�i���o�[ 6:�W�����v����                           #
keycut $Tmp-RWMINS1_%1_%2_%3

# --- �ۃm���x���̎��O���ʏ��� ---------------------------------------
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

# --- ���s�S���ʋ΋}�s�𐶐����鎖�O���ʏ��� -------------------------
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
# �W�����v���ԃ}�X�^�[�t�@�C���쐬2(�אڂ��ĂȂ��w�E�w�Ԃ̃��R�[�h�⊮)
######################################################################

ls -1 $Tmp-RWMINS1_*                       |
sed 's/_odpt.TrainType:/ odpt.TrainType:/' |
sed 's/_\([01]\)/ \1/'                     |
sed 's/_odpt.Railway:/ odpt.Railway:/'     |
while read -r filebase rwc dir typ; do
  cat "${filebase}_${rwc}_${dir}_${typ}"                              |
  # 1:�H���R�[�h 2:����(�w�i���o�[�������Ȃ�0,�t�Ȃ�1) 3:��ʃR�[�h   #
  # 4:���ԉw�i���o�[ 5:�����w�i���o�[ 6:�W�����v����                  #
  # --- 3���w�i���o�[�� ----------------------------------------------#
  awk '{print $1,$2,$3,$4 "0",$5 "0",$6;}'                            |
  # 1:�H���R�[�h 2:����(�w�i���o�[�������Ȃ�0,�t�Ȃ�1) 3:��ʃR�[�h   #
  # 4:����3���w�i���o�[ 5:����3���w�i���o�[ 6:�W�����v����            #
  # --- �w��,�ʉ߉w�ɑ΂��Ă����R�[�h�̂���אډw�܂ł̃��R�[�h��⊮ #
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
  # --- �n���w-�n���w�E�I���w-�I���w�̏��v����0���R�[�h��⊮ --------#
  awk 'NR==1{s=($4<$5)?$4:$5;print $1,$2,$3,s,s,0;}                   #
            {print;                               }                   #
       END  {s=($4<$5)?$5:$4;print $1,$2,$3,s,s,0;}'                  |
  # --- �S�w�E�S�ʉ߉w�E�S�w�Ԃ���e��ԉw�ւ̏��v���ԃ��R�[�h��⊮ -#
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
          # �Ⴆ�΁AT055��T010�̏��v���ԏ�񂪖����ꍇ                #
          # �܂��AT055��T010�͖������A�������T055��T020�͖������A    #
          # �ƒT���āAT055��T050�ɍs���������Č�����̂�            #
          # �����ϐ�mins�ɒǉ�����B                                #
          # ����T055��T010�̂����A                                    #
          # �܂��������Ă��Ȃ�T050��T010��Ԃ𒲂ׂ�B                #
          # ���l�ɁAT050��T010�AT050��T020�Ƃ������ԂŒT���Ă����c    #
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
  # --- �W�����v������0.5�P�ʂɊۂ߂� --------------------------------#
  awk '{$6=($6>=0)?int($6*2+.5)/2:-int(-$6*2+.5)/2;print;}'           |
  # --- �ړI�̃}�X�^�[�`���ɂ��� -------------------------------------#
  awk '{print $3 "/" $4 "/" $5,$6;}'                                  > "$Tmp-RWMINS2_${rwc}_${dir}_${typ}"
  # 1:<��ʃR�[�h>/<3�����ԉw�i���o�[>/<3����ԉw�i���o�[> 2:�W����������
done

# --- �ۃm���x���̎�����ʏ��� ---------------------------------------
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
# �W�����v���ԃ}�X�^�[�t�@�C���쐬3(������ʂ̕���)
######################################################################

# --- ���c�� -------------------------------------------------------
# (���}=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (�����}�s=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/TamaExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.TamaExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/TamaExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.TamaExpress"
# (�}�s=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                              > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Express"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                              > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Express"
# (���}���}���X�J�[=�e��A��ԉw�͕\�Q���A�����ցA��蒬�A�k��Z�̂�)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.Local" |
awk '$1~/C(04|08|11|18)0$/{print;}'                                                  |
sed 's/Local/RomanceCar/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_0_odpt.TrainType:TokyoMetro.RomanceCar"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.Local" |
awk '$1~/C(04|08|11|18)0$/{print;}'                                                  |
sed 's/Local/RomanceCar/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Chiyoda_1_odpt.TrainType:TokyoMetro.RomanceCar"

# --- ���s�S�� -------------------------------------------------------
# (���}=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                             > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                             > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (����=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                   > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Rapid"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                   > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Rapid"
# (�����}�s=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.RapidExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.RapidExpress"
# (�y�x�}�s=�}�s�A���������}�s�̃}�X�^�[���y�x�}�s�ɂȂ��Ă���)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.Express" |
sed 's/Express/HolidayExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_0_odpt.TrainType:TokyoMetro.HolidayExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.Express" |
sed 's/Express/HolidayExpress/g'                                                          > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Fukutoshin_1_odpt.TrainType:TokyoMetro.HolidayExpress"

# --- ��k�� ---------------------------------------------------------
# (�}�s=�e��A�ڍ����ʍs�̂�)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Namboku_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                              > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Namboku_1_odpt.TrainType:TokyoMetro.Express"

# --- �L�y���� -------------------------------------------------------
# (���}=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                            > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (����=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                  > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Rapid"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Rapid/g'                                                                  > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Rapid"
# (�����}�s=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_0_odpt.TrainType:TokyoMetro.RapidExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/RapidExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Yurakucho_1_odpt.TrainType:TokyoMetro.RapidExpress"

# --- ������� -------------------------------------------------------
# (���}=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.SemiExpress"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/SemiExpress/g'                                                           > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.SemiExpress"
# (�}�s=�e��)
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                               > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_0_odpt.TrainType:TokyoMetro.Express"
cat "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.Local" |
sed 's/Local/Express/g'                                                               > "$Tmp-RWMINS2_odpt.Railway:TokyoMetro.Hanzomon_1_odpt.TrainType:TokyoMetro.Express"


######################################################################
# �W�����v���ԃ}�X�^�[�t�@�C���쐬4(�����ʂɓ���H���t�@�C���𓝍�)
######################################################################

# --- ���ʂɓ��� -----------------------------------------------------
echo $Tmp-RWMINS2*         |
tarr                       |
sed 's/_\([01]\)_.*$/_\1/' |
while read -r file_rwc_dir; do
  cat "$file_rwc_dir"* |
  sort                 > "$Homedir/DATA/RWMINS${file_rwc_dir##*-RWMINS2}.TXT"
done

# --- ���s�S���E�L�y�����͍X�ɓ��� -----------------------------------
cat "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Fukutoshin_0.TXT" \
    "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Yurakucho_0.TXT"  |
sort                                                                > "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.FY_0.TXT"
cat "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Fukutoshin_1.TXT" \
    "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.Yurakucho_1.TXT"  |
sort                                                                > "$Homedir/DATA/RWMINS_odpt.Railway:TokyoMetro.FY_1.TXT"


######################################################################
# ����I��
######################################################################

rm $Tmp-*
exit 0