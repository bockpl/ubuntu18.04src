#!/bin/bash
# Naprawa uprawnień na właściwe
# GIT przechowuje pliki 644 lub dodatkowo flagę execute bit
# Skrypt powinien być uruchamiany przed makeTemplate

CONFIG=./CONFIGS

# Konfiguracja dla monita
chmod 0700 $CONFIG/etc/monit/monit.pem
chmod 0600 $CONFIG/etc/monit/monitrc
chmod 0600 $CONFIG/etc/monit/monitrc_distribution


