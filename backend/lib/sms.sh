# SMS actions (content provider + isms)

sms_list() {
  RAW=$(/system/bin/content query --uri content://sms --projection _id:address:date:body:type:read --sort "date DESC" 2>&1)
  if echo "$RAW" | /system/bin/busybox grep -q "No result found"; then
    echo '{"reply":"ok","sms":[]}'; return 0
  fi
  echo -n '{"reply":"ok","sms":['
  FIRST=1
  echo "$RAW" | while IFS= read -r line; do
    id=$(echo "$line" | /system/bin/busybox sed -n 's/.*_id=\([0-9]*\).*/\1/p')
    addr=$(echo "$line" | /system/bin/busybox sed -n 's/.*address=\([^,]*\).*/\1/p')
    date=$(echo "$line" | /system/bin/busybox sed -n 's/.*date=\([0-9]*\).*/\1/p')
    body=$(echo "$line" | /system/bin/busybox sed -n 's/.*body=\([^,]*\), type=.*/\1/p')
    type=$(echo "$line" | /system/bin/busybox sed -n 's/.*type=\([0-9]*\).*/\1/p')
    read=$(echo "$line" | /system/bin/busybox sed -n 's/.*read=\([0-9]*\).*/\1/p')
    [ -z "$id" ] && continue
    body=$(echo "$body" | /system/bin/busybox sed 's/"/\\"/g')
    if [ $FIRST -eq 1 ]; then FIRST=0; else echo -n ","; fi
    echo -n "{\"id\":$id,\"address\":\"$addr\",\"date\":$date,\"body\":\"$body\",\"type\":$type,\"read\":$read}"
  done
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

sms_send() {
  if [ -z "$ADDR" ] || [ -z "$BODY" ]; then
    echo '{"reply":"error","msg":"address and body required"}'; return 0
  fi
  ADDR=$(urldecode "$ADDR")
  BODY=$(urldecode "$BODY")
  OUT=""; OK=0
  OUT=$(service call isms 5 s16 "com.android.mms" s16 "$ADDR" s16 "null" s16 "$BODY" i32 0 i32 0 2>&1)
  if echo "$OUT" | /system/bin/busybox grep -qiE 'SecurityException|Exception|Permission|denied|Error|ffffffff'; then
    OUT2=$(service call isms 5 s16 "$ADDR" i32 0 i32 0 s16 "$BODY" 2>&1)
    if ! echo "$OUT2" | /system/bin/busybox grep -qiE 'SecurityException|Exception|Permission|denied|Error|ffffffff'; then
      OUT="$OUT2"; OK=1
    else
      OUT3=$(service call isms 7 s16 "com.android.mms" s16 "$ADDR" s16 "null" s16 "$BODY" i32 0 i32 0 2>&1)
      if ! echo "$OUT3" | /system/bin/busybox grep -qiE 'SecurityException|Exception|Permission|denied|Error|ffffffff'; then
        OUT="$OUT3"; OK=1
      else
        OUT="$OUT | $OUT2 | $OUT3"; OK=0
      fi
    fi
  else
    OK=1
  fi
  ERRMSG=$(echo "$OUT" | /system/bin/busybox tr -d '\0' | /system/bin/busybox sed 's/[^[:print:][:space:]]//g' | /system/bin/busybox tr '\n' ' ' | /system/bin/busybox sed 's/  */ /g')
  ERRMSG=$(json_escape "$ERRMSG")
  if [ "$OK" -eq 1 ]; then
    NOW=$(date +%s000 2>/dev/null || echo 0)
    /system/bin/content insert --uri content://sms/sent \
      --bind address:s:"$ADDR" --bind body:s:"$BODY" \
      --bind date:l:$NOW --bind read:i:1 --bind type:i:2 2>&1 >/dev/null
    echo '{"reply":"ok","msg":"sent","detail":"'"$ERRMSG"'"}'
  else
    echo '{"reply":"error","msg":"send failed (need SIM + radio)","detail":"'"$ERRMSG"'"}'
  fi
}
