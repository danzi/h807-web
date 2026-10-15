import { nowDateTimeLocal } from '../utils/format.js';
import { smsAtPayload } from '../utils/smsEncode.js';

export function createSmsRepo({ api }) {
  return {
    list: () => api.request({ action: 'list' }),
    remove: (id) => api.request({ action: 'delete', id }),
    mark: (id, read) => api.request({ action: 'mark', id, read }),
    send: (address, body) => {
      const p = smsAtPayload(address, body);
      const q = {
        action: 'send',
        address: p.address,
        body: p.body,
        encoding: p.encoding,
        client_ts: String(Date.now()),
        datetime: nowDateTimeLocal(),
        tz: Intl.DateTimeFormat().resolvedOptions().timeZone || '',
      };
      if (p.encoding === 'ucs2') {
        q.addrhex = p.addrhex || '';
        q.bodyhex = p.bodyhex || '';
        q.pduhex = p.pduhex || '';
        q.pdulen = p.pdulen || '';
      }
      return api.request(q);
    },
  };
}
