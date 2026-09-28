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
const id = '12345678-1234-1234-1234-123456789abc';
const request = (method, payload, credential = secret) => new Request('https://test.supabase.co/functions/v1/manage-note', {
  method, headers: { 'x-read-secret': credential, 'Content-Type': 'application/json' },
  body: JSON.stringify(payload),
});
test('unauthorized mutations never reach the database', async () => {
  const { handler, requests } = setup();
  assert.equal((await handler(request('DELETE', { id }, 'b'.repeat(64)))).status, 401);
  assert.equal(requests.length, 0);
});
test('rejects missing/invalid IDs, empty bodies and oversized edits', async () => {
  const { handler, requests } = setup();
  for (const payload of [{}, { id: 'eq.anything' }, { id, body: ' ' }, { id, body: 'x'.repeat(10001) }]) {
    assert.equal((await handler(request('PATCH', payload))).status, 422);
  }
  assert.equal((await handler(request('DELETE', {}))).status, 422);
  assert.equal(requests.length, 0);
});
test('edits only body of the requested row', async () => {
  const note = { id, body: 'updated' };
  const { handler, requests } = setup({}, async () => Response.json([note]));
  const response = await handler(request('PATCH', { id, body: ' updated ', source: 'ignored' }));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { note });
  assert.equal(requests[0].url.searchParams.get('id'), `eq.${id}`);
  assert.equal(requests[0].options.method, 'PATCH');
  assert.deepEqual(JSON.parse(requests[0].options.body), { body: 'updated' });
});
test('permanently deletes only the requested row', async () => {
  const { handler, requests } = setup({}, async () => Response.json([{ id }]));
  const response = await handler(request('DELETE', { id }));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { deleted: id });
  assert.equal(requests[0].options.method, 'DELETE');
  assert.equal(requests[0].url.searchParams.get('id'), `eq.${id}`);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});
test('missing rows and upstream errors are reported', async () => {
  const missing = setup();
  assert.equal((await missing.handler(request('DELETE', { id }))).status, 404);
  const failed = setup({}, async () => new Response('internal detail', { status: 500 }));
  const response = await failed.handler(request('PATCH', { id, body: 'hello' }));
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'Unable to change note' });
});
