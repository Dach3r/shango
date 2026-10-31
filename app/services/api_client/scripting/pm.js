// The `pm` API of Shango scripts (a subset of Postman's) and the single entry point the sandbox calls. Everything a script can
// see arrives as one JSON argument and everything it changes leaves as one JSON result: there are no host functions, no I/O
// and no timers inside the sandbox.
(function () {
  "use strict";

  const MAX_TESTS = 100;
  const MAX_LOGS = 200;
  const MAX_LOG_BYTES = 65536;
  const MAX_LINE = 2000;
  const MAX_NAME = 200;
  const MAX_MESSAGE = 500;

  class AssertionError extends Error {}

  const fail = (message) => {
    throw new AssertionError(message);
  };
  const cut = (text, limit) => (text.length > limit ? text.slice(0, limit) : text);
  const show = (value) => {
    if (value === undefined) return "undefined";
    try {
      return JSON.stringify(value);
    } catch (error) {
      return String(value);
    }
  };
  const text = (value) => {
    if (typeof value === "string") return value;
    if (value === undefined) return "undefined";
    if (value instanceof Error) return `${value.name}: ${value.message}`;
    try {
      const json = JSON.stringify(value);
      return json === undefined ? String(value) : json;
    } catch (error) {
      return String(value);
    }
  };
  const typeOf = (value) => {
    if (value === null) return "null";
    if (Array.isArray(value)) return "array";
    return typeof value;
  };
  const deepEqual = (a, b) => {
    if (a === b) return true;
    if (typeOf(a) !== typeOf(b)) return false;
    if (Array.isArray(a)) return a.length === b.length && a.every((item, index) => deepEqual(item, b[index]));
    if (typeOf(a) === "object") {
      const keys = Object.keys(a);
      return keys.length === Object.keys(b).length && keys.every((key) => Object.prototype.hasOwnProperty.call(b, key) && deepEqual(a[key], b[key]));
    }
    return Number.isNaN(a) && Number.isNaN(b);
  };

  // A small chai-style assertion: `pm.expect(value).to.equal(1)`, `.not`, `.deep`.
  class Assertion {
    constructor(value, negate, deep) {
      this._value = value;
      this._negate = Boolean(negate);
      this._deep = Boolean(deep);
    }

    _check(passed, message, negated) {
      if (Boolean(passed) === this._negate) fail(this._negate ? negated : message);
      return this;
    }

    get to() { return this; }
    get be() { return this; }
    get been() { return this; }
    get is() { return this; }
    get that() { return this; }
    get which() { return this; }
    get and() { return this; }
    get has() { return this; }
    get have() { return this; }
    get with() { return this; }
    get at() { return this; }
    get of() { return this; }
    get same() { return this; }
    get not() { return new Assertion(this._value, !this._negate, this._deep); }
    get deep() { return new Assertion(this._value, this._negate, true); }

    get ok() { return this._check(this._value, `expected ${show(this._value)} to be truthy`, `expected ${show(this._value)} to be falsy`); }
    get true() { return this._check(this._value === true, `expected ${show(this._value)} to be true`, `expected ${show(this._value)} not to be true`); }
    get false() { return this._check(this._value === false, `expected ${show(this._value)} to be false`, `expected ${show(this._value)} not to be false`); }
    get null() { return this._check(this._value === null, `expected ${show(this._value)} to be null`, "expected value not to be null"); }
    get undefined() { return this._check(this._value === undefined, `expected ${show(this._value)} to be undefined`, "expected value not to be undefined"); }
    get exist() { return this._check(this._value !== null && this._value !== undefined, "expected value to exist", `expected ${show(this._value)} not to exist`); }
    get empty() {
      const value = this._value;
      const size = typeof value === "string" || Array.isArray(value) ? value.length : value && typeof value === "object" ? Object.keys(value).length : NaN;
      return this._check(size === 0, `expected ${show(value)} to be empty`, `expected ${show(value)} not to be empty`);
    }

    equal(expected) {
      const passed = this._deep ? deepEqual(this._value, expected) : this._value === expected;
      return this._check(passed, `expected ${show(this._value)} to equal ${show(expected)}`, `expected ${show(this._value)} not to equal ${show(expected)}`);
    }
    equals(expected) { return this.equal(expected); }
    eq(expected) { return this.equal(expected); }
    eql(expected) { return this._check(deepEqual(this._value, expected), `expected ${show(this._value)} to deeply equal ${show(expected)}`, `expected ${show(this._value)} not to deeply equal ${show(expected)}`); }

    include(expected) {
      const value = this._value;
      let passed = false;
      if (typeof value === "string") passed = value.includes(String(expected));
      else if (Array.isArray(value)) passed = value.some((item) => (this._deep ? deepEqual(item, expected) : item === expected));
      else if (value && typeof value === "object" && expected && typeof expected === "object") passed = Object.keys(expected).every((key) => deepEqual(value[key], expected[key]));
      return this._check(passed, `expected ${show(value)} to include ${show(expected)}`, `expected ${show(value)} not to include ${show(expected)}`);
    }
    includes(expected) { return this.include(expected); }
    contain(expected) { return this.include(expected); }
    contains(expected) { return this.include(expected); }

    property(name, expected) {
      const value = this._value;
      const has = value !== null && value !== undefined && Object.prototype.hasOwnProperty.call(Object(value), name);
      if (arguments.length < 2) return this._check(has, `expected ${show(value)} to have property ${show(name)}`, `expected ${show(value)} not to have property ${show(name)}`);
      return this._check(has && deepEqual(value[name], expected), `expected ${show(value)} to have property ${show(name)} of ${show(expected)}`, `expected ${show(value)} not to have property ${show(name)} of ${show(expected)}`);
    }

    a(type) { return this._check(typeOf(this._value) === type, `expected ${show(this._value)} to be a ${type}`, `expected ${show(this._value)} not to be a ${type}`); }
    an(type) { return this.a(type); }

    above(limit) { return this._check(this._value > limit, `expected ${show(this._value)} to be above ${show(limit)}`, `expected ${show(this._value)} not to be above ${show(limit)}`); }
    greaterThan(limit) { return this.above(limit); }
    gt(limit) { return this.above(limit); }
    below(limit) { return this._check(this._value < limit, `expected ${show(this._value)} to be below ${show(limit)}`, `expected ${show(this._value)} not to be below ${show(limit)}`); }
    lessThan(limit) { return this.below(limit); }
    lt(limit) { return this.below(limit); }
    least(limit) { return this._check(this._value >= limit, `expected ${show(this._value)} to be at least ${show(limit)}`, `expected ${show(this._value)} not to be at least ${show(limit)}`); }
    most(limit) { return this._check(this._value <= limit, `expected ${show(this._value)} to be at most ${show(limit)}`, `expected ${show(this._value)} not to be at most ${show(limit)}`); }
    within(low, high) { return this._check(this._value >= low && this._value <= high, `expected ${show(this._value)} to be within ${low}..${high}`, `expected ${show(this._value)} not to be within ${low}..${high}`); }

    oneOf(list) { return this._check(Array.isArray(list) && list.some((item) => deepEqual(item, this._value)), `expected ${show(this._value)} to be one of ${show(list)}`, `expected ${show(this._value)} not to be one of ${show(list)}`); }
    match(pattern) { return this._check(pattern.test(String(this._value)), `expected ${show(this._value)} to match ${String(pattern)}`, `expected ${show(this._value)} not to match ${String(pattern)}`); }
    lengthOf(size) {
      const length = this._value === null || this._value === undefined ? undefined : this._value.length;
      return this._check(length === size, `expected ${show(this._value)} to have length ${size} but got ${length}`, `expected ${show(this._value)} not to have length ${size}`);
    }
    length(size) { return this.lengthOf(size); }
  }

  const stringify = (value) => (typeof value === "string" ? value : text(value));

  const scope = (values, writes) => ({
    get(key) { return values[key]; },
    has(key) { return Object.prototype.hasOwnProperty.call(values, key); },
    set(key, value) {
      const name = String(key);
      values[name] = stringify(value);
      writes[name] = values[name];
    },
    unset(key) {
      const name = String(key);
      delete values[name];
      writes[name] = null;
    },
    toObject() { return Object.assign({}, values); },
    replaceIn(template) { return String(template).replace(/\{\{\s*([^{}\s]+)\s*\}\}/g, (match, name) => (Object.prototype.hasOwnProperty.call(values, name) ? values[name] : match)); },
  });

  const headerList = (list, writable) => {
    const same = (row, name) => String(row.key).toLowerCase() === String(name).toLowerCase();
    const api = {
      get(name) { const row = list.find((item) => item.enabled && same(item, name)); return row ? row.value : undefined; },
      has(name) { return list.some((item) => item.enabled && same(item, name)); },
      toObject() { return list.filter((item) => item.enabled).reduce((all, item) => Object.assign(all, { [item.key]: item.value }), {}); },
    };
    if (!writable) return api;

    api.add = (header) => { list.push({ key: String(header.key), value: stringify(header.value), enabled: true, description: "" }); };
    api.upsert = (header) => {
      const row = list.find((item) => same(item, header.key));
      if (row) { row.value = stringify(header.value); row.enabled = true; } else api.add(header);
    };
    api.remove = (name) => {
      for (let index = list.length - 1; index >= 0; index -= 1) if (same(list[index], name)) list.splice(index, 1);
    };
    return api;
  };

  globalThis.__shango_run = function (phase, payload, source) {
    const input = JSON.parse(payload);
    const tests = [];
    const logs = [];
    let logBytes = 0;
    const envValues = Object.assign({}, input.environment);
    const varValues = Object.assign({}, input.variables);
    const envWrites = {};
    const varWrites = {};
    const requestState = {
      url: input.request.url,
      http_method: input.request.http_method,
      headers: input.request.headers.map((row) => Object.assign({}, row)),
      body: input.request.body,
    };

    const log = (level, args) => {
      if (logs.length >= MAX_LOGS || logBytes >= MAX_LOG_BYTES) return;
      const line = cut(args.map(text).join(" "), MAX_LINE);
      logBytes += line.length;
      logs.push({ level, text: line });
    };
    const console = {
      log: (...args) => log("log", args),
      info: (...args) => log("info", args),
      debug: (...args) => log("log", args),
      warn: (...args) => log("warn", args),
      error: (...args) => log("error", args),
    };

    const pm = {
      info: { eventName: phase === "pre" ? "prerequest" : "test" },
      environment: scope(envValues, envWrites),
      variables: scope(varValues, varWrites),
      request: {
        get url() { return requestState.url; },
        set url(value) { requestState.url = String(value); },
        get method() { return requestState.http_method; },
        set method(value) { requestState.http_method = String(value).toUpperCase(); },
        get body() { return requestState.body; },
        set body(value) { requestState.body = value === null || value === undefined ? "" : stringify(value); },
        headers: headerList(requestState.headers, phase === "pre"),
      },
      expect: (value) => new Assertion(value, false, false),
      test: (name, fn) => {
        if (tests.length >= MAX_TESTS) return;
        const label = cut(String(name), MAX_NAME);
        try {
          fn();
          tests.push({ name: label, passed: true, message: null });
        } catch (error) {
          tests.push({ name: label, passed: false, message: cut(error && error.message ? String(error.message) : String(error), MAX_MESSAGE) });
        }
      },
    };
    pm.collectionVariables = pm.variables;

    if (input.response) {
      const response = input.response;
      const headers = headerList(response.headers.map(([key, value]) => ({ key, value, enabled: true })), false);
      pm.response = {
        code: response.status,
        status: response.status_text,
        responseTime: response.duration_ms,
        headers,
        text: () => response.body,
        json: () => JSON.parse(response.body),
        to: {
          have: {
            status(expected) { new Assertion(response.status, false, false).equal(expected); },
            header(name) { if (!headers.has(name)) fail(`expected response to have header ${show(name)}`); },
          },
        },
      };
    }

    globalThis.pm = pm;
    globalThis.console = console;

    let error = null;
    try {
      (0, eval)(source);
    } catch (thrown) {
      error = thrown instanceof Error ? `${thrown.name}: ${thrown.message}` : String(thrown);
    }

    return JSON.stringify({ tests, logs, env_writes: envWrites, var_writes: varWrites, request: requestState, error });
  };
})();
