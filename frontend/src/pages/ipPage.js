import { fmtDate } from '../utils/format.js';

function isPrivateIp(ip) {
  const s = String(ip || '');
  return /^10\.|^192\.168\.|^172\.(1[6-9]|2\d|3[0-1])\./.test(s);
}

export function historyRow(L) {
  const ipFrom = L.ipFrom || (!isPrivateIp(L.from) ? L.from : '') || '';
  const ipTo = L.ipTo || (!isPrivateIp(L.to) ? L.to : '') || '';
  const wanFrom = L.wanFrom || (isPrivateIp(L.from) ? L.from : '') || '';
  const wanTo = L.wanTo || (isPrivateIp(L.to) ? L.to : '') || '';
  return { ipFrom, ipTo, wanFrom, wanTo };
}

export function createIpPageSetup({ Vue, ipInteractor }) {
  const { ref } = Vue;
  const ix = ipInteractor;

  return function setupIp() {
    const ipCurrent = ref('');
    const ipWan = ref('');
    const ipMode = ref('');
    const ipModeLabel = ref('');
    const ipRadio = ref('');
    const ipLogs = ref([]);
    const ipInfo = ref('');
    const ipErr = ref('');
    const ipOk = ref('');
    const ipBusy = ref(false);
    const ipChanging = ref(false);

    function applyStatus(d) {
      if (d.ip) ipCurrent.value = d.ip;
      if (d.wan) ipWan.value = d.wan;
      if (d.mode !== undefined && d.mode !== '') ipMode.value = d.mode;
      if (d.modeLabel) ipModeLabel.value = d.modeLabel;
      if (d.radio) ipRadio.value = d.radio;
      if (d.logs) {
        ipLogs.value = d.logs;
        ipInfo.value = d.logs.length ? d.logs.length + ' record(s)' : 'No IP history yet';
      }
    }

    async function loadIpHistory() {
      ipErr.value = '';
      ipBusy.value = true;
      try {
        applyStatus(await ix.load());
      } catch (e) {
        ipErr.value = e.message || String(e);
      } finally {
        ipBusy.value = false;
      }
    }

    async function changeIp() {
      ipErr.value = '';
      ipOk.value = '';
      ipBusy.value = true;
      ipChanging.value = true;
      ipInfo.value = 'Switching radio mode and back…';
      try {
        const data = await ix.change(
          (p) => {
            applyStatus(p);
            if (p.msg) ipOk.value = p.msg;
          },
          { ip: ipCurrent.value, wan: ipWan.value }
        );
        ipOk.value =
          'IP ' +
          (data.ipFrom || '—') +
          ' → ' +
          (data.ipTo || '—') +
          '\nWAN ' +
          (data.wanFrom || '—') +
          ' → ' +
          (data.wanTo || '—');
        applyStatus(data);
        try {
          const hist = await ix.logsOnly();
          if (hist.wan) ipWan.value = hist.wan;
          if (hist.mode !== undefined && hist.mode !== '') ipMode.value = hist.mode;
          if (hist.mode_label) ipModeLabel.value = hist.mode_label;
          if (hist.radio) ipRadio.value = hist.radio;
          ipLogs.value = hist.logs || [];
          ipInfo.value = ipLogs.value.length ? ipLogs.value.length + ' record(s)' : 'No IP history yet';
        } catch {
          /* keep values from change() */
        }
      } catch (e) {
        ipErr.value = e.message || 'Could not change IP';
      } finally {
        ipBusy.value = false;
        ipChanging.value = false;
      }
    }

    async function clearIpHistory() {
      if (!confirm('Clear IP history?')) return;
      ipBusy.value = true;
      try {
        await ix.clear();
        ipLogs.value = [];
        ipOk.value = '';
        ipInfo.value = 'Cleared';
      } catch (e) {
        ipErr.value = e.message || String(e);
      } finally {
        ipBusy.value = false;
      }
    }

    return {
      ipCurrent, ipWan, ipMode, ipModeLabel, ipRadio, ipLogs,
      ipInfo, ipErr, ipOk, ipBusy, ipChanging,
      loadIpHistory, changeIp, clearIpHistory, fmtDate, historyRow,
    };
  };
}
