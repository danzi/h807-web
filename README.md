# H807 Pro — Web SMS, IP, time

Custom UI for a rooted H807 Pro (Qualcomm MSM8916, Android 4.4.4). Replaces HiMI token HTTP for SMS, clock, and WAN recycle.

BusyBox `httpd` on **8001**, document root `/data/local/tmp/sms-cgi`. Stock HiMI stays on 192.168.100.1. UI language is English.

## Repo layout

```
h807-web/
├── frontend/                    # Vue 3 (JS, no TS)
│   ├── src/
│   │   ├── pages/               # sms, ip, logs, settings
│   │   ├── interactor/          # use-cases (throw on error)
│   │   ├── repo/                # CGI wrappers
│   │   ├── di/                  # mini container
│   │   ├── utils/               # api, logger, smsEncode, format
│   │   └── main.js
│   ├── assets/css, vendor/
│   ├── index.html
│   └── build.mjs
├── backend/
│   ├── api.cgi                  # router only
│   └── lib/
│       ├── common.sh
│       ├── sms.sh
│       ├── time.sh
│       ├── net.sh
│       └── logs.sh
├── init/start-sms-monitor.sh
└── dist/                        # ← only this goes on the device
```

On the Mac: sources by feature (page → interactor → repo). On the device: `dist/` only.

Debug logs in the browser: `localStorage.setItem('h807_debug','1')` then reload.

## 1. Root

```bash
adb -s 3518106 shell setprop service.adb.root 1
adb -s 3518106 root
adb -s 3518106 shell id
# uid=0(root)
```

BusyBox: `/system/bin/busybox`. `adb root` can drop the USB session — reconnect if `adb devices` is empty.

## 2. Build

```bash
cd frontend
npm i
npm run build                    # → ../dist/
# or: ESBUILD=/path/to/esbuild node build.mjs
```

## 3. Deploy (`dist/` only)

```bash
adb -s 3518106 shell "mkdir -p /data/local/tmp/sms-cgi/js \
  /data/local/tmp/sms-cgi/css /data/local/tmp/sms-cgi/vendor \
  /data/local/tmp/sms-cgi/cgi-bin/lib /data/local/tmp/sms-cgi/logs"

adb -s 3518106 push dist/index.html                /data/local/tmp/sms-cgi/index.html
adb -s 3518106 push dist/js/app.bundle.js          /data/local/tmp/sms-cgi/js/app.bundle.js
adb -s 3518106 push dist/css/app.css               /data/local/tmp/sms-cgi/css/app.css
adb -s 3518106 push dist/vendor/vue.global.prod.js /data/local/tmp/sms-cgi/vendor/vue.global.prod.js
adb -s 3518106 push dist/cgi-bin/api.cgi           /data/local/tmp/sms-cgi/cgi-bin/api.cgi
adb -s 3518106 push dist/cgi-bin/lib/common.sh     /data/local/tmp/sms-cgi/cgi-bin/lib/common.sh
adb -s 3518106 push dist/cgi-bin/lib/sms.sh        /data/local/tmp/sms-cgi/cgi-bin/lib/sms.sh
adb -s 3518106 push dist/cgi-bin/lib/time.sh       /data/local/tmp/sms-cgi/cgi-bin/lib/time.sh
adb -s 3518106 push dist/cgi-bin/lib/net.sh        /data/local/tmp/sms-cgi/cgi-bin/lib/net.sh
adb -s 3518106 push dist/cgi-bin/lib/logs.sh       /data/local/tmp/sms-cgi/cgi-bin/lib/logs.sh
adb -s 3518106 push dist/start-sms-monitor.sh      /data/local/tmp/sms-cgi/start-sms-monitor.sh

adb -s 3518106 shell "chmod 755 /data/local/tmp/sms-cgi/cgi-bin/api.cgi /data/local/tmp/sms-cgi/start-sms-monitor.sh"

adb -s 3518106 shell "/system/bin/busybox killall -9 httpd 2>/dev/null; sleep 1; \
  /system/bin/busybox httpd -p 8001 -h /data/local/tmp/sms-cgi -f &"
```

Browser: `http://<LAN-IP>:8001/` — **Ctrl+Shift+R** after JS/HTML changes (`index.html` cache-busts `app.bundle.js`).

```bash
adb -s 3518106 shell "/system/bin/busybox wget -qO- 'http://127.0.0.1:8001/cgi-bin/api.cgi?action=list'"
adb -s 3518106 shell "/system/bin/busybox wget -qO- 'http://127.0.0.1:8001/cgi-bin/api.cgi?action=time_get'"
adb -s 3518106 shell "/system/bin/busybox wget -qO- 'http://127.0.0.1:8001/cgi-bin/api.cgi?action=ip_get'"
```

## 4. API

JSON `{ "reply": "ok"|"error", "msg": "..." }` plus action fields. `api.cgi` only routes.

| action | Module | Notes |
|--------|--------|--------|
| `list` | sms.sh | Inbox/sent from telephony DB |
| `delete&id=` | sms.sh | |
| `mark&id=&read=` | sms.sh | |
| `send&address=&body=` | sms.sh | AT on `/dev/smd11`. UCS-2: `encoding=ucs2`, `addrhex`, `bodyhex`, `pduhex`, `pdulen`. `client_ts` stores the SMS date. |
| `time_get` | time.sh | Device clock |
| `time_set&datetime=&tz=&client_ts=` | time.sh | POSIX `GMT-3` (busybox has no zoneinfo) |
| `logs_send` / `logs_clear_send` | logs.sh | SMS send log |
| `ip_get` / `ip_history` | net.sh | WAN from `getprop` / ifconfig (not AT) |
| `ip_change` | net.sh | See IP hop below |
| `ip_log` / `ip_clear` | net.sh | History file |

Do not concatenate AT commands on one write — this modem OKs the first and ERRORs the rest.

## 5. SMS

SIM must be READY. Latin goes GSM-7; Cyrillic is UCS-2 (hex), then PDU if needed. One AT per write.

Send log: `/data/local/tmp/sms-cgi/logs/send.log` (Logs tab).

## 6. IP change

HiMI netmode: **0** = 4G/3G, **1** = 4G, **2** = 3G.

`ip_change` reads the current mode, flips to the other of `0`/`1` **without waiting for WAN**, then restores the original (`0→1→0` or `1→0→1`). WAN is checked **after return**. If WAN is unchanged, one retry.

Public IP is polled in the browser (ipify). WAN is the modem 10.x / CGNAT address. History stores both pairs.

Airplane mode is never used (it kills the Wi-Fi AP). Data off/on only.

## 7. Time

Tap the device clock or **Settings**. Apply / sync from the browser. Stored SMS dates use `client_ts`, not the modem’s 2004 default.

## 8. Autostart

Append to `/system/etc/init.qcom.post_boot.sh`:

```sh
/system/bin/sh /data/local/tmp/sms-cgi/start-sms-monitor.sh
```

Starts `httpd -p 8001 -h /data/local/tmp/sms-cgi`. Log: `/data/local/tmp/sms-cgi/autostart.log`.

```bash
adb -s 3518106 pull /system/etc/init.qcom.post_boot.sh ./init.qcom.post_boot.sh.orig
adb -s 3518106 shell "mount -o remount,rw /system"
# patch /system/etc/init.qcom.post_boot.sh
adb -s 3518106 shell "mount -o remount,ro /system"
```

## Device paths

| What | Path |
|------|------|
| Web root | `/data/local/tmp/sms-cgi` |
| API | `.../cgi-bin/api.cgi` + `lib/` |
| Logs | `.../logs/` |
| Serial | `3518106` |
| UI | `http://<IP>:8001/` |
