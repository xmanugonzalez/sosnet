export async function probeBackend(url, request = fetch) {
  let response
  try {
    response = await request(url, { signal: AbortSignal.timeout(1000) })
  } catch {
    return false
  }
  if (response.ok) return true
  const body = await response.json().catch(() => ({}))
  if (body.code === 'insecure_config' || (response.status === 503 && body.error?.startsWith('Configuración insegura:'))) {
    throw new Error('La API está bloqueada por su configuración de seguridad. Ejecuta npm run dev:setup y reinicia Flask o recrea el backend Docker para cargar las claves. No se seguirá consultando /api/health.')
  }
  return false
}
