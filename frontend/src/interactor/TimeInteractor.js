import { toDateTimeLocal, nowDateTimeLocal } from '../utils/format.js';

export function createTimeInteractor({ timeRepo }) {
  return {
    async load() {
      const data = await timeRepo.get();
      if (data.reply !== 'ok') throw new Error(data.msg || 'time_get failed');
      return {
        date: data.date || '—',
        timezone: data.timezone || '',
        epoch: data.epoch || 0,
        input: data.epoch ? toDateTimeLocal(data.epoch) : '',
      };
    },

    async apply(datetime, tz) {
      if (!datetime || !String(datetime).trim()) {
        throw new Error('Enter datetime: YYYY-MM-DD HH:MM:SS');
      }
      const data = await timeRepo.set(String(datetime).trim(), tz ? String(tz).trim() : '');
      if (data.reply !== 'ok') {
        const err = new Error(data.msg || 'time_set failed');
        err.detail = data.detail || '';
        throw err;
      }
      return data;
    },

    syncFromBrowser(tz) {
      return this.apply(nowDateTimeLocal(), tz);
    },
  };
}
