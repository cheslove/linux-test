#!/bin/bash
# Установка офисных пакетов в ALT Linux p11 (контейнер) и открытие тестовых файлов.
# Экран (Xvfb :99) поднят на хосте, контейнер рисует в него; скриншоты делает хост по запросу.
OUT=/w/out/office; mkdir -p $OUT
exec > >(tee $OUT/log.txt) 2>&1
set -x
cat /etc/os-release > $OUT/os.txt
cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list > $OUT/sources_before.txt 2>&1
cat > /etc/apt/sources.list.d/zz-p11.list <<'L'
rpm [p11] http://ftp.altlinux.org/pub/distributions/ALTLinux p11/branch/x86_64 classic
rpm [p11] http://ftp.altlinux.org/pub/distributions/ALTLinux p11/branch/noarch classic
L
timeout 600 apt-get update -q > $OUT/apt_update.txt 2>&1
timeout 900 apt-get dist-upgrade -y -q > $OUT/apt_distupgrade.txt 2>&1; echo "dist-upgrade exit=$?" >> $OUT/apt.txt
for p in eepm wget curl fonts-ttf-dejavu fonts-ttf-liberation LibreOffice LibreOffice-langpack-ru; do
  timeout 900 apt-get install -y -q $p > /tmp/inst_$p.log 2>&1; echo "$p exit=$?" >> $OUT/apt.txt; tail -3 /tmp/inst_$p.log >> $OUT/apt.txt
done
for p in onlyoffice r7-office wpsoffice myoffice; do
  echo "=== epm play $p" >> $OUT/install.log; timeout 600 epm play --auto $p </dev/null >> $OUT/install.log 2>&1; echo "exit=$?" >> $OUT/install.log
done
timeout 120 epm play --list-all </dev/null > $OUT/epm_play_list.txt 2>&1
ls /usr/bin /opt | grep -i -E "office|wps|^et$|wpp|r7|myoffice|libre|soffice" > $OUT/bins.txt
rpm -qa | grep -i -E "office|wps|r7|libre" | sort > $OUT/rpms.txt
export DISPLAY=:99
shot(){ touch "$OUT/req_$1"; for i in $(seq 1 20); do [ -e "$OUT/req_$1" ] || break; sleep 1; done; }
openf(){ # name cmd file
  timeout 60 $2 "$3" >/dev/null 2>&1 & P=$!; sleep 35; shot "$1"; kill $P 2>/dev/null; pkill -f "$4" 2>/dev/null; sleep 3; }
cd /w/files
LO=$(command -v libreoffice || command -v soffice || ls /usr/bin | grep -m1 -E "^libreoffice[0-9.]*$")
[ -n "$LO" ] && for f in *; do openf "libreoffice_${f%.*}_${f##*.}" "$LO --norestore" "$f" soffice; done
OO=$(command -v onlyoffice-desktopeditors || command -v desktopeditors)
[ -n "$OO" ] && for f in *; do openf "onlyoffice_${f%.*}_${f##*.}" "$OO" "/w/files/$f" DesktopEditors; done
R7=$(command -v r7-office-desktopeditors || command -v r7-office || ls /usr/bin/* | grep -m1 -i r7)
[ -n "$R7" ] && for f in *; do openf "r7_${f%.*}_${f##*.}" "$R7" "/w/files/$f" r7; done
for pair in "wps:docx odt" "et:xlsx ods" "wpp:pptx odp" "wpspdf:pdf"; do b=${pair%%:*}; command -v $b >/dev/null && for e in ${pair#*:}; do for f in *.$e; do openf "wps_${f%.*}_$e" "$b" "/w/files/$f" wps; done; done; done
MO=$(ls /usr/bin /opt 2>/dev/null | grep -i myoffice | tr '\n' ' '); echo "myoffice: $MO" >> $OUT/bins.txt
ls -la $OUT
