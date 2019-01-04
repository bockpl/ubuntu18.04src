FROM ubuntu
LABEL maintainer="seweryn.sitarski@p.lodz.pl"

RUN echo y|unminimize -y \
    && apt-get install -y linux-image-generic \
    && apt-get install -y grub-efi

RUN sed -i -e 's/root:\*/root:$6$MpxiqUwV$grZXHjiqaj2YmDgoJprGSij3v62DdE5tWMrRAmzDX7Pifrt2G8IwDz91Pq7k2wsEVE1hheyVNz.K9U2ZR0POT0/g' /etc/shadow

# Zmiana domyslnych ustawien grub-a
RUN sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub

#ADD etc/bocm /etc/bocm
#RUN rm -rf /etc/initramfs-tools && ln -s /etc/bocm/initramfs-tools /etc/initramfs-tools

# Dodanie obslugi zfs-a
#RUN apt-get install -y zfs-initramfs

# Dodanie lvm-a
RUN apt-get install -y lvm2

# Dodanie standardowych pakietow
RUN apt-get install -y vim gdisk xfsprogs

# Czyzczenie APT-a
RUN apt-get -y autoremove
RUN apt-get clean

# Aktualizacja initramfs na zgodny z bocm
#RUN update-initramfs -c -k all

# Aktualizacja /etc/fstab
#RUN DISK=$(mount|awk '/ \/ /{ print $1 }'); FS=$(cat /etc/bocm/volumes|awk -F : '/:\/:/{ print $4 }'); echo "$DISK	$FS	defaults	0	1" > /etc/fstab
