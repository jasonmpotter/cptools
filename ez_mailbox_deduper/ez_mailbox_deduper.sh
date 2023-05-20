#!/bin/bash
# Author: JPotter jpotter@liquidweb.com linkedin.com/in/JasonMPotter
# Version: 1.0.0
# This tool uses dovadmn to clean dupes from mdbox and maildir accounts
# simply provide the necessary email address as the command line argument
# and it will process all dovecot mailboxes for the user and clean duplicate message ids

#Quota name     Type       Value      Limit                                                          %
#Mailbox        STORAGE 20531405          -                                                          0
#Mailbox        MESSAGE     5991 2147483647                                                          0
#cPanel Account STORAGE 84321900  184320000                                                         45

EMAIL=$1
MAILBOX="INBOX.*"
echo
doveadm user $EMAIL | awk '$1~/^(mail|home|userdb_user)$/{print " Target User Info:^"$2|"tac|column -t -s^"}' &&\
(
    echo
    echo " -- Is this the correct target info and did you make a backup?"
    echo " -- Type YES to run deduplication"
    read -p " -- #> " ans
    echo
    [ $ans == "YES" ] &&\
        doveadm -f flow fetch -u $EMAIL "guid mailbox-guid uid" mailbox $MAILBOX |\
            awk -v "EMAIL=$EMAIL" '
                BEGIN { dupes=0;
                        split("",UNIQ);
                        split("",DUPES);
                        printf " Expunging Duplicates (each . is 100 msgs)\n " }
                {
                    sub(/^guid=/,"",$1)
                    sub(/^mailbox-guid=/,"",$2)
                    sub(/^uid=/,"",$3)
                    counter++
                    if(counter >= 100) {printf "."; counter=1}
                    if(UNIQ[$1]) {
                        #DUPE CODE HERE
                        x="doveadm expunge -u \047" EMAIL "\047 mailbox-guid " $2 " uid " $3 " >/dev/null"
                        system(x);close(x);
                        dupes++
                        #DUPES["mailbox-guid "$2" uid "$3]=$2" "$3
                    } else {
                        #FIRST OCCURENCE
                        UNIQ[$1]=$0
                    }
                }
                END {
                    print ""
                    printf " .Purging Expunged Messages..."
                        x="doveadm purge -u \047" EMAIL "\047";system(x);close(x);
                    print "done."
                    printf " .Recalculating Users Quota..."
                        x="doveadm quota recalc -u \047" EMAIL "\047";system(x);close(x);
                    print "done.\n"
                        x="doveadm quota get -u \047" EMAIL "\047| sed -e s/Quota\\ name/Quota_name/ -e s/cPanel\\ Account/cPanel_Account/ |column -t";
                        while(x|getline y){print "\t"y};close(x);

                    #n=asorti(DUPES,SORTED)
                    #for (i=1;i<=n;i++) {
                    #    print length(SORTED[i])
                    #}
                    print ""
                    printf " Total Processed Messages: %\047d\n",NR
                    printf " Total Duplicate Messages: %\047d\n",dupes
                    printf " Total Remaining Messages: %\047d\n",length(UNIQ)
                }
            '
)
