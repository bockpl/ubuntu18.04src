#!/bin/sh

PREREQ=""

prereqs()
{
     echo "$PREREQ"
}
case $1 in
prereqs)
     prereqs
     exit 0
     ;;
esac

# Begin real processing below this line
. /scripts/functions

# NFS network configuration
OLD_DIR=${pwd}
cd /root/etc/network
/bin/ln -sf interfaces.nfs interfaces
cd $OLD_DIR

# Give a shell:
#/bin/sh;

exit 0
