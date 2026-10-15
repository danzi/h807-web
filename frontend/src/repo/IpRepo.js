export function createIpRepo({ api }) {
  return {
    get: () => api.request({ action: 'ip_get' }),
    history: () => api.request({ action: 'ip_history' }),
    change: () => api.request({ action: 'ip_change' }),
    log: ({ ipFrom, ipTo, wanFrom, wanTo, status, msg } = {}) =>
      api.request({
        action: 'ip_log',
        ipfrom: ipFrom || '',
        ipto: ipTo || '',
        wanfrom: wanFrom || '',
        wanto: wanTo || '',
        ipstatus: status || 'seen',
        ipmsg: msg || '',
      }),
    clear: () => api.request({ action: 'ip_clear' }),
  };
}
