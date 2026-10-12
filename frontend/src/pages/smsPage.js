import { fmtDate } from '../utils/format.js';

export function createSmsPageSetup({ Vue, smsInteractor, storage }) {
  const { ref, computed, watch } = Vue;
  const ix = smsInteractor;

  return function setupSms() {
    const allSms = ref([]);
    const smsTab = ref('inbox');
    const filter = ref('all');
    const search = ref('');
    const expandedId = ref(null);
    const expandedStickyUnread = ref(false); // keep card in Unread while open
    const busyIds = ref(new Set());
    const selected = ref((storage.getJson('h807_sel', []) || []).map(String));
    const info = ref('Loading…');
    const error = ref('');
    const composeOpen = ref(false);
    const sendAddr = ref('');
    const sendBody = ref('');
    const sendErr = ref('');
    const sending = ref(false);
    const autoOn = ref(storage.getStr('h807_auto', '0') === '1');
    const autoSec = ref(parseInt(storage.getStr('h807_sec', '15'), 10) || 15);
    let autoTimer = null;

    function saveSel() {
      storage.setJson('h807_sel', selected.value);
    }

    const visibleSms = computed(() =>
      ix.filterSms(allSms.value, {
        tab: smsTab.value,
        filter: filter.value,
        search: search.value,
        expandedId: expandedId.value,
      })
    );

    const unreadList = computed(() => visibleSms.value.filter((s) => {
      if (expandedStickyUnread.value && String(s.id) === expandedId.value) return true;
      return s.read == 0;
    }));
    const readList = computed(() => visibleSms.value.filter((s) => {
      if (expandedStickyUnread.value && String(s.id) === expandedId.value) return false;
      return s.read != 0;
    }));
    // Sections always on in All (stable; no toggle on expand)
    const showSections = computed(
      () => smsTab.value === 'inbox' && filter.value === 'all'
    );

    async function loadSms(manual) {
      if (manual) info.value = 'Refreshing…';
      try {
        const list = await ix.loadList();
        allSms.value = list;
        const exist = new Set(list.map((s) => String(s.id)));
        selected.value = selected.value.filter((id) => exist.has(id));
        saveSel();
        const st = ix.stats(list);
        info.value =
          `Inbox ${st.inbox}` +
          (st.unread ? ` (${st.unread} unread)` : '') +
          ` · Sent ${st.sent}`;
        error.value = '';
      } catch (e) {
        error.value = e.message || String(e);
        if (manual) info.value = 'Error';
      }
    }

    function setBusy(id, on) {
      const n = new Set(busyIds.value);
      if (on) n.add(String(id));
      else n.delete(String(id));
      busyIds.value = n;
    }

    async function toggleExpand(id, ev) {
      if (ev && (ev.target.closest('.msg-actions') || ev.target.classList.contains('sel'))) return;
      if (busyIds.value.has(id)) return;
      if (expandedId.value === id) {
        expandedId.value = null;
        expandedStickyUnread.value = false;
        return;
      }
      expandedId.value = id;
      const msg = allSms.value.find((s) => String(s.id) === id);
      expandedStickyUnread.value = !!(msg && msg.read == 0);
      if (msg && msg.read == 0) {
        setBusy(id, true);
        try {
          await ix.markRead(id, 1);
          msg.read = 1;
        } catch {
          /* keep */
        }
        setBusy(id, false);
      }
    }

    function onCheck(id, checked) {
      if (checked) {
        if (!selected.value.includes(id)) selected.value = [...selected.value, id];
      } else {
        selected.value = selected.value.filter((x) => x !== id);
      }
      saveSel();
    }

    function toggleSelectAll() {
      const vis = visibleSms.value.map((s) => String(s.id));
      const allSel = vis.length && vis.every((id) => selected.value.includes(id));
      if (allSel) selected.value = selected.value.filter((id) => !vis.includes(id));
      else selected.value = [...new Set([...selected.value, ...vis])];
      saveSel();
    }

    async function markRead(id, value) {
      const sid = String(id);
      if (busyIds.value.has(sid)) return;
      setBusy(sid, true);
      try {
        await ix.markRead(id, value);
        const msg = allSms.value.find((s) => String(s.id) === sid);
        if (msg) msg.read = value;
        await loadSms(true);
      } finally {
        setBusy(sid, false);
      }
    }

    async function delOne(id) {
      const sid = String(id);
      if (busyIds.value.has(sid)) return;
      if (!confirm('Delete #' + id + '?')) return;
      setBusy(sid, true);
      try {
        await ix.removeOne(id);
        selected.value = selected.value.filter((x) => x !== sid);
        if (expandedId.value === sid) expandedId.value = null;
        saveSel();
        await loadSms(true);
      } finally {
        setBusy(sid, false);
      }
    }

    async function deleteSelected() {
      if (!selected.value.length) return;
      if (!confirm('Delete ' + selected.value.length + ' message(s)?')) return;
      await ix.removeMany([...selected.value]);
      selected.value = [];
      expandedId.value = null;
      saveSel();
      await loadSms(true);
    }

    async function sendSms() {
      sendErr.value = '';
      sending.value = true;
      try {
        await ix.sendMessage(sendAddr.value.trim(), sendBody.value.trim());
        sendBody.value = '';
        composeOpen.value = false;
        await loadSms(true);
      } catch (e) {
        sendErr.value = (e.message || 'Send failed') + (e.detail ? ': ' + e.detail : '');
      } finally {
        sending.value = false;
      }
    }

    function toggleAuto() {
      storage.setStr('h807_auto', autoOn.value ? '1' : '0');
      storage.setStr('h807_sec', String(Math.max(1, autoSec.value || 15)));
      if (autoTimer) {
        clearInterval(autoTimer);
        autoTimer = null;
      }
      if (autoOn.value) {
        autoTimer = setInterval(() => loadSms(false), Math.max(1, autoSec.value || 15) * 1000);
      }
    }

    watch(autoSec, () => {
      storage.setStr('h807_sec', String(Math.max(1, autoSec.value || 15)));
      if (autoOn.value) toggleAuto();
    });

    return {
      allSms, smsTab, filter, search, expandedId, busyIds, selected,
      info, error, composeOpen, sendAddr, sendBody, sendErr, sending,
      autoOn, autoSec, visibleSms, unreadList, readList, showSections,
      loadSms, toggleExpand, onCheck, toggleSelectAll, markRead, delOne,
      deleteSelected, sendSms, toggleAuto, fmtDate,
      _smsInit() {
        loadSms(true);
        if (autoOn.value) toggleAuto();
      },
    };
  };
}
