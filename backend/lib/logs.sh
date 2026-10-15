# Persistent logs under web root
LOG_DIR="/data/local/tmp/sms-cgi/logs"
SEND_LOG="$LOG_DIR/sms-send.log"

ensure_log_dir() {
  /system/bin/busybox mkdir -p "$LOG_DIR" 2>/dev/null
}

# usage: log_send STATUS ADDR BODY DETAIL
log_send() {
  ensure_log_dir
  local status="$1"
  local addr="$2"
  local body="$3"
  local detail="$4"
  local ts when
  ts=$(date +%s 2>/dev/null || echo 0)
  ts="${ts}000"
  when=$(date 2>/dev/null | /system/bin/busybox tr -d '\n' || echo "")
  addr=$(json_escape "$addr")
  body=$(json_escape "$body")
  detail=$(json_escape "$detail")
  when=$(json_escape "$when")
  echo "{\"ts\":$ts,\"when\":\"$when\",\"status\":\"$status\",\"address\":\"$addr\",\"body\":\"$body\",\"detail\":\"$detail\"}" >> "$SEND_LOG"
  local lines
  lines=$(/system/bin/busybox wc -l < "$SEND_LOG" 2>/dev/null || echo 0)
  if [ "$lines" -gt 200 ] 2>/dev/null; then
    /system/bin/busybox tail -n 150 "$SEND_LOG" > "$SEND_LOG.tmp" 2>/dev/null
    /system/bin/busybox mv "$SEND_LOG.tmp" "$SEND_LOG" 2>/dev/null
  fi
}

logs_list_send() {
  ensure_log_dir
  if [ ! -f "$SEND_LOG" ]; then
    echo '{"reply":"ok","logs":[]}'
    return 0
  fi
  # reverse order (newest first) into temp
  local tmp="$LOG_DIR/sms-send.rev"
  if /system/bin/busybox tac "$SEND_LOG" > "$tmp" 2>/dev/null; then
    :
  else
    /system/bin/busybox awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$SEND_LOG" > "$tmp" 2>/dev/null
  fi
  echo -n '{"reply":"ok","logs":['
  FIRST=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      \{*) ;;
      *) continue ;;
    esac
    if [ $FIRST -eq 1 ]; then FIRST=0; else echo -n ","; fi
    echo -n "$line"
  done < "$tmp"
  echo ']}'
  /system/bin/busybox rm -f "$tmp" 2>/dev/null
}

logs_clear_send() {
  ensure_log_dir
  : > "$SEND_LOG"
  echo '{"reply":"ok","cleared":"sms-send"}'
}
