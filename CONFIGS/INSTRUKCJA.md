# INSTRUKCJA

TL;DR;

Pliki konfiguracyjne pobieramy z tego repozytorium z katalogu CONFIGS. To w nim znajdują się pliki, które należy przegrać do katalogu hosta. 

## WYMAGANIA WSTĘPNE

- administrator uruchamianej maszyny musi mieć dostęp do katalogów konfiguracyjnych znajdujacych się na MFS
    Logowanie `ssh root@192.168.8.144` lub podmontowanie udziału MFS lokalnie
    Katalogi z konfiguracjami `cd /srv/TEMPLATES/CONFIGS`
- uruchamiana maszyna (fizyczna lub wirtualna) musi mieć ustawione bootowanie z efi (nie BIOS)
    Ustawi to administrator maszyn fizycznych lub administartor usługi DMW dla wirtualek.
- musi istnieć wpis w DHCP z MAC adresem przyznanej maszyny
    Wpisy w DHCP realizuje administrator DMW
- administrator uruchamianej maszyny musi zapisać wymagane dane w pliku `/etc/first_boot`
    Szczegóły w pliku `/etc/first_boot`
- upewnić się że maszyna będzie miała dostęp do zabixx serwera

## PRZYGOTOWANIE KATALOGU KONFIGURACYJNEGO - WERSJA MINIMALNA

### W tym przypadku wykorzystujemy niezbędne minimum oraz opieramy się na defaltsach (wielkość oraz ilość lvm, itp)

Zaloguj się na maszynę z konfiguiracjami
`ssh root@192.168.8.144` lub podmontuj udział MFS lokalnie.
Skopiuj z katalogu CONFIG z repozytorium (tego repozytorium) na zdalny udział pliki

`cp -a CONFIGS/etc/first_boot MOJHOSTNAME/etc/first_boot`
`cp -a CONFIGS/boot.ipxe MOJHOSTNAME/boot.ipxe`

Dokonaj konfiguracji w pliku `first_boot` zgodnie z informacjami tam zawartymi
`vi MOJHOSTNAME/etc/first_boot`

PRZEJDŹ DO URUCHOMIENIE MASZYNY

## PRZYGOTOWANIE KATALOGU KONFIGURACYJNEGO - WERSJA DLA PEŁNEJ KONTROLI

### W tym przypadku po zgraniu plików i katalogów możesz dokonać zmian tam gdzie uważasz za słuszne.

Zaloguj się na maszynę z konfiguiracjami 
`ssh root@192.168.8.144` lub podmontuj udział MFS lokalnie.
Skopiuj katalog CONFIG z repozytorium (tego repozytorium) na zdalny udział

`cp -a CONFIGS MOJHOSTNAME`

MOJHOSTNAME - to katalog na maszynie 192.168.8.144:/srv/TEMPLATES/CONFIGS/MOJHOSTNAME

gdzie MOJHOSTNAME to nazwa katalogu która jest zbierzna z hostname uzyskanym od administratora serwera DHCP/iPXE

Dokonaj konfiguracji w pliku `first_boot` zgodnie z informacjami tam zawartymi
`vi MOJHOSTNAME/etc/first_boot`

## URUCHONMIENIE MASZYNY

Z menu boot uefi wybrać "UEFI Netowrk BOOT" lub podobnie

Przy pierwszym uruchonieniu należy wybrać pozycję DiskInfo aby uzyskać informację nt. dysków zainstalowanych w systemie. Z listy należy przepisać wybrany dysk (pierwsza kolumna - PATH) i wpisać do pliku partitions.yaml w polu `DISKDEV=`. Plik partistions.yaml znajduje się w MOJHOSTNAME/initrd.conf/etc/bocm/partitions.yaml

Po poprawnym uruchomieniu otrzymasz mail z informacjami.


## Zmiany w układzie partycji

Aby zmienić rozmiary lv należy zmienić konfigurację w pliku `partitions.yaml` zgodnie z wytycznymi tam zawartymi.
Plik znajduje się w `MOJHOSTNAME/initrd.conf/etc/bocm/partitions.yaml`

Po dodaniu lub usunięciu lv należy uwzględnić tę zmianę w pliku `fstab`. Jego położenie to `MOJHOSTNAME/etc/fstab`

## KONFIGURACJA SIECI

Domyślna konfiguracja jest dla jednego iface pobierającego IP z dhcp.
Konfiguracji dokonujemy w pliku `MOJHOSTNAME/etc/netplan/config.yaml`


## JESTEM SUPER ADMINEM I SAM SOBIE PORADZĘ

Zamiast kopiować cały katalog `HOST_TEMPLATE` musisz skopiować tylko:
boot.ipxe
initrd.conf/etc/bocm/default
etc/resolv.conf (link)
etc/dhcp (katalog z zawartością)
etc/docker (katalog z zawartością)
etc/systemd (katalog z zawartością)

Jest to niezbędne minium aby bootowany obraz mógł poprawnie działać.
Resztę należy skonfigurować wg uznania.
