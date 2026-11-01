const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const source = fs.readFileSync('lib/api/tiktok_client.dart', 'utf8');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
for (const name of ['unlikeVideo', 'unfollowUser']) {
  const section = source.slice(source.indexOf(`Future<DeleteResult> ${name}`));
  const body = section.match(/const functionBody = r'''([\s\S]*?)''';/)[1];
  for (const scenario of [
    { name: 'success', status: 200, payload: '{"status_code":0}', success: true, code: 0 },
    { name: 'HTML with HTTP 200', status: 200, payload: '<!doctype html>', success: false, code: -2 },
    { name: 'HTTP forbidden', status: 403, payload: '<html>', success: false, code: 403 },
    { name: 'CSRF rejection', status: 200, payload: '{"status_code":10402}', success: false, code: 10402 },
    { name: 'rate limit', status: 429, payload: '{}', success: false, code: 429 },
  ]) {
    test(`${name}: ${scenario.name}`, async () => {
      let posts = 0;
      const fetch = async (url, options) => {
        if (options.method === 'POST') posts++;
        return { ok: scenario.status === 200, status: scenario.status,
          url, redirected: false, headers: { get: () => null },
          text: async () => scenario.payload };
      };
      const run = new AsyncFunction('window', 'document', 'aid', 'awemeId', 'userId', body);
      const result = JSON.parse(await run({ fetch }, { cookie: '' }, 1988, '123', '456'));
      assert.equal(result.success, scenario.success);
      assert.equal(Number(result.status_code), scenario.code);
      assert.equal(posts, 1);
    });
  }
}
