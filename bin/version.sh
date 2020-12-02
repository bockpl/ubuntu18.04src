#!/bin/bash

VERSION_FILE=VERSION
VERSION=$(cat $VERSION_FILE)

function get_verstion {
	echo $VERSION
}

function increment_patch {
	echo $VERSION | awk -F '[ .]' '{print $1"."$2"."$3+1}' > $VERSION_FILE
}

function increment_minor {
	echo $VERSION | awk -F '[ .]' '{print $1"."$2+1"."$3}' > $VERSION_FILE
}

function increment_major {
	echo $VERSION | awk -F '[ .]' '{print $1+1"."$2"."$3}' > $VERSION_FILE
}

function usage {
	echo "$0		wyświetla tę pomoc"
	echo "$0 version	wyświetla aktualną wersję"
	echo "$0 inc_patch	zwiększa o jeden aktualną wersję w pozycji patch - poprawka bezpieczeńśtwa (3 miejsce"
	echo "$0 inc_minor	zwieksza o jeden aktualną wersję w pozycji minor - dodanie/zmiana funkcjonalnosci w ramach głównej wersji (2 miejsce)"
	echo "$0 inc_major	zwiększa o jeden aktualną wersję w pozycji major - dodanie nowej funkcjonalności (1 miejsce)"
}

if [ $# -ne 1 ]
then
	usage
	exit 1
fi

case $1 in
	version)
		echo $VERSION
		;;
	inc_patch)
		increment_patch
		;;
	inc_minor)
		increment_minor
		;;
	inc_major)
		increment_major
		;;
	*)
		echo "BŁĄD: Nieznany parametr"
		echo
		usage
		exit 1
		;;
esac
