#!/system/bin/busybox ash
# Entry point — routes actions to lib modules

CGI_DIR=$(/system/bin/busybox dirname "$0")
. "$CGI_DIR/lib/common.sh"
. "$CGI_DIR/lib/sms.sh"
. "$CGI_DIR/lib/time.sh"

http_headers
parse_query

case "$ACTION" in
  list)       sms_list ;;
  delete)     sms_delete ;;
  mark)       sms_mark ;;
  send)       sms_send ;;
  time_get)   time_get ;;
  time_set)   time_set ;;
  *)          echo '{"reply":"error","msg":"unknown action"}' ;;
esac
