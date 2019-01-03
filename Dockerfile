FROM ubuntu
LABEL maintainer="seweryn.sitarski@p.lodz.pl"

RUN echo y|unminimize -y \
    && apt install -y linux-image-generic \
    && apt install -y grub-efi

RUN sed -i -e 's/root:\*/root:$6$MpxiqUwV$grZXHjiqaj2YmDgoJprGSij3v62DdE5tWMrRAmzDX7Pifrt2G8IwDz91Pq7k2wsEVE1hheyVNz.K9U2ZR0POT0/g' /etc/shadow

ADD etc/bocm /etc/bocm
RUN rm -rf /etc/initramfs-tools && ln -s /etc/bocm/initramfs-tools /etc/initramfs-tools

# Aktualizacja initramfs na zgodny z bocm
RUN update-initramfs -c -k all

# Aktualizacja /etc/fstab
#RUN DISK=$(mount|awk '/ \/ /{ print $1 }'); FS=$(cat /etc/bocm/volumes|awk -F : '/:\/:/{ print $4 }'); echo "$DISK	$FS	defaults	0	1" > /etc/fstab
