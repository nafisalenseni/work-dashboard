const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');
const source = stripTypeScriptTypes(fs.readFileSync(__dirname + '/index.ts', 'utf8'));
const secret = 'a'.repeat(64);
function setup(env = {}, upstream = async () => Response.json([])) {
  let handler;
  let requests = [];
  const values = { READ_NOTES_SECRET: secret, SUPABASE_URL: 'https://test.supabase.co', SUPABASE_SECRET_KEYS: '{"default":"sb_secret_test"}', ...env };
  new Function('Deno', 'fetch', source)(
    { env: { get: key => values[key] }, serve: fn => { handler = fn; } },
    async (url, options) => { requests.push({ url, options }); return upstream(); },
  );
  return { handler, requests };
}
const request = (headers = {}, method = 'GET') => new Request('https://test.supabase.co/functions/v1/read-notes', { headers, method });
test('missing/wrong credentials fail before querying notes', async () => {
  const { handler, requests } = setup();
  for (const headers of [{}, { 'x-read-secret': 'b'.repeat(64) }, { 'x-capture-secret': secret }]) {
    assert.equal((await handler(request(headers))).status, 401);
  }
  assert.equal(requests.length, 0);
});
test('missing configuration fails closed and writes are rejected', async () => {
  const { handler, requests } = setup({ READ_NOTES_SECRET: undefined });
  assert.equal((await handler(request())).status, 503);
  assert.equal((await handler(request({}, 'POST'))).status, 405);
  assert.equal(requests.length, 0);
});
test('authorized read is limited, ordered, and not cacheable', async () => {
  const notes = [{ id: 'example', body: 'A note', captured_at: '2026-09-26T00:00:00Z', source: 'ios-shortcut' }];
  const { handler, requests } = setup({}, async () => Response.json(notes));
  const response = await handler(request({ 'x-read-secret': secret }));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await response.json(), { notes });
  assert.equal(requests[0].url.pathname, '/rest/v1/notes');
  assert.equal(requests[0].url.searchParams.get('limit'), '100');
  assert.equal(requests[0].url.searchParams.get('order'), 'captured_at.desc,id.desc');
  assert.equal(requests[0].url.searchParams.get('select'), 'id,body,source,captured_at');
  assert.equal(requests[0].options.headers.apikey, 'sb_secret_test');
});
test('upstream failures do not expose database details', async () => {
  const { handler } = setup({}, async () => new Response('private error detail', { status: 500 }));
  const response = await handler(request({ 'x-read-secret': secret }));
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'Unable to read notes' });
});
