import { toDatetimeLocalValue, fromDatetimeLocalValue, nowDateTimeLocal, fmtClock } from '../utils/format.js';

export function createSettingsPageSetup({ Vue, timeInteractor }) {
  const { ref } = Vue;
  const ix = timeInteractor;

  return function setupSettings() {
    const deviceDate = ref('—');
    const deviceTz = ref('');
    const timeInput = ref('');
    const tzInput = ref('Europe/Vilnius');
    const timeMsg = ref('');
    const timeErr = ref('');
    const timeBusy = ref(false);
    const timeModal = ref(false);
    const timePicker = ref('');
    let clockEpoch = 0;
    let clockFetchedAt = 0;
    let clockTick = null;
    let clockSync = null;

    function paintClock() {
      if (!clockEpoch) return;
      const sec = clockEpoch + Math.floor((Date.now() - clockFetchedAt) / 1000);
      deviceDate.value = fmtClock(sec);
    }

    function startClock() {
      if (!clockTick) clockTick = setInterval(paintClock, 1000);
      if (!clockSync) clockSync = setInterval(() => loadTime(), 120000);
    }

    async function loadTime() {
      timeErr.value = '';
      try {
        const t = await ix.load();
        deviceTz.value = t.timezone;
        if (t.timezone) tzInput.value = t.timezone;
        if (t.input) timeInput.value = t.input;
        if (t.epoch && t.epoch > 1420070400) {
          clockEpoch = Number(t.epoch);
          clockFetchedAt = Date.now();
          paintClock();
          timePicker.value = toDatetimeLocalValue(new Date(t.epoch * 1000));
        } else {
          deviceDate.value = t.date || '—';
          timePicker.value = toDatetimeLocalValue(new Date());
        }
        startClock();
      } catch (e) {
        timeErr.value = e.message || String(e);
      }
    }

    function openTimeModal() {
      timeMsg.value = '';
      timeErr.value = '';
      timePicker.value = toDatetimeLocalValue(new Date());
      timeModal.value = true;
    }

    function closeTimeModal() {
      timeModal.value = false;
    }

    async function applyPicker() {
      const dt = fromDatetimeLocalValue(timePicker.value);
      if (!dt) {
        timeErr.value = 'Pick a date and time';
        return;
      }
      timeMsg.value = '';
      timeErr.value = '';
      timeBusy.value = true;
      try {
        const data = await ix.apply(dt, tzInput.value);
        timeMsg.value = 'Time updated: ' + (data.date || '');
        timeInput.value = dt;
        await loadTime();
        timeModal.value = false;
      } catch (e) {
        timeErr.value = (e.message || 'Failed') + (e.detail ? ': ' + e.detail : '');
      } finally {
        timeBusy.value = false;
      }
    }

    async function setTime() {
      timeMsg.value = '';
      timeErr.value = '';
      timeBusy.value = true;
      try {
        const data = await ix.apply(timeInput.value || nowDateTimeLocal(), tzInput.value);
        timeMsg.value = 'Time updated: ' + (data.date || '');
        await loadTime();
      } catch (e) {
        timeErr.value = (e.message || 'Failed') + (e.detail ? ': ' + e.detail : '');
      } finally {
        timeBusy.value = false;
      }
    }

    async function syncFromBrowser() {
      timePicker.value = toDatetimeLocalValue(new Date());
      tzInput.value = Intl.DateTimeFormat().resolvedOptions().timeZone || tzInput.value;
      await applyPicker();
    }

    return {
      deviceDate, deviceTz, timeInput, tzInput,
      timeMsg, timeErr, timeBusy, timeModal, timePicker,
      loadTime, setTime, syncFromBrowser, openTimeModal, closeTimeModal, applyPicker,
    };
  };
}
