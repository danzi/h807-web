# shared helpers for CGI
json_escape() {
  echo "$1" | /system/bin/busybox sed 's/\\/\\\\/g;s/"/\\"/g;s/\r//g;s/\n/\\n/g'
}

urldecode() {
  printf '%b' "$(echo "$1" | /system/bin/busybox sed 's/+/ /g;s/%/\\x/g')" 2>/dev/null || \
  echo "$1" | /system/bin/busybox sed 's/+/ /g;s/%20/ /g;s/%3A/:/g;s/%2B/+/g;s/%2D/-/g;s/%2F/\//g'
}

parse_query() {
  QS="$QUERY_STRING"
  ACTION=""; ID=""; ADDR=""; BODY=""; READ=""; DATETIME=""; TZ=""
  for pair in $(echo "$QS" | /system/bin/busybox tr '&' ' '); do
    key=$(echo "$pair" | /system/bin/busybox cut -d= -f1)
    val=$(echo "$pair" | /system/bin/busybox cut -d= -f2-)
    case "$key" in
      action)   ACTION="$val" ;;
      id)       ID="$val" ;;
      address)  ADDR="$val" ;;
      body)     BODY="$val" ;;
      read)     READ="$val" ;;
      datetime) DATETIME="$val" ;;
      tz)       TZ="$val" ;;
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
