# shared helpers for CGI
DBG_FLAG="/data/local/tmp/sms-cgi/DEBUG"
DBG_LOG="/data/local/tmp/sms-cgi/logs/debug.log"
DEBUG=0
[ -f "$DBG_FLAG" ] && DEBUG=1

log_dbg() {
  [ "$DEBUG" = "1" ] || return 0
  /system/bin/busybox mkdir -p /data/local/tmp/sms-cgi/logs 2>/dev/null
  echo "$(date +%s 2>/dev/null) $*" >> "$DBG_LOG"
}

json_escape() {
  # sed is line-based: a real newline in $1 would split JSON. Flatten first.
  printf '%s' "$1" | /system/bin/busybox tr '\r\n' '  ' | /system/bin/busybox sed 's/\\/\\\\/g;s/"/\\"/g'
}

is_ipv4() {
  echo "$1" | /system/bin/busybox grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || return 1
  [ "$1" = "0.0.0.0" ] && return 1
  return 0
}

extract_ipv4() {
  echo "$1" | /system/bin/busybox grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | /system/bin/busybox head -n 1
}

# One-shot AT on Qualcomm smd (MSM8916 typically /dev/smd11)
at_chat() {
  local cmd="$1"
  local wait="${2:-2}"
  local p cpid out
  out="/data/local/tmp/sms-cgi/logs/at.out"
  /system/bin/busybox mkdir -p /data/local/tmp/sms-cgi/logs 2>/dev/null
  for p in /dev/smd11 /dev/smd8; do
    [ -e "$p" ] || continue
    : > "$out"
    /system/bin/busybox timeout -t "$wait" cat "$p" > "$out" 2>/dev/null &
    cpid=$!
    sleep 1
    printf '%s\r' "$cmd" > "$p" 2>/dev/null
    sleep "$wait"
    kill "$cpid" 2>/dev/null
    wait "$cpid" 2>/dev/null
    if [ -s "$out" ]; then
      /system/bin/busybox cat "$out"
      return 0
    fi
  done
  echo ""
  return 1
}

# Decode %XX and + → space. Prefer busybox awk / sed fallback.
urldecode() {
  local s="$1"
  # busybox printf %b often works for \xHH
  local out
  out=$(printf '%b' "$(echo "$s" | /system/bin/busybox sed 's/+/ /g;s/%/\\x/g')" 2>/dev/null)
  if [ -n "$out" ] || [ -z "$s" ]; then
    echo -n "$out"
    return 0
  fi
  # fallback: common encodings only
  echo "$s" | /system/bin/busybox sed \
    's/+/ /g;s/%20/ /g;s/%21/!/g;s/%22/"/g;s/%23/#/g;s/%24/$/g;s/%25/%/g;s/%26/\&/g;s/%27/'"'"'/g;s/%28/(/g;s/%29/)/g;s/%2[Bb]/+/g;s/%2[Cc]/,/g;s/%2[Dd]/-/g;s/%2[Ee]/./g;s/%2[Ff]/\//g;s/%3[Aa]/:/g;s/%3[Bb]/;/g;s/%3[Dd]/=/g;s/%3[Ff]/?/g;s/%40/@/g;s/%5[Bb]/[/g;s/%5[Dd]/]/g'
}

parse_query() {
  QS="$QUERY_STRING"
  ACTION=""; ID=""; ADDR=""; BODY=""; READ=""; DATETIME=""; TZ=""; CLIENT_TS=""
  IPFROM=""; IPTO=""; IPSTATUS=""; IPMSG=""; WANFROM=""; WANTO=""
  ENCODING=""; ADDRHEX=""; BODYHEX=""; PDUHEX=""; PDULEN=""
  # Split only on & — do not use word-split (spaces in values are already %20)
  local rest="$QS"
  while [ -n "$rest" ]; do
    local pair="${rest%%&*}"
    if [ "$pair" = "$rest" ]; then
      rest=""
    else
      rest="${rest#*&}"
    fi
    [ -z "$pair" ] && continue
    local key="${pair%%=*}"
    local val="${pair#*=}"
    [ "$key" = "$pair" ] && val=""
    case "$key" in
      action)    ACTION="$val" ;;
      id)        ID="$val" ;;
      address)   ADDR="$val" ;;
      body)      BODY="$val" ;;
      read)      READ="$val" ;;
      datetime)  DATETIME="$val" ;;
      tz)        TZ="$val" ;;
      client_ts) CLIENT_TS="$val" ;;
      ipfrom)    IPFROM="$val" ;;
      ipto)      IPTO="$val" ;;
      ipstatus)  IPSTATUS="$val" ;;
      ipmsg)     IPMSG="$val" ;;
      wanfrom)   WANFROM="$val" ;;
      wanto)     WANTO="$val" ;;
      encoding)  ENCODING="$val" ;;
      addrhex)   ADDRHEX="$val" ;;
      bodyhex)   BODYHEX="$val" ;;
      pduhex)    PDUHEX="$val" ;;
      pdulen)    PDULEN="$val" ;;
    esac
  done
}

http_headers() {
  echo "Content-Type: application/json; charset=utf-8"
  echo "Access-Control-Allow-Origin: *"
  echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
  echo "Access-Control-Allow-Headers: Content-Type"
  echo ""
}
