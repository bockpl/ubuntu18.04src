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

# Jezeli nie ma wskazanej sciezki MFS-a to nic nie rob
if [ "x${IPXEHTTP}" = 'x' ]; then
  exit 0
fi

maybe_break before_user_bottom

/bin/bash -c ". /scripts/functions; . ./${BOCMDIR}/functions.sh; bocm_bottom;"

maybe_break after_user_bottom

# Release DHCP address and flush ip from interface
# Network iterface configure after boot real system from disk
dhclient -r eth0
ip addr flush eth0
ip link set eth0 down

maybe_break end

# Obejscie w celu pozbycia sie domyslnego adresu ip przez DHCP, dodatkowo chodzi o wyczyszczenie opcji /proc/cmdline uruchomionego kernela
reboot

exit 0

