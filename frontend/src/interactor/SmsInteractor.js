export function createSmsInteractor({ smsRepo }) {
  return {
    async loadList() {
      const data = await smsRepo.list();
      if (data.reply !== 'ok') throw new Error(data.msg || 'list failed');
      return data.sms || [];
    },

    async markRead(id, value) {
      const data = await smsRepo.mark(id, value);
      if (data.reply !== 'ok') throw new Error(data.msg || 'mark failed');
      return data;
    },

    async removeOne(id) {
      const data = await smsRepo.remove(id);
      if (data.reply !== 'ok') throw new Error(data.msg || 'delete failed');
      return data;
    },

    async removeMany(ids) {
      for (const id of ids || []) {
        await this.removeOne(id);
      }
    },

    async sendMessage(address, body) {
      if (!address || !body) throw new Error('Phone and text required');
      const data = await smsRepo.send(address, body);
      if (data.reply !== 'ok') {
        const err = new Error(data.msg || 'Send failed');
        err.detail = data.detail || '';
        throw err;
      }
      return data;
    },

    filterSms(list, opts = {}) {
      const tab = opts.tab || 'inbox';
      const filter = opts.filter || 'all';
      const q = (opts.search || '').trim().toLowerCase();
      let out = (list || []).filter((s) => (tab === 'inbox' ? s.type == 1 : s.type == 2));
      if (tab === 'inbox' && filter === 'unread') out = out.filter((s) => s.read == 0);
      if (tab === 'inbox' && filter === 'read') out = out.filter((s) => s.read != 0);
      if (q) {
        out = out.filter(
          (s) =>
            (s.address || '').toLowerCase().includes(q) ||
            (s.body || '').toLowerCase().includes(q)
        );
      }
      out.sort((a, b) => (b.date || 0) - (a.date || 0));
      return out;
    },

    stats(list) {
      let inbox = 0, sent = 0, unread = 0;
      for (const s of list || []) {
        if (s.type == 1) {
          inbox++;
          if (s.read == 0) unread++;
        } else if (s.type == 2) sent++;
      }
      return { inbox, sent, unread };
    },
  };
}
