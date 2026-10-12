const API = '/cgi-bin/api.cgi';

export function createApiClient() {
  return {
    request(params) {
      const q = Object.entries(params)
        .map(([k, v]) => k + '=' + encodeURIComponent(v == null ? '' : v))
        .join('&');
      return fetch(API + '?' + q + '&_=' + Date.now()).then((r) => r.json());
    },
  };
}
