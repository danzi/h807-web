export function createLogsInteractor({ logsRepo }) {
  return {
    async loadSendLogs() {
      const data = await logsRepo.listSend();
      if (data.reply !== 'ok') throw new Error(data.msg || 'logs failed');
      return data.logs || [];
    },
    async clearSendLogs() {
      const data = await logsRepo.clearSend();
      if (data.reply !== 'ok') throw new Error(data.msg || 'clear failed');
      return data;
    },
  };
}
