export function createSmsRepo({ api }) {
  return {
    list: () => api.request({ action: 'list' }),
    remove: (id) => api.request({ action: 'delete', id }),
    mark: (id, read) => api.request({ action: 'mark', id, read }),
    send: (address, body) => api.request({ action: 'send', address, body }),
  };
}
