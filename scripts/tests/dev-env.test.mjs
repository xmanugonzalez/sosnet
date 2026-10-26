import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { prepareDevEnv, repairDevSecrets } from '../dev-env.mjs'

test('replaces example secrets, preserves unrelated settings and remains stable on restart', () => {
  const source = 'DATABASE_URL=mysql://keep-this\r\nSECRET_KEY=cambiar-en-produccion\r\nJWT_SECRET_KEY=dev-only-jwt-secret-change-me-1234567890\r\n'
  const result = repairDevSecrets(source)
  assert.equal(result.changed, true)
  assert.ok(result.content.includes('DATABASE_URL=mysql://keep-this\r\n'))
  const values = result.content.split('\r\n').filter(line => /^(SECRET_KEY|JWT_SECRET_KEY)=/.test(line)).map(line => line.split('=')[1])
  assert.equal(values.length, 2)
  assert.ok(values.every(value => /^[a-f0-9]{96}$/.test(value)))
  assert.notEqual(values[0], values[1])
  assert.equal(repairDevSecrets(result.content).changed, false)
})

test('keeps distinct custom secrets unchanged, including quoted values', () => {
  const source = 'SECRET_KEY="custom-session-secret"\nJWT_SECRET_KEY=\'custom-jwt-secret\'\n'
  assert.deepEqual(repairDevSecrets(source), { content: source, changed: false })
})

test('repairs shared custom secrets without replacing the session secret', () => {
  const source = 'SECRET_KEY=shared-custom-secret\nJWT_SECRET_KEY=shared-custom-secret\n'
  const result = repairDevSecrets(source)
  assert.ok(result.content.includes('SECRET_KEY=shared-custom-secret\n'))
  assert.ok(!result.content.includes('JWT_SECRET_KEY=shared-custom-secret'))
})

test('creates missing env files and never overwrites existing settings', t => {
  const root = mkdtempSync(join(tmpdir(), 'sosnet-dev-env-test-'))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  for (const directory of ['', 'backend', 'frontend']) {
    if (directory) mkdirSync(join(root, directory))
    writeFileSync(join(root, directory, '.env.example'), 'CUSTOM_SETTING=example\n')
  }
  writeFileSync(join(root, 'backend/.env'), 'CUSTOM_SETTING=existing\nSECRET_KEY=cambiar-en-produccion\n')
  const messages = []
  assert.deepEqual(prepareDevEnv(root, message => messages.push(message)), ['.env', 'backend/.env'])
  assert.ok(readFileSync(join(root, 'backend/.env'), 'utf8').includes('CUSTOM_SETTING=existing\n'))
  assert.equal(readFileSync(join(root, 'frontend/.env'), 'utf8'), 'CUSTOM_SETTING=example\n')
  assert.deepEqual(prepareDevEnv(root, () => {}), [])
  assert.ok(messages.every(message => !/SECRET_KEY=|JWT_SECRET_KEY=/.test(message)))
})
