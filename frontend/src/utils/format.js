export function fmtDate(ts) {
  let d = new Date(Number(ts));
  if (isNaN(d.getTime()) || d.getFullYear() < 2000) d = new Date(Number(ts) * 1000);
  if (isNaN(d.getTime())) return String(ts);
  return d.toLocaleString('en-GB', {
    day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit',
  });
}

function pad(n) {
  return String(n).padStart(2, '0');
}

export function toDateTimeLocal(epochSec) {
  const d = new Date(epochSec * 1000);
  return (
    d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
    ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds())
  );
}

export function nowDateTimeLocal() {
  return toDateTimeLocal(Math.floor(Date.now() / 1000));
}
