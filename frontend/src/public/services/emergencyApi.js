const configuredEndpoint =
  import.meta.env?.VITE_PUBLIC_REQUESTS_ENDPOINT?.trim() || ''

export function createEmergencyClient({
  endpoint = configuredEndpoint,
  fetchImpl = fetch,
} = {}) {
  return {
    configured: Boolean(endpoint),
    async submit(payload) {
      if (!endpoint)
        throw new Error(
          'El envío todavía no está habilitado. Puedes guardar el formulario en este dispositivo.',
        )
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 15000)
      try {
        const response = await fetchImpl(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': payload.client_request_id,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
          credentials: 'omit',
        })
        if (!response.ok)
          throw new Error(
            `El servidor respondió con un error (${response.status}). No hay recepción confirmada. Conserva tu formulario antes de volver a intentar.`,
          )
        // Un HTTP exitoso por sí solo no es una confirmación de registro.
        const body = await response.json().catch(() => null)
        const receipt = body?.receipt
        const confirmed =
          receipt?.status === 'received' &&
          (typeof receipt.request_id === 'string' ||
            typeof receipt.request_id === 'number') &&
          String(receipt.request_id).trim().length > 0 &&
          typeof receipt.received_at === 'string' &&
          !Number.isNaN(Date.parse(receipt.received_at))
        return {
          state: confirmed ? 'confirmed' : 'sent',
          receipt: confirmed ? receipt : null,
        }
      } catch (error) {
        if (controller.signal.aborted)
          throw new Error(
            'Se agotó el tiempo de espera. El resultado del envío es desconocido: la central podría haberlo recibido. No hay confirmación disponible.',
          )
        if (error instanceof TypeError)
          throw new Error(
            'No se pudo obtener una respuesta. El resultado del envío es desconocido. Verifica la conexión con la red SOSNET; no hay recepción confirmada.',
          )
        throw error
      } finally {
        clearTimeout(timeout)
      }
    },
  }
}

export const emergencyClient = createEmergencyClient()
