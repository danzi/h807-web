#!/system/bin/busybox ash
# Entry point — routes actions to lib modules

CGI_DIR=$(/system/bin/busybox dirname "$0")

# Headers first so a later source error is still JSON, not busybox HTML.
echo "Content-Type: application/json; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

src_ok() {
  # shellcheck disable=SC1090
  . "$1" && return 0
  echo "{\"reply\":\"error\",\"msg\":\"failed to load $1\"}"
  exit 0
}

src_ok "$CGI_DIR/lib/common.sh"
src_ok "$CGI_DIR/lib/logs.sh"
src_ok "$CGI_DIR/lib/time.sh"
src_ok "$CGI_DIR/lib/sms.sh"
src_ok "$CGI_DIR/lib/net.sh"

parse_query
log_dbg "action=$ACTION qs=$QUERY_STRING"

case "$ACTION" in
  list)            sms_list ;;
  delete)          sms_delete ;;
  mark)            sms_mark ;;
  send)            sms_send ;;
  time_get)        time_get ;;
  time_set)        time_set ;;
  time_debug)      time_debug ;;
  logs_send)       logs_list_send ;;
  logs_clear_send) logs_clear_send ;;
  ip_get)          ip_get ;;
  ip_history)      ip_history ;;
  ip_change)       ip_change ;;
  ip_log)          ip_log ;;
  ip_clear)        ip_clear ;;
  *)               echo '{"reply":"error","msg":"unknown action"}' ;;
esac
