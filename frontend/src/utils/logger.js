export function createLogger({ storage }) {
  const enabled = () => storage.getStr('h807_debug', '0') === '1';
  return {
    debug(...args) {
      if (enabled()) console.log('[h807]', ...args);
    },
    error(...args) {
      console.error('[h807]', ...args);
    },
  };
}
