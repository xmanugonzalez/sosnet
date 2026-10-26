import assert from 'node:assert/strict'
import test from 'node:test'
import { probeBackend } from '../backend-health.mjs'

test('accepts a ready backend', async () => {
  assert.equal(await probeBackend('http://local/health', async () => new Response('{}', { status: 200 })), true)
})

test('allows retries while backend or database is unavailable', async () => {
  assert.equal(await probeBackend('http://local/health', async () => { throw new Error('ECONNREFUSED') }), false)
  assert.equal(await probeBackend('http://local/health', async () => new Response('{"database":"unavailable"}', { status: 503 })), false)
})

test('fails immediately for invalid security settings rather than retrying', async () => {
  let calls = 0
  await assert.rejects(async () => {
    for (let attempt = 0; attempt < 60; attempt++) {
      await probeBackend('http://local/health', async () => {
        calls++
        return new Response('{"code":"insecure_config"}', { status: 503 })
      })
    }
  }, /configuración de seguridad/)
  assert.equal(calls, 1)
})

test('recognizes the security error from older backend versions', async () => {
  await assert.rejects(probeBackend('http://local/health', async () => new Response(JSON.stringify({ error: 'Configuración insegura: define SECRET_KEY y JWT_SECRET_KEY.' }), { status: 503 })), /configuración de seguridad/)
})
