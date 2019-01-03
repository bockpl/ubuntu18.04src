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

# Jezeli nie jest zdefiniowany szablon na MFS to nic nie rob
if [ "x${MFSUPPER}" = "x" ]; then
  exit 0
fi

# from /usr/share/initramfs-tools/scripts/nfs
#	modprobe nfs
	# For DHCP
	modprobe af_packet

	#wait_for_udev 10
	udevadm settle

maybe_break before_net_config

log_begin_msg "Configuring networking"
	configure_networking
# Now we have in /tmp/net-eth0.conf:
# DEVICE=eth0; IPV4ADDR=192.168.0.2; IPV4BROADCAST=192.168.0.255;IPV4NETMASK=255.255.255.0;IPV4GATEWAY=192.168.0.1;IPV4DNS0;IPV4DNS1;HOSTNAME=n02.rostclust;DNSDOMAIN;NISDOMAIN(unset);filename="/cluster_node/pxelinux.0"
log_end_msg

maybe_break after_net_config
maybe_break before_mfsnet_config

if [ "x${MFSMANUALNET}" = "x" ]; then
	log_begin_msg "Configuring mfs networking"
	if [ -n $MFSINT ]; then 
          configure_mfs_network $MFSINT
	fi
	log_end_msg
else
	log_begin_msg "Configuring lo interface"
        ip link set lo up
	log_end_msg
	panic "Please configure mfs networking manually"
fi

maybe_break after_mfsnet_config
maybe_break before_mount_rootstandard

log_begin_msg "Mounting template from mfs as rootstandard"
	mount_rootstandard
log_end_msg

maybe_break after_mount_rootstandard

if [ ${readonly} = y ]; then
	roflag="ro"
else
	roflag="rw"
fi

mount -o remount,${roflag} "${ROOTSTANDARD}"

ln -s "${ROOTSTANDARD}"/bin/bash /bin/bash

if ( mount|grep ${ROOTSTANDARD} > /dev/null ); then

  bin/bash -c ". /scripts/functions; . /scripts/custom_functions; . ${ROOTSTANDARD}/${BOCMDIR}/functions.sh; bocm_top;"
fi

exit 0
