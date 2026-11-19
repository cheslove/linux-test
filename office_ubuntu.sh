#!/bin/bash
# Резервный стенд: те же файлы в Ubuntu 24.04 (LibreOffice из репозитория, ONLYOFFICE из GitHub)
OUT=$PWD/out/office_ubuntu; mkdir -p $OUT
exec > >(tee $OUT/log.txt) 2>&1
set -x
export DEBIAN_FRONTEND=noninteractive
timeout 600 sudo -E apt-get update -q >/dev/null
for p in xvfb openbox ffmpeg fonts-dejavu-core fonts-liberation2 fonts-crosextra-carlito fonts-crosextra-caladea libreoffice libreoffice-l10n-ru; do timeout 900 sudo -E apt-get install -y -q $p > /tmp/apt_$p.log 2>&1; echo "$p exit=$?" >> $OUT/apt.txt; done
mkdir -p /tmp/oo && timeout 300 gh release download -R ONLYOFFICE/DesktopEditors --pattern 'onlyoffice-desktopeditors_amd64.deb' -D /tmp/oo && timeout 900 sudo -E apt-get install -y -q /tmp/oo/*.deb > /tmp/apt_oo.log 2>&1; echo "onlyoffice exit=$?" >> $OUT/apt.txt; tail -3 /tmp/apt_oo.log >> $OUT/apt.txt
{ libreoffice --version; dpkg -l | grep -i -E "onlyoffice|libreoffice-core"; } > $OUT/versions.txt 2>&1
Xvfb :98 -screen 0 1366x768x24 & sleep 2; export DISPLAY=:98; openbox & sleep 1
shot(){ ffmpeg -loglevel error -y -f x11grab -video_size 1366x768 -i :98 -frames:v 1 "$OUT/$1.png"; }
openf(){ timeout 60 $2 "$3" >/dev/null 2>&1 & P=$!; sleep 30; shot "$1"; kill $P 2>/dev/null; pkill -f "$4"; sleep 3; }
cd files
for f in *; do openf "libreoffice_${f%.*}_${f##*.}" "libreoffice --norestore" "$PWD/$f" soffice; done
OO=$(command -v onlyoffice-desktopeditors); [ -n "$OO" ] && for f in *; do openf "onlyoffice_${f%.*}_${f##*.}" "$OO" "$PWD/$f" DesktopEditors; done
ls -la $OUT
