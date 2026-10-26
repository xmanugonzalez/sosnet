import test from 'node:test'
import assert from 'node:assert/strict'
import {
  emptyRequest,
  validateRequest,
  toPayload,
  validCoordinates,
} from '../src/public/requestModel.js'
import { createEmergencyClient } from '../src/public/services/emergencyApi.js'

const values = {
  ...emptyRequest(),
  name: 'Persona de prueba',
  contact: '+595 981 123456',
  type: 'Inundación',
  description: 'El agua está entrando a la vivienda.',
  location: 'Barrio de prueba',
}

test('un borrador incompleto no es una solicitud válida', () => {
  assert.deepEqual(Object.keys(validateRequest(emptyRequest())).sort(), [
    'contact',
    'description',
    'location',
    'name',
    'type',
  ])
})
test('acepta referencias escritas sin GPS y coordenadas sin dirección', () => {
  assert.deepEqual(validateRequest(values), {})
  assert.deepEqual(
    validateRequest({
      ...values,
      location: '',
      coordinates: { latitude: 0, longitude: 0 },
    }),
    {},
  )
})
test('rechaza coordenadas inválidas y cantidades fuera de rango', () => {
  assert.equal(validCoordinates(91, 0), false)
  assert.equal(validCoordinates(0, Infinity), false)
  for (const people of ['0', '1.5', '1001', 'x'])
    assert.ok(validateRequest({ ...values, people }).people)
})
test('el payload conserva contacto, referencias y un código de reintento estable', () => {
  const payload = toPayload(
    { ...values, references: 'Portón negro' },
    'same-id',
  )
  assert.equal(payload.client_request_id, 'same-id')
  assert.equal(payload.reporter.contact, values.contact)
  assert.equal(payload.location.references, 'Portón negro')
  assert.equal(payload.emergency.affected_people, 1)
})
test('sin endpoint no hace llamadas de red', async () => {
  const client = createEmergencyClient({
    endpoint: '',
    fetchImpl: () => assert.fail('No debe enviar'),
  })
  await assert.rejects(
    client.submit(toPayload(values, 'id')),
    /no está habilitado/,
  )
})
test('un 2xx, HTML o JSON sin recibo no confirma una emergencia', async () => {
  for (const body of [
    { id: 1 },
    {
      receipt: {
        status: 'received',
        request_id: '',
        received_at: '2026-10-25',
      },
    },
    null,
  ]) {
    const client = createEmergencyClient({
      endpoint: '/endpoint-de-prueba',
      fetchImpl: async () => ({ ok: true, json: async () => body }),
    })
    assert.deepEqual(await client.submit(toPayload(values, 'id')), {
      state: 'sent',
      receipt: null,
    })
  }
  const html = createEmergencyClient({
    endpoint: '/prueba',
    fetchImpl: async () => ({
      ok: true,
      json: async () => {
        throw new SyntaxError()
      },
    }),
  })
  assert.equal((await html.submit(toPayload(values, 'id'))).state, 'sent')
})
test('solo un recibo explícito y completo confirma el registro', async () => {
  const receipt = {
    status: 'received',
    request_id: 'SERVER-17',
    received_at: '2026-10-25T12:00:00Z',
  }
  let request
  const client = createEmergencyClient({
    endpoint: '/endpoint-acordado',
    fetchImpl: async (url, options) => {
      request = { url, options }
      return { ok: true, json: async () => ({ receipt }) }
    },
  })
  assert.deepEqual(await client.submit(toPayload(values, 'stable-id')), {
    state: 'confirmed',
    receipt,
  })
  assert.equal(request.url, '/endpoint-acordado')
  assert.equal(request.options.headers['Idempotency-Key'], 'stable-id')
  assert.equal(request.options.credentials, 'omit')
})
test('errores HTTP y de red nunca producen confirmación', async () => {
  const http = createEmergencyClient({
    endpoint: '/prueba',
    fetchImpl: async () => ({ ok: false, status: 503 }),
  })
  await assert.rejects(
    http.submit(toPayload(values, 'id')),
    /No hay recepción confirmada/,
  )
  const offline = createEmergencyClient({
    endpoint: '/prueba',
    fetchImpl: async () => {
      throw new TypeError('offline')
    },
  })
  await assert.rejects(offline.submit(toPayload(values, 'id')), /desconocido/)
})
