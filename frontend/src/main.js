import { createAppContainer } from './di/container.js';
import { createSmsPageSetup } from './pages/smsPage.js';
import { createSettingsPageSetup } from './pages/settingsPage.js';
import { createLogsPageSetup } from './pages/logsPage.js';
import { createIpPageSetup } from './pages/ipPage.js';

const container = createAppContainer();
const { storage, smsInteractor, timeInteractor, logsInteractor, ipInteractor } = container.cradle;

const setupSms = createSmsPageSetup({ Vue, smsInteractor, storage });
const setupSettings = createSettingsPageSetup({ Vue, timeInteractor });
const setupLogs = createLogsPageSetup({ Vue, logsInteractor });
const setupIp = createIpPageSetup({ Vue, ipInteractor });

Vue.createApp({
  setup() {
    const page = Vue.ref(storage.getStr('h807_page', 'sms'));
    const sms = setupSms();
    const settings = setupSettings();
    const logs = setupLogs();
    const ip = setupIp();

    function go(p) {
      page.value = p;
      storage.setStr('h807_page', p);
      if (p === 'settings') settings.loadTime();
      if (p === 'sms') sms.loadSms(false);
      if (p === 'logs') logs.loadSendLogs();
      if (p === 'ip') ip.loadIpHistory();
    }

    function onClockClick() {
      settings.openTimeModal();
    }

    Vue.onMounted(() => {
      sms._smsInit();
      settings.loadTime();
      if (page.value === 'ip') ip.loadIpHistory();
    });

    return Object.assign({ page, go, onClockClick }, sms, settings, logs, ip);
  },
}).mount('#app');
