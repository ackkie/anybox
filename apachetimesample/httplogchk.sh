#!/bin/sh -u
################################################################################
# 前日のApache Log 遅延、エラー検出用シェルスクリプト
#         遅延(awkのLIMIT=10sec)、エラーのログの指定行分をメールで転送します。
# 条件  : apacheのログファイル名=time_logXXX 
#       :  LogFormat "%T %b %{%FT%T}t %>s %s %X %a \"%r\" \"%{User-Agent}i\"
# 注意  : outdirのファイルは適宜cron等で削除してください。
#       : メーラーは適宜変更してください。
# 作成者: 秋山 俊郎(j-wing.jp)
################################################################################
# Apache Log Directory
logdir=/var/log/httpd
# 出力ファイルディレクトリ
outdir=/tmp/apachelog
# メール送信先
maddress=root@localhost
# メール転送の指定行数LIMIT
maillimit=100

main() {
    dtptn=`getyesterday`
    tmpfname=$outdir/log-$dtptn
    slowlog=$outdir/slow-$dtptn
    stserrlog=$outdir/stserror-$dtptn

    if [ ! -d $outdir ]; then
	mkdir -p $outdir || ( echo 'TMDPIR ERROR' ; exit 1 )
    fi

    touch $tmpfname

# Apache Log Directoryから指定日付のログを抜き出す
    greptarget $logdir $dtptn $tmpfname ||
    ( echo "GREPTARGET ERROR" ; exit 1)

# Apache Log Directoryから指定日付のログを抜き出す
    cat $tmpfname |
    awk 'BEGIN { LIMIT = 10 }
  $2 > LIMIT {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' |
    sort > $slowlog 

    if [ -s $slowlog ]; then
	head -n $maillimit $slowlog | mail -s "HTTP SLOW $dtptn(`hostname`)" $maddress
    fi

    cat $tmpfname |
    awk '
  $3 == 403 {next}
  $3 >= 400 {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' |
    sort > $stserrlog 

    if [ -s $stserrlog ]; then
	cat $stserrlog |
	perl -pe 's/^([^ ].*) ([^ ].*) ([^ ].*) ([^ ].*) ([^ ].*) ([^ ].*) ([^ ].*) "(.*)" ".*"/$3 $8/'
	sort |
	uniq -c |
	sort -nr |
	head -n $maillimit $stserrlog | 
	mail -s "HTTP STATUS ERROR $dtptn(`hostname`)" $maddress
    fi

    rm  $tmpfname
}

function greptarget() {
    local _logdir=$1
    local _dtptn=$2
    local _outname=$3

    find $_logdir -mtime -1 -name "time_log*" |
    xargs --no-run-if-empty cat |
    grep $_dtptn > $_outname

    return $?
}

function getyesterday () {
    date '+%Y-%m-%d' --date '1 days ago'
}

main

exit 0
