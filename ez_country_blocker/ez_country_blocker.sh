#!/bin/bash
VERSION="1.2.0"
AUTHOR="jpotter@liquidweb.com - https://linkedin.com/in/jasonmpotter"
#   Summarizes connections by count and country while generating easy copy+paste CSF commands
#   Features:
#       Excludes all locally configured IP addresses automatically
#       Configure country exclusions
#       Configure which services to scan
#       Supports Temporary or Permanent Blocks
#       Configurable output script target
#       Automatically Ignores LW Internal IPS
#       Toggle for treating unknown IPs as foreign (disabled by default)
#       Toggle for treating internal Private IPs as foreign (disabled by default)
#       Self-Updating
#       Configuration file to retain settings between updates, default: /etc/ez_country_blocker.conf
#
## 
CONF=/etc/ez_country_blocker.conf

## CODE -- Do Not Modify Below This Line
if [[ ! -e $CONF ]]; then
    cat <<'eof'>$CONF
COUNTRIES="CA,US,MX"                            #Comma separated list of countries to exclude  
PORTS="80,443,8080,110,995,143,993,2095,2096"   #Comma separated list of TCP Ports to scan
SCRIPT=/root/ez-country-blocker-block-all       #Target for generating block-all script
TIME=$((86400*7))                               #Duration in seconds to block IPs (0 = permanent)
#BLOCK_PRIVATE="1"                              #Uncomment this to block Internal Private IPs as Foreign
#BLOCK_UNKNOWN="1"                              #Uncomment this to block unknown IPs as Foreign
eof
fi

source $CONF
COUNTRIES=${COUNTRIES-CA,US}
PORTS=${PORTS-80,443,8080,110,995,143,993,2095,2096}
SCRIPT=${SCRIPTS-/root/ez-country-blocker-block-all}
TIME=${TIME-$((86400*7))}
UPDATE_URL=https://cpguy.com/toolchest/ez_country_blocker/ez_country_blocker.sh

## END CONF
################################################################################################################
echo -e "\033[1;37mEZ-Blocker\033[m \033[0;33m$VERSION \033[0;37mby\033[0;36m $AUTHOR\033[m"
echo -e "\033[0;37m Checking for Updates...\033[m"
## Check for Updates before running
FILE=/usr/local/bin/ez_country_blocker.sh
cd /usr/local/bin/ &>/dev/null
if [[ $(wget -N $UPDATE_URL |& grep "^Saving to:") ]]; then
    chmod +x $FILE &>/dev/null
    ln -fs /usr/local/bin/ez_country_blocker.sh /bin/ez_country_blocker &>/dev/dull
    cd - &> /dev/null
    echo -e "\033[0;37m Update Complete. Restarting..\033[m"
    $FILE "$@" 
    exit
fi
cd - &> /dev/null
##
NAGIOS='10\\.[2-4][0-1]\\.[0-9]'
PRIVATE='(^127\\.)|(^192\\.168\\.)|(^10\\.)|(^172\\.1[6-9]\\.)|(^172\\.2[0-9]\\.)|(^172\\.3[0-1]\\.)|(^::1$)|(^[fF][cCdD])'

if [[ -z $BLOCK_UNKNOWN ]]; then 
   COUNTRIES="$COUNTRIES,UNKNOWN"
fi

if [[ -z $BLOCK_PRIVATE ]]; then 
   COUNTRIES="$COUNTRIES,PRIVATE"
fi
 

echo -e "\033[0;37m The following countries are excluded:\033[0;33m $COUNTRIES\033[m"
echo -e "\033[0;37m The following services are checked:\033[0;33m $PORTS\033[m"
printf "\033[0;37m The Block duration is set to:\033[m "
 
if [[ $TIME == 0 ]]; then
    echo -e "\033[0;33m0\033[m (permanent)"
else
    echo -e "\033[0;33m$TIME\033[m (seconds)"
fi
echo -e " \033[0;37mProcessing Connections\033[0;33m...\033[m"
echo
 
$(type -fP netstat) -antp | awk \
    -v "COUNTRIES=(${COUNTRIES//,/|}),"\
    -v "PORTS=:(${PORTS//,/|})\$" \
    -v "TIME=$TIME" \
    -v "NAGIOS=$NAGIOS" \
    -v "PRIVATE=$PRIVATE" \
    -v "SCRIPT=$SCRIPT" '
    BEGIN {
        E="/sbin/ip a"
        while(E|getline) {
            if (/inet/) { LIPS[gensub(/\/[0-9 \t]+$/,"","g",$2)]++ }
        }
        close(E)
        split("",OUTPUT)
        split("",SVCS)
    }
 
    $5~/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ &&
    !LIPS[gensub(/:[0-9]+$/,"","g",$5)] &&
    $4~PORTS {
        gsub(/:[0-9 \t\r\n]+$/,"",$5)
        gsub(/[^:]+:/,"",$4)
        $4+=1000000
        IPS[$5]=$5
        COUNTS[$5]++
        SVCS[$5":"$4]=$5":"$4
        SVCS_CNTS[$5":"$4]++
    }
 
    END {
        N=asorti(IPS,SIPS)
        for (I=1;I<=N;I++) {    
            IP=SIPS[I]
            if (IP !~ NAGIOS) {
                E="geoiplookup "IP" 2>&1|head -1"
                O=""
                while(E|getline x) { 
                    if (x ~ PRIVATE) {
                        sub(/IP Address not found/,"PRIVATE, ",x); 
                    } 
                    if (x ~ UNKNOWN) {
                        sub(/IP Address not found/,"UNKNOWN, ",x); 
                    }
                    gsub(/GeoIP[^:]+: |[\047\"><|*&\$]/,"",x) 
                    O=O x 
                }
                close(E)
                #print "COMPARE " IP toupper(O) " !~ " COUNTRIES | "column -t"
                if (toupper(O) !~ COUNTRIES) { 
                    sub(/UNKNOWN,/,"--, UNKNOWN IP",O) 
                    sub(/PRIVATE,/,"--, PRIVATE IP",O) 
                    OUTPUT[length(OUTPUT)+1]=COUNTS[IP]+1000000 "|" IP "|" O 
                }
            }
        }

        N=asort(SVCS,SVCSS)
        for (I=1;I<=N;N--) {    
            split(SVCSS[N],SPARTS,":")
            SVC=SPARTS[2]
            SERVICES[SPARTS[1]]=SERVICES[SPARTS[1]]" "SVC-1000000
            #SVCLIST[SVC]=SVC
        }
 
        N=asort(OUTPUT,SORTED)
        S="\033[0;33m|\033[m"
        printf "  \033[1;33m%7s   %15s   %8s   %-18s   %s\033[m\n","COUNT","IP ADDRESS","SERVICES","COUNTRY","EZ BLOCKER QUICK CODE"
 
        for (I=1;I<=N;N--) {    
            split(SORTED[N],PARTS,"|")
            if (TIME) {
                EZ="csf -td " PARTS[2] " " TIME " EZ: " PARTS[3]
                print EZ > SCRIPT
            } else {
                EZ="csf -d " PARTS[2] " EZ: " PARTS[3]
                print "echo " PARTS[2] " \\# EZ: " PARTS[3] " >> /etc/csf/csf.deny "> SCRIPT
            }
         
            printf "  %\0477d "S" %15s "S" %8s "S" %-18s "S" %s\n",PARTS[1]-1000000,PARTS[2],SERVICES[PARTS[2]],substr(PARTS[3],0,18),EZ
        }
        if (!TIME) { print "csf -ra" > SCRIPT}

        print "echo Stopping httpd,imap, and exim services to force disconnects." > SCRIPT
        print "echo httpd stopping [12s timeout]..." > SCRIPT
        print "(timeout 12 /scripts/restartsrv_httpd stop &>/dev/null  || (killall -9 httpd php; echo ..FORCED))" > SCRIPT
        print "echo httpd starting in background..." > SCRIPT
        print "/scripts/restartsrv_httpd start &>/dev/null &&" > SCRIPT
        print "echo imap stopping [12s timeout]..." > SCRIPT
        print "(timeout 12 /scripts/restartsrv_imap stop &>/dev/null || (killall -9 dovecot; echo ..FORCED))" > SCRIPT
        print "echo imap starting in background..." > SCRIPT
        print "/scripts/restartsrv_imap start  &>/dev/null &&" > SCRIPT
        print "echo exim stopping [12s timeout]..." > SCRIPT
        print "(timeout 12 /scripts/restartsrv_exim stop &>/dev/null || (killall -9 exim; echo ..FORCED))" > SCRIPT
        print "echo exim starting in background..." > SCRIPT
        print "/scripts/restartsrv_exim start &>/dev/null &&" > SCRIPT
        print "echo finished" > SCRIPT

        "chmod +x "SCRIPT" 2>/dev/null"|getline
        print "\n   Block all IP Addresses in the above report by running the EZ-blocker script located here:\n \033[0;33m" SCRIPT"\033[m"
    }
'
