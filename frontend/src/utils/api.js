const API = '/cgi-bin/api.cgi';

export function createApiClient() {
  return {
    request(params) {
      const q = Object.entries(params)
        .map(([k, v]) => k + '=' + encodeURIComponent(v == null ? '' : v))
        .join('&');
      return fetch(API + '?' + q + '&_=' + Date.now()).then((r) =>
        r.text().then((t) => {
          try {
            return JSON.parse(t);
          } catch (e) {
            throw new Error(
              'API returned non-JSON. ' +
                String(t).replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').slice(0, 160)
            );
          }
        })
      );
    },
  };
}
