#/bin/bash

BUILD_FILE=./BUILD
BUILD=$(cat $BUILD_FILE)

function usage {

	echo "Użycie:"
	echo "$0 version	- wyżwietla aktualny build"
	echo "$0 increment	- zwiększa o jeden build"
}

function get_version {
	echo $BUILD
	exit 0
}

function increment_build {
	echo $BUILD | awk '{print $1+1}' > $BUILD_FILE
}

if [ $# -ne 1 ]
then
	echo "Niepoprawna ilość parametrów"
	usage
	exit 1
fi

if [ ! -f ./BUILD ]
then
	echo brak pliku BUILD
	exit 1
fi

case $1 in 
	version)
		get_version
		;;
	increment)
		increment_build
		;;
	*)
		usage
		exit 1
		;;
esac


exit
