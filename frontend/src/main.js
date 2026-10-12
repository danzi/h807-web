import { createAppContainer } from './di/container.js';
import { createSmsPageSetup } from './pages/smsPage.js';
import { createSettingsPageSetup } from './pages/settingsPage.js';

const container = createAppContainer();
const { storage, smsInteractor, timeInteractor } = container.cradle;

const setupSms = createSmsPageSetup({
  Vue,
  smsInteractor,
  storage,
});
const setupSettings = createSettingsPageSetup({
  Vue,
  timeInteractor,
});

Vue.createApp({
  setup() {
    const page = Vue.ref(storage.getStr('h807_page', 'sms'));
    const sms = setupSms();
    const settings = setupSettings();

    function go(p) {
      page.value = p;
      storage.setStr('h807_page', p);
      if (p === 'settings') settings.loadTime();
      if (p === 'sms') sms.loadSms(false);
    }

    Vue.onMounted(() => {
      sms._smsInit();
      settings.loadTime();
    });

    return Object.assign({ page, go }, sms, settings);
  },
}).mount('#app');
