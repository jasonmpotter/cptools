#!/bin/bash
# kill_sleepers Version 1.3
# by jpotter@liquidweb.com http://linkedin.com/in/JasonMPotter
# Scripts runs via cron every 5 minutes and kills any "Sleeping" queries longer than $SLEEP_LIMIT, default 300
SLEEP_LIMIT=${1-300}
DEF=" --defaults-file=/root/.my.cnf "
MYSQL_LOG=$(/usr/bin/mysql $DEF -NBe 'SHOW GLOBAL VARIABLES;' | awk '$1~/^datadir$/{dir=$2} $1~/^log_error$/{file=$2}END { if(file~/^[/]/){print file} else {print dir gensub(/^\.[/]/,"","",file)}}')
HTTPD_LOG=$(/usr/sbin/httpd -V | awk -F"=" '/HTTPD_ROOT/{dir=$2} /DEFAULT_ERRORLOG/{file=$2} END {p=dir file; gsub(/^"|"$/,"",p); print gensub(/""/,"/","",p)} ')
PID=$$

(/usr/bin/mysql $DEF -NBe "SELECT id,user,host,db,time FROM INFORMATION_SCHEMA.PROCESSLIST WHERE ( Command = 'Sleep' OR State = 'User sleep' ) AND Time > $SLEEP_LIMIT;"|\
    awk -v "DEF=$DEF"\
    'BEGIN {
            INFO[1]="qid"
            INFO[2]="user"
            INFO[3]="host"
            INFO[4]="db"
            INFO[5]="time"
        }
        {   
            x=x $1 ","; 
            for (i=1;i<=NF;i++) { 
                $i="["INFO[i]":"$i"]"
            }; 
            print 
        } 
        END { 
            if(x){ 
                sub(/,$/,"",x)
                system("/usr/bin/mysqladmin "DEF" kill "x) 
            } 
    }' 2>&1
)|\
    awk -v "name=$0"\
        -v "lim=$SLEEP_LIMIT"\
        -v "pid=$PID"\
        -v "mysql_log=$MYSQL_LOG"\
        -v "httpd_log=$HTTPD_LOG"\
        -v "host=$(hostname -s)"\
        '{
            print strftime("%a %b %T "host" "name"["pid"]: [LIMIT: "lim"]"),$0,"[KILLED]" >> "/var/log/messages"
            print strftime("%y%m%d %T ["name"] [LIMIT: "lim"]"),$0,"[KILLED]" >> mysql_log
            print strftime("[%a %b %e %H:%M:%S %Z %Y] ["name"] [LIMIT: "lim"]"),$0,"[KILLED]" >> httpd_log
        }'

