export function createTimeRepo({ api }) {
  return {
    get: () => api.request({ action: 'time_get' }),
    set: (datetime, tz) => {
      const p = { action: 'time_set', datetime };
      if (tz) p.tz = tz;
      return api.request(p);
    },
  };
}
