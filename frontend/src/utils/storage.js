export function createStorage() {
  return {
    getJson(key, fallback) {
      try {
        const v = localStorage.getItem(key);
        return v == null ? fallback : JSON.parse(v);
      } catch {
        return fallback;
      }
    },
    setJson(key, val) {
      localStorage.setItem(key, JSON.stringify(val));
    },
    getStr(key, fallback) {
      const v = localStorage.getItem(key);
      return v == null ? fallback : v;
    },
    setStr(key, val) {
      localStorage.setItem(key, String(val));
    },
  };
}
