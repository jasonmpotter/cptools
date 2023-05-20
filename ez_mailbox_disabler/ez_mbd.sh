#!/bin/bash
# Easy Mailbox Disabler (ez_mbd) by jpotter@liquidweb.com - https://linkedin.com/in/jasonmpotter
#
# Current Features:
#   Accepts a list of email addresses on command line or a file path to a file containing the list.
#   Invalidates the password hash for each mailbox found on the server that is in the list.
#   Notifies the cPanel account notification email using a template email in /etc/ez_mbd.conf
#   Reports status of each mailbox in the list and a summary report of all status types.
#
# Planned Features:
#   Clean Mail Queue
#   Suspend Outgoing Email until the mailbox passwd is updated
#   Remember bad password hashes & scan accounts for known bad hashes
#
# Tentative Features:
#   Show notification in cPanel Interface 
#   Send only one email notification per cPanel account.

# /usr/local/cpanel/bin/uapi
# uapi --user=username Email delete_held_messages email=username@example.com
# uapi --user=username Email hold_outgoing email=username%40example.com
# uapi --user=username Email suspend_outgoing email=user%40example.com
# uapi --user=username Email unsuspend_outgoing email=user%40example.com


NAME="Easy Mailbox Disabler" 
VERSION=2.4

function syntax {
    echo $NAME $VERSION
    echo "  ez_mbd user@domain.tld [user@domain.tld] [...]"
    echo "   or"
    echo "  ez_mbd /path/to/file"
}

function gethome { 
    awk -v "who=$(/scripts/whoowns $1 2>/dev/null)" -F: '$1==who{print $6}' /etc/passwd
}

function sendmail { 
    awk -F '='\
        -v "OWNER=$EZ_MDB_OWNER"\
        -v "DOMAIN=$EZ_MDB_DOMAIN"\
        -v "CONTACT=$EZ_MDB_CONTACT"\
        -v "HOSTNAME=$HOSTNAME"\
        -v "MAILBOX=$1"\
    'BEGIN {
            split("",_VARS)
            MSG=""
            #print "OWNER="OWNER
            #print "DOMAIN="DOMAIN
            #print "CONTACT="CONTACT
            #print "HOSTNAME="HOSTNAME
            #print "MAILBOX="MAILBOX
            MSGKEY="^## MESSAGE BODY BELOW THIS LINE[ \\t]*$"
            TYPE="Content-Type: text/plain; charset=utf-8\n"
        }

        {  
            gsub(/[[]OWNER[]]/,OWNER)
            gsub(/[[]DOMAIN[]]/,DOMAIN)
            gsub(/[[]CONTACT[]]/,CONTACT)
            gsub(/[[]HOSTNAME[]]/,HOSTNAME)
            gsub(/[[]MAILBOX[]]/,MAILBOX)
        }

        /^(FROM|SUBJECT|TO|CC|BCC)=/ {
            _VAR[$1]=$2
        }
        $0~MSGKEY,/^EOF$/ {
            if ($0~MSGKEY) { MSG=TYPE } else { MSG=MSG $0 "\n" }
        }

        END {
            #print "FROM="_VAR["FROM"]
            #print "SUBJECT="_VAR["SUBJECT"]
            #print "TO="_VAR["TO"]
            #print "CC="_VAR["CC"]
            #print "BCC="_VAR["BCC"]
            #print "MSG="MSG
            FROM=SUBJECT=TO=CC=BCC=""
            if (_VAR["FROM"])    { FROM=" -r \047" _VAR["FROM"] "\047" }
            if (_VAR["SUBJECT"]) { SUBJECT=" -s \047" _VAR["SUBJECT"] "\047"}
            if (_VAR["TO"])      { TO=" \047" _VAR["TO"] "\047"}
            if (_VAR["CC"])      { CC=" -c \047" _VAR["CC"] "\047"}
            if (_VAR["BCC"])     { BCC=" -b \047" _VAR["BCC"] "\047"}
            EXE="echo \047\n\n" MSG "\047|mailx " SUBJECT CC BCC FROM TO 
            EXE | getline x
            RET=close(EXE)
            if (RET) {
                print "Failed:" RET ": "x > /dev/stderr
                exit 5
            } else {
                print "Success:" TO gensub(/^-c/,"","",CC) gensub(/^-b/,"","",BCC) 
            }
        }
    ' /etc/ez_mbd.conf
    return 
    ##cat $template | mail -s "$subject" $contact
}

function main { 
    local list="$@"
    local array=()
    if [[ -z $1 ]]; then
        syntax 
        exit 1
    elif [[ -e $1 ]]; then
        list=$(cat $1)
    fi
    local dom usr home o s INVALID SKIPPED ERRORS MISSING NO_HOSTED
    echo "Disabling Passwords..."
    for i in $list; do
        dom=${i#*@}
        usr=${i%@*}
        home=$(gethome $dom)
        EZ_MDB_OWNER=$(/scripts/whoowns $dom)
        if [[ -f $home/etc/$dom/shadow ]]; then
            o=$(grep -E "^$usr:!.*" $home/etc/$dom/shadow)
            if [[ -z $o ]]; then 
                s=$(sed -i -re "s/^$usr:(.*)/$usr:!\1/" $home/etc/$dom/shadow 2>&1)
                if [[ -z $s ]]; then
                    o=$(egrep "^$usr:!.*" $home/etc/$dom/shadow)
                    if [[ -n $o ]]; then
                        echo -n "$(printf "  %12s: " "INVALIDATED") $i"
                        INVALID=$(($INVALID + 1))
                        EZ_MDB_CONTACT=$(awk -F "[ \t\047]" '$1~/"email":/{print $(NF-1)}' $home/.cpanel/contactinfo)
                        EZ_MDB_DOMAIN=$(awk -F "[ \t\047]" '$1~/main_domain:/{print $NF}' /var/cpanel/userdata/$EZ_MDB_OWNER/main)
                        RET=$(sendmail $i 2>&1)
                        echo -e "\t[Notify:$RET]"
                        array+=($i)      
                    else
                        echo "$(printf "  %12s: " "MISSING") $i - mailbox does not exist on $dom."
                        MISSING=$(($MISSING + 1))
                    fi
                else
                    echo "$(printf "  %12s: " "ERROR") $i - while acting on $home/etc/$dom/shadow - $s" > /dev/stderr
                    ERRORS=$(($ERRORS + 1))
                fi
            else
                echo "$(printf "  %12s: " "SKIPPED") $i - already disabled."
                SKIPPED=$(($SKIPPED + 1))
            fi
        else
            echo "$(printf "  %12s: " "NOT_HOSTED") $dom does not exist on the server."
            NOT_HOSTED=$(($NOT_HOSTED + 1))
        fi
    done

    local LENGTH=${#INVALID}
    if [[ ${#MISSING} > $LENGTH ]]; then LENGTH=${#MISSING}; fi 
    if [[ ${#ERRORS} > $LENGTH ]]; then LENGTH=${#ERRORS}; fi 
    if [[ ${#SKIPPED} > $LENGTH ]]; then LENGTH=${#SKIPPED}; fi 
    if [[ ${#NOT_HOSTED} > $LENGTH ]]; then LENGTH=${#NOT_HOSTED}; fi 
    echo 
    local BAR="+----------------------------------------------------------------------------------------+"
    echo $BAR
    echo "| BATCH MAILBOX DISABLE SUMMARY                                                          |"
    echo $BAR
    echo "$(printf "  %12s : %'${LENGTH}d" "INVALID" $INVALID) : Addresses who were disabled this session."
    echo "$(printf "  %12s : %'${LENGTH}d" "MISSING" $MISSING) : Missing mailboxes on their domain."
    echo "$(printf "  %12s : %'${LENGTH}d" "SKIPPED" $SKIPPED) : Already disabled addresses"
    echo "$(printf "  %12s : %'${LENGTH}d" "NOT_HOSTED" $NOT_HOSTED) : Domains not hosted on the server."
    echo "$(printf "  %12s : %'${LENGTH}d" "ERRORS" $ERRORS) : Number of failures."
    echo $BAR
    echo "IMPORTANT: A hard stop of BOTH EXIM & IMAP is needed to break exisiting connections."
    if [[ $INVALID > 0 ]]; then
        read -p "Automatically STOP/START BOTH EXIM/DOVECOT & Clean Mail Queue? (YES|NO)" answer
        if [[ $answer =~ ^(y(es)?|Y(ES)?)$ ]]; then
            /scripts/restartsrv_exim stop
            /scripts/restartsrv_imap stop
            sleep 3
            /scripts/restartsrv_exim start
            /scripts/restartsrv_imap start
            echo "Preparing Queue Cleaning to run in background (NICELY)."
            nice -n 15 ionice -c2 -n7 find /var/spool/exim/input -type f -regex '.*-H$' | awk -v "list=$(for each in ${array[*]}; do echo $each; done)" '
                BEGIN { 
                    split(list,arr," ") 
                    for (e in arr) { emails[arr[e]]=1} 
                } { 
                    while(getline x < $0) {
                        if (x ~ /^-auth_id/) {
                            if (emails[gensub(/^-auth_id[ \t]+/,"","g",x)]) {
                                print gensub(/.*[/]|-H$/,"","g",$0)
                            }
                            close($0)
                            next
                        }
                    }
                }
            ' | xargs --no-run-if-empty /usr/sbin/exim -Mrm 2>&1 | awk '{print "[",strftime(),"] " $0;}' > ez_mbd_clean_queue.log &
            echo Mail Queue Cleaning will continue in the background as nicely as possible.
            echo Deletions are logged in ez_mbd_clean_queue.log in the current directory.
            echo -e "\t Example: tail ./ez_mbd_clean_queue.log"
        fi
    else
        echo "There were not any successful disabled addresses, no need for restarts."
    fi
}
main "$@"
