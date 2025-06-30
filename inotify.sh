#!/bin/sh
#########################################################################
#
# File:         inotify.sh
# Description:  rsync+inotify real-time synchronization.
# Language:     GNU Bourne-Again SHell
# Version:  2.0
# Date:     2022/6/28
# Corp.:    c1gstudio
# Author:   andychu
#
#
# 监听 ${V_WATCH} 和 ${V_WATCH2} 目录, 每秒只传输一次
# 注意：${V_RSYNC_DELETE}请谨慎操作,会删除不一致文件
# 如需半自动同步那就从监听中移除 ${V_WATCH}
# 手动同步 touch ${V_WATCH2}/syncbbs 
# 开机启动
# echo "cd /opt/shell && /opt/shell/inotify.sh &" >> /etc/rc.local
# 运行
# cd /opt/shell && /opt/shell/inotify.sh &
# 关闭可以直接杀
# pkill inotify
#########################################################################

V_SERVERNAME=`hostname`
V_INOTIFYPATH=/usr/bin/

V_TODAY=`date +%Y%m%d`
# 需同步代码目录
V_WATCH=/opt/htdocs/discuz/
# V_WATCH2 不要以/结尾
V_WATCH2=/opt/htdocs/codesync
# 同步目标主机,多个以空格分割
V_DES_BBS=(192.168.0.88 192.168.0.89) 
# 目录主机rsync用户
V_DES_USER='www'
# rsync是否测试运行，不同步数据？0=no;1=yes
V_RSYNC_TEST=0
# rsync是否文件保持一致，删目标多余文件？0=no;1=yes
V_RSYNC_DELETE=0
# rsync密码文件
V_RSYNC_PASS='/etc/rsyncd.passwd'

V_INFO_LASTTIME=time

V_DEBUGLOG=./rsynclog/inotify.${V_TODAY}.log
V_DEBUGPATH=`dirname ${V_DEBUGLOG}`
# 是否开启本脚本运行日志;写入DEBUGLOG ?0=no;1=yes
V_DEBUGLOGOPEN=1

# 是否强制使用root运行?0=no;1=yes
V_USEROOT=0

if [ ! -d ${V_DEBUGPATH} ]; then
    mkdir -p ${V_DEBUGPATH}
    chmod 700 ${V_DEBUGPATH}
	echo "make dir ${V_DEBUGPATH}!"
fi

function check_param(){
    if [ "$1" ]; then
        if [ `ipcalc -c ${1} 2>&1 |grep -c 'ipcalc'` = 0 ]; then
            local desip=$1
        else
            echo "Error: bad input 1" >> ${V_DEBUGLOG}
            return 1
        fi
    else
        echo "Error: need ip" >> ${V_DEBUGLOG}
        return 1
    fi
    return 0
}

function check_root() {
    # we need root to run 
    if [ ${V_USEROOT} -eq 1 ] && test "`id -u`" -ne 0
    then
        echo "You need root to run!"
        exit 1
    fi
}

function check_inotify(){
    command -v ${V_INOTIFYPATH}inotifywait >/dev/null 2>&1 || { echo >&2 "I require inotify but it's not installed.  Aborting."; exit 1; }
}

function check_rsync(){
    command -v rsync >/dev/null 2>&1 || { echo >&2 "I require rsync but it's not installed.  Aborting."; exit 1; }
}

function writelog(){
    local content="$@"
    if [ ${V_DEBUGLOGOPEN} -eq 1 ]; then
        echo -e "${content}  " >> ${V_DEBUGLOG} && echo -e "${content}  "
    else
        echo "${content}  "
    fi
}

function opt_inotify() {
    if [ ${V_USEROOT} -eq 1 ] && test "`id -u`" -eq 0
    then
        echo 163840 > /proc/sys/fs/inotify/max_queued_events 
        echo 10485760 > /proc/sys/fs/inotify/max_user_watches
    fi
}

function sync_bbs(){
    if [ ${V_RSYNC_TEST} -eq 1 ]; then
        local V_RSYNC_TESTTEXT='-n'
    else 
        local V_RSYNC_TESTTEXT=''
    fi
    if [ ${V_RSYNC_DELETE} -eq 1 ]; then
        local V_RSYNC_DELETETEXT='--delete'
    else 
        local V_RSYNC_DELETETEXT=''
    fi
    
    n_inner_array=${#V_DES_BBS[*]} 
    for ((j=0;j<$n_inner_array;j++));
    do
        local desip=${V_DES_BBS[$j]} 
        check_param "${desip}"
        if [ $? -eq 0 ]; then
            writelog "sync bbs "$(date +%Y-%m-%d_%H:%M:%S)" "${desip}"\r"
	        rsync -av ${V_RSYNC_TESTTEXT} ${V_RSYNC_DELETETEXT} --password-file=${V_RSYNC_PASS} --exclude "config/config_global.php" --exclude "data/threadcache/" --exclude "data/template/" --exclude "data/log/" --exclude "data/cache/" --exclude "data/attachment/" --exclude "exam/cache/" --exclude "data/sendmail.lock"  ${V_WATCH} ${V_DES_USER}@${desip}::discuz  >> ${V_DEBUGLOG}
        fi
    done
}

check_root
check_inotify
check_rsync
opt_inotify


echo -e "start ${V_SERVERNAME} inotify!\r"
echo -e "watch:${V_WATCH} \r"
echo -e "watch2:${V_WATCH2} \r"
echo -e "log file:${V_DEBUGLOG} \r"

writelog "=====${V_SERVERNAME}==`date +'%Y%m%d %H:%M:%S'`========" 

${V_INOTIFYPATH}inotifywait -mrq --exclude "(data/(threadcache|log|template|sendmail\.lock|cache|attachment))" --timefmt '%Y/%m/%d_%H:%M:%S' --format '%T %Xe %w%f' \
-e modify,delete,create,attrib ${V_WATCH} ${V_WATCH2} | while read file
do
    V_INFO_TIME=$(echo $file |awk '{print $1}')
    V_INFO_EVENT=$(echo $file |awk '{print $2}')
    V_INFO_FILE=$(echo $file |awk '{print $3}')
    V_EVENTDIR=`dirname ${V_INFO_FILE}`
    writelog "${file}\r" 
    if [[ "${V_EVENTDIR}" =~ "${V_WATCH2}" ]]; then
        if [[ ${V_INFO_EVENT} =~ 'ATTRIB' ]] || [[ ${V_INFO_EVENT} =~ 'CREATE' ]]; then
            sync_bbs
            #echo -e 'sync'
        fi
    else
        if [[ ${V_INFO_LASTTIME} != ${V_INFO_TIME} ]]; then
            V_INFO_LASTTIME=${V_INFO_TIME}
            touch --time=modify ${V_WATCH2}/syncbbs
        fi
    fi
done
