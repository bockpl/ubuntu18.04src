#!/bin/bash

BRANCH=$(git branch | grep '*' | awk '{print $2}')
VERSION=$(bin/version.sh version)

TEMPLATES_DIR=./TEMPLATE_FILES
CONFIG_DIR=./CONFIGS

if [ $BRANCH = 'develop' ];
then
        VERSION=$VERSION-$BRANCH
fi

# Przygotowanie pliku boot.ipxe w odpowiedniej wersji (master/develop)
echo "Przetwarzam template boot.ipxe dla wersji $VERSION i gałęzi $BRANCH"
cat $TEMPLATES_DIR/boot.ipxe.$BRANCH.tmpl | sed "s/%%VERSION%%/$VERSION/g" > $CONFIG_DIR/boot.ipxe
echo "Plik boot.ipxe wrzucony do $CONFIG_DIR/boot.ipxe"
