function hex2(n) {
  const s = n.toString(16).toUpperCase();
  return s.length < 2 ? '0' + s : s;
}

export function utf16BeHex(str) {
  let h = '';
  const s = String(str || '');
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    h += hex2((c >> 8) & 0xff) + hex2(c & 0xff);
  }
  return h;
}

const GSM =
  "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" +
  "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà|^€{}[]~\\";

export function isGsm7(str) {
  const s = String(str || '');
  for (let i = 0; i < s.length; i++) {
    if (GSM.indexOf(s.charAt(i)) < 0) return false;
  }
  return true;
}

export function smsUnits(body) {
  const s = String(body || '');
  if (isGsm7(s)) {
    const n = s.length;
    if (n <= 160) return { alphabet: 'GSM', chars: n, per: 160, segs: n ? 1 : 0 };
    return { alphabet: 'GSM', chars: n, per: 153, segs: Math.ceil(n / 153) };
  }
  const n = s.length;
  if (n <= 70) return { alphabet: 'UCS-2', chars: n, per: 70, segs: n ? 1 : 0 };
  return { alphabet: 'UCS-2', chars: n, per: 67, segs: Math.ceil(n / 67) };
}

function bcdSwap(digits) {
  const s = digits.length % 2 ? digits + 'F' : digits;
  let out = '';
  for (let i = 0; i < s.length; i += 2) out += s.charAt(i + 1) + s.charAt(i);
  return out.toUpperCase();
}

export function buildUcs2Pdu(address, text) {
  const digits = String(address || '').replace(/\D/g, '');
  const ud = utf16BeHex(text);
  if (!digits || !ud) return { pdu: '', len: 0 };
  const dest = hex2(digits.length) + '91' + bcdSwap(digits);
  const tpdu = '0100' + dest + '0008' + hex2(ud.length / 2) + ud;
  return { pdu: '00' + tpdu, len: tpdu.length / 2 };
}

export function smsAtPayload(address, body) {
  const addr = String(address || '');
  const text = String(body || '');
  if (isGsm7(text)) {
    return { encoding: 'gsm', address: addr, body: text };
  }
  const pdu = buildUcs2Pdu(addr, text);
  return {
    encoding: 'ucs2',
    address: addr,
    body: text,
    addrhex: utf16BeHex(addr),
    bodyhex: utf16BeHex(text),
    pduhex: pdu.pdu,
    pdulen: String(pdu.len),
  };
}
