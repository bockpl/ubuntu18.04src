From ubuntu:18.04
#Maintainer is deprecated 
LABEL authors="konrad.stefanski@p.lodz.pl,seweryn.sitarski@p.lodz.pl"

# W celu eliminacji bledu "debconf: unable to initialize frontend: Dialog"
ENV DEBIAN_FRONTEND noninteractive

# Aktualizacja podstawowego obrazu oraz czyszczenie
RUN set -xe \
    apt-get -y update \
    && apt-get -qy upgrade \
    && apt-get -qy autoremove \
    && apt-get -qy clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Odminimalizowanie obrazu
RUN yes | unminimize

# Naprawa  invoke-rc.d: policy-rc.d denied execution of start.
RUN printf "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d 

RUN set -xe \
    && apt-get -qy update \
    && apt-get -qy -y --no-install-recommends install apt-utils linux-image-generic grub-efi \
    && apt-get -qy autoremove \
    && apt-get -qy clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

RUN sed -i -e 's/root:\*/root:$6$MpxiqUwV$grZXHjiqaj2YmDgoJprGSij3v62DdE5tWMrRAmzDX7Pifrt2G8IwDz91Pq7k2wsEVE1hheyVNz.K9U2ZR0POT0/g' /etc/shadow

# Zmiana domyslnych ustawien grub-a
RUN sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub

# Dodanie obsługi lvm oraz xfs
RUN set -xe \
    && apt-get -qy update \
    && apt-get -qy --no-install-recommends install lvm2 xfsprogs \
    && apt-get -qy autoremove \
    && apt-get -qy clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Dodanie standardowych pakietów
# policykit-1 - obsługa nadawania hostname z dhcp
RUN set -xe \
    && apt-get -qy update \
    && apt-get -qy --no-install-recommends install openssh-server vim gdisk ifenslave vlan coreutils policykit-1 \
    && apt-get -qy autoremove \
    && apt-get -qy clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Dodanie kluczy
RUN mkdir /root/.ssh && chmod 0700 /root/.ssh
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4CZ7LBn7IGO5fstKVMDujZVXKv8zczCJFC5EhDqTIhweCDul3t7iK9AL2QHSxyL4KgR/PBZQdqhCp5QoQAd9ZbntAiTgXReVXUW2HB6ikZc1JnrIWz873D/FUYM6bhHLI9kDAoSjah/8tCRVjMXfzCjCg2GyBRWCbSRC7TXNXgHz9hLesc63u5ATnDXJjQ8sCNJqtMXVnheI1c0BhSH5WSippdSK674VnGStdl223ADslRX0ghXV2H6zOEvZFZMC/tMJB6ccz/WjzUeZMAjQVI1nz03E/TPOlGwWlyX1ayzuyZrkCNiuSfpqHeLIkawBxX6otCGdz0AH/jPzQqUX2m2y+6+Ub2Jh21zxB709TxnTKm02x4iGnTCzkM63mP4UHzdFNn2szeZracMZLyXmmnLQOij9uYrgdKrubn0ioygEu6GKVEjOSTgM/I+N5SHa83WuHrv/Q5SpV0NuGC7P4AZQ2km17GD8W24gx7KR4YxDjPItYOLaRPuuYeOL0z2N5teosCHHBL8Lyx8R0Omq3sarxaVRR5B3S95DkzbF7O8jq95wdawTDTGeYfKoZ3Fn6k6p12Cxvx24NLpmiB49ARQDfWg0xiwIOddc+gFfr2oMr0iTpv2bKdnUEndBaW7socZlg/Urbn2pKr0pNoZq+J+nTJyOSn4cp46zBwRcVmw== wojciech.gabryjelski@p.lodz.pl" > /root/.ssh/authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDn8ahTPc0f0oDHfjIyXJxfeULNQ0oTNirbTLv+vttAXfa8Avp/X53iX7FXyfmAcNbyHViPQN5g750muT5+zIO90YH6yYWkA3Mn9BiQSMYbyU8j1kyfoRQY97Fi1BFErWNjSw8tp33Y292u6dZmD6GuVo2kBfWsaZ8j/GQd4cfaMQ== seweryn.sitarski@p.lodz.pl" >> /root/.ssh/authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDR4Us6wC4qtVZtGgTygjqe8lt8URLgd/ZfkwyFMrOqDn9FVXDoUtXjj0YTgsZ75qo1GTUuF15jAS2TWAd3BntP2/RUpqf8WHbD/nyIr3snKBNnxKZOQ2BwpsWtfqXPMCd9Qi4vAqeJN+G4oLp28ywg9eNss2xgLLdUCf2Dg8bk/w== przemyslaw.trzeciak@p.lodz.pl" >> /root/.ssh/authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDiJPwrc06LOzguNB73UwsJ7oH/VxpusqAYuXmH3zsEaxzUDQ1SRlafRHRzcmACkRaZpcS3qZxArds3q09TC8SduKOrJIbCshWX86h7p6hMEDeljCAH5rHB2ydzvFUaqv85gueFipRm/x16YKOktkUO86P4VLqFIhKC6C8pejhzaQ== konrad.stefanski@p.lodz.pl" >> /root/.ssh/authorized_keys

RUN chmod 0600 /root/.ssh/authorized_keys

# Docker engine
RUN set -xe \
    && apt-get -qy update \
    && apt-get -qy --no-install-recommends install docker.io \
    && apt-get -qy autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Docker compose
# niezbędny jest curl
RUN set -xe \
    && apt-get update \
    && apt-get -qy --no-install-recommends install curl jq \
    && apt-get -qy autoremove \
    && apt-get -qy clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# docker-compose w najnowszej wersji
RUN VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r) \
    && sudo curl -L "https://github.com/docker/compose/releases/download/$(echo $VERSION)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \ 
    && chmod +x /usr/local/bin/docker-compose

# Playbooki

ADD ansible /ansible

RUN set -xe \
    && apt-get -yq update \
    && apt-get install -y --no-install-recommends ansible \
    && ansible-playbook /ansible/Playbooks/monitoring.yml --connection=local --extra-vars "var_host=127.0.0.1" \
    && ansible-playbook /ansible/Playbooks/install_tools.yml --connection=local --extra-vars "var_host=127.0.0.1" \
    && ansible-playbook /ansible/Playbooks/grubTimeout.yml --connection=local --extra-vars "var_host=127.0.0.1" \
    && ansible-playbook /ansible/Playbooks/MFSClient.yml --connection=local --extra-vars "var_host=127.0.0.1" \
    && ansible-playbook /ansible/Playbooks/clean.yml --connection=local --extra-vars "var_host=127.0.0.1" \
    && apt-get purge -y ansible \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /ansible \
    && rm -rf /tmp/*

# Dodanie rc.local
ADD CONFIGS/etc/rc.local /etc/rc.local

# Dodanie konfiguracji postawowych usług
ADD CONFIGS/etc/fstab /etc/fstab
ADD CONFIGS/etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf
ADD CONFIGS/etc/ssmtp /etc/ssmtp
ADD CONFIGS/etc/netplan/ /etc/netplan
ADD CONFIGS/etc/systemd/system/multi-user.target.wants/docker.service /etc/systemd/system/multi-user.target.wants/docker.service
ADD CONFIGS/etc/docker/daemon.json /etc/docker/daemon.json
ADD CONFIGS/etc/monit /etc/monit
ADD CONFIGS/etc/zabbix /etc/zabbix
ADD CONFIGS/etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf
ADD CONFIGS/usr/local/sbin/ps_mem.py /usr/local/sbin/ps_mem.py
ADD CONFIGS/usr/local/sbin/process_dump_m /usr/local/sbin/process_dump_m
ADD CONFIGS/etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf

# Naprawa uprawnień dla monit-a
RUN chmod 600 /etc/monit/monitrc
RUN chmod 600 /etc/monit/monit.pem
RUN chmod 600 /etc/monit/monitrc_distribution

# Konfiguraja strefy czasowej
RUN set -xe \
    && apt-get -yq update \
    && apt-get -yq install tzdata \
    && apt-get -yq autoremove \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*
ENV TZ="Europe/Warsaw"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata

# Konfiguracja lokalnego initramfs-a
# Wylaczenie funkcji suspend systemu
RUN printf "# Disable resume (this system has no swap)\nRESUME=none\n" > /etc/initramfs-tools/conf.d/resume

# Dodanie wersji
ADD VERSION /VERSION
