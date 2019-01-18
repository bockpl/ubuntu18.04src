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
. /scripts/custom_functions

# Jezeli nie ma wskazanej sciezki MFS-a to nic nie rob
if [ "${MFSUPPER}x" = 'x' ] && [ "x${IPXEHTTP}" = 'x' ]; then
  exit 0
fi

maybe_break before_user_bottom

if [ -e ${ROOTSTANDARD}/${BOCMDIR}/functions.sh ]; then
	/bin/bash -c ". /scripts/functions; . /scripts/custom_functions; . ${ROOTSTANDARD}/${BOCMDIR}/functions.sh; bocm_bottom;"
else
	/bin/bash -c ". /scripts/functions; . /scripts/custom_functions; . ./${BOCMDIR}/functions.sh; bocm_bottom;"
fi

maybe_break after_user_bottom

# Nadpisanie funkcji ktore mogly byc wczesniej nadpisane przez functions.sh
. /scripts/custom_functions

if [ "${MFSUPPER}x" != 'x' ]; then
	umount_rootstandard || panic "Error unmouting rootstandard!"

	log_begin_msg "Unconfiguring mfs networking"
	unconfigure_mfs_network $MFSINT
	log_end_msg
fi

# Release DHCP address and flush ip from interface
# Network iterface configure after boot real system from disk
#dhclient -r eth0
ip addr flush eth0
ip link set eth0 down

maybe_break end

exit 0

