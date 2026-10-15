# SMS actions (content provider + isms)

sms_now_ms() {
  local ts
  ts=$(client_ts_ms)
  if [ "$ts" != "0" ] && [ -n "$ts" ]; then
    echo "$ts"
    return 0
  fi
  ts=$(/system/bin/busybox date +%s 2>/dev/null)
  [ -z "$ts" ] && ts=$(date +%s 2>/dev/null)
  if epoch_sec_ok "$ts"; then
    echo "${ts}000"
    return 0
  fi
  echo "0"
  return 1
}

# This firmware stores sms.date as Unix seconds (10 digits), not ms.
# content --bind date:l:<13-digit ms> is dropped; RIL then leaves 2004 SCTS.
sms_now_sec() {
  local ts
  ts=$(echo "$CLIENT_TS" | /system/bin/busybox tr -cd '0-9')
  if [ "${#ts}" -ge 10 ]; then
    echo "$ts" | /system/bin/busybox cut -c1-10
    return 0
  fi
  ts=$(/system/bin/busybox date +%s 2>/dev/null)
  [ -z "$ts" ] && ts=$(date +%s 2>/dev/null)
  if epoch_sec_ok "$ts"; then
    echo "$ts"
    return 0
  fi
  echo "0"
  return 1
}

sms_stamp() {
  local id="$1"
  local sec="$2"
  [ -z "$id" ] && return 1
  [ "$sec" = "0" ] && return 1
  /system/bin/content update --uri content://sms --where "_id=$id" \
    --bind date:l:"$sec" --bind date_sent:l:"$sec" >/dev/null 2>&1
}

# Stamp every row inserted after $before (AT path often inserts after our first wait).
sms_stamp_since() {
  local before="$1"
  local sec="$2"
  local raw id
  [ "$sec" = "0" ] && return 0
  raw=$(/system/bin/content query --uri content://sms --projection _id 2>/dev/null)
  echo "$raw" | /system/bin/busybox sed -n 's/.*_id=\([0-9][0-9]*\).*/\1/p' | while read -r id; do
    if [ -n "$id" ] && [ "$id" -gt "$before" ] 2>/dev/null; then
      sms_stamp "$id" "$sec"
    fi
  done
}

# Extract field value from content query Row line.
# Handles: field=value, field="value", trailing comma or end of line.
# Usage: sms_field "$line" fieldname
sms_field() {
  local line="$1"
  local name="$2"
  local val
  # Prefer quoted value
  val=$(echo "$line" | /system/bin/busybox sed -n "s/.*[, ]${name}=\"\\([^\"]*\\)\".*/\\1/p")
  if [ -n "$val" ]; then
    echo "$val"
    return 0
  fi
  # Unquoted: value ends at next ", field=" or end
  val=$(echo "$line" | /system/bin/busybox sed -n "s/.*[, ]${name}=\\([^,]*\\).*/\\1/p")
  echo "$val"
}

sms_list() {
  RAW=$(/system/bin/content query --uri content://sms --projection _id:address:date:body:type:read --sort "date DESC" 2>&1)
  if echo "$RAW" | /system/bin/busybox grep -q "No result found"; then
    echo '{"reply":"ok","sms":[]}'; return 0
  fi
  # Also accept empty / error that is not rows
  if ! echo "$RAW" | /system/bin/busybox grep -q "^Row:"; then
    # fallback without projection (some firmwares ignore projection order)
    RAW=$(/system/bin/content query --uri content://sms --sort "date DESC" 2>&1)
    if echo "$RAW" | /system/bin/busybox grep -q "No result found"; then
      echo '{"reply":"ok","sms":[]}'; return 0
    fi
  fi
  TMP="/data/local/tmp/sms-cgi/logs/sms-list.raw"
  /system/bin/busybox mkdir -p /data/local/tmp/sms-cgi/logs 2>/dev/null
  echo "$RAW" > "$TMP"
  echo -n '{"reply":"ok","sms":['
  FIRST=1
  while IFS= read -r line; do
    case "$line" in
      Row:*) ;;
      *) continue ;;
    esac
    id=$(sms_field "$line" "_id")
    [ -z "$id" ] && id=$(sms_field "$line" "id")
    addr=$(sms_field "$line" "address")
    date=$(sms_field "$line" "date")
    # date must be digits only
    date=$(echo "$date" | /system/bin/busybox tr -cd '0-9')
    body=$(sms_field "$line" "body")
    # If body extraction failed because of commas in body, take everything between body= and , type=
    if [ -z "$body" ] || echo "$line" | /system/bin/busybox grep -q 'body=.*,.*, type='; then
      body2=$(echo "$line" | /system/bin/busybox sed -n 's/.*[, ]body=\(.*\), type=.*/\1/p')
      [ -n "$body2" ] && body="$body2"
    fi
    type=$(sms_field "$line" "type")
    type=$(echo "$type" | /system/bin/busybox tr -cd '0-9')
    read=$(sms_field "$line" "read")
    read=$(echo "$read" | /system/bin/busybox tr -cd '0-9')
    [ -z "$id" ] && continue
    [ -z "$date" ] && date=0
    [ -z "$type" ] && type=0
    [ -z "$read" ] && read=0
    # Normalize date: if looks like seconds (10 digits), keep as-is; frontend multiplies
    # if already ms (13+), keep. Never invent.
    body=$(echo "$body" | /system/bin/busybox sed 's/\\/\\\\/g;s/"/\\"/g;s/\r//g;s/\n/\\n/g')
    addr=$(echo "$addr" | /system/bin/busybox sed 's/\\/\\\\/g;s/"/\\"/g')
    if [ $FIRST -eq 1 ]; then FIRST=0; else echo -n ","; fi
    echo -n "{\"id\":$id,\"address\":\"$addr\",\"date\":$date,\"body\":\"$body\",\"type\":$type,\"read\":$read}"
  done < "$TMP"
  echo ']}'
}

sms_delete() {
  if [ -z "$ID" ]; then echo '{"reply":"error","msg":"id required"}'; return 0; fi
  /system/bin/content delete --uri content://sms --where "_id=$ID" 2>&1 >/dev/null
  echo '{"reply":"ok","deleted":"'"$ID"'"}'
}

sms_mark() {
  if [ -z "$ID" ] || [ -z "$READ" ]; then
    echo '{"reply":"error","msg":"id and read required"}'; return 0
  fi
  /system/bin/content update --uri content://sms --bind read:i:$READ --where "_id=$ID" 2>&1 >/dev/null
  echo '{"reply":"ok","id":"'"$ID"'","read":"'"$READ"'"}'
}

sms_max_id() {
  local raw max
  raw=$(/system/bin/content query --uri content://sms --projection _id 2>/dev/null)
  max=$(echo "$raw" | /system/bin/busybox sed -n 's/.*_id=\([0-9][0-9]*\).*/\1/p' | /system/bin/busybox sort -n | /system/bin/busybox tail -n 1)
  echo "${max:-0}"
}

# Binder exception header: first word fffffffc = EX_NULL_POINTER (-4). That is NOT a send.
_sms_isms_ok() {
  local result="$1"
  if echo "$result" | /system/bin/busybox grep -qiE 'SecurityException|DeadObject|Permission denied|Unknown transaction|does not exist'; then
    return 1
  fi
  if echo "$result" | /system/bin/busybox grep -qE 'fffffffc|EX_NULL|NullPointer'; then
    return 1
  fi
  echo "$result" | /system/bin/busybox grep -q 'Parcel(00000000' && return 0
  return 1
}

_sms_snoop() {
  local p="$1"
  local out="$2"
  /system/bin/busybox dd if="$p" of="$out" bs=1 2>/dev/null &
  echo $!
}

_sms_wait_token() {
  local out="$1"
  local pat="$2"
  local tries="$3"
  local i=0
  while [ $i -lt "$tries" ]; do
    if /system/bin/busybox grep -qE "$pat" "$out" 2>/dev/null; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

# One AT per write. Burst ATE0+CMGF+CSCS on this Qualcomm → first OK, rest ERROR.
_sms_line() {
  printf '%s\r' "$1" > "$2" 2>/dev/null
  sleep 1
}

_sms_at_try() {
  local p="$1"
  local mode="$2"
  local cmgs="$3"
  local payload="$4"
  local tag="$5"
  local out cpid
  out="/data/local/tmp/sms-cgi/logs/at-sms.out"
  : > "$out"
  /system/bin/busybox chmod 644 "$out" 2>/dev/null
  cpid=$(_sms_snoop "$p" "$out")
  sleep 1
  _sms_line "ATE0" "$p"
  if [ "$mode" = "pdu" ]; then
    _sms_line "AT+CMGF=0" "$p"
  elif [ "$mode" = "ucs2" ]; then
    _sms_line "AT+CMGF=1" "$p"
    _sms_line 'AT+CSCS="UCS2"' "$p"
    _sms_line "AT+CSMP=17,167,0,8" "$p"
  else
    _sms_line "AT+CMGF=1" "$p"
    _sms_line 'AT+CSCS="GSM"' "$p"
  fi
  printf '%s\r' "$cmgs" > "$p" 2>/dev/null
  if ! _sms_wait_token "$out" '>' 5; then
    OUT=$(cat "$out" 2>/dev/null)
    _sms_line "AT+CMGF=1" "$p"
    _sms_line 'AT+CSCS="GSM"' "$p"
    kill "$cpid" 2>/dev/null
    wait "$cpid" 2>/dev/null
    return 1
  fi
  printf '%s' "$payload" > "$p" 2>/dev/null
  /system/bin/busybox printf '\x1a' > "$p" 2>/dev/null
  _sms_wait_token "$out" '\+CMGS:|\+CMS ERROR' 10
  OUT=$(cat "$out" 2>/dev/null)
  _sms_line "AT+CMGF=1" "$p"
  _sms_line 'AT+CSCS="GSM"' "$p"
  kill "$cpid" 2>/dev/null
  wait "$cpid" 2>/dev/null
  /system/bin/busybox chmod 644 "$out" 2>/dev/null
  if echo "$OUT" | /system/bin/busybox grep -q '+CMGS:'; then
    METHOD="$tag"
    OK=1
    return 0
  fi
  return 1
}

_sms_at_send() {
  local hex_body hex_addr hex_pdu pdu_len p
  hex_body=$(echo "$BODYHEX" | /system/bin/busybox tr -cd '0-9A-Fa-f')
  hex_addr=$(echo "$ADDRHEX" | /system/bin/busybox tr -cd '0-9A-Fa-f')
  hex_pdu=$(echo "$PDUHEX" | /system/bin/busybox tr -cd '0-9A-Fa-f')
  pdu_len=$(echo "$PDULEN" | /system/bin/busybox tr -cd '0-9')
  p=/dev/smd11
  [ -e "$p" ] || p=/dev/smd8
  [ -e "$p" ] || return 1

  if [ -n "$hex_body" ]; then
    if [ -n "$hex_addr" ] && _sms_at_try "$p" ucs2 "AT+CMGS=\"$hex_addr\"" "$hex_body" "at+ucs2:$p"; then
      return 0
    fi
    if _sms_at_try "$p" ucs2 "AT+CMGS=\"$ADDR\"" "$hex_body" "at+ucs2-ascii:$p"; then
      return 0
    fi
  fi
  if [ -n "$hex_pdu" ] && [ -n "$pdu_len" ]; then
    if _sms_at_try "$p" pdu "AT+CMGS=$pdu_len" "$hex_pdu" "at+pdu:$p"; then
      return 0
    fi
  fi
  if [ -z "$hex_body" ]; then
    _sms_at_try "$p" gsm "AT+CMGS=\"$ADDR\"" "$BODY" "at+gsm:$p"
    return $?
  fi
  return 1
}

_sms_try_isms5() {
  local pkg="$1"
  local result
  # KitKat ISms.sendText = txn 5
  # scAddr MUST be empty (default SMSC). s16 "null" is a literal invalid SMSC.
  result=$(service call isms 5 s16 "$pkg" s16 "$ADDR" s16 "" s16 "$BODY" i32 0 i32 0 2>&1)
  log_dbg "isms5 pkg=$pkg result=$result"
  if _sms_isms_ok "$result"; then
    OUT="$result"
    OK=1
    METHOD="isms5:$pkg"
    return 0
  fi
  OUT="${OUT:+$OUT | }$result"
  return 1
}

_sms_wait_new() {
  local before="$1"
  local tries="${2:-12}"
  local i=0 id
  while [ $i -lt "$tries" ]; do
    sleep 1
    id=$(sms_max_id)
    if [ -n "$id" ] && [ "$id" -gt "$before" ] 2>/dev/null; then
      echo "$id"
      return 0
    fi
    i=$((i + 1))
  done
  echo ""
  return 1
}

sms_send() {
  if [ -z "$ADDR" ] || [ -z "$BODY" ]; then
    echo '{"reply":"error","msg":"address and body required"}'; return 0
  fi
  ADDR=$(urldecode "$ADDR")
  BODY=$(urldecode "$BODY")
  ADDR=$(echo "$ADDR" | /system/bin/busybox tr -d '\n\r\0"')
  BODY=$(echo "$BODY" | /system/bin/busybox tr -d '\0')

  # Do not rewrite a good NITZ clock (that was producing 1970).
  # If the SoC is already in 1970/2004, apply the browser datetime string.
  time_sync_if_bad

  local sim radio
  sim=$(getprop gsm.sim.state 2>/dev/null)
  [ -z "$sim" ] && sim=$(getprop ril.sim.state 2>/dev/null)
  radio=$(getprop gsm.network.type 2>/dev/null)
  log_dbg "sms_send addr=$ADDR sim=$sim radio=$radio"

  if echo "$sim" | /system/bin/busybox grep -qiE 'ABSENT|NOT_READY|UNKNOWN|^$'; then
    if [ "$sim" = "ABSENT" ]; then
      log_send "error" "$ADDR" "$BODY" "SIM ABSENT"
      echo '{"reply":"error","msg":"SIM is absent — insert a SIM before sending","detail":"gsm.sim.state='"$sim"'"}'
      return 0
    fi
  fi

  OUT=""; OK=0; METHOD=""
  local before newid
  before=$(sms_max_id)

  # ISms.sendText (isms txn 5) always returns EX_NULL_POINTER on this KitKat
  # build (null PendingIntent). Skip it — it only wasted ~4s per send.
  _sms_at_send

  newid=""
  if [ "$OK" -ne 1 ]; then
    newid=$(_sms_wait_new "$before" 4)
    if [ -n "$newid" ]; then
      OK=1
      METHOD="${METHOD:-at-cmgs-assumed}"
    fi
  fi
  if [ "$OK" -eq 1 ] && [ -z "$newid" ]; then
    newid=$(_sms_wait_new "$before" 4)
  fi

  local ERRMSG SEC
  ERRMSG=$(echo "$OUT" | /system/bin/busybox tr -d '\0' | /system/bin/busybox sed 's/[^[:print:][:space:]]//g' | /system/bin/busybox tr '\n' ' ' | /system/bin/busybox sed 's/  */ /g')
  ERRMSG=$(json_escape "$ERRMSG")
  NOW=$(sms_now_ms)
  [ -z "$NOW" ] && NOW=0
  SEC=$(sms_now_sec)
  [ -z "$SEC" ] && SEC=0

  if [ "$OK" -eq 1 ]; then
    if [ -z "$newid" ] && [ "$SEC" != "0" ]; then
      /system/bin/content insert --uri content://sms/sent \
        --bind address:s:"$ADDR" --bind body:s:"$BODY" \
        --bind date:l:"$SEC" --bind date_sent:l:"$SEC" \
        --bind read:i:1 --bind type:i:2 --bind seen:i:1 >/dev/null 2>&1
      newid=$(_sms_wait_new "$before" 4)
    fi
    sms_stamp_since "$before" "$SEC"
    if [ -n "$newid" ]; then
      sms_stamp "$newid" "$SEC"
    else
      newid=$(sms_max_id)
    fi
    log_send "ok" "$ADDR" "$BODY" "method=$METHOD id=${newid:-none} sec=$SEC radio=$radio sim=$sim $ERRMSG"
    echo '{"reply":"ok","msg":"sent","detail":"'"$METHOD"' id='"${newid:-none}"' sim='"$sim"' radio='"$radio"' '"$ERRMSG"'","date":'"$NOW"'}'
  else
    log_send "error" "$ADDR" "$BODY" "sim=$sim radio=$radio $ERRMSG"
    local fail
    fail="Send failed"
    echo "$OUT" | /system/bin/busybox grep -q '305' && fail="Phone rejected the alphabet (Cyrillic needs UCS-2)"
    echo "$OUT" | /system/bin/busybox grep -qE '\+CMS ERROR: 500|\+CMS ERROR: 302' && fail="Network/SMSC rejected the SMS"
    echo '{"reply":"error","msg":"'"$fail"'","detail":"sim='"$sim"' radio='"$radio"' '"$ERRMSG"'"}'
  fi
}
