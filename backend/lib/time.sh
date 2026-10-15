# Device time. MSM8916 32-bit ash: never [ ]-compare 13-digit values.
# KitKat `service` has no working i64 — alarm setTime(ms) was writing 1970.
# Do not kill time_daemon / ats_* (that also jumps to 1970).
# toolbox date -s wants MMDDhhmmYYYY.ss ; busybox wants YYYY-MM-DD HH:MM:SS.

time_norm_tz() {
  local z="$1"
  [ "$z" = "Europe/Kyiv" ] && z="Europe/Kiev"
  echo "$z"
}

epoch_sec_ok() {
  local s="$1"
  s=$(echo "$s" | /system/bin/busybox tr -cd '0-9' | /system/bin/busybox cut -c1-10)
  [ "${#s}" -eq 10 ] || return 1
  [ "$s" -ge 1420070400 ] 2>/dev/null || return 1
  return 0
}

client_ts_ms() {
  local ts
  ts=$(echo "$CLIENT_TS" | /system/bin/busybox tr -cd '0-9')
  if [ "${#ts}" -ge 13 ]; then
    echo "$ts" | /system/bin/busybox cut -c1-13
    return 0
  fi
  if [ "${#ts}" -eq 10 ] && epoch_sec_ok "$ts"; then
    echo "${ts}000"
    return 0
  fi
  echo "0"
  return 1
}

datetime_to_toolbox() {
  echo "$1" | /system/bin/busybox sed -n 's/^ *\([0-9][0-9][0-9][0-9]\)-\([0-9][0-9]\)-\([0-9][0-9]\)[ T]\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\).*/\2\3\4\5\1.\6/p'
}

time_apply_tz() {
  local z
  z=$(time_norm_tz "$(urldecode "$1")")
  [ -z "$z" ] && return 0
  setprop persist.sys.timezone "$z" 2>/dev/null
  log_dbg "time_apply_tz $z"
}

time_now_sec() {
  date +%s 2>/dev/null || echo 0
}

time_zone() {
  local z
  z=$(getprop persist.sys.timezone 2>/dev/null)
  [ -z "$z" ] && z="Europe/Vilnius"
  echo "$z"
}

# DATETIME is UTC wall-clock (browser converts local picker → UTC).
# Android busybox has no zoneinfo, so TZ=Europe/Vilnius is ignored (=UTC) and
# adding persist.sys.timezone then shows +3h. Always set the clock in UTC.
time_apply_datetime() {
  local dt="$1"
  [ -z "$dt" ] && return 1
  echo "$dt" | /system/bin/busybox grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}' || return 1
  local after
  TZ=UTC /system/bin/busybox date -s "$dt" >/dev/null 2>&1
  after=$(time_now_sec)
  if ! epoch_sec_ok "$after"; then
    log_dbg "time_apply_datetime FAILED utc=$dt after=$after"
    return 1
  fi
  TZ=UTC /system/bin/busybox hwclock -w -u >/dev/null 2>&1
  TZ=UTC /system/bin/hwclock -w -u >/dev/null 2>&1
  log_dbg "time_apply_datetime ok utc=$dt epoch=$after"
  return 0
}

# busybox cannot load Europe/Vilnius; POSIX GMT-3 = UTC+3 (EEST).
time_display_tz() {
  echo "GMT-3"
}

time_apply_epoch() {
  local sec="$1"
  sec=$(echo "$sec" | /system/bin/busybox tr -cd '0-9' | /system/bin/busybox cut -c1-10)
  epoch_sec_ok "$sec" || return 1
  local dt
  dt=$(/system/bin/busybox date -d "@$sec" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
  [ -z "$dt" ] && dt=$(/system/bin/busybox date -D "%s" -d "$sec" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
  [ -n "$dt" ] || return 1
  time_apply_datetime "$dt"
}

time_sync_from_client() {
  local dt
  dt=$(urldecode "$DATETIME")
  if [ -n "$TZ" ]; then
    time_apply_tz "$TZ"
  fi
  if [ -n "$dt" ]; then
    time_apply_datetime "$dt" && return 0
  fi
  return 1
}

# Only touch the clock if it is already in 1970/2004-era.
time_sync_if_bad() {
  if epoch_sec_ok "$(time_now_sec)"; then
    return 0
  fi
  time_sync_from_client
}

time_get() {
  ZONE=$(time_zone)
  NOW=$(TZ="$(time_display_tz)" date 2>&1)
  EPOCH=$(date +%s 2>/dev/null || echo 0)
  echo '{"reply":"ok","date":"'"$(json_escape "$NOW")"'","epoch":'"$EPOCH"',"timezone":"'"$(json_escape "$ZONE")"'"}'
}

time_set() {
  DATETIME=$(urldecode "$DATETIME")
  if ! time_sync_from_client; then
    echo '{"reply":"error","msg":"could not set time (refusing 1970)","detail":"'"$(json_escape "$(date 2>&1)")"'"}'
    return 0
  fi
  NOW=$(TZ="$(time_display_tz)" date 2>&1)
  EPOCH=$(date +%s 2>/dev/null || echo 0)
  echo '{"reply":"ok","msg":"time updated","date":"'"$(json_escape "$NOW")"'","epoch":'"$EPOCH"'}'
}

time_debug() {
  D1=$(date 2>&1)
  D2=$(date +%s 2>&1)
  D3=$(/system/bin/busybox date +%s 2>&1)
  D4=$(/system/bin/busybox date 2>&1)
  echo '{"reply":"ok","date":"'"$(json_escape "$D1")"'","epoch":"'"$(json_escape "$D2")"'","busybox_epoch":"'"$(json_escape "$D3")"'","busybox_date":"'"$(json_escape "$D4")"'"}'
}
