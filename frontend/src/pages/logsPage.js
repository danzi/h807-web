import { fmtDate } from '../utils/format.js';

export function createLogsPageSetup({ Vue, logsInteractor }) {
  const { ref } = Vue;
  const ix = logsInteractor;

  return function setupLogs() {
    const logsTab = ref('send'); // send | (future)
    const sendLogs = ref([]);
    const logsErr = ref('');
    const logsInfo = ref('');
    const logsBusy = ref(false);

    async function loadSendLogs() {
      logsErr.value = '';
      logsBusy.value = true;
      try {
        sendLogs.value = await ix.loadSendLogs();
        logsInfo.value = sendLogs.value.length
          ? sendLogs.value.length + ' send log(s)'
          : 'No send logs yet';
      } catch (e) {
        logsErr.value = e.message || String(e);
      } finally {
        logsBusy.value = false;
      }
    }

    async function clearSendLogs() {
      if (!confirm('Clear all SMS send logs?')) return;
      logsBusy.value = true;
      try {
        await ix.clearSendLogs();
        sendLogs.value = [];
        logsInfo.value = 'Cleared';
      } catch (e) {
        logsErr.value = e.message || String(e);
      } finally {
        logsBusy.value = false;
      }
    }

    return {
      logsTab,
      sendLogs,
      logsErr,
      logsInfo,
      logsBusy,
      loadSendLogs,
      clearSendLogs,
      fmtDate,
    };
  };
}
