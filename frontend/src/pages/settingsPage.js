export function createSettingsPageSetup({ Vue, timeInteractor }) {
  const { ref } = Vue;
  const ix = timeInteractor;

  return function setupSettings() {
    const deviceDate = ref('—');
    const deviceTz = ref('');
    const timeInput = ref('');
    const tzInput = ref('Europe/Kyiv');
    const timeMsg = ref('');
    const timeErr = ref('');
    const timeBusy = ref(false);

    async function loadTime() {
      timeErr.value = '';
      try {
        const t = await ix.load();
        deviceDate.value = t.date;
        deviceTz.value = t.timezone;
        if (t.timezone) tzInput.value = t.timezone;
        if (t.input) timeInput.value = t.input;
      } catch (e) {
        timeErr.value = e.message || String(e);
      }
    }

    async function setTime() {
      timeMsg.value = '';
      timeErr.value = '';
      timeBusy.value = true;
      try {
        const data = await ix.apply(timeInput.value, tzInput.value);
        timeMsg.value = 'Time updated: ' + (data.date || '');
        await loadTime();
      } catch (e) {
        timeErr.value = (e.message || 'Failed') + (e.detail ? ': ' + e.detail : '');
      } finally {
        timeBusy.value = false;
      }
    }

    async function syncFromBrowser() {
      timeMsg.value = '';
      timeErr.value = '';
      timeBusy.value = true;
      try {
        const data = await ix.syncFromBrowser(tzInput.value);
        timeMsg.value = 'Synced: ' + (data.date || '');
        await loadTime();
      } catch (e) {
        timeErr.value = (e.message || 'Failed') + (e.detail ? ': ' + e.detail : '');
      } finally {
        timeBusy.value = false;
      }
    }

    return {
      deviceDate, deviceTz, timeInput, tzInput,
      timeMsg, timeErr, timeBusy,
      loadTime, setTime, syncFromBrowser,
    };
  };
}
