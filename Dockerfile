FROM ub
LABEL maintainer="seweryn.sitarski@p.lodz.pl"

RUN echo y|unminimize -y \
    && apt install -y linux-image-generic \
    && apt install -y grub-efi \
    && echo "root:serwisC4!"|chpasswd 


