FROM ubuntu
LABEL maintainer="seweryn.sitarski@p.lodz.pl"

RUN apt-get update \
    && apt-get -y upgrade

RUN echo y | unminimize -y \
    && apt-get install -y linux-image-generic \
    && apt-get install -y grub-efi

RUN sed -i -e 's/root:\*/root:$6$MpxiqUwV$grZXHjiqaj2YmDgoJprGSij3v62DdE5tWMrRAmzDX7Pifrt2G8IwDz91Pq7k2wsEVE1hheyVNz.K9U2ZR0POT0/g' /etc/shadow

# Zmiana domyslnych ustawien grub-a
RUN sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub

# Dodanie obslugi zfs-a
#RUN apt-get install -y zfs-initramfs

# Dodanie lvm-a i xfs-a
RUN apt-get install -y lvm2 xfsprogs

# Wylaczenie networkd do czasu przejscia na konfiguracje sieci przez netplan
RUN systemctl disable systemd-networkd \
    && systemctl mask systemd-networkd

# Dodanie standardowych pakietow
RUN apt-get install -y openssh-server vim gdisk ifenslave vlan

# Dodanie kluczy dla użytkownika root
RUN mkdir /root/.ssh
RUN chmod 700 /root/.ssh

RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4CZ7LBn7IGO5fstKVMDujZVXKv8zczCJFC5EhDqTIhweCDul3t7iK9AL2QHSxyL4KgR/PBZQdqhCp5QoQAd9ZbntAiTgXReVXUW2HB6ikZc1JnrIWz873D/FUYM6bhHLI9kDAoSjah/8tCRVjMXfzCjCg2GyBRWCbSRC7TXNXgHz9hLesc63u5ATnDXJjQ8sCNJqtMXVnheI1c0BhSH5WSippdSK674VnGStdl223ADslRX0ghXV2H6zOEvZFZMC/tMJB6ccz/WjzUeZMAjQVI1nz03E/TPOlGwWlyX1ayzuyZrkCNiuSfpqHeLIkawBxX6otCGdz0AH/jPzQqUX2m2y+6+Ub2Jh21zxB709TxnTKm02x4iGnTCzkM63mP4UHzdFNn2szeZracMZLyXmmnLQOij9uYrgdKrubn0ioygEu6GKVEjOSTgM/I+N5SHa83WuHrv/Q5SpV0NuGC7P4AZQ2km17GD8W24gx7KR4YxDjPItYOLaRPuuYeOL0z2N5teosCHHBL8Lyx8R0Omq3sarxaVRR5B3S95DkzbF7O8jq95wdawTDTGeYfKoZ3Fn6k6p12Cxvx24NLpmiB49ARQDfWg0xiwIOddc+gFfr2oMr0iTpv2bKdnUEndBaW7socZlg/Urbn2pKr0pNoZq+J+nTJyOSn4cp46zBwRcVmw== wojciech.gabryjelski@p.lodz.pl" > /root/.ssh/authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDn8ahTPc0f0oDHfjIyXJxfeULNQ0oTNirbTLv+vttAXfa8Avp/X53iX7FXyfmAcNbyHViPQN5g750muT5+zIO90YH6yYWkA3Mn9BiQSMYbyU8j1kyfoRQY97Fi1BFErWNjSw8tp33Y292u6dZmD6GuVo2kBfWsaZ8j/GQd4cfaMQ== seweryn.sitarski@p.lodz.pl" >> /root/.ssh/authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDR4Us6wC4qtVZtGgTygjqe8lt8URLgd/ZfkwyFMrOqDn9FVXDoUtXjj0YTgsZ75qo1GTUuF15jAS2TWAd3BntP2/RUpqf8WHbD/nyIr3snKBNnxKZOQ2BwpsWtfqXPMCd9Qi4vAqeJN+G4oLp28ywg9eNss2xgLLdUCf2Dg8bk/w== przemyslaw.trzeciak@p.lodz.pl" >> /root/.ssh/authorized_keys

RUN chmod 600 /root/.ssh/authorized_keys


# Czyszczenie APT-a
RUN apt-get -y autoremove
RUN apt-get clean
