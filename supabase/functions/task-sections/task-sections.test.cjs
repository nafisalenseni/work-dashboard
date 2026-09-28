const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');
const source = stripTypeScriptTypes(fs.readFileSync(__dirname + '/index.ts', 'utf8'));
const secret = 'a'.repeat(64);
function setup(env = {}, upstream = async () => Response.json([])) {
  let handler;
  const requests = [];
  const values = { READ_NOTES_SECRET: secret, SUPABASE_URL: 'https://test.supabase.co', SUPABASE_SECRET_KEYS: '{"default":"sb_secret_test"}', ...env };
  new Function('Deno', 'fetch', source)(
    { env: { get: key => values[key] }, serve: fn => { handler = fn; } },
    async (url, options) => { requests.push({ url, options }); return upstream(); },
  );
  return { handler, requests };
}
function request(method, payload, credential = secret) {
  return new Request('https://test.supabase.co/functions/v1/task-sections', {
    method, headers: { 'x-read-secret': credential, 'Content-Type': 'application/json' },
    ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
  });
}
test('GET and POST reject unauthorized access before touching the database', async () => {
  const { handler, requests } = setup();
  for (const credential of ['', 'b'.repeat(64), 'invalid']) {
    assert.equal((await handler(request('GET', undefined, credential))).status, 401);
    assert.equal((await handler(request('POST', { name: 'Growth' }, credential))).status, 401);
  }
  assert.equal(requests.length, 0);
});
test('lists sections in stable order without exposing server credentials', async () => {
  const sections = [{ id: 'inbox-id', name: 'Inbox', color: 'yellow' }];
  const { handler, requests } = setup({}, async () => Response.json(sections));
  const response = await handler(request('GET'));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { sections });
  assert.equal(requests[0].url.pathname, '/rest/v1/task_sections');
  assert.equal(requests[0].url.searchParams.get('order'), 'created_at.asc,id.asc');
  assert.equal(requests[0].options.headers.Authorization, undefined);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});
test('creates a trimmed section and permits only name/color fields', async () => {
  const section = { id: 'server-generated', name: 'Growth', color: 'green' };
  const { handler, requests } = setup({}, async () => Response.json([section]));
  const response = await handler(request('POST', { name: ' Growth ', color: 'green', id: 'override', sort_order: 9 }));
  assert.equal(response.status, 201);
  assert.deepEqual(await response.json(), { section });
  assert.deepEqual(JSON.parse(requests[0].options.body), { name: 'Growth', color: 'green' });
  assert.equal(requests[0].options.headers.Prefer, 'return=representation');
});
test('defaults color and rejects malformed input, blank/long names and unsupported colors', async () => {
  const { handler, requests } = setup({}, async () => Response.json([{ id: 'new' }]));
  for (const payload of [null, [], {}, { name: ' ' }, { name: 3 }, { name: 'x'.repeat(81) }, { name: 'A', color: 'orange' }, { name: 'A', color: null }]) {
    assert.equal((await handler(request('POST', payload))).status, 422);
  }
  assert.equal(requests.length, 0);
  const malformed = new Request('https://test.supabase.co', { method: 'POST', headers: { 'x-read-secret': secret }, body: '{' });
  assert.equal((await handler(malformed)).status, 400);
  assert.equal((await handler(request('POST', { name: 'Extras' }))).status, 201);
  assert.deepEqual(JSON.parse(requests[0].options.body), { name: 'Extras', color: 'yellow' });
});
test('fails closed on missing configuration and disallows deletion', async () => {
  const missing = setup({ READ_NOTES_SECRET: '' });
  assert.equal((await missing.handler(request('GET'))).status, 503);
  assert.equal(missing.requests.length, 0);
  assert.equal((await setup().handler(request('DELETE'))).status, 405);
});
test('handles upstream failure and unexpected creation responses without leaking details', async () => {
  for (const upstream of [async () => new Response('private detail', { status: 500 }), async () => { throw Error('secret'); }]) {
    const response = await setup({}, upstream).handler(request('GET'));
    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: 'Unable to access sections' });
  }
  assert.equal((await setup().handler(request('POST', { name: 'Growth' }))).status, 502);
});
test('supports the existing legacy service-role key', async () => {
  const { handler, requests } = setup({ SUPABASE_SECRET_KEYS: '{}', SUPABASE_SERVICE_ROLE_KEY: 'legacy-key' });
  assert.equal((await handler(request('GET'))).status, 200);
  assert.equal(requests[0].options.headers.Authorization, 'Bearer legacy-key');
});
