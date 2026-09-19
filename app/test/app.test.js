'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert');

let server;
let baseUrl;

before(async () => {
  process.env.PORT = '0';
  process.env.ENVIRONMENT = 'test';
  server = require('../src/index.js');
  await new Promise((resolve) => server.on('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET /healthz returns ok', async () => {
  const res = await fetch(`${baseUrl}/healthz`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.status, 'ok');
});

test('GET / returns HTML page', async () => {
  const res = await fetch(`${baseUrl}/`);
  assert.strictEqual(res.status, 200);
  const body = await res.text();
  assert.match(body, /Sample WebApp/);
});

test('GET /missing returns 404', async () => {
  const res = await fetch(`${baseUrl}/missing`);
  assert.strictEqual(res.status, 404);
});
