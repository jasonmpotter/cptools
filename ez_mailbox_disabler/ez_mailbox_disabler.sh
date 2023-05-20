#!/bin/bash
# Tool for simplifying mass password disabling of a list of email accounts on cPanel.
# This tool slips an extra character into the proper shadow file for the user to invalidated the password.
# by jpotter@liquidweb.com  - https://linkedin.com/in/jasonmpotter
# Version 1.0

function syntax {
    echo "Syntax Error: one or more email addresses required"
    echo "  $0 user@domain.tld [user@domain.tld] [...]"
}

function gethome { 
    awk -v "who=$(/scripts/whoowns $1 2>/dev/null)" -F: '$1==who{print $6}' /etc/passwd
}

function main { 
    if [[ -z $1 ]]; then
        syntax 
        exit 1
    fi
    local dom usr home o s INVALID SKIPPED ERRORS MISSING NO_HOSTED
    echo "Disabling Passwords..."
    for i in $@; do
        dom=${i#*@}
        usr=${i%@*}
        home=$(gethome $dom)
        if [[ -f $home/etc/$dom/shadow ]]; then
            o=$(grep -E "^$usr:!.*" $home/etc/$dom/shadow)
            if [[ -z $o ]]; then 
                s=$(sed -i -re "s/^$usr:(.*)/$usr:!\1/" $home/etc/$dom/shadow 2>&1)
                if [[ -z $s ]]; then
                    o=$(egrep "^$usr:!.*" $home/etc/$dom/shadow)
                    if [[ -n $o ]]; then
                        echo "$(printf "  %12s: " "INVALIDATED") $i"
                        INVALID=$(($INVALID + 1))
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
    echo "+----------------------------------------------------------------------------------------+"
    echo "| BATCH MAILBOX DISABLE SUMMARY                                                          |"
    echo "+----------------------------------------------------------------------------------------+"
    echo "$(printf "  %12s : %'${LENGTH}d" "INVALID" $INVALID) : addresses who were disabled this session."
    echo "$(printf "  %12s : %'${LENGTH}d" "MISSING" $MISSING) : missing mailboxes on their domain."
    echo "$(printf "  %12s : %'${LENGTH}d" "SKIPPED" $SKIPPED) : already disabled addresses"
    echo "$(printf "  %12s : %'${LENGTH}d" "NOT_HOSTED" $NOT_HOSTED) : domains not hosted on the server."
    echo "$(printf "  %12s : %'${LENGTH}d" "ERRORS" $ERRORS) : Number of failures."
    echo "+----------------------------------------------------------------------------------------+"
    echo "IMPORTANT: A hard stop of BOTH EXIM & IMAP is needed to break exisiting connections."
    if [[ $INVALID > 0 ]]; then
        read -p "Do you want to STOP & START BOTH EXIM & IMAP Auotmatically? (YES|NO)" answer
        if [[ $answer =~ ^(y(es)?|Y(ES)?)$ ]]; then
            /scripts/restartsrv_exim stop
            /scripts/restartsrv_imap stop
            sleep 3
            /scripts/restartsrv_exim start
            /scripts/restartsrv_imap start
        fi
    else
        echo "There were not any successful disabled addresses, no need for restarts."
    fi
}

main $@


