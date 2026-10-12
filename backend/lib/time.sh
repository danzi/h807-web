# Device time actions

time_get() {
  NOW=$(date 2>&1)
  EPOCH=$(date +%s 2>/dev/null || echo 0)
  ZONE=$(getprop persist.sys.timezone 2>/dev/null || echo "")
  echo '{"reply":"ok","date":"'"$(json_escape "$NOW")"'","epoch":'"$EPOCH"',"timezone":"'"$(json_escape "$ZONE")"'"}'
}

time_set() {
  DATETIME=$(urldecode "$DATETIME")
  if [ -z "$DATETIME" ]; then
    echo '{"reply":"error","msg":"datetime required (YYYY-MM-DD HH:MM:SS)"}'
    return 0
  fi
  OUT=$(date -s "$DATETIME" 2>&1)
  RC=$?
  if [ $RC -ne 0 ]; then
    OUT2=$(/system/bin/busybox date -s "$DATETIME" 2>&1)
    RC2=$?
    if [ $RC2 -ne 0 ]; then
      echo '{"reply":"error","msg":"date -s failed","detail":"'"$(json_escape "$OUT $OUT2")"'"}'
      return 0
    fi
  fi
  if [ -n "$TZ" ]; then
    TZ=$(urldecode "$TZ")
    setprop persist.sys.timezone "$TZ" 2>/dev/null
  fi
  NOW=$(date 2>&1)
  echo '{"reply":"ok","date":"'"$(json_escape "$NOW")"'"}'
}
