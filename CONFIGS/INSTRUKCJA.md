# INSTRUKCJA

TL;DR;

Katalog HOST_TEMPLATE zawiera wszystkie niezbędne pliki aby uruchomić host z sieci (iPXE).

## WYMAGANIA WSTĘPNE

- administrator uruchamianej maszyny musi mieć dostęp do katalogów konfiguracyjnych znajdujacych się na MFS
    Logowanie `ssh root@192.168.8.144`
    Katalogi z konfiguracjami `cd /srv/TEMPLATES/CONFIGS`
- uruchamiana maszyna (fizyczna lub wirtualna) musi mieć ustawione bootowanie z efi (nie BIOS)
    Ustawi to administrator maszyn fizycznych lub administartor usługi DMW dla wirtualek.
- musi istnieć wpis w DHCP z MAC adresem przyznanej maszyny
    Wpisy w DHCP realizuje administrator DMW
- administrator uruchamianej maszyny musi zapisać wymagane dane w pliku `/etc/first_boot`
    Szczegóły w pliku `/etc/first_boot`
- upewnić się że maszyna będzie miała dostęp do zabixx serwera

## PRZYGOTOWANIE KATALOGU KONFIGURACYJNEGO

Zaloguj się na maszynę z konfiguiracjami 
`ssh root@192.168.8.144`
Skopiuj katalog HOST_TEMPLATE
`cd /srv/TEMPLATES/CONFIGS`
`cp -a HOST_TEMPLATE MOJHOSTNAME`
gdzie MOJHOSTNAME to nazwa katalogu która jest zbierzna z hostname uzyskanym od administratora serwera DHCP/iPXE
Dokonaj konfiguracji w pliku `first_boot` zgodnie z informacjami tam zawartymi
`vi MOJHOSTNAME/etc/first_boot`

## URUCHONMIENIE MASZYNY

Z menu boot uefi wybrać "UEFI Netowrk BOOT" lub podobnie

Po poprawnym uruchomieniu otrzymasz mail z informacjami.


## Zmiany w układzie partycji

Aby zmienić rozmiary lv należy zmienić konfigurację w pliku `partitions.yaml` zgodnie z wytycznymi tam zawartymi.
Plik znajduje się w `MOJHOSTNAME/initrd.conf/etc/bocm/partitions.yaml`

Po dodaniu lub usunięciu lv należy uwzględnić tę zmianę w pliku `fstab`. Jego położenie to `MOJHOSTNAME/etc/fstab`

## W maszynie jest dysk typu NVME

Musisz zmienić oznaczenie dysku w systemie. Miejsce docelowe pliku jest w tym amym katalogu co plik partitions.yml
Utwórz plik defaults z zawartością
    #Root disk device:
    export DISKDEV="/dev/sda"

    #Root volume group
    export VG_NAME=vgroot

    #File with default volumes
    export VOLUMES_FILE=${BOCMDIR}/partitions.yml

    #Manual disk menagement
    export MANUAL_DISK_MANAGE="no"

    export SGDISK=/sbin/sgdisk`

Podmień `/dev/sda` na właściwe urządzenie blokowe



## KONFIGURACJA SIECI

Domyślna konfiguracja jest dla jednego iface pobierającego IP z dhcp.
Konfiguracji dokonujemy w pliku `MOJHOSTNAME/etc/netplan/config.yaml`


## JESTEM SUPER ADMINEM I SAM SOBIE PORADZĘ

Zamiast kopiować cały katalog `HOST_TEMPLATE` musisz skopiować tylko:
boot.ipxe
etc/resolv.conf (link)
etc/dhcp (katalog z zawartością)
etc/docker (katalog z zawartością)
etc/systemd (katalog z zawartością)

Jest to niezbędne minium aby bootowany obraz mógł poprawnie działać.
Resztę należy skonfigurować wg uznania.
