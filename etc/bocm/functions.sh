#!/bin/bash

if [[ $0 =~ ^.*functions.sh$ ]]; then
  cat <<EOF
Lista funkcji:
  cleanDisk
  makeStdPartition
  makeVolumes
  mountAll
  umountAll
  change_kernelparams
  ssh_config
  override_initrd_scripts
  bocm_top (in initramfs only)
  bocm_bottom (in initramfs only)
  make_network_config_file (in initramfs only)
EOF
  exit
fi

# For syntax check:
#set -n;
# For debug:
#set -x;

# Load default, then allow override.
HOSTNAME="$(hostname)"


source ${BOCMDIR}/default

# Funkcja zastępuje polecenie by dodac w kazdym wypadku parametr
# --config "global { use_lvmetad = 0 }"
lvm() {
  # Jezeli initramfs
  if [ "x$init" != "x" ]; then
    sed -i -e 's/use_lvmetad = 1/use_lvmetad =0/g' /etc/lvm/lvm.conf
    RESULT=$(/sbin/lvm "$@" --config "global { use_lvmetad = 0 }")
  else
    RESULT=$(/sbin/lvm "$@")
  fi
  echo -e "$RESULT"
}

# Funkcja uruchamiania polecen zewnętrzych
_run() {
  local _result="OK"
  local _retcode=0

  if [ "x${DEBUG}" = "xsym" ]; then
    echo "$@" >&2
    echo -en ${_result}
    return 0
  else
    _result=$(eval "$@" 2>&1)
    _retcode=$?
  fi

  if [ ${_retcode} != 0 ]; then
    if [ "x${MFSUPPER}" = 'x' ]; then
      _result="Error in command: $* \n  ${_result} \n  Exit status: ${_retcode} \n "
    else
      panic "Error in command: $* \n  ${_result} \n  Exit status: ${_retcode} \n "
    fi
  else
    _result="OK"
  fi
  printf ${_result}
  return ${_retcode}
}

# Funkcja zwraca wielkosc pamieci RAM w GB (np. 4)
_getMemorySize() {
  local RESULT="0"
  RESULT=$(awk '/MemTotal/{printf("%.2f\n", $2 / 1024)}' </proc/meminfo)
  echo -e "$RESULT"
}

# Funkcja zwraca ilosc dostepnych do zagospodarowania dyskow
_getDiskCount() {
  local RESULT="0"
  RESULT=$(find /dev -name "sd?" | wc -l)

  echo -e "$RESULT"
}

# !!!!! ***** Do poprawy, kasuje lv i pv mirrorowane!
#
# Czyszczenie dysku, wymazuje wszystko bez pytania
# Parametry:
#   devDisk - sciezka urzadzenia blokowego dysku
# Wynik:
#   OK - jesli wszystko przebieglo pomyslnie
#   Komunikat bledu - w przypadku wystapienia dowolnego bledu
cleanDisk() {
  local _result="OK"
  local devDisk=$1

   local vgs=""
   local lvs=""
   local pvs=""

  # Ustalamy czy sa PV i VG
  vgs=$(lvm pvs --noheadings -o vg_name -S pv_name=~"$devDisk.*")
  for vg in $vgs; do
    _result=$(_run "lvm vgchange -a n \"${vg}\"") || break
    pvs=$(lvm pvs --noheadings -o pv_name -S vg_name="${vg}"|grep ${devDisk} |  awk '{ print $1 }')
    _result=$(_run "lvm pvremove -y -ff ${pvs}") || break
    _result=$(_run "vgreduce --removemissing --force \"${vg}\"") || break
    _result=$(_run "lvm vgchange -a y -P \"${vg}\"") || break
  done
  _result=$(_run "sgdisk -Z $devDisk")
  printf "${_result}"
}

_unsetArrays() {
  unset partition__number
  unset partition__name
  unset partition__type
  unset partition__fstype
  unset partition__mnt
  unset partition__mntopt
  unset partition__size
  unset volume__part
  unset volume__name
  unset volume__dev
  unset volume__fstype
  unset volume__size
  unset volume__mnt
  unset volume__mntopt
  unset volume__raid
}

# Tworzenie standardowego schematu podzialu dysku na partycje
# Parametry:
#   devDisk - sciezka urzadzenia blokowego dysku
#   partFile - sciezka do pliku z opisem partycji
# Wynieki:
#   OK - jesli wszystko przebieglo pomyslnie
#   Komunikat bledu - w przypadku wystapienia dowolnego bledu
makeStdPartition() {
  local _result="OK"
  local _devdisk=$1
  local _partfile=$2

  local _SGDISK=/sbin/sgdisk
  local _SEC_SIZE=$(cat /sys/block/${_devdisk#/dev}/queue/physical_block_size || echo 4096)

  if [ "x${_partfile}" != 'x' ] && [ -f ${_partfile} ]; then
    source ${BOCMDIR}/bash-yaml/script/yaml.sh

    create_variables "${_partfile}"

    for ((p = 0; p < ${#partition__number[@]}; p++)); do
      _result=$(_run "${_SGDISK} -n ${partition__number[$p]}::+${partition__size[$p]} ${_devdisk} -t ${partition__number[$p]}:${partition__type[$p]} -c ${partition__number[$p]}:${partition__name[$p]}") || break      
      
      case ${partition__fstype[$p]} in
      "vfat") _result=$(_run "/sbin/mkfs.vfat -F 32 ${_devdisk}${partition__number[$p]}") ;;
      *) if [ "x${partition__type[$p]}" != 'x8e00' ]; then
        _result=$(_run "/sbin/mkfs.xfs -s size=${_SEC_SIZE} -f -L ${partition__name[$p]} ${_devdisk}${partition__number[$p]}")
      fi
      esac
      if [ $? != 0 ]; then
        printf ${_result}
        return 1
      fi
    done
  fi
  _unsetArrays
  printf "${_result}"
  return 0
}

# Tworzenie standardowego schematu podzialu na wolumeny
# Parametry:
#   disk - sciezka urzadzenia blokowego dysku
#   volFile - sciezka do pliku opisu wolumenow
# Wynieki:
#   return_code = 0 - jesli wszystko przebieglo pomyslnie
#   return_code = 1 - w przypadku wystapienia dowolnego bledu, wyswietlany jest tez komunikat
makeVolumes() {
  local _result="ENTER"
  local _disk=$1
  local _volFile=$2
  local _vgname=""
  local _lvname=""
  local _makeFS=false

  local _SGDISK=/sbin/sgdisk
  local _SEC_SIZE=$(cat /sys/block/${_disk#/dev}/queue/physical_block_size || echo 4096)
  local _SCSIchan=$(ls "/sys/block/${_disk#/dev}/device/scsi_device" | awk '{gsub(":","", $1); print}')

  if [ "x${_volFile}" != 'x' ] && [ -f ${_volFile} ]; then
    source ${BOCMDIR}/bash-yaml/script/yaml.sh

    create_variables "${_volFile}"

    # Tworzenie PV i VG
    for ((v = 0; v < ${#volume__part[@]}; v++)); do
      # Jezeli nie istnieje PV to utworz
      local npv=""
      npv=$(lvm pvs --noheadings -o pv_name -S pv_name="${_disk}${volume__part[$v]}" | awk '{ print $1 }')
      if [ "x$npv" != "x${_disk}${volume__part[$v]}" ]; then
        _result=$(_run "lvm pvcreate ${_disk}${volume__part[$v]}")
        if [ $? != 0 ]; then
          break
        fi
      fi

      # Parsowanie vgname z nazwy wolumenu zmienna volume_dev np mapper/vgroot-lvroot
      _vgname=${volume__dev[$v]%%-*}
      _vgname=${_vgname##mapper/} 

      # Tworzenie VG
      # Jezeli istnieje VG o podanej nazwie to dodaj PV
      # Jezeli nie istnieje VG o podanej nazwie to utworz i dodaj PV
      local nvg=""
      nvg=$(lvm vgs --noheadings -o vg_name -S vg_name=${_vgname} | awk '{ print $1 }')
      if [[ "x$nvg" == "x${_vgname}" ]]; then
        # Jezeli w VG nie ma PV to dodaj
        local npvinvg=""
        npvinvg=$(lvm vgs --noheadings -o pv_name -S vg_name=${_disk},pv_name="${_disk}${volume__part[$v]}"  | awk '{ print $1 }')
        if [[ "x$npvinvg" != "x${_disk}${volume__part[$v]}" ]]; then
          _result=$(_run "lvm vgextend ${_vgname} ${_disk}${volume__part[$v]}")
          if [ $? != 0 ]; then
            break
          fi
        fi
      else
        _result=$(_run "lvm vgcreate -y ${_vgname} ${_disk}${volume__part[$v]}")
        if [ $? != 0 ]; then
          break
        fi  
      fi
    done

    # Tworzenie LV
    if [ ${_result} == "OK" ]; then
      for ((v = 0; v < ${#volume__part[@]}; v++)); do
        # Parsowanie vgname i lvname z nazwy wolumenu zmienna volume_dev np mapper/vgroot-lvroot
        _lvname=${volume__dev[$v]##*-}
        _vgname=${volume__dev[$v]%%-*}
        _vgname=${_vgname##mapper/}

        if [ "x${volume__name[$v]}" == "xSWAP" ]; then
          if [ ${volume__size[$v]} == "0" ]; then
            volume__size[$v]=$(echo "$(_getMemorySize) $(_getDiskCount)" | awk '{printf("%.2f\n", 2*$1/$2)}')
          fi
        else
          if [ ${volume__size[$v]} == "0" ]; then
            # Jezeli to ostatni wolumen
            if [ $v = $(expr ${#volume__part[@]} - 1) ]; then
              volume__size[$v]="99%PVS"
              _lvname="${_lvname}_${_SCSIchan}"
            else
              _result="Error: Volume size \"0\" is only valid for last volume"
              break
            fi
            _result=$(_run "lvm lvcreate -y -n ${_lvname} -l ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")
            if [ "$?" != 0 ]; then
              break
            fi
          fi
        fi

        if [ "x${volume__raid[$v]}" == "xraid1" ]; then
          # Jezeli istnieje juz LV o podanej nazwie i nie znajduje sie na przetwarzanym PV
          local nlv=$(lvm lvs --noheadings -o lv_name -S lv_name="$_lvname" | awk '{ print $1 }')
          local devlv=$(lvm lvs --noheadings -o devices -S lv_name="$_lvname" | awk '{ print $1 }' | grep "${_disk}${volume__part[$v]}")
          if [[ "x${nlv}" = "x${_lvname}" && "x${devlv}" = "x" ]]; then
            # Liczba kopii mirror-a
            local stripes=$(lvm lvs --noheadings -o stripes -S lv_name="$_lvname" | awk '{ print $1 }')
            printf "Converting logical volume ${_lvname} to mirror...\n"
            #_result=$(_run "lvm lvconvert -y -m${stripes} --type mirror --mirrorlog core -i 3 /dev/${volume__dev[$v]}")
            _result=$(_run "lvm lvconvert -y -m${stripes} --alloc anywhere /dev/${volume__dev[$v]}")
            _result=$(_run "lvm lvchange -ay /dev/${volume__dev[$v]}")
            local syncP=0
            until [ $syncP = "100" ]; do
              printf "\r"
              syncP=$(lvm lvs --noheadings -o sync_percent -S lv_name="${_lvname}" | awk '{ printf "%d\n", $1 }')
              printf " Waitng for ${_lvname} mirror syncing: ${syncP}%%"
              sleep 1
            done
            printf "\ndone\n"
          else
            # Jezeli nie istnieje LV o podanej nazwie
            printf "Creating logical volume ${_lvname}..."
            # Jezeli wielkowsc okreslona procentowo
            if [ $(expr index ${volume__size[$v]} %) != "0" ]; then
              _result=$(_run "lvm lvcreate -y -n ${_lvname} -l ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")     
            else
              _result=$(_run "lvm lvcreate -y -n ${_lvname} -L ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")
            fi
            if [ "$?" != 0 ]; then
              break
            fi
            _makeFS="true"
            printf "done\n"
          fi
        fi #raid=raid1

        if [ "x${volume__raid[$v]}" == "xn" ]; then
          # Jezeli wolumen o podanej nazwie juz istnieje, nic nie rob
          if [ "x$(lvm lvs --noheadings -o lv_name -S lv_name=${_lvname}| awk '{print $1}')" == "x${_lvname}" ]; then
            continue
          fi
          printf "Creating logical volume ${_lvname}..."
          _result=$(_run "lvm lvcreate -y -n ${_lvname} -L ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")
          if [ "$?" != 0 ]; then
            break
          fi
          _makeFS="true"
          printf "done\n"
        else
          _result="Error: Bad value for \"raid\" field for volume ${volume__dev[$v]}"
          if [ "$?" != 0 ]; then
            break
          fi
        fi #raid=n

        if ${_makeFS}; then
          case ${volume__fstype[$v]} in
            "vfat") _result=$(_run "/sbin/mkfs.vfat -F 32 /dev/${volume__dev[$v]}") ;;
            "xfs") 
              # Parsowanie lvname z nazwy wolumenu zmienna volume_dev np mapper/vgroot-lvroot
              _lvname=${volume__dev[$v]##*-}
              _result=$(_run "/sbin/mkfs.xfs -s size=${_SEC_SIZE} -f -L ${_lvname} /dev/${volume__dev[$v]}")
              ;;
          esac
        fi
      done
    fi # Tworzenie LV
  else
    _result="Error: Volumes file not exist! - ${_volFile}"
  fi

  _unsetArrays
  if [ "${_result}" == "OK" ]; then
    return 0
  else
    echo -ne "${_result}"
    return 1
  fi
}

# Montowanie wszystki systemow plikow do partycji root
# Paramtry:
#   dev - sciezka do dysku np. /dev/sda
#   rootmnt - sciezka montowania rootfs np. /rootmnt
#   volFile - sciezka do pliku z opisem wolumenow
# Wyniki:
#   OK - jezeli wszystko OK, ret code <> 0
#   Komunikat bledu - w przypadku niepowodzenia, ret code = 0
mountAll() {
  local _dev=$1
  local _rootmnt=$2
  local _volFile=$3
  local _result="OK"

  if [ "x${_volFile}" != 'x' ] && [ -f ${_volFile} ]; then
    source ${BOCMDIR}/bash-yaml/script/yaml.sh

    create_variables "${_volFile}"
    # Montowanie partycji
    log_begin_msg "Mounting all partitions ${_dev}"
    for ((p = 0; p < ${#partition__number[@]}; p++)); do
      if [[ "x${partition__mnt[$p]}" != "x" && "x${partition__mnt[$p]}" != "x/" && "x${partition__mnt[$p]}" != "x\"\"" ]]; then
        _result=$(_run "mkdir -p ${_rootmnt}${partition__mnt[$p]}") || break

        if [[ "x${partition__mntopt[$p]}" != "x" && "x${partition__mntopt[$p]}" != "x\"\"" ]]; then
          _result=$(_run "mount -o ${partition__mntopt[$p]} ${_dev}${partition__number[$p]} ${_rootmnt}${partition__mnt[$p]}")
        else
          _result=$(_run "mount ${_dev}${partition__number[$p]} ${_rootmnt}${partition__mnt[$p]}")
        fi
        if [ ${_result} != "OK" ]; then
          printf "Error mounting partition ${_dev}${partition__number[$p]}! ${_result}"
        fi
      fi
    done
    log_end_msg
    # Montowanie wolumenow LVM
    log_begin_msg "Mounting all volumes"
    for ((v = 0; v < ${#volume__part[@]}; v++)); do
      if [[ "x${volume__mnt[$v]}" != "x" && "x${volume__mnt[$v]}" != "x/" && "x${volume__mnt[$v]}" != "x\"\"" ]]; then
        _result=$(_run "mkdir -p ${_rootmnt}${volume__mnt[$v]}") || break
        if [[ "x${volume__mntopt[$v]}" != "x" && "x${volume__mntopt[$v]}" != "x\"\"" ]]; then
          _result=$(_run "mount -o ${volume__mntopt[$v]} /dev/${volume__dev[$v]} ${_rootmnt}${volume__mnt[$v]}")
        else
          _result=$(_run "mount /dev/${volume__dev[$v]} ${_rootmnt}${volume__mnt[$v]}")
        fi
        if [ ${_result} != "OK" ]; then
          printf "Error mounting volume dev/${volume__dev[$v]}! ${_result}"
        fi
      fi
    done
    log_end_msg
  else
    _result="Error: Volumes file not exist! - ${_volFile}\n"
  fi

  _unsetArrays
  printf ${_result}
  if [ _result == "OK" ]; then
    return 0
  else
    return 1
  fi
}

# Odmontowanie wszystki systemow plikow do partycji root
# Paramtry:
#   rootmnt - sciezka montowania rootfs np. /rootmnt
#   volFile - sciezka do pliku z opisem wolumenow
# Wyniki:
#   OK - jezeli wszystko OK, ret code <> 0
#   Komunikat bledu - w przypadku niepowodzenia, ret code = 0
umountAll() {
  local _rootmnt=$1
  local _volFile=$2
  local _result="OK"

  if [ "x${_volFile}" != 'x' ] && [ -f ${_volFile} ]; then
    source ${BOCMDIR}/bash-yaml/script/yaml.sh

    create_variables "${_volFile}"

    # Odmontowanie wolumenow LVM
    log_begin_msg "Mounting all volumes"
    for ((v = $(expr ${#volume__part[@]} - 1); v >= 0; v--)); do
      if [[ "x${volume__mnt[$v]}" != "x" && "x${volume__mnt[$v]}" != "x/" && "x${volume__mnt[$v]}" != "x\"\"" ]]; then
        $(mount | grep -q ${volume__mnt[$v]})
        if [ $? = 0 ]; then
          _result=$(_run "umount ${_rootmnt}${volume__mnt[$v]}")
        fi
        if [ ${_result} != "OK" ]; then
          printf "Error unmounting ${_rootmnt}${volume__mnt[$v]}! ${_result}"
        fi
      fi
    done
    log_end_msg

    # Odmontowanie partycji
    log_begin_msg "Unmounting all partitions"
    for ((p = $(expr ${#partition__number[@]} - 1); p >= 0; p--)); do
      if [[ "x${partition__mnt[$p]}" != "x" && "x${partition__mnt[$p]}" != "x/" && "x${partition__mnt[$p]}" != "x\"\"" ]]; then
        $(mount | grep -q ${partition__mnt[$p]})
        if [ $? = 0 ]; then
          _result=$(_run "umount ${_rootmnt}${partition__mnt[$p]}")
        fi
        if [ ${_result} != "OK" ]; then
          printf "Error unmounting ${_rootmnt}${partition__mnt[$p]}! ${_result}"
        fi
      fi
    done
    log_end_msg
  else
    _result="Error: Volumes file not exist! - ${_volFile}\n"
  fi

  _unsetArrays
  printf ${_result}
  if [ _result == "OK" ]; then
    return 0
  else
    return 1
  fi
}

change_kernelparams() {
  local FILE=$1
  local PARAMS=""

  for P in $(cat /proc/cmdline); do
    if [[ ${P} != BOOT_IMAGE* && ${P} != vmlinuz && ${P} != root=* ]]; then
      if [[ ${P} = '--' ]]; then break; fi
      PARAMS=${PARAMS}' '${P}
    fi
  done
  # FIXIT: Specyficzne dla ubuntu do poprawy
  sed -i -e "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${PARAMS}\"/g" ${FILE}
}

ssh_config() {
  # Konfiguracja ssh
  mkdir -p /etc/ssh
  echo "StrictHostKeyChecking=no" >>/etc/ssh/ssh_config
}

override_initrd_scripts() {
  # Jezeli zmienna zdefiniowana
  if [[ "x${IPXEHTTP}" != 'x' ]]; then
    local CONFIMAGE=${IPXEHTTP#*\/}
    local CONFIMAGE="/srv/${CONFIMAGE%\/*}/CONFIGS/$(hostname)"
    local CONFIMAGE="${CONFIMAGE}/initrd.conf/"

    local SSHC="/usr/bin/ssh -i ${BOCMDIR}/boipxe_rsa root@${IPXEHTTP%%\/*}"
    local CONFEXIST=$(${SSHC} "if [ -d ${CONFIMAGE} ]; then echo Exist; else echo NotExist; fi")
    if [[ "${CONFEXIST}" != 'NotExist' ]]; then
      log_begin_msg "Download configuration initrd from ${CONFIMAGE}"
      echo -ne "\n"
      ${SSHC} "tar -zcf - -C ${CONFIMAGE} ." | tar zxf - -C / || panic "Configuration ${CONFIMAGE} download error!"
      log_end_msg
    fi
  fi
}

bocm_top() {
  [ "x$init" = "x" ] && (
    echo "Not initramfs!"
    return 1
  )

  # Jezeli nie ma synchronizacji nic nie rob
  if [ "x${IPXEHTTP}" = 'x' ]; then
    return 1 
  fi

  # Zabezpieczenie na wypadek opoznionego pojawienia sie dysku w systemie, wystepuje czesto na rzeczywistym sprzecie
  while [ "x$(ls /dev/sda 2>/dev/null)" != "x/dev/sda" ]; do
    printf "No /dev/sda disk, waiting...\n"
    sleep 1
  done

  # Jezeli nie jest zdefiniowane lub ma jedna z wartosci
  if [[ "x${MANUAL_DISK_MANAGE}" =~ ^(x|xn|xno|xfasle|x0)$ ]]; then

    # Jezeli ma jedna z wartosci to Force reinitialization?
    if [[ "x${MAKE_VOLUMES}" =~ ^(xy|xY|xyes|xtrue|x1)$ ]]; then
      log_warning_msg "Node reinitialization requested"

      log_begin_msg "Erasing root disk (${DISKDEV})"
      RESULT=$(cleanDisk ${DISKDEV})
      if [ "$RESULT" != "OK" ]; then
        printf "$RESULT"
        panic "Error in: cleanDisk ${DISKDEV}"
      fi
      log_end_msg

      log_begin_msg "Make partitions"
      RESULT=$(makeStdPartition ${DISKDEV} ${VOLUMES_FILE})
      if [ "$RESULT" != "OK" ]; then
        printf "${RESULT}"
        panic "Error in: makeStdPartition ${DISKDEV}"
      fi
      log_end_msg
      log_begin_msg "Make volumes"
      printf "\n"
      makeVolumes ${DISKDEV} ${VOLUMES_FILE}
      if [[ "$?" != "0" ]]; then
        panic "Error in: makeVolumes ${DISKDEV}"
      fi
      log_end_msg
    else
      log_begin_msg "Activating volumegroups"
      _run "lvm vgchange -ay"
      log_end_msg
    fi
  else
    panic "Manual disk manage."
  fi
}

bocm_bottom() {
  [ "x$init" = "x" ] && (
    echo "Not initramfs!"
    return
  )

  if [ "x${IPXEHTTP}" = 'x' ]; then
    exit
  fi

  # Na potrzeby sciagania image-u po ssh
  #local _SERVER=${IPXEHTTP%%\/*}
  local _TEMPLATE=${IPXEHTTP##*\/}
  #local IMAGE="/srv/${IPXEHTTP#*\/}/${TEMPLATE}.tgz"
  local _IMAGE="http://${IPXEHTTP}/${_TEMPLATE}.tgz"

  local _PARTITIONS_FILE=${BOCMDIR}/partitions.yml

  local CONFIMAGE=${IPXEHTTP#*\/}
  local CONFIMAGE="/srv/${CONFIMAGE%\/*}/CONFIGS/$(hostname)/"

  mount -o remount,rw ${rootmnt} || panic "could not remount rw ${rootmnt}"
  mountAll ${DISKDEV} ${rootmnt} ${_PARTITIONS_FILE}

  cd ${rootmnt}
  log_begin_msg "Downloading system image"
  printf "\n"
  /usr/bin/wget -q --show-progress -O - ${_IMAGE} | tar zxf - || panic "System image ${_IMAGE} download error!"
  #/usr/bin/ssh -i ${BOCMDIR}/boipxe_rsa root@${_SERVER} "dd if=${_IMAGE}"|tar zxf - || panic "System image ${_IMAGE} download error!"
  log_end_msg

  log_begin_msg "Download configuration from ${CONFIMAGE}"
  printf "\n"
  /usr/bin/ssh -o BatchMode=yes -i ${BOCMDIR}/boipxe_rsa root@${IPXEHTTP%%\/*} "tar -zcf - --exclude=boot.ipxe --exclude=.git --exclude=initrd.conf -C ${CONFIMAGE}/ ." | tar zxf - -C ${rootmnt} || panic "Configuration ${CONFIMAGE} download erro!"
  log_end_msg

  log_begin_msg "Installing bootloader"
  printf "\n"
  # Zabezpieczenie istniejącego fstab przed nadpisaniem
  if [ -f ${rootmnt}/etc/fstab ]; then
    mv ${rootmnt}/etc/fstab ${rootmnt}/etc/fstab.org
  fi
  cp ${BOCMDIR}/fstab ${rootmnt}/etc/fstab
  mount -o bind /dev ${rootmnt}/dev
  mount -o bind /proc ${rootmnt}/proc
  mount -o bind /sys ${rootmnt}/sys
  change_kernelparams ${rootmnt}/etc/default/grub
  chroot /root /bin/bash -c " \
      sed -i -e 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf; \
      update-grub; \
      grub-install --efi-directory=/boot/efi; \
      sed -i -e 's/use_lvmetad = 0/use_lvmetad = 1/g' /etc/lvm/lvm.conf; \
      exit"
  if [ -f ${rootmnt}/etc/fstab.org ]; then
    mv ${rootmnt}/etc/fstab.org ${rootmnt}/etc/fstab
  fi
  umount ${rootmnt}/sys
  umount ${rootmnt}/proc
  umount ${rootmnt}/dev
  cd /
  log_end_msg

  umountAll ${rootmnt} ${_PARTITIONS_FILE}
  mount -o remount,ro ${rootmnt} || panic "could not remount ro ${rootmnt}"
}

make_network_config_file() {
  [ "x$init" = "x" ] && (
    echo "Not initramfs!"
    return
  )
  # Local network configuration
  local OLDDIR=""
  OLDDIR=$(pwd)
  cd "${rootmnt}/etc/network/"
  /bin/ln -sf "interfaces.${BOOT}" interfaces || panic "Error making network configuration file!"
  cd "$OLDDIR"
}
