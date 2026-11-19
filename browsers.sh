#!/bin/bash
# Проверка браузеров и доступности сайтов (выполняется в GitHub Actions, Ubuntu)
set -x
OUT=$PWD/out/browsers; mkdir -p $OUT
sudo apt-get update -qq
sudo apt-get install -y -qq xvfb xdotool imagemagick libnss3-tools fonts-dejavu-core fonts-noto-core x11-utils wmctrl openbox >/dev/null
# Chromium-GOST
mkdir -p /tmp/cg && gh release download -R deemru/Chromium-Gost --pattern '*amd64.deb' -D /tmp/cg && sudo apt-get install -y -qq /tmp/cg/*.deb
# Яндекс Браузер
curl -fsSL https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG | sudo gpg --dearmor -o /usr/share/keyrings/yandex.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex.gpg] http://repo.yandex.ru/yandex-browser/deb stable main" | sudo tee /etc/apt/sources.list.d/yb.list
sudo apt-get update -qq; sudo apt-get install -y -qq yandex-browser-stable
{ echo "== versions"; ls /opt; which firefox chromium-gost chromium-gost-stable yandex-browser google-chrome; firefox --version; dpkg -l | grep -i -E "chromium-gost|yandex|firefox"; dpkg -L chromium-gost-stable 2>/dev/null | grep -E "bin/|/chrome$" ; } > $OUT/versions.txt 2>&1
CG=$(command -v chromium-gost-stable || command -v chromium-gost || ls /opt/chromium-gost/chrome 2>/dev/null)
YB=$(command -v yandex-browser-stable || command -v yandex-browser)
FF=$(command -v firefox)
echo "CG=$CG YB=$YB FF=$FF" >> $OUT/versions.txt
# сертификаты сайтов
for h in fstec.ru cryptopro.ru www.gosuslugi.ru; do
  { echo "== $h"; echo | timeout 20 openssl s_client -connect $h:443 -servername $h 2>&1 | grep -E "verify return|Verify return code|depth"; echo | timeout 20 openssl s_client -connect $h:443 -servername $h 2>/dev/null | openssl x509 -noout -subject -issuer -dates; timeout 30 curl -sS -o /dev/null -w "curl http_code=%{http_code} ssl_verify=%{ssl_verify_result}\n" https://$h; } >> $OUT/certs.txt 2>&1
done
curl -sS -L -o /tmp/root.cer https://gu-st.ru/content/downloads/Russian_Trusted_Root_CA.cer
curl -sS -L -o /tmp/sub.cer https://gu-st.ru/content/downloads/Russian_Trusted_Sub_CA.cer
curl -sS -L -o /tmp/sub24.cer https://gu-st.ru/content/downloads/Russian_Trusted_Sub_CA_2024.cer
for c in /tmp/root.cer /tmp/sub.cer /tmp/sub24.cer; do openssl x509 -in $c -noout -subject -issuer -dates 2>/dev/null || openssl x509 -inform der -in $c -noout -subject -issuer -dates; done > $OUT/mincifry_certs.txt 2>&1
Xvfb :99 -screen 0 1366x768x24 & sleep 2; export DISPLAY=:99; openbox & sleep 1
shot(){ # browser-name url file
  sleep 22; import -window root "$OUT/$3.png"; }
run_chromium(){ # bin name
  for s in fstec.ru cryptopro.ru www.gosuslugi.ru; do
    $1 --no-first-run --no-default-browser-check --password-store=basic --user-data-dir=/tmp/p_$2 --window-position=0,0 --window-size=1366,768 --start-maximized https://$s >/dev/null 2>&1 &
    P=$!; shot x x "$2_${s}_$3"; kill $P; pkill -f "p_$2" ; sleep 2
  done; }
run_ff(){
  for s in fstec.ru cryptopro.ru www.gosuslugi.ru; do
    $FF --profile /tmp/ffprof -no-remote --width 1366 --height 768 https://$s >/dev/null 2>&1 &
    P=$!; shot x x "firefox_${s}_$1"; kill $P; pkill -f ffprof; sleep 3
  done; }
mkdir -p /tmp/ffprof; $FF -CreateProfile "t /tmp/ffprof" >/dev/null 2>&1
# пользовательские настройки Firefox: без стартовых страниц
cat > /tmp/ffprof/user.js <<'U'
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.firstRunURL", "");
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("intl.locale.requested", "ru");
U
[ -n "$CG" ] && run_chromium $CG chromiumgost 1_bez_sertifikata
[ -n "$YB" ] && run_chromium $YB yandex 1_bez_sertifikata
[ -n "$FF" ] && run_ff 1_bez_sertifikata
# установка сертификатов Минцифры в хранилища браузеров
mkdir -p $HOME/.pki/nssdb; certutil -d sql:$HOME/.pki/nssdb -N --empty-password 2>/dev/null
for c in root sub sub24; do certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "mincifry_$c" -i /tmp/$c.cer; certutil -d sql:/tmp/ffprof -A -t "C,," -n "mincifry_$c" -i /tmp/$c.cer; done
certutil -d sql:$HOME/.pki/nssdb -L > $OUT/nssdb_after.txt 2>&1
[ -n "$CG" ] && run_chromium $CG chromiumgost 2_s_sertifikatom
[ -n "$FF" ] && run_ff 2_s_sertifikatom
ls -la $OUT
