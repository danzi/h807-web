export function createTimeRepo({ api }) {
  return {
    get: () => api.request({ action: 'time_get' }),
    set: (datetime, tz) => {
      const p = { action: 'time_set', datetime, client_ts: String(Date.now()) };
      if (tz) p.tz = tz;
      return api.request(p);
    },
  };
}
