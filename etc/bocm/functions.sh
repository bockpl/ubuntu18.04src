#!/bin/bash

if [[ $0 =~ ^.*functions.sh$ ]]; then
  cat <<EOF
Lista funkcji:
  getSizeDirectory
  getMemorySize
  getDiskCount
  cleanDisk
  makeStdPartition
  makeVolumes
  makeVolumes_new
  syncDir
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

# Czy przeniesc do konfiguracji?
SGDISK=/sbin/sgdisk

LV_ROOT=""

# Load default, then allow override.
HOSTNAME="$(hostname)"

# USTAWIANE w script/custom_functions
if [ "x$ROOTSTANDARD" = "x" ]; then
  ROOTSTANDARD=""
fi

if [ -s "${ROOTSTANDARD}/${BOCMDIR}/default" ]; then
  . ${ROOTSTANDARD}/${BOCMDIR}/default
else
  DISKDEV=/dev/sda
  VG_NAME=vgroot
  VOLUMES_FILE=${ROOTSTANDARD}/${BOCMDIR}/volumes
  VOLUME_FILE=./volumes
  MANUAL_DISK_MANAGE="no"
  CCRSYNCDELETE="yes"
fi
if [ -s "${ROOTSTANDARD}/${BOCMDIR}/${HOSTNAME}" ]; then . "${ROOTSTANDARD}/${BOCMDIR}/${HOSTNAME}"; fi

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

  if [ "x${DEBUG}" = "xsym" ]; then
    echo "$@" >&2
    echo -en ${_result}
    return 0
  else
    _result=$(eval "$@" 2>&1)
    local RET=$?
  fi

  if [ $RET != 0 ]; then
    if [ "x${MFSUPPER}" = 'x' ]; then
      _result="$RESULT \n Exit status: $RET \n Error in command: $*"
    else
      panic "$RESULT \n Exit status: $RET \n Error in command: $*"
    fi
  else
    _result="OK"
  fi
  echo -en ${_result}
  return ${RET}
}

# Funkcja zwraca wielkośćw GB np.(1.75) katalogu wskazanego w parametrze
getSizeDirectory() {
  local DIR=$1
  local RESULT="0"

  # /usr/bin/find is true find not busybox find
  RESULT=$(/usr/bin/find "$DIR/" -type f -printf "%s\n" | awk '{ total += $1 }; END { printf "%.2f\n", total/1024/1024/1024 }' 2>&1)
  if [ $? != "0" ]; then
    RESULT="0"
  fi
  echo $RESULT
}

# Funkcja zwraca wielkosc pamieci RAM w GB (np. 4)
getMemorySize() {
  local RESULT="0"
  RESULT=$(awk '/MemTotal/{printf("%.2f\n", $2 / 1024)}' </proc/meminfo)
  echo -e "$RESULT"
}

# Funkcja zwraca ilosc dostepnych do zagospodarowania dyskow
getDiskCount() {
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
  printf "${_result}"
  return 0
}

# Tworzenie standardowego schematu podzialu na wolumeny
# Parametry:
#   DISK - sciezka urzadzenia blokowego dysku
#   VOLUMES_FILE - sciezka do pliku opisu wolumenow
# Wynieki:
#   return_code = 0 - jesli wszystko przebieglo pomyslnie
#   return_code = 1 - w przypadku wystapienia dowolnego bledu, wyswietlany jest tez komunikat
makeVolumes() {
  local _result="ENTER"
  local _disk=$1
  local _volFile=$2
  local _vgname=""
  local _lvname=""
  local _makeFS=$(false)

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
            printf "\nDone\n"
          else
            # Jezeli nie istnieje LV o podanej nazwie
            printf "Creating logical volume ${_lvname}..."
            if [ ${volume__size[$v]} == "0" ]; then
              if [ $v = $(expr ${#volume__part[@]} - 1) ]; then
                volume__size[$v]="99%PVS"
                local _SCSIchan=$(ls "/sys/block/${_disk#/dev}/device/scsi_device" | awk '{gsub(":","", $1); print}')
                _lvname="${_lvname}_${_SCSIchan}"
                # Modyfikacja nazwy urzadzenia, poniewaz zmienia sie nazwa LV
                volume__dev[$v]="${volume__dev[$v]}_${_SCSIchan}"
              else
                _result="Error: Volume size \"0\" is only valid for last volume"
                break
              fi
              _result=$(_run "lvm lvcreate -y -n ${_lvname} -l ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")     
            else
              _result=$(_run "lvm lvcreate -y -n ${_lvname} -L ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")
            fi
            if [ "$?" != 0 ]; then
              break
            fi
            _makeFS=$(true)
            printf "Done\n"
          fi
          continue
        fi #raid=raid1

        if [ "x${volume__raid[$v]}" == "xn" ]; then
          # Jezeli wolumen o podanej nazwie juz istnieje, nic nie rob
          if [ "x$(lvm lvs --noheadings -o lv_name -S lv_name=${_lvname}| awk '{print $1}')" == "x${_lvname}" ]; then
            continue
          fi
          printf "Creating logical volume ${_lvname}..."
          if [ "x${volume__name[$v]}" == "xSWAP" ]; then
            if [ ${volume__size[$v]} == "0" ]; then
              volume__size[$v]=$(echo "$(getMemorySize) $(getDiskCount)" | awk '{printf("%.2f\n", 2*$1/$2)}')
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
          _result=$(_run "lvm lvcreate -y -n ${_lvname} -L ${volume__size[$v]} --wipesignatures y --zero y $_vgname ${_disk}${volume__part[$v]}")
          if [ "$?" != 0 ]; then
            break
          fi
          _makeFS=$(true)
          printf "Done\n"
          continue
        else
          _result="Error: Bad value for \"raid\" field for volume ${volume__dev[$v]}"
          if [ "$?" != 0 ]; then
            break
          fi
          continue
        fi #raid=n

        if [ _makeFS ]; then
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

  if [ "${_result}" == "OK" ]; then
    return 0
  else
    echo -ne "${_result}"
    return 1
  fi
}

# Tworzenie standardowego schematu podzialu na wolumeny
# Parametry:
#   DISK - sciezka urzadzenia blokowego dysku
#   VOLUMES_FILE - sciezka do pliku opisu wolumenow
# Wynieki:
#   return_code = 0 - jesli wszystko przebieglo pomyslnie
#   return_code = 1 - w przypadku wystapienia dowolnego bledu, wyswietlany jest tez komunikat
makeVolumes_new() {
  local RESULT="ENTER"
  local SGDISK=/sbin/sgdisk
  local PV_PART_NUM=2
  local DISK=$1
  local VOLUMES=$2

  local doMakeFS=N

  echo -ne "\n"

  SEC_SIZE=$(cat /sys/block/${DISK#/dev}/queue/physical_block_size)

  if [[ "x$VOLUMES" = "x" ]]; then
    VOLUMES=$VOLUME_FILE
  fi

  local npv=""
  npv=$(lvm pvs --noheadings -o pv_name -S pv_name="${DISK}${PV_PART_NUM}" | awk '{ print $1 }')
  if [[ "x$npv" != "x" ]]; then
    RESULT=$(_run "lvm pvcreate ${DISK}${PV_PART_NUM}")
  fi
  local nvg=""
  nvg=$(lvm vgs --noheadings -o vg_name -S vg_name=$VG_NAME | awk '{ print $1 }')
  # Jezeli istnieje juz vg o podanej nazwie
  if [[ "x$nvg" = "x$VG_NAME" ]]; then
    local npvinvg=""
    npvinvg=$(lvm vgs --noheadings -o pv_name -S vg_name=$VG_NAME,pv_name="${DISK}${PV_PART_NUM}")
    # Jezeli w vg nie ma pv o podanej nazwie
    if [[ "x$npvinvg" = "x" ]]; then
      RESULT=$(_run "lvm vgextend $VG_NAME ${DISK}${PV_PART_NUM}")
    fi
  else
    RESULT=$(_run "lvm vgcreate -y $VG_NAME ${DISK}${PV_PART_NUM}")
  fi

  local LVM_NAME LVM_MOUNT LVM_SIZE LVM_FS LVM_RAID

  grep -vE '(^#.*|^$)' $VOLUMES_FILE | while IFS=:, read LVM_NAME LVM_MOUNT LVM_SIZE LVM_FS LVM_RAID; do
    if [[ "x$(printf "%c" "${LVM_NAME}")" != "x#" ]] &&
      [[ "x$(printf "%c" "${LVM_NAME}")" != "x " ]] &&
      [[ "x$(printf "%c" "${LVM_NAME}")" != "x" ]]; then
      if [[ "$LVM_MOUNT" = "swap" ]]; then
        if [[ "$LVM_SIZE" = "0" ]]; then
          LVM_SIZE=$(echo "$(getMemorySize) $(getDiskCount)" | awk '{printf("%.2f\n", 2*$1/$2)}')
        fi
      fi

      if [[ "$LVM_RAID" = "RAID1" ]]; then
        local nlv=""
        nlv=$(lvm lvs --noheadings -o lv_name -S lv_name="$LVM_NAME" | awk '{ print $1 }')
        local devlv=""
        devlv=$(lvm lvs --noheadings -o devices -S lv_name="$LVM_NAME" | awk '{ print $1 }' | grep "${DISK}${PV_PART_NUM}")
        # Jezeli istnieje juz LV o podanej nazwie i nie znajduje sie na przetwarzanym PV
        #set -x
        if [[ "x$nlv" = "x$LVM_NAME" && "x${devlv}" = "x" ]]; then

          # Liczba kopii mirror-a
          local stripes=""
          stripes=$(lvm lvs --noheadings -o stripes -S lv_name="$LVM_NAME" | awk '{ print $1 }')
          echo -ne "Converting logical volume $LVM_NAME to mirror...\n"
          doMakeFS="N"
          #RESULT=$(_run "lvm lvconvert -y -m$stripes --type mirror --mirrorlog core -i 3 /dev/$VG_NAME/$LVM_NAME")
          RESULT=$(_run "lvm lvconvert -y -m$stripes --alloc anywhere /dev/$VG_NAME/$LVM_NAME")
          RESULT=$(_run "lvm lvchange -ay /dev/$VG_NAME/$LVM_NAME")
          local syncP=0
          until [ $syncP = "100" ]; do
            echo -ne "\r"
            syncP=$(lvm lvs --noheadings -o sync_percent -S lv_name="$LVM_NAME" | awk '{ printf "%d\n", $1 }')
            echo -ne " Waitng for $LVM_NAME mirror syncing: $syncP%... "
            sleep 1
          done
          echo -ne "Done\n"
        else
          echo -ne "Creating logical volume $LVM_NAME..."
          doMakeFS="Y"
          if [[ "$LVM_SIZE" = "0" ]]; then
            local SCSIchan=""
            SCSIchan=$(ls "/sys/block/${DISK#/dev}/device/scsi_device" | awk '{gsub(":",""); print}')
            #SCSIchan=$(echo "$SCSIchan"|awk '{gsub(/:/,"", $1); print}')
            LVM_NAME=${LVM_NAME}_$SCSIchan
            RESULT=$(_run "lvm lvcreate -y -n $LVM_NAME -l 99%PVS --wipesignatures y --zero y $VG_NAME ${DISK}${PV_PART_NUM}")
          else
            RESULT=$(_run "lvm lvcreate -y -n $LVM_NAME -L $LVM_SIZE --wipesignatures y --zero y $VG_NAME ${DISK}${PV_PART_NUM}")
          fi
          echo -ne "Done\n"
        fi
        #set +x
      # Jezeli nie RAID
      else
        local SCSIchan=""
        SCSIchan=$(ls "/sys/block/${DISK#/dev}/device/scsi_device" | awk '{gsub(":","", $1); print}')
        #SCSIchan=$(echo "$SCSIchan"|awk '{gsub(/:/,"", $1); print}')
        LVM_NAME=${LVM_NAME}_$SCSIchan
        local nlv=""
        nlv=$(lvm lvs --noheadings -o lv_name -S lv_name="$LVM_NAME" | awk '{ print $1 }')
        # Jezeli nie istnieje LV o podanej nazwie
        if [[ "x$nlv" = "x" ]]; then
          echo -ne "Creating logical volume $LVM_NAME..."
          doMakeFS="Y"
          if [[ $LVM_SIZE = "0" ]]; then
            RESULT=$(_run "lvm lvcreate -y -n ${LVM_NAME} -l 99%PVS --wipesignatures y --zero y $VG_NAME ${DISK}${PV_PART_NUM}")
          else
            RESULT=$(_run "lvm lvcreate -y -n ${LVM_NAME} -L $LVM_SIZE --wipesignatures y --zero y $VG_NAME ${DISK}${PV_PART_NUM}")
          fi
          echo -ne "Done\n"
        fi
      fi
      if [[ "$LVM_MOUNT" = "/" ]]; then
        LV_ROOT=$LVM_NAME
      fi

      if [[ "$doMakeFS" = "Y" ]]; then
        if [[ "$LVM_MOUNT" = "swap" ]]; then
          RESULT=$(_run "/sbin/mkswap -f -L swapdevice /dev/$VG_NAME/$LVM_NAME")
        else
          RESULT=$(_run "/sbin/mkfs.xfs -s size=$SEC_SIZE -f -L $LVM_NAME /dev/$VG_NAME/$LVM_NAME")
        fi
      fi
    fi
  done

  if [[ $RESULT = "OK" ]]; then
    return 0
  else
    echo "$RESULT"
    return 1
  fi
}

syncDir() {
  local RESULT="OK"

  local SRC=$1
  local DST=$2
  local CMP=$3
  local EXCLUDE_PATH="$SRC/${BOCMDIR}"
  #local LOGFILE=$DST/var/log/rsync_log
  local LOGFILE=/rsynclog.log

  if ! [[ -d ${EXCLUDE_PATH} ]]; then
    EXCLUDE_PATH="${BOCMDIR}"
  fi

  if [ -s "$EXCLUDE_PATH/rsync_exclude_${HOSTNAME}" ]; then
    RSYNC_EXCLUDE=$EXCLUDE_PATH/rsync_exclude_${HOSTNAME}
  else
    RSYNC_EXCLUDE=$EXCLUDE_PATH/rsync_exclude
  fi

  date >$LOGFILE
  if [[ -z $CMP ]]; then
    echo "rsync -a -HAX -P --exclude-from=$RSYNC_EXCLUDE \
          --one-file-system ${CCRSYNCDELETE} \
          $SRC/. $DST/." >>$LOGFILE
    rsync -a -HAX -P --exclude-from=$RSYNC_EXCLUDE \
      --one-file-system ${CCRSYNCDELETE} \
      "$SRC/." "$DST/." \
      >>$LOGFILE 2>&1 ||
      RESULT="failed to rsync $SRC/. to $DST/."
  else
    #    echo "rsync -a -HAX -P --exclude-from=$RSYNC_EXCLUDE \
    #          --one-file-system --delete --compare-dest $CMP/ $SRC/ $DST/" >> $LOGFILE
    echo "rsync -a -HAX -P --exclude-from=$RSYNC_EXCLUDE \
	   --one-file-system --delete --compare-dest \"$CMP/\" \"$SRC/\" \"$DST/\""
    #    rsync -a -HAX -P --exclude-from=$RSYNC_EXCLUDE \
    #          --one-file-system --delete --compare-dest "$CMP/" "$SRC/" "$DST/" \
    #	  >> $LOGFILE 2>&1 \
    #    || RESULT="failed to rsync $SRC/. to $DST/."
    rsync -a -HAX -P --exclude-from=$RSYNC_EXCLUDE \
      --one-file-system --delete --compare-dest "$CMP/" "$SRC/" "$DST/"
  fi

  mv $LOGFILE /root/${BOCMDIR}
  RESULT="OK"
  echo -e "$RESULT"
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
    return
  )

  # Jezeli zmienna zdefiniowana
  if [[ "x${IPXEHTTP}" != 'x' ]]; then
    VOLUMES_FILE=${BOCMDIR}/${VOLUME_FILE}
  fi

  # Zabezpieczenie na wypadek opoznionego pojawienia sie dysku w systemie, wystepuje czesto na rzeczywistym sprzecie
  while [ "x$(ls /dev/sda 2>/dev/null)" != "x/dev/sda" ]; do
    echo "Brak /dev/sda"
    sleep 1
  done

  # Jezeli nie ma synchronizacji nic nie rob
  if [ "x${MFSUPPER}" = 'x' ] && [ "x${IPXEHTTP}" = 'x' ]; then
    exit
  fi

  # Jezeli nie jest zdefiniowane lub ma jedna z wartosci
  if [[ "x${MANUAL_DISK_MANAGE}" =~ ^(x|xn|xno|xfasle|x0)$ ]]; then

    # Jezeli ma jedna z wartosci to Force reinitialization?
    if [[ "x${MAKE_VOLUMES}" =~ ^(xy|xY|xyes|xtrue|x1)$ ]]; then
      log_warning_msg "Node reinitialization requested"
      log_begin_msg "Erasing root disk (${DISKDEV})"
      RESULT=$(cleanDisk ${DISKDEV})
      if [ "$RESULT" != "OK" ]; then
        echo -e "$RESULT"
        panic "Error in: cleanDisk ${DISKDEV}"
      fi
      log_end_msg
      log_begin_msg "Make partitions and volumes"
      RESULT=$(makeStdPartition ${DISKDEV} ${BOCMDIR}/partitions.yml)
      if [ "$RESULT" != "OK" ]; then
        echo -e "$RESULT"
        panic "Error in: makeStdPartition ${DISKDEV}"
      fi
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
  # Jezeli nie ma synchronizacji nic nie rob
  if [ "x${MFSUPPER}" = 'x' ] && [ "x${IPXEHTTP}" = 'x' ]; then
    exit
  fi

  # At this point we have:
  # * root disk partitions
  # * root disk filesystems for rootdevice and swapdevice

  if [ "x${IPXEHTTP}" != 'x' ]; then
    VOLUMES_FILE=${BOCMDIR}/volumes
  fi

  grep -vE '(^#.*|^$)' $VOLUMES_FILE | while IFS=:, read LVM_NAME LVM_MOUNT LVM_SIZE LVM_FS LVM_RAID; do
    if [ "x${LVM_MOUNT}" = "x/" ]; then
      LV_ROOT=${LVM_NAME}
    fi
  done

  if [ "x${MFSUPPER}" != 'x' ]; then
    local OVER_SIZE=1.3 # +30%

    log_begin_msg "Calculating template size"
    T_SIZE=$(echo "$(getSizeDirectory ${ROOTSTANDARD}) $OVER_SIZE" | awk '{ printf "%.2f", $1 * $2 }')
    log_success_msg "${T_SIZE}g"
    log_end_msg

    ROOT_SIZE=$(lvm lvs -o lv_size --noheadings --nosuffix --units g -S vg_name="$VG_NAME",lv_name="$LV_ROOT")
    if [ "$(echo "$T_SIZE" "$ROOT_SIZE" | awk '{ print ($2 > $1) ? "YES" : "NO" }')" = "YES" ]; then
      log_success_msg "Root volume ${LV_ROOT} size ${ROOT_SIZE}g is OK."
    else
      panic "Root volume ${LV_ROOT} size ${ROOT_SIZE}g is lower from template size ${T_SIZE}g"
    fi

    log_begin_msg "resynchronisation ${MFSUPPER} to /root"

    if [ "x${CCRSYNCDELETE}" = 'xy' -o "x${CCRSYNCDELETE}" = "xyes" -o "x${CCRSYNCDELETE}" = 'xtrue' -o "x${CCRSYNCDELETE}" = "x1" ]; then CCRSYNCDELETE="--delete"; else CCRSYNCDELETE=""; fi

    # mount /boot partition before syncing
    mount -o remount,rw ${rootmnt} || panic "could not remount rw ${rootmnt}"
    if ! [[ -d ${rootmnt}/boot ]]; then
      mkdir ${rootmnt}/boot
    fi
    mount -o noexec,uid=0,gid=4,dmask=0023,fmask=0133 ${DISKDEV}1 ${rootmnt}/boot

    # syncing
    RESULT=$(syncDir ${ROOTSTANDARD} ${rootmnt})

    if [[ $RESULT != "OK" ]]; then
      panic "$RESULT"
    fi
    log_end_msg

    # create, chown and chmod excluded dirs
    local DIR

    # Did we create a new root fs?
    if [ "x${CCNEWROOTFS}" = "xy" ]; then touch ${rootmnt}/etc/ccnewrootfs; fi

    # Local network configuration
    log_begin_msg "Make network config file"
    make_network_config_file
    log_end_msg
  fi

  if [ "x${IPXEHTTP}" != 'x' ]; then
    # mount /boot/efi partition before syncing
    mount -o remount,rw ${rootmnt} || panic "could not remount rw ${rootmnt}"
    if ! [[ -d ${rootmnt}/boot/efi ]]; then
      mkdir -p ${rootmnt}/boot/efi
    fi
    mount -o noexec,uid=0,gid=4,dmask=0023,fmask=0133 ${DISKDEV}1 ${rootmnt}/boot/efi

    cd ${rootmnt}
    log_begin_msg "Downloading system image"
    echo -ne "\n"
    local SERVER=${IPXEHTTP%%\/*}
    local TEMPLATE=${IPXEHTTP##*\/}
    #local IMAGE="/srv/${IPXEHTTP#*\/}/${TEMPLATE}.tgz"
    local IMAGE="http://${IPXEHTTP}/${TEMPLATE}.tgz"
    /usr/bin/wget -q --show-progress -O - ${IMAGE} | tar zxf - || panic "System image ${IMAGE} download error!"
    #/usr/bin/ssh -i ${BOCMDIR}/boipxe_rsa root@${SERVER} "dd if=${IMAGE}"|tar zxf - || panic "System image ${IMAGE} download error!"
    log_end_msg

    local CONFIMAGE=${IPXEHTTP#*\/}
    local CONFIMAGE="/srv/${CONFIMAGE%\/*}/CONFIGS/$(hostname)/"
    log_begin_msg "Download configuration from ${CONFIMAGE}"
    echo -ne "\n"
    /usr/bin/ssh -o BatchMode=yes -i ${BOCMDIR}/boipxe_rsa root@${IPXEHTTP%%\/*} "tar -zcf - --exclude=boot.ipxe --exclude=.git --exclude=initrd.conf -C ${CONFIMAGE}/ ." | tar zxf - -C ${rootmnt} || panic "Configuration ${CONFIMAGE} download erro!"
    log_end_msg
    log_begin_msg "Installing bootloader"
    echo -ne "\n"
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
    log_end_msg
    umount ${rootmnt}/sys
    umount ${rootmnt}/proc
    umount ${rootmnt}/dev
    cd /
  fi

  umount ${rootmnt}/boot/efi
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
