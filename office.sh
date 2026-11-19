#!/bin/bash
# Установка офисных пакетов в ALT Linux (контейнер alt:p11) и открытие тестовых файлов
OUT=/w/out/office; mkdir -p $OUT
exec > >(tee $OUT/log.txt) 2>&1
set -x
timeout 600 apt-get update -q
{ apt-repo list; apt-cache policy eepm; } > $OUT/repos.txt 2>&1
for p in eepm xorg-xvfb xvfb-run xdotool ImageMagick-tools fonts-ttf-dejavu fonts-ttf-liberation fonts-ttf-ms openbox wmctrl LibreOffice LibreOffice-still LibreOffice-langpack-ru wget curl sudo; do
  timeout 900 apt-get install -y -q $p > /tmp/inst_$p.log 2>&1; echo "$p exit=$?" >> $OUT/apt.txt; tail -3 /tmp/inst_$p.log >> $OUT/apt.txt
done
command -v epm || { timeout 120 wget -qO- https://raw.githubusercontent.com/Etersoft/eepm/master/packed/epm.sh > /tmp/epm.sh && bash /tmp/epm.sh --auto ei eepm >> $OUT/apt.txt 2>&1; }
command -v epm >> $OUT/apt.txt
{ cat /etc/os-release; } > $OUT/os.txt
for p in onlyoffice r7-office wpsoffice myoffice; do
  echo "=== epm play $p" >> $OUT/install.log; timeout 600 epm play --auto $p </dev/null >> $OUT/install.log 2>&1; echo "exit=$?" >> $OUT/install.log
done
timeout 120 epm play --list-all </dev/null > $OUT/epm_play_list.txt 2>&1
ls /usr/bin | grep -i -E "office|wps|^et$|wpp|r7|myoffice|libre|soffice" > $OUT/bins.txt
rpm -qa | grep -i -E "office|wps|r7|libre" > $OUT/rpms.txt
Xvfb :99 -screen 0 1366x768x24 & sleep 2; export DISPLAY=:99; openbox & sleep 1
shot(){ sleep ${2:-25}; import -window root "$OUT/$1.png"; }
openf(){ # name cmd file
  timeout 50 $2 "$3" >/dev/null 2>&1 & P=$!; shot "$1" 30; kill $P 2>/dev/null; pkill -f "$(basename $2)" 2>/dev/null; sleep 3; }
cd /w/files
for f in *; do openf "libreoffice_${f%.*}_${f##*.}" "libreoffice --norestore" "$f"; done
OO=$(command -v onlyoffice-desktopeditors); [ -n "$OO" ] && for f in *; do openf "onlyoffice_${f%.*}_${f##*.}" "$OO" "/w/files/$f"; done
R7=$(ls /usr/bin | grep -i -E "^r7" | head -1); [ -n "$R7" ] && for f in *; do openf "r7_${f%.*}_${f##*.}" "/usr/bin/$R7" "/w/files/$f"; done
for pair in "wps:docx doc odt" "et:xlsx ods" "wpp:pptx odp" "wpspdf:pdf"; do b=${pair%%:*}; command -v $b >/dev/null && for e in ${pair#*:}; do for f in *.$e; do openf "wps_${f%.*}_$e" "$b" "/w/files/$f"; done; done; done
MO=$(ls /usr/bin | grep -i myoffice | head -3 | tr '\n' ' '); echo "myoffice bins: $MO" >> $OUT/bins.txt
ls -la $OUT
