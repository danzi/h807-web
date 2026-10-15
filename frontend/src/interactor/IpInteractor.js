const IPIFY = ['http://api.ipify.org', 'http://ipv4.icanhazip.com', 'http://checkip.amazonaws.com'];

function parseIpv4(text) {
  const m = String(text || '').match(/\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b/);
  if (m && m[1] && m[1] !== '0.0.0.0') return m[1];
  return '';
}

export function fetchPublicIp(ms = 3000) {
  return new Promise((resolve) => {
    const ctrl = new AbortController();
    let settled = false;
    let pending = IPIFY.length;
    const done = (ip) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try {
        ctrl.abort();
      } catch {
        /* ignore */
      }
      resolve(ip || '');
    };
    const timer = setTimeout(() => done(''), ms);
    IPIFY.forEach((u) => {
      fetch(u + '?_=' + Date.now(), { cache: 'no-store', signal: ctrl.signal })
        .then((r) => r.text())
        .then((t) => {
          const ip = parseIpv4(t);
          if (ip) done(ip);
        })
        .catch(() => {})
        .finally(() => {
          pending -= 1;
          if (pending <= 0) done('');
        });
    });
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

export function createIpInteractor({ ipRepo, logger }) {
  return {
    async load() {
      const [data, pub] = await Promise.all([ipRepo.history(), fetchPublicIp(3000)]);
      if (data.reply !== 'ok') throw new Error(data.msg || 'ip_history failed');
      logger.debug('ip load', pub, (data.logs || []).length);
      return {
        ip: pub || data.ip || '',
        wan: data.wan || '',
        mode: data.mode || '',
        modeLabel: data.mode_label || '',
        radio: data.radio || '',
        logs: data.logs || [],
      };
    },

    async change(onProgress, snapshot = {}) {
      const notify = (p) => {
        if (typeof onProgress === 'function') onProgress(p);
      };
      const [fromPubLive, snap] = await Promise.all([
        fetchPublicIp(2500),
        ipRepo.get().catch(() => ({})),
      ]);
      const fromPub = fromPubLive || snapshot.ip || '';
      const fromWan = snap.wan || snapshot.wan || '';
      notify({ ip: fromPub, wan: fromWan });

      const data = await ipRepo.change();
      if (data.reply !== 'ok') {
        const err = new Error(data.msg || 'mode hop failed');
        err.detail = data;
        throw err;
      }
      const wanTo = data.to || data.wan || fromWan;
      notify({
        wan: wanTo,
        mode: data.mode,
        modeLabel: data.mode_label || '',
        radio: data.radio || '',
      });

      let toPub = '';
      for (let i = 0; i < 12; i++) {
        const got = await fetchPublicIp(2500);
        if (got) {
          toPub = got;
          notify({ ip: got });
          if (fromPub && got !== fromPub) break;
        }
        await sleep(1200);
      }
      if (!toPub) toPub = fromPub;

      const pubChanged = !!(fromPub && toPub && fromPub !== toPub);
      const wanChanged = !!(fromWan && wanTo && fromWan !== wanTo);
      const msg =
        'IP ' +
        (fromPub || '—') +
        ' → ' +
        (toPub || '—') +
        ' · WAN ' +
        (fromWan || '—') +
        ' → ' +
        (wanTo || '—');
      const status = pubChanged || wanChanged ? 'changed' : 'unchanged';
      await ipRepo.log({
        ipFrom: fromPub,
        ipTo: toPub,
        wanFrom: fromWan,
        wanTo,
        status,
        msg,
      });
      logger.debug('ip change', msg, data);
      return {
        reply: 'ok',
        msg,
        ip: toPub || '',
        wan: wanTo || '',
        ipFrom: fromPub,
        ipTo: toPub,
        wanFrom: fromWan,
        wanTo,
        mode: data.mode,
        modeLabel: data.mode_label || '',
        radio: data.radio || '',
        status,
      };
    },

    async logsOnly() {
      const data = await ipRepo.history();
      if (data.reply !== 'ok') throw new Error(data.msg || 'ip_history failed');
      return data;
    },

    async clear() {
      const data = await ipRepo.clear();
      if (data.reply !== 'ok') throw new Error(data.msg || 'clear failed');
      return data;
    },
  };
}
