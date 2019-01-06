#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091

# Configure
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./bash-yaml/script/yaml.sh

parse_yaml ./partitions.yml
create_variables ./partitions.yml

#echo il_part=${#part__number[@]}
#echo il_vol=${#vol__part[@]}

for (( i=0; i<${#partition__number[@]}; i++ )); do
  echo part: ${partition__number[i]}
  for (( v=0; v<${#volume__part[@]}; v++ )); do
    if [[ ${volume__part[$v]} = ${partition__number[i]} ]]; then
      echo part_vol_name: ${volume__name[$v]}
    fi
  done
done

#echo Ilosc_partycji=${#partition__number[@]}
#echo Ilosc_vol=${#partition__volume__number[@]}

# Execute
#create_variables file.yml

#echo ${partition}
#len=${#partition__number[@]}
#echo LEN ${len}
#for (( vol=0; vol<${#partition__number[@]}; vol++ )); do
#  echo ${partition__number[${vol}]} ${partition__name[${vol}]} ${partition__volname[${vol}]} ${partition__mntpoint[${vol}]} \
#${partition__size[${vol}]} ${partition__fstype[${vol}]} ${partition__raid[${vol}]}
#done

