const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness() {
  class Element {
    constructor() { this.hidden = true; this.children = []; this.dataset = {}; this.classList = {toggle() {}}; }
    setAttribute(key, value) { if (key === 'data-key') this.dataset.key = value; }
    addEventListener(name, callback) { this[name] = callback; }
    append(...children) { this.children.push(...children); }
    replaceChildren(...children) { this.children = children; }
    querySelectorAll() { return this.children; }
  }
  const html = fs.readFileSync('admin/index.html', 'utf8');
  const elements = Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(m => [m[1], new Element()]));
  elements.search.query = {value: ''};
  const requests = [];
  let clock = 1000;
  class Clock extends Date { static now() { return clock; } }
  const client = {auth: {signOut: async () => {}, signInWithPassword: async () => ({data: {user: {id: 'admin'}}})},
    functions: {invoke: (_, {body}) => new Promise(resolve => requests.push({body, resolve}))}};
  const context = vm.createContext({
    document: {getElementById: id => elements[id], createElement: () => new Element(), createTextNode: text => text},
    Node: Element, createClient: () => client, Date: Clock, setTimeout, clearTimeout, confirm: () => true,
  });
  vm.runInContext(fs.readFileSync('admin/app.js', 'utf8').replace(/^import .*;\r?\n/, ''), context);
  const run = code => vm.runInContext(code, context);
  run("currentAdminId = 'admin'");
  return {elements, requests, run, advance: ms => { clock += ms; }};
}

test('admin cache coalesces requests, expires at 15 seconds and refresh bypasses completed cache', async () => {
  const h = harness();
  const first = h.run("loadSection('devices', '')");
  const duplicate = h.run("loadSection('devices', '')");
  assert.equal(h.requests.length, 1);
  h.requests[0].resolve({data: []});
  await Promise.all([first, duplicate]);
  await h.run("loadSection('devices', '')");
  assert.equal(h.requests.length, 1);
  h.advance(15000);
  const expired = h.run("loadSection('devices', '')");
  assert.equal(h.requests.length, 2);
  h.requests[1].resolve({data: []});
  await expired;
  const refresh = h.run("loadSection('devices', '', true)");
  assert.equal(h.requests.length, 3);
  h.requests[2].resolve({data: []});
  await refresh;
});

test('late response and late error cannot replace another admin section', async () => {
  const h = harness();
  const old = h.run("switchSection('users')");
  const next = h.run("switchSection('devices')");
  assert.equal(h.elements.heading.textContent, 'Thiết bị (Devices)');
  assert.equal(h.elements.records.children.length, 0);
  h.requests[1].resolve({data: []});
  await next;
  const currentRows = h.elements.records.children;
  h.requests[0].resolve({error: Error('old request failed')});
  await old;
  assert.equal(h.elements.records.children, currentRows);
});

test('mutation and logout invalidate cache and pending render', async () => {
  const h = harness();
  const initial = h.run("loadSection('devices', '')");
  h.requests[0].resolve({data: []});
  await initial;
  const restore = h.run("rpc('restore_device', {id: 'test-device'})");
  h.requests[1].resolve({data: {ok: true}});
  await restore;
  const pending = h.run("switchSection('devices')");
  assert.equal(h.requests.length, 3);
  await h.elements.logout.onclick();
  h.requests[2].resolve({data: []});
  await pending;
  assert.equal(h.elements.panel.hidden, true);
  assert.equal(h.elements.records.children.length, 0);
  assert.equal(h.run('sectionCache.size'), 0);
});

test('admin login fetches dashboard once', async () => {
  const h = harness();
  const login = h.elements.login.onsubmit({preventDefault() {}, target: {email: {value: 'admin@example.invalid'}, password: {value: 'test-only'}}});
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.requests.length, 1);
  h.requests[0].resolve({data: {}});
  await login;
  assert.equal(h.requests.length, 1);
  assert.equal(h.elements.panel.hidden, false);
});
