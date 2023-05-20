#!/bin/bash
# ez_spamid version 1.0.2
# by jpotter@liquidweb.com - http://linkedin.com/in/JasonMPotter
# This tool accept a path to a CSV file within the following format:
# out.anti-spam-premium.com,sepimuss@servidor1253.il.controladordns.com0 / 2 users locked,"6,814",7.49%
# 
# Features:
#   Parses the email address from the 3rd CSV field.
#   cleans error locked user data from email address (e.g. 0 / 2 users locked)
#   Compiles a list of unique EMAIL addresses
#   Compiles a list of unique domain names
#   Performs DNS lookups on domain names to determine NS record
#   Caches DNS Lookups so multiple email addresses from the same domain do not require additional lookups
#   Outputs the following format:
#Test Execution: ez_spamid
#Processing:.....................
#Unique Domains: 20
#unique Email Addresses: 21
#berenice.gastelum@apex-corporativo.com,apex-corporativo.com,ns3303.tl.controladordns.com
#recepcion@cecorey.com.mx,cecorey.com.mx,ns1.dnscentralmachine.com.mx
#gmorales@crh.mx,crh.mx,ns3328.tl.controladordns.com
#ventas2@esgrotextil.com,esgrotextil.com,ns1.hddpool5.net

syntax() {
    echo Syntax: 
    echo -e "    $(basename $0) /path/to/file.csv"
    echo 
    echo -e "    This tool accept a path to a CSV file with the 2nd item being an email address."
    echo -e "    item1,item2,EMAIL,item3,item4,etc..."
    echo -e "      Note: errant user data in the form of \"# / # user*\" is purged from item3."
}

process() {
    awk -F, '
        function dig(dom        ,_,exe,x,r) {
            if (!LOOKUPS[dom]) {
                exe="dig ns +short "dom
                exe|getline r
                if (!r) { r=dom }
                gsub(/[.]$/,"",r)
                LOOKUPS[dom]=gensub(/ $/,"","g",r)
            }
            return LOOKUPS[dom]
        }

        BEGIN {
            split("",LOOKUPS,"")
            printf "Processing:" 
        }

        $2~/@/{
            email=gensub(/[0-9]+[ \t]+[/][ \t]+[0-9]+[ \t]+users?.*$/,"","g",$2)
            split(email,_,/@/)
            user=_[1]; dom=_[2];
            EMAILS[dom,user]=email
            if (EMAILS_WIDTH < length(email)) { EMAILS_WIDTH=length(email) }
            if (DOMAINS_WIDTH < length(dom)) { DOMAINS_WIDTH=length(dom) }
            DOMAINS[dom]=dom
            printf "."
        }

        END {
            print ""
            DOMAINS_N=asorti(DOMAINS,_DOMAINS)
            EMAILS_N=asorti(EMAILS,_EMAILS)
            print "Unique Domains:",DOMAINS_N
            print "unique Email Addresses:",EMAILS_N
            for (i=1;i<=EMAILS_N;i++) {
                email=EMAILS[_EMAILS[i]]
                split(email,_,/@/)
                user=_[1]; dom=_[2];
                #printf "%"EMAILS_WIDTH"s | %"DOMAINS_WIDTH"s | ",email,dom
                printf "%s,%s,",email,dom
                d=dig(dom)
                print d
            }
        }
    ' $1
}

main() {
    if [[ -e $1 ]]; then
        process $1
    else
        syntax
    fi
} 
main "$@"

