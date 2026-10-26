const DB_NAME = 'sosnet-public-requests'
const STORE = 'requests'

function openDatabase() {
  return new Promise((resolve, reject) => {
    if (!globalThis.indexedDB) {
      reject(new Error('Este navegador no permite guardar formularios.'))
      return
    }
    const request = indexedDB.open(DB_NAME, 1)
    request.onupgradeneeded = () =>
      request.result.createObjectStore(STORE, { keyPath: 'id' })
    request.onerror = () =>
      reject(new Error('No se pudo abrir el almacenamiento del dispositivo.'))
    request.onblocked = () =>
      reject(
        new Error(
          'Cierra otras pestañas de SOSNET e intenta guardar nuevamente.',
        ),
      )
    request.onsuccess = () => resolve(request.result)
  })
}

async function transaction(mode, operation) {
  const db = await openDatabase()
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, mode)
      const request = operation(tx.objectStore(STORE))
      let result
      request.onsuccess = () => {
        result = request.result
      }
      tx.oncomplete = () => resolve(result)
      tx.onerror = () =>
        reject(
          new Error(
            'No se pudo completar el guardado local. Puede que no haya espacio disponible.',
          ),
        )
      tx.onabort = () =>
        reject(
          new Error(
            'El almacenamiento se interrumpió. Tu formulario no se guardó.',
          ),
        )
    })
  } finally {
    db.close()
  }
}

export async function listLocalRequests() {
  const items = await transaction('readonly', (store) => store.getAll())
  return items.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
}
export function saveLocalRequest(record) {
  return transaction('readwrite', (store) => store.put(record))
}
export function deleteLocalRequest(id) {
  return transaction('readwrite', (store) => store.delete(id))
}
