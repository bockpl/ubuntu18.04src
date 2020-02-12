#!/bin/sh

PREREQ=""

prereqs() {
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

# Jezeli nie jest zdefiniowany szablon na MFS i nie jest to start z iPXE http to nic nie rob
if [ "x${IPXEHTTP}" = "x" ]; then
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

bin/bash -c ". /scripts/functions; . ./${BOCMDIR}/functions.sh; ssh_config;"
# Nadpisywanie plikow initramfs-u z katalogu konfiguracyjnego
bin/bash -c ". /scripts/functions; . ./${BOCMDIR}/functions.sh; override_initrd_scripts;"
# Tu korzystamy z juz nadpisanych skryptow i funkcji
bin/bash -c ". /scripts/functions; . ./${BOCMDIR}/functions.sh; bocm_top;"

exit 0
