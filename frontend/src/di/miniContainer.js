/** Minimal DI (Awilix-style) — no external dependency */
export function createContainer() {
  const registrations = {};
  const cache = {};

  function resolve(name) {
    if (cache[name]) return cache[name];
    const reg = registrations[name];
    if (!reg) throw new Error('Unknown dependency: ' + name);
    const value = reg.resolver(cradle);
    if (reg.singleton) cache[name] = value;
    return value;
  }

  const cradle = new Proxy(
    {},
    {
      get(_t, prop) {
        if (typeof prop === 'symbol') return undefined;
        return resolve(prop);
      },
    }
  );

  return {
    register(defs) {
      for (const [name, reg] of Object.entries(defs)) {
        registrations[name] = reg;
      }
      return this;
    },
    resolve,
    get cradle() {
      return cradle;
    },
  };
}

export function asFunction(fn, opts = {}) {
  return {
    resolver(cradle) {
      // PROXY mode: pass cradle so fn can destructure deps by name
      return fn(cradle);
    },
    singleton: opts.lifetime !== 'TRANSIENT',
  };
}

export function asValue(value) {
  return {
    resolver() {
      return value;
    },
    singleton: true,
  };
}
