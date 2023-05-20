#!/bin/bash
# by Jason Potter thecpanelguy@gmail.com
## backup-pruner :: install script
if [[ $(type -t debug) != function ]]; then
	function debug {
	    if [[ $VERBOSE == 1 ]]; then
	        echo "[DEBUG] $@"
	    fi
	}
fi 

function pruner_install {
    local U=http://backup-pruner.cpguy.com/backup-pruner.tar
    debug U = $U

    local ERR=0
    debug ERR = $ERR

    debug change to src dir...
    cd /usr/local/src/

    debug force directory to exist...
    mkdir -p /usr/local/cpguy.com/backup-pruner

    debug downloading tarball...
    wget -O backup-pruner.tar $U

    RET=$?

    if [[ $RET == 0 ]]; then
        echo download successful. 
        printf "%s" "Verifying download: "

        md5sum -c <(curl -skL $U.checksum.txt) --status
        RET=$?

        if [[ $RET == 0 ]]; then
            echo verified.
            debug  Extracting tarball...
            tar --overwrite --overwrite-dir -C / -xvf backup-pruner.tar

            #cron.d file was renamed in 1.3.2 so the old ones need to be purged
            if [[ -f /etc/cron.d/backup-pruner ]]; then
                unlink /etc/cron.d/backup-pruner
            fi
            if [[ -d /root/lw/backup-pruner ]]; then
                rm -rf /root/lw/backup-pruner
            fi
            #this is deprecated and will be remove in 1.4.x 

            echo 
            debug Creating backup-pruner log dir
            mkdir -p /usr/local/cpanel/logs/cpbackup/backup-pruner

            debug configuring cron job...
            source /usr/local/cpguy.com/backup-pruner/tools/configure-cron

        else
	        ERR=1
            debug ERR = $ERR ':: checksum failure!'
        fi

        debug cleaning src dir
        unlink backup-pruner.tar
    else
        ERR=2
        debug ERR = $ERR ':: download failed!'
    fi

    return $ERR
}

function pruner_install_main { 
    pruner_install $@ 
    local RET=$?

    if [[ $RET > 0 ]]; then
        ERRORTXT[1]='checksum failure!'
        ERRORTXT[2]='download failure!'
        echo "ERROR [$RET] ${ERRORTXT[$RET]}"
    fi    
    return $RET
}

pruner_install_main $@ 2>&1 | gawk '{print "[INSTALL]",$0}' 
