FROM ubuntu
LABEL maintainer="seweryn.sitarski@p.lodz.pl"

RUN echo y|unminimize -y \
    && apt install -y linux-image-generic \
    && apt install -y grub-efi \
    && echo "root:serwisC4!"|chpasswd

ADD etc/bocm /etc/bocm
RUN rm -rf /etc/initramfs-tools && ln -s /etc/bocm/initramfs-tools /etc/initramfs-tools


