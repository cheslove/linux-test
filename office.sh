#!/bin/bash
# Установка офисных пакетов в ALT Linux p11 (контейнер) и открытие тестовых файлов.
# Экран (Xvfb :99) поднят на хосте, контейнер рисует в него; скриншоты делает хост по запросу.
OUT=/w/out/office; mkdir -p $OUT
exec > >(tee $OUT/log.txt) 2>&1
set -x
cat /etc/os-release > $OUT/os.txt
cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list > $OUT/sources_before.txt 2>&1
rm -f /etc/apt/sources.list.d/*.list
cat > /etc/apt/sources.list <<'L'
rpm [p11] http://mirror.yandex.ru/altlinux p11/branch/x86_64 classic
rpm [p11] http://mirror.yandex.ru/altlinux p11/branch/noarch classic
L
for i in 1 2 3; do timeout 900 apt-get update > $OUT/apt_update.txt 2>&1 && grep -q "noarch/classic pkglist" $OUT/apt_update.txt && break; sleep 5; done
ls -la /var/lib/apt/lists/ >> $OUT/apt_update.txt
timeout 900 apt-get dist-upgrade -y -q > $OUT/apt_distupgrade.txt 2>&1; echo "dist-upgrade exit=$?" >> $OUT/apt.txt
for p in eepm wget curl glibc-locales util-linux fonts-ttf-dejavu fonts-ttf-liberation fonts-ttf-google-noto-sans LibreOffice LibreOffice-langpack-ru; do
  timeout 900 apt-get install -y -q $p > /tmp/inst_$p.log 2>&1; echo "$p exit=$?" >> $OUT/apt.txt; tail -3 /tmp/inst_$p.log >> $OUT/apt.txt
done
for p in onlyoffice r7-office wpsoffice myoffice; do
  echo "=== epm play $p" >> $OUT/install.log; timeout 600 epm play --auto $p </dev/null >> $OUT/install.log 2>&1; echo "exit=$?" >> $OUT/install.log
done
timeout 120 epm play --list-all </dev/null > $OUT/epm_play_list.txt 2>&1
ls /usr/bin /opt | grep -i -E "office|wps|^et$|wpp|r7|myoffice|libre|soffice" > $OUT/bins.txt
rpm -qa | grep -i -E "office|wps|r7|libre" | sort > $OUT/rpms.txt
export DISPLAY=:99 LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8
useradd -m student 2>/dev/null; mkdir -p /home/student/.config/Kingsoft
printf '[6.0]\ncommon\\AcceptedEULA=true\n' > /home/student/.config/Kingsoft/Office.conf; chown -R student /home/student
locale -a | grep -i ru > $OUT/locales.txt
AS(){ runuser -u student -- env HOME=/home/student DISPLAY=:99 LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 XDG_RUNTIME_DIR=/tmp/xdg-student "$@"; }
mkdir -p /tmp/xdg-student; chown student /tmp/xdg-student; chmod 700 /tmp/xdg-student
shot(){ touch "$OUT/req_$1"; for i in $(seq 1 20); do [ -e "$OUT/req_$1" ] || break; sleep 1; done; }
act(){ echo "$*" > "$OUT/act_$RANDOM"; sleep 3; }
openf(){ # name cmd file pkillpattern [wps]
  timeout 70 runuser -u student -- env HOME=/home/student DISPLAY=:99 LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 XDG_RUNTIME_DIR=/tmp/xdg-student $2 "$3" >>$OUT/apps_stderr.txt 2>&1 & P=$!
  sleep 25; [ -n "$5" ] && { act mousemove 319 478 click 1; act mousemove 994 478 click 1; sleep 8; }
  sleep 12; shot "$1"; kill $P 2>/dev/null; pkill -f "$4" 2>/dev/null; sleep 3; }
cd /w/files
LO=$(command -v libreoffice || command -v soffice)
[ -n "$LO" ] && for f in *; do openf "libreoffice_${f%.*}_${f##*.}" "$LO --norestore" "/w/files/$f" soffice; done
OO=$(command -v onlyoffice-desktopeditors || command -v desktopeditors)
[ -n "$OO" ] && for f in *; do openf "onlyoffice_${f%.*}_${f##*.}" "$OO" "/w/files/$f" DesktopEditors; done
R7=$(command -v r7-office-desktopeditors || command -v r7-office)
[ -n "$R7" ] && for f in *; do openf "r7_${f%.*}_${f##*.}" "$R7" "/w/files/$f" r7; done
for pair in "wps:docx odt" "et:xlsx ods" "wpp:pptx odp" "wpspdf:pdf"; do b=${pair%%:*}; command -v $b >/dev/null && for e in ${pair#*:}; do for f in *.$e; do openf "wps_${f%.*}_$e" "$b" "/w/files/$f" wps 1; done; done; done
for pair in "myoffice-text-home-edition:docx odt" "myoffice-spreadsheet-home-edition:xlsx ods" "myoffice-presentation-home-edition:pptx odp"; do b=${pair%%:*}; command -v $b >/dev/null && for e in ${pair#*:}; do for f in *.$e; do openf "myoffice_${f%.*}_$e" "$b" "/w/files/$f" myoffice; done; done; done
{ for b in libreoffice onlyoffice-desktopeditors r7-office wps; do echo "== $b"; rpm -qf $(command -v $b) 2>&1; done; } > $OUT/pkg_of_bins.txt
ls -la $OUT
