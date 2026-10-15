export function createLogsRepo({ api }) {
  return {
    listSend: () => api.request({ action: 'logs_send' }),
    clearSend: () => api.request({ action: 'logs_clear_send' }),
  };
}
