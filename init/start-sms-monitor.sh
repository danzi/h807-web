#!/system/bin/sh
BASE=/data/local/tmp/sms-cgi
BUSYBOX=/system/bin/busybox
LOG="$BASE/autostart.log"
echo "Starting SMS Monitor: $(date)" >> "$LOG"
[ -x "$BUSYBOX" ] || exit 1
[ -f "$BASE/index.html" ] || exit 1
[ -f "$BASE/cgi-bin/api.cgi" ] || exit 1
"$BUSYBOX" chmod 755 "$BASE/cgi-bin/api.cgi"
"$BUSYBOX" chmod 644 "$BASE/cgi-bin/lib/"*.sh 2>/dev/null
if "$BUSYBOX" ps | "$BUSYBOX" grep -q '[h]ttpd.*8001'; then
  echo "httpd already running" >> "$LOG"
  exit 0
fi
"$BUSYBOX" httpd -p 8001 -h "$BASE" >> "$LOG" 2>&1 &
echo "httpd launch requested: $(date)" >> "$LOG"
