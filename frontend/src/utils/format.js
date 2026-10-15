export function fmtDate(ts) {
  const n = Number(ts);
  if (!n || isNaN(n)) return '—';
  // Android stores ms; some firmwares may store seconds
  const ms = n < 1e12 ? n * 1000 : n;
  const d = new Date(ms);
  if (isNaN(d.getTime())) return String(ts);
  const y = d.getFullYear();
  const pad = (x) => String(x).padStart(2, '0');
  // Fixed local format: DD Mon YYYY, HH:MM (no locale quirks)
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const s =
    pad(d.getDate()) +
    ' ' +
    months[d.getMonth()] +
    ' ' +
    y +
    ', ' +
    pad(d.getHours()) +
    ':' +
    pad(d.getMinutes());
  // Clock was wrong when SMS stored (e.g. 1970 / 1995)
  if (y < 2015 || y > 2035) return s + ' ⚠';
  return s;
}

export function isBadDate(ts) {
  const n = Number(ts);
  if (!n || isNaN(n)) return true;
  const ms = n < 1e12 ? n * 1000 : n;
  const d = new Date(ms);
  if (isNaN(d.getTime())) return true;
  const y = d.getFullYear();
  return y < 2015 || y > 2035;
}

function pad(n) {
  return String(n).padStart(2, '0');
}

export function fmtClock(epochSec) {
  const n = Number(epochSec);
  if (!n || isNaN(n)) return '—';
  const d = new Date(n * 1000);
  if (isNaN(d.getTime())) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return (
    days[d.getDay()] +
    ' ' +
    months[d.getMonth()] +
    ' ' +
    pad(d.getDate()) +
    ' ' +
    pad(d.getHours()) +
    ':' +
    pad(d.getMinutes()) +
    ':' +
    pad(d.getSeconds())
  );
}

export function toDateTimeLocal(epochSec) {
  const d = new Date(epochSec * 1000);
  return (
    d.getFullYear() +
    '-' +
    pad(d.getMonth() + 1) +
    '-' +
    pad(d.getDate()) +
    ' ' +
    pad(d.getHours()) +
    ':' +
    pad(d.getMinutes()) +
    ':' +
    pad(d.getSeconds())
  );
}

export function nowDateTimeLocal() {
  return toDateTimeLocal(Math.floor(Date.now() / 1000));
}

export function toDatetimeLocalValue(d) {
  const x = d instanceof Date ? d : new Date();
  if (isNaN(x.getTime())) return '';
  return (
    x.getFullYear() +
    '-' +
    pad(x.getMonth() + 1) +
    '-' +
    pad(x.getDate()) +
    'T' +
    pad(x.getHours()) +
    ':' +
    pad(x.getMinutes())
  );
}

export function fromDatetimeLocalValue(v) {
  const s = String(v || '').trim();
  if (!s) return '';
  const m = s.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(?::(\d{2}))?/);
  if (!m) return s.replace('T', ' ');
  return m[1] + ' ' + m[2] + ':' + (m[3] || '00');
}

export function wallClockToUtc(wall) {
  const local = fromDatetimeLocalValue(wall);
  if (!local) return '';
  const d = new Date(local.replace(' ', 'T'));
  if (isNaN(d.getTime())) return local;
  return (
    d.getUTCFullYear() +
    '-' +
    pad(d.getUTCMonth() + 1) +
    '-' +
    pad(d.getUTCDate()) +
    ' ' +
    pad(d.getUTCHours()) +
    ':' +
    pad(d.getUTCMinutes()) +
    ':' +
    pad(d.getUTCSeconds())
  );
}
