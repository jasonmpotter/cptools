#!/bin/bash
# Easy Robots.txt Manager for cPanel 
# By jpotter@liquidweb.com - https://linkedin.com/in/jasonmpotter
# This tool will crawl the cPanel userdata for all DocumentRoots on the server
# Any site that is missing a robots.txt file in their DocumentRoot will have
# a default one installed. This can be provided on the command line or saved
# to /root/robots.txt
# If a site already has a robots.txt it will be skipped.
# use the REPLACE option to interactively replace any existing robots.txt files
# use the FORCE option to auto-replace all robot.txt files that do not match
# the current default. When a robots.txt file is replaced, a backup is made
# in the same directory called robots.txt.ez_robots_bkp this can be accessed
# by the user and used to restore the file if necessary. 

function main { 
    echo "Easy Robots.txt Manager (ez_robots_manager) Version:1.0.0"
    local REPLACE=0
    local FORCE=0
    local FILE=/root/robots.txt

    if [[ -n $@ ]]; then
        for e in $@; do 
            echo $e
            if [[ $e == REPLACE ]]; then
                REPLACE=1
            elif [[ $e == FORCE ]]; then
                FORCE=1
            elif [[ -f $e ]]; then
                FILE=$e
            fi
        done    
    fi

    if [[ -f $FILE ]]; then
        md5=$(md5sum $FILE|awk '{print $1}')
        echo Default: $FILE
        echo MD5: $md5
        echo --------------------------------------
        cat $FILE
        echo --------------------------------------
    else
        echo "Error: Pleae provide a default robots.txt file or create one at /root/robots.txt"
        return
    fi

    read -p "Press any key to continue or ctrl+c to abort."
    
    printf "Finding all configured DocumentRoot directives"...

    awk -v "MD5=$md5"\
        -v "REPLACE=$REPLACE"\
        -v "FORCE=$FORCE"\
        -v "FILE=$FILE" 'BEGIN {
        }
        $NF!~/usr.local.apache.htdocs|var.html.www/ && /^documentroot:/{ 
            O[$NF]=$NF 
            printf "."
        }
        END {
            print "done.\n Processing each directory now:\n"
            N=asorti(O,OS)   
            for (I=1;I<=N;I++) {
                HOME=OS[I]
                print "DocumentRoot:", HOME
    
                X="stat --printf \"%U\"  "HOME" 2>/dev/null"
                X|getline WHO
                close(X)
                print "Username:",WHO
    
                X="ls -lah "HOME"/robots.txt 2>/dev/null"
                isFILE=""
                X|getline isFILE
                close(X)
                if (isFILE=="") {
                    printf "robots.txt: ADDING..." 
                    X="cp " FILE " " HOME "/ && chown " WHO ":" WHO " " HOME "/robots.txt"
                    X|getline x
                    close(X)
                    if (x) {
                        print "ERROR: "x
                    } else {
                        print "done."
                    }
                } else {
                    X="md5sum " HOME "/robots.txt"
                    X|getline
                    close(X)
                    if ($1==MD5) {
                        print "robots.txt: EXISTS (default)"
                    } else {
                        print "robots.txt: EXISTS ("$1")"
                        if (REPLACE) {
                            print "REPLACE ENABLED:"
                            if (!FORCE) {
                                print "Exising robots.txt:"
                                print "--------------------------------------"
                                system("cat "HOME"/robots.txt")
                                close("cat "HOME"/robots.txt")
                                print ""
                                print "--------------------------------------"
                                close(HOME"/robots.txt")
                                print "Do you want to replace the above robots.txt with the default?"
                                print "(Type YES to replace, anything else to skip.)"
                                getline answer < "-"
                            }

                            if (answer == "YES" || FORCE) {
                                printf "Backup Existing..."
                                X="cp -fp "HOME"/robots.txt{,.ez_robots_bkp}"
                                X|getline x
                                close(X)
                                print ".done"

                                printf "Replacing..."
                                X="cp -f " FILE" " HOME "/ && chown " WHO ":" WHO " " HOME "/robots.txt{,.ez_robots_bkp}"
                                X|getline x
                                close(X)
                                print ".done"
                            }
                        }
                    }
                }
                print ""
            }
        }' /var/cpanel/userdata/*/*_SSL
}
main $@
