#!/bin/bash

#!/usr/bin/env bash

onExit() {
  popd
}
trap onExit SIGQUIT
pushd $(pwd)
cd $(dirname $0)

BOCMDIR="../etc/bocm"

source ${BOCMDIR}/functions.sh

DEV=$1
if [ "x$DEV" == "x" ]; then
  DEV=/dev/sdb
fi
echo $DEV
#export DEBUG=sym
_result=$(cleanDisk ${DEV})
makeStdPartition ${DEV} "${BOCMDIR}/partitions.yml"
#set -x
makeVolumes ${DEV} "${BOCMDIR}/partitions.yml"
#echo ${_result}