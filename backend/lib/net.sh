# WAN IP + 4G/3G/auto (HiMI netmode 0/1/2) without their token API
# 0 = 4G/3G, 1 = 4G, 2 = 3G

IP_LOG_DIR="/data/local/tmp/sms-cgi/logs"
IP_LOG="$IP_LOG_DIR/ip-history.log"
IP_MAX_ATTEMPTS=2

ensure_ip_dir() {
  /system/bin/busybox mkdir -p "$IP_LOG_DIR" 2>/dev/null
}

http_get() {
  local url="$1"
  /system/bin/busybox wget -q -O - -T 8 "$url" 2>/dev/null
}

_is_lan_ip() {
  case "$1" in
    127.*|192.168.*|169.254.*) return 0 ;;
    *) return 1 ;;
  esac
}

collect_inet_ips() {
  ifconfig 2>/dev/null | /system/bin/busybox sed -n \
    's/.*inet addr:\([0-9.]*\).*/\1/p;s/.*inet \([0-9.]*\).*/\1/p'
  /system/bin/busybox ip -f inet addr show 2>/dev/null | /system/bin/busybox sed -n \
    's/.*inet \([0-9.]*\).*/\1/p'
}

# Instant WAN (getprop / ifconfig). Do not call AT here — at_chat is ~3s/port
# and made the IP page look hung on every open/refresh.
wan_from_props() {
  local ip p
  for p in dhcp.rmnet_data0.ipaddress dhcp.rmnet0.ipaddress dhcp.ccmni0.ipaddress \
           net.rmnet_data0.ip net.rmnet0.ip net.gprs.local-ip net.ppp0.local-ip; do
    ip=$(getprop "$p" 2>/dev/null)
    if is_ipv4 "$ip" && ! _is_lan_ip "$ip"; then
      echo "$ip"
      return 0
    fi
  done
  for ip in $(collect_inet_ips); do
    is_ipv4 "$ip" || continue
    _is_lan_ip "$ip" && continue
    echo "$ip"
    return 0
  done
  echo ""
}

wan_iface_ip() {
  local ip
  ip=$(wan_from_props)
  [ -n "$ip" ] && echo "$ip" && return 0
  wan_at_ip
}

# Bearer IP from modem (often CGNAT 10.x). One port, short wait.
wan_at_ip() {
  local raw ip
  raw=$(at_chat "AT+CGPADDR" 1)
  ip=$(extract_ipv4 "$raw")
  if is_ipv4 "$ip" && ! _is_lan_ip "$ip"; then
    echo "$ip"
    return 0
  fi
  echo ""
}

public_ip() {
  local ip u body
  # HTTP only — HTTPS redirects return HTML, not an address.
  for u in "http://api.ipify.org" "http://ipv4.icanhazip.com" "http://checkip.amazonaws.com"; do
    body=$(http_get "$u")
    ip=$(extract_ipv4 "$body")
    if is_ipv4 "$ip"; then
      echo "$ip"
      return 0
    fi
  done
  echo ""
}

# Prefer public; fall back to carrier/WAN iface (10.x is fine)
current_ip() {
  local ip
  ip=$(public_ip)
  [ -n "$ip" ] && echo "$ip" && return 0
  wan_iface_ip
}

radio_type() {
  getprop gsm.network.type 2>/dev/null
}

# Map RIL preferred_network_mode → HiMI 0/1/2
ril_to_himi() {
  local n="$1"
  case "$n" in
    11) echo 1 ;;
    1|2) echo 2 ;;
    0|9|10|12|13) echo 0 ;;
    *) echo "" ;;
  esac
}

himi_from_radio() {
  local r
  r=$(echo "$1" | /system/bin/busybox tr 'A-Z' 'a-z')
  case "$r" in
    lte|lte_ca) echo 1 ;;
    umts|hspa|hsdpa|hsupa|hspap|wcdma|td_scdma) echo 2 ;;
    *) echo "" ;;
  esac
}

# Current HiMI netmode 0/1/2
himi_mode() {
  local ril himi
  ril=$(settings get global preferred_network_mode 2>/dev/null)
  himi=$(ril_to_himi "$ril")
  [ -z "$himi" ] && himi=$(himi_from_radio "$(radio_type)")
  [ -z "$himi" ] && himi=1
  echo "$himi"
}

himi_label() {
  case "$1" in
    0) echo "4G/3G" ;;
    1) echo "4G" ;;
    2) echo "3G" ;;
    *) echo "unknown" ;;
  esac
}

net_at() {
  local cmd="$1"
  local d
  for d in /dev/smd8 /dev/smd11 /dev/smd7 /dev/smd0; do
    [ -e "$d" ] || continue
    printf '%s\r' "$cmd" > "$d" 2>/dev/null
  done
}

# HiMI netmode → RIL + AT (same as their setnetworkmode, without token)
net_set_himi() {
  local himi="$1"
  local ril at
  case "$himi" in
    0) ril=12; at="AT+CNMP=2" ;;
    2) ril=2;  at="AT+CNMP=14" ;;
    *) himi=1; ril=11; at="AT+CNMP=38" ;;
  esac
  settings put global preferred_network_mode "$ril" 2>/dev/null
  settings put global preferred_network_mode1 "$ril" 2>/dev/null
  setprop persist.radio.networkmode "$ril" 2>/dev/null
  local t
  for t in 73 74 83 91 96 103 104 109 133; do
    service call phone "$t" i32 "$ril" >/dev/null 2>&1
    service call phone "$t" i32 0 i32 "$ril" >/dev/null 2>&1
  done
  net_at "$at"
  log_dbg "net_set_himi $himi ril=$ril at=$at radio=$(radio_type)"
}

wait_radio() {
  local i=0 r
  while [ $i -lt 12 ]; do
    r=$(radio_type)
    if [ -n "$r" ] && ! echo "$r" | /system/bin/busybox grep -qiE 'Unknown|^$'; then
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done
  return 1
}

# Mobile data only — never airplane (that also kills the Wi-Fi AP).
net_mobile_off() {
  svc data disable >/dev/null 2>&1
  net_at "AT+CGATT=0"
  net_at "AT+CGACT=0"
}

net_mobile_on() {
  svc data enable >/dev/null 2>&1
  net_at "AT+CGATT=1"
  net_at "AT+CGACT=1"
}

# One PDP recycle onto the given HiMI mode. Needed because 4G↔3G without
# detach keeps the same QCMAP/CGNAT lease (GetWANIP / 10.x stays put).
net_hop_mode() {
  local mode="$1"
  net_mobile_off
  sleep 3
  net_set_himi "$mode"
  sleep 2
  net_mobile_on
}

# Other of 0 (4G/3G) / 1 (4G). Mode 2 (3G) flips to 1.
_ip_other_mode() {
  if [ "$1" = "1" ]; then
    echo 0
  else
    echo 1
  fi
}

# orig → other → orig. Do not wait for WAN on the intermediate step.
net_hop_out_and_back() {
  local orig="$1"
  local other="$2"
  net_mobile_off
  sleep 2
  net_set_himi "$other"
  sleep 1
  net_set_himi "$orig"
  sleep 2
  net_mobile_on
}

wait_wan() {
  local prev="$1"
  local i=0 wan
  while [ $i -lt 10 ]; do
    sleep 2
    wan=$(wan_iface_ip)
    if [ -n "$wan" ]; then
      if [ -z "$prev" ] || [ "$wan" != "$prev" ]; then
        echo "$wan"
        return 0
      fi
      # still have an address (same or not) after radio is back
      if [ $i -ge 4 ]; then
        echo "$wan"
        return 0
      fi
    fi
    i=$((i + 1))
  done
  echo "$(wan_iface_ip)"
}

ip_log_append() {
  ensure_ip_dir
  local status="$1"
  local ip_from="$2"
  local ip_to="$3"
  local wan_from="$4"
  local wan_to="$5"
  local msg="$6"
  local ts when
  ts=$(date +%s 2>/dev/null || echo 0)
  ts="${ts}000"
  when=$(date 2>/dev/null | /system/bin/busybox tr -d '\n' || echo "")
  status=$(json_escape "$status")
  ip_from=$(json_escape "$ip_from")
  ip_to=$(json_escape "$ip_to")
  wan_from=$(json_escape "$wan_from")
  wan_to=$(json_escape "$wan_to")
  msg=$(json_escape "$msg")
  when=$(json_escape "$when")
  printf '%s\n' "{\"ts\":$ts,\"when\":\"$when\",\"status\":\"$status\",\"from\":\"$ip_from\",\"to\":\"$ip_to\",\"ipFrom\":\"$ip_from\",\"ipTo\":\"$ip_to\",\"wanFrom\":\"$wan_from\",\"wanTo\":\"$wan_to\",\"msg\":\"$msg\"}" >> "$IP_LOG"
  local lines
  lines=$(/system/bin/busybox wc -l < "$IP_LOG" 2>/dev/null || echo 0)
  if [ "$lines" -gt 200 ] 2>/dev/null; then
    /system/bin/busybox tail -n 150 "$IP_LOG" > "$IP_LOG.tmp" 2>/dev/null
    /system/bin/busybox mv "$IP_LOG.tmp" "$IP_LOG" 2>/dev/null
  fi
}

# Complete one-line object. Do not use "}" in `case` inside a function — ash
# treats it as end of the function and previously wiped the log file.
_ip_json_line() {
  echo "$1" | /system/bin/busybox grep -q '^[{].*[}]$'
}

ip_history_json() {
  ensure_ip_dir
  if [ ! -f "$IP_LOG" ]; then
    echo '[]'
    return 0
  fi
  local tmp="$IP_LOG_DIR/ip-history.rev"
  if /system/bin/busybox tac "$IP_LOG" > "$tmp" 2>/dev/null; then
    :
  else
    /system/bin/busybox awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$IP_LOG" > "$tmp" 2>/dev/null
  fi
  echo -n '['
  FIRST=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    _ip_json_line "$line" || continue
    if [ $FIRST -eq 1 ]; then FIRST=0; else echo -n ","; fi
    printf '%s' "$line"
  done < "$tmp"
  echo ']'
  /system/bin/busybox rm -f "$tmp" 2>/dev/null
}

ip_note_if_new() {
  local ip="$1"
  [ -z "$ip" ] && return 0
  ensure_ip_dir
  local last=""
  if [ -f "$IP_LOG" ]; then
    last=$(/system/bin/busybox tail -n 1 "$IP_LOG")
    last=$(echo "$last" | /system/bin/busybox sed -n 's/.*"to":"\([^"]*\)".*/\1/p')
  fi
  if [ "$ip" != "$last" ]; then
    ip_log_append "seen" "$last" "$ip" "" "" "Was ${last:-none}, now $ip"
  fi
}

ip_status_fields() {
  local wan himi lab radio ril
  wan=$(wan_from_props)
  himi=$(himi_mode)
  lab=$(himi_label "$himi")
  radio=$(radio_type)
  ril=$(settings get global preferred_network_mode 2>/dev/null)
  wan=$(json_escape "$wan")
  lab=$(json_escape "$lab")
  radio=$(json_escape "$radio")
  ril=$(json_escape "$ril")
  echo -n "\"ip\":\"\",\"wan\":\"$wan\",\"mode\":\"$himi\",\"mode_label\":\"$lab\",\"radio\":\"$radio\",\"ril\":\"$ril\""
}

ip_get() {
  echo -n '{"reply":"ok","msg":"ok",'
  ip_status_fields
  echo '}'
}

ip_history() {
  echo -n '{"reply":"ok","msg":"ok",'
  ip_status_fields
  echo -n ',"logs":'
  ip_history_json
  echo '}'
}

# orig → other → orig (0→1→0 or 1→0→1). Wait for WAN only after return.
# Second pass only if WAN is still the same. Public IP is read in the browser.
ip_change() {
  local orig other wan0 wan2 attempt himi lab radio
  orig=$(himi_mode)
  [ -z "$orig" ] && orig=1
  other=$(_ip_other_mode "$orig")
  wan0=$(wan_iface_ip)
  log_dbg "ip_change orig=$orig other=$other wan0=$wan0"

  attempt=1
  wan2="$wan0"
  while [ "$attempt" -le "$IP_MAX_ATTEMPTS" ]; do
    net_hop_out_and_back "$orig" "$other"
    wan2=$(wait_wan "$wan0")
    log_dbg "ip_change try=$attempt back=$orig wan=$wan2 radio=$(radio_type)"
    if [ -n "$wan2" ] && [ "$wan2" != "$wan0" ]; then
      break
    fi
    attempt=$((attempt + 1))
  done

  himi=$(himi_mode)
  [ -z "$himi" ] && himi="$orig"
  lab=$(himi_label "$himi")
  radio=$(radio_type)
  echo "{\"reply\":\"ok\",\"msg\":\"mode hop done\",\"mode\":\"$(json_escape "$himi")\",\"mode_label\":\"$(json_escape "$lab")\",\"from\":\"$(json_escape "$wan0")\",\"to\":\"$(json_escape "$wan2")\",\"wan\":\"$(json_escape "$wan2")\",\"radio\":\"$(json_escape "$radio")\"}"
}

ip_log() {
  local from to status msg wfrom wto
  from=$(urldecode "$IPFROM")
  to=$(urldecode "$IPTO")
  wfrom=$(urldecode "$WANFROM")
  wto=$(urldecode "$WANTO")
  status=$(urldecode "$IPSTATUS")
  msg=$(urldecode "$IPMSG")
  [ -z "$status" ] && status="seen"
  [ -z "$msg" ] && msg="IP ${from:-—} → ${to:-—} · WAN ${wfrom:-—} → ${wto:-—}"
  ip_log_append "$status" "$from" "$to" "$wfrom" "$wto" "$msg"
  echo "{\"reply\":\"ok\",\"msg\":\"$(json_escape "$msg")\",\"from\":\"$(json_escape "$from")\",\"to\":\"$(json_escape "$to")\",\"ipFrom\":\"$(json_escape "$from")\",\"ipTo\":\"$(json_escape "$to")\",\"wanFrom\":\"$(json_escape "$wfrom")\",\"wanTo\":\"$(json_escape "$wto")\"}"
}

ip_clear() {
  ensure_ip_dir
  : > "$IP_LOG"
  echo '{"reply":"ok","msg":"cleared","cleared":"ip-history"}'
}
