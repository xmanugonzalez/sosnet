import {
  createElement,
  lazy,
  Suspense,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import {
  AlertTriangle,
  ArrowDown,
  ArrowRight,
  Check,
  ChevronDown,
  HeartPulse,
  LifeBuoy,
  LocateFixed,
  MapPin,
  Package,
  Radio,
  Save,
  Send,
  ShieldCheck,
  Users,
  Waves,
  WifiOff,
  Flame,
  X,
} from 'lucide-react'
import logo from '../assets/logo.png'
import {
  emptyRequest,
  EMERGENCY_TYPES,
  toPayload,
  validCoordinates,
  validateRequest,
} from './requestModel.js'
import { emergencyClient } from './services/emergencyApi.js'
import {
  deleteLocalRequest,
  listLocalRequests,
  saveLocalRequest,
} from './storage/requestStore.js'
import './public.css'

const LocationMap = lazy(() => import('./LocationMap.jsx'))
const typeIcons = [Waves, HeartPulse, LifeBuoy, Flame, Package, AlertTriangle]
const labels = {
  preparing: 'En preparación',
  saved: 'Guardada en este dispositivo',
  sending: 'Enviando al servidor',
  sent: 'Enviada · recepción sin confirmar',
  confirmed: 'Recepción confirmada por el servidor',
  unknown: 'Resultado del envío desconocido',
}

export default function PublicApp() {
  const [values, setValues] = useState(emptyRequest)
  const [id, setId] = useState(() => crypto.randomUUID())
  const [state, setState] = useState('preparing')
  const [receipt, setReceipt] = useState(null)
  const [errors, setErrors] = useState({})
  const [message, setMessage] = useState('')
  const [localItems, setLocalItems] = useState([])
  const [storageError, setStorageError] = useState('')
  const [saving, setSaving] = useState(false)
  const [deleteCandidate, setDeleteCandidate] = useState(null)
  const [locating, setLocating] = useState(false)
  const [locationMessage, setLocationMessage] = useState('')
  const [mapEnabled, setMapEnabled] = useState(false)
  const [latitude, setLatitude] = useState('')
  const [longitude, setLongitude] = useState('')
  const [connection, setConnection] = useState(navigator.onLine)
  const errorRef = useRef(null)
  const geoRequest = useRef(0)
  const busy = saving || state === 'sending'
  const locked = ['sent', 'confirmed', 'unknown'].includes(state) || busy

  useEffect(() => {
    let active = true
    listLocalRequests()
      .then((items) => {
        if (active) setLocalItems(items)
      })
      .catch((error) => {
        if (active) setStorageError(error.message)
      })
    const online = () => setConnection(navigator.onLine)
    window.addEventListener('online', online)
    window.addEventListener('offline', online)
    return () => {
      active = false
      geoRequest.current += 1
      window.removeEventListener('online', online)
      window.removeEventListener('offline', online)
    }
  }, [])

  const updateCoordinates = useCallback((coordinates) => {
    geoRequest.current += 1
    setLocating(false)
    setValues((current) => ({ ...current, coordinates }))
    setLatitude(coordinates ? String(coordinates.latitude) : '')
    setLongitude(coordinates ? String(coordinates.longitude) : '')
    setState('preparing')
    setErrors((current) => ({ ...current, location: '' }))
    setMessage('')
    setLocationMessage(
      coordinates?.source === 'gps'
        ? `Ubicación obtenida. Precisión aproximada: ±${Math.round(coordinates.accuracy)} metros.`
        : 'Ubicación ajustada manualmente. La precisión GPS ya no se aplica.',
    )
  }, [])

  function update(field, value) {
    setValues((current) => ({ ...current, [field]: value }))
    setState('preparing')
    setMessage('')
    setErrors((current) => ({ ...current, [field]: '' }))
  }
  async function refreshLocal() {
    setLocalItems(await listLocalRequests())
  }
  function record(nextState, nextReceipt = receipt) {
    return {
      id,
      values,
      state: nextState,
      receipt: nextReceipt,
      updatedAt: new Date().toISOString(),
    }
  }
  async function save() {
    setSaving(true)
    setStorageError('')
    setMessage('')
    try {
      const next = ['sent', 'confirmed', 'unknown'].includes(state)
        ? state
        : 'saved'
      await saveLocalRequest(record(next))
      setState(next)
      await refreshLocal()
      setMessage(
        'Formulario guardado en este dispositivo. Guardar aquí no envía ni comunica la emergencia a SOSNET.',
      )
    } catch (error) {
      setStorageError(error.message)
    } finally {
      setSaving(false)
    }
  }
  function locate() {
    if (!navigator.geolocation || !window.isSecureContext) {
      setLocationMessage(
        'La ubicación automática necesita un navegador compatible y HTTPS (o localhost). Describe el lugar manualmente.',
      )
      return
    }
    const token = ++geoRequest.current
    setLocating(true)
    setLocationMessage(
      'Solicitando ubicación. Puedes aceptar o rechazar el permiso del navegador.',
    )
    navigator.geolocation.getCurrentPosition(
      (position) => {
        if (token !== geoRequest.current) return
        updateCoordinates({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          source: 'gps',
          captured_at: new Date().toISOString(),
        })
      },
      (error) => {
        if (token !== geoRequest.current) return
        setLocating(false)
        setLocationMessage(
          error.code === 1
            ? 'No autorizaste la ubicación. Puedes escribir la dirección o introducir coordenadas.'
            : 'No pudimos obtener tu ubicación. Intenta de nuevo o indica dónde estás manualmente.',
        )
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 },
    )
  }
  function applyCoordinates() {
    const lat = Number(latitude.trim().replace(',', '.'))
    const lng = Number(longitude.trim().replace(',', '.'))
    if (!latitude.trim() || !longitude.trim() || !validCoordinates(lat, lng)) {
      setLocationMessage(
        'Introduce una latitud entre −90 y 90 y una longitud entre −180 y 180.',
      )
      return
    }
    updateCoordinates({
      latitude: lat,
      longitude: lng,
      accuracy: null,
      source: 'manual',
      captured_at: new Date().toISOString(),
    })
  }
  function restore(item) {
    geoRequest.current += 1
    setLocating(false)
    setLocationMessage('')
    setValues(item.values)
    setId(item.id)
    setState(item.state)
    setReceipt(item.receipt)
    setErrors({})
    setMessage(
      'Formulario recuperado del dispositivo. Revisa la ubicación y los datos antes de enviar.',
    )
    setLatitude(
      item.values.coordinates ? String(item.values.coordinates.latitude) : '',
    )
    setLongitude(
      item.values.coordinates ? String(item.values.coordinates.longitude) : '',
    )
    document
      .getElementById('public-form')
      .scrollIntoView({ behavior: 'smooth' })
  }
  function startNew() {
    geoRequest.current += 1
    setLocating(false)
    setLocationMessage('')
    setValues(emptyRequest())
    setId(crypto.randomUUID())
    setState('preparing')
    setReceipt(null)
    setErrors({})
    setMessage('')
    setLatitude('')
    setLongitude('')
  }
  async function send(event) {
    event.preventDefault()
    if (busy || state === 'confirmed' || state === 'sent') return
    const validation = validateRequest(values)
    setErrors(validation)
    setMessage('')
    if (Object.keys(validation).length) {
      requestAnimationFrame(() => errorRef.current?.focus())
      return
    }
    if (!emergencyClient.configured) {
      setMessage(
        'El envío no está habilitado: falta integrar el servidor. Guarda el formulario localmente; todavía no se comunicará la emergencia.',
      )
      return
    }
    geoRequest.current += 1
    setLocating(false)
    setState('sending')
    try {
      const result = await emergencyClient.submit(toPayload(values, id))
      setState(result.state)
      setReceipt(result.receipt)
      setMessage(
        result.state === 'confirmed'
          ? 'El servidor confirmó que registró tu solicitud. Esto no significa que un equipo esté en camino.'
          : 'El servidor respondió al envío, pero no entregó una confirmación de registro válida. No podemos confirmar la recepción de tu emergencia.',
      )
      try {
        await saveLocalRequest(record(result.state, result.receipt))
        await refreshLocal()
      } catch {
        setStorageError(
          'La respuesta está visible en esta página, pero no se pudo guardar en el dispositivo. Anota el código si aparece.',
        )
      }
    } catch (error) {
      setState('unknown')
      setMessage(error.message)
      try {
        await saveLocalRequest(record('unknown', null))
        await refreshLocal()
      } catch {
        setStorageError(
          'No se pudo conservar el formulario localmente. Mantén esta página abierta.',
        )
      }
    }
  }
  const fieldError = (field) =>
    errors[field] && (
      <span className="public-field-error" id={`error-${field}`}>
        {errors[field]}
      </span>
    )
  const fieldProps = (field) => ({
    'aria-invalid': Boolean(errors[field]),
    'aria-describedby': errors[field] ? `error-${field}` : undefined,
  })

  return (
    <div className="public-app min-h-screen">
      <header className="public-header">
        <a href="/" aria-label="SOSNET inicio">
          <img src={logo} alt="SOSNET" width="170" />
        </a>
        <nav aria-label="Navegación pública">
          <a href="#como-funciona">Cómo funciona</a>
          <a href="/admin" className="public-admin-link">
            <ShieldCheck size={15} />
            Acceso a la central
            <ArrowRight size={14} />
          </a>
        </nav>
      </header>
      <main className="public-main">
        <section className="public-hero">
          <div>
            <span className="public-eyebrow">
              <Radio size={15} />
              CERCA, CUANDO MÁS IMPORTA
            </span>
            <h1>
              No estás solo.
              <br />
              <span>Hagamos llegar tu pedido de ayuda.</span>
            </h1>
            <p>
              Si necesitas asistencia, cuéntanos qué está pasando y dónde estás.
              No necesitas una cuenta para completar tu solicitud.
            </p>
            <a className="public-cta" href="#public-form">
              Solicitar ayuda
              <ArrowDown size={17} />
            </a>
            <span className="public-hero-note">
              Sin registro · Pensado para tu comunidad
            </span>
          </div>
          <aside className="public-hero-card">
            <span className="public-rescue-icon">
              <LifeBuoy size={32} />
            </span>
            <h2>
              La información clara
              <br />
              acerca la ayuda.
            </h2>
            <p>
              Indica el lugar, cuántas personas necesitan asistencia y una
              referencia que permita encontrarte.
            </p>
            <div>
              <MapPin size={17} />
              <span>Tu ubicación hace la diferencia</span>
            </div>
          </aside>
        </section>
        <div className="public-prototype">
          <AlertTriangle size={18} />
          <p>
            <strong>Prototipo en desarrollo.</strong>{' '}
            {emergencyClient.configured
              ? 'El envío está configurado. Espera una confirmación del servidor para saber si se registró la solicitud.'
              : 'El envío a la central aún no está habilitado. Puedes preparar y guardar tu formulario; eso todavía no comunica una emergencia.'}{' '}
            Este sistema no reemplaza los servicios de emergencia oficiales.
          </p>
        </div>
        <section className="public-content" id="public-form">
          <div className="public-form-column">
            <div className="public-section-title">
              <span className="public-step-icon">
                <LifeBuoy size={23} />
              </span>
              <div>
                <span className="public-eyebrow">SOLICITUD DE ASISTENCIA</span>
                <h2>Cuéntanos qué necesitas</h2>
                <p>Los campos con * son obligatorios.</p>
              </div>
            </div>
            <div className={`public-delivery ${state}`} role="status">
              <span className="public-state-dot" />
              <div>
                <strong>{labels[state]}</strong>
                <small>
                  {state === 'saved'
                    ? 'Solo está en este dispositivo. Aún no se ha comunicado a SOSNET.'
                    : state === 'preparing'
                      ? 'Completar el formulario no envía una emergencia.'
                      : state === 'confirmed'
                        ? `Código del servidor: ${receipt?.request_id ?? '—'}`
                        : 'Consulta el mensaje del envío antes de realizar otra acción.'}
                </small>
              </div>
            </div>
            <form onSubmit={send} noValidate>
              {Object.values(errors).some(Boolean) && (
                <div
                  className="public-error-summary"
                  role="alert"
                  tabIndex={-1}
                  ref={errorRef}
                >
                  <strong>Revisa estos datos antes de continuar:</strong>
                  <ul>
                    {Object.entries(errors)
                      .filter(([, value]) => value)
                      .map(([key, value]) => (
                        <li key={key}>
                          <a href={`#field-${key}`}>{value}</a>
                        </li>
                      ))}
                  </ul>
                </div>
              )}
              <fieldset disabled={locked} className="public-fieldset">
                <legend>
                  <span>01</span>¿Qué está ocurriendo? *
                </legend>
                <div
                  className="public-type-grid"
                  id="field-type"
                  role="group"
                  aria-label="Tipo de emergencia"
                  {...fieldProps('type')}
                >
                  {EMERGENCY_TYPES.map((type, index) => (
                    <button
                      key={type}
                      type="button"
                      aria-pressed={values.type === type}
                      onClick={() => update('type', type)}
                    >
                      {createElement(typeIcons[index], {
                        size: 21,
                        'aria-hidden': true,
                      })}
                      <span>{type}</span>
                      {values.type === type && <Check size={14} />}
                    </button>
                  ))}
                </div>
                {fieldError('type')}
                <div className="public-two-fields">
                  <label className="public-field" htmlFor="field-name">
                    Nombre del solicitante *
                    <input
                      id="field-name"
                      required
                      autoComplete="name"
                      maxLength={120}
                      value={values.name}
                      onChange={(e) => update('name', e.target.value)}
                      placeholder="Tu nombre y apellido"
                      {...fieldProps('name')}
                    />
                    {fieldError('name')}
                  </label>
                  <label className="public-field" htmlFor="field-contact">
                    Número de contacto *
                    <input
                      id="field-contact"
                      required
                      type="tel"
                      autoComplete="tel"
                      maxLength={25}
                      value={values.contact}
                      onChange={(e) => update('contact', e.target.value)}
                      placeholder="Ej.: 0981 123 456"
                      {...fieldProps('contact')}
                    />
                    {fieldError('contact')}
                    <small>No necesitas señal para completar este campo.</small>
                  </label>
                </div>
                <label className="public-field" htmlFor="field-people">
                  <span>
                    <Users size={16} />
                    Cantidad de personas afectadas *
                  </span>
                  <input
                    className="public-people-input"
                    id="field-people"
                    required
                    type="number"
                    inputMode="numeric"
                    min="1"
                    max="1000"
                    step="1"
                    value={values.people}
                    onChange={(e) => update('people', e.target.value)}
                    {...fieldProps('people')}
                  />
                  {fieldError('people')}
                </label>
                <label className="public-field" htmlFor="field-description">
                  Descripción de la emergencia *
                  <textarea
                    id="field-description"
                    required
                    rows={4}
                    maxLength={1000}
                    value={values.description}
                    onChange={(e) => update('description', e.target.value)}
                    placeholder="Cuéntanos qué sucede y si hay niños, personas mayores o alguien que necesita atención urgente."
                    {...fieldProps('description')}
                  />
                  {fieldError('description')}
                  <small>{values.description.length}/1000 caracteres</small>
                </label>
              </fieldset>
              <fieldset disabled={locked} className="public-fieldset">
                <legend>
                  <span>02</span>Ayúdanos a encontrarte
                </legend>
                <label className="public-field" htmlFor="field-location">
                  Ubicación actual
                  <input
                    id="field-location"
                    maxLength={250}
                    value={values.location}
                    onChange={(e) => update('location', e.target.value)}
                    placeholder="Barrio, comunidad, calle o dirección alternativa"
                    {...fieldProps('location')}
                  />
                  {fieldError('location')}
                  <small>
                    Escribe el lugar o agrega coordenadas. Puedes indicar otra
                    ubicación si pides ayuda por alguien más.
                  </small>
                </label>
                <div className="public-location-tools">
                  <button
                    type="button"
                    className="public-location-button"
                    onClick={locate}
                    disabled={locating}
                  >
                    <LocateFixed size={17} />
                    {locating
                      ? 'Obteniendo ubicación…'
                      : 'Usar mi ubicación actual'}
                  </button>
                  {values.coordinates && (
                    <button
                      type="button"
                      className="public-text-button"
                      onClick={() => {
                        updateCoordinates(null)
                        setLocationMessage(
                          'Coordenadas retiradas. Describe dónde necesitas ayuda.',
                        )
                      }}
                    >
                      Quitar coordenadas
                    </button>
                  )}
                </div>
                <p className="public-location-status" role="status">
                  {locationMessage ||
                    'El navegador te pedirá permiso. También puedes indicar tu ubicación manualmente.'}
                </p>
                {values.coordinates && (
                  <div className="public-coordinates">
                    <MapPin size={16} />
                    <span>
                      {values.coordinates.latitude.toFixed(6)},{' '}
                      {values.coordinates.longitude.toFixed(6)}
                      <small>
                        {values.coordinates.source === 'gps'
                          ? `GPS · Precisión aproximada ±${Math.round(values.coordinates.accuracy)} m · ${new Date(values.coordinates.captured_at).toLocaleTimeString('es-PY')}`
                          : 'Ajuste manual · Precisión no disponible'}
                      </small>
                    </span>
                  </div>
                )}
                {mapEnabled ? (
                  <Suspense
                    fallback={
                      <div className="public-map-placeholder">
                        Cargando mapa…
                      </div>
                    }
                  >
                    <LocationMap
                      coordinates={values.coordinates}
                      onChange={updateCoordinates}
                      disabled={locked}
                    />
                  </Suspense>
                ) : (
                  <div className="public-map-placeholder">
                    <MapPin size={29} />
                    <strong>Marca el lugar donde necesitas ayuda</strong>
                    <p>
                      Puedes pulsar el mapa o arrastrar el marcador.
                      <br />
                      El fondo de OpenStreetMap requiere internet.
                    </p>
                    <button
                      className="public-secondary"
                      type="button"
                      onClick={() => setMapEnabled(true)}
                    >
                      Cargar mapa en línea
                    </button>
                  </div>
                )}
                <p className="public-map-help">
                  El centro inicial del mapa es Asunción; no representa tu
                  ubicación. Sin mapa, usa la dirección, las referencias o las
                  coordenadas.
                </p>
                <label className="public-field" htmlFor="field-references">
                  Referencias del lugar
                  <textarea
                    id="field-references"
                    rows={2}
                    maxLength={500}
                    value={values.references}
                    onChange={(e) => update('references', e.target.value)}
                    placeholder="Ej.: casa con portón negro pequeño, frente a la despensa."
                  />
                  <small>
                    Una referencia ayuda cuando el GPS no es suficientemente
                    preciso.
                  </small>
                </label>
                <details className="public-manual-location">
                  <summary>
                    Introducir coordenadas de otra ubicación
                    <ChevronDown size={15} />
                  </summary>
                  <div className="public-two-fields">
                    <label className="public-field">
                      Latitud
                      <input
                        type="text"
                        inputMode="decimal"
                        value={latitude}
                        onChange={(e) => setLatitude(e.target.value)}
                        placeholder="-25.2867"
                      />
                    </label>
                    <label className="public-field">
                      Longitud
                      <input
                        type="text"
                        inputMode="decimal"
                        value={longitude}
                        onChange={(e) => setLongitude(e.target.value)}
                        placeholder="-57.3333"
                      />
                    </label>
                  </div>
                  <button
                    type="button"
                    className="public-secondary"
                    onClick={applyCoordinates}
                  >
                    Aplicar coordenadas
                  </button>
                </details>
              </fieldset>
              {message && (
                <div className="public-feedback" role="status">
                  {message}
                </div>
              )}
              {storageError && (
                <div className="public-warning" role="alert">
                  {storageError} No se garantiza que los datos estén guardados
                  al cerrar la página.
                </div>
              )}
              <div className="public-actions">
                <button
                  type="button"
                  className="public-secondary"
                  onClick={save}
                  disabled={busy}
                >
                  <Save size={17} />
                  {saving ? 'Guardando…' : 'Guardar en este dispositivo'}
                </button>
                <button
                  type="submit"
                  className="public-cta"
                  disabled={busy || state === 'sent' || state === 'confirmed'}
                >
                  <Send size={17} />
                  {state === 'sending'
                    ? 'Enviando…'
                    : !emergencyClient.configured
                      ? 'Revisar formulario'
                      : state === 'unknown'
                        ? 'Reintentar con el mismo código'
                        : 'Enviar solicitud'}
                </button>
              </div>
              {!emergencyClient.configured && (
                <p className="public-send-note">
                  Envío pendiente de integración con el backend. Guardar
                  localmente no avisa a la central.
                </p>
              )}
              {['confirmed', 'sent', 'unknown'].includes(state) && (
                <button
                  type="button"
                  className="public-text-button"
                  onClick={startNew}
                >
                  Preparar otro formulario (será una solicitud diferente)
                </button>
              )}
              <p className="public-privacy">
                <ShieldCheck size={14} />
                Los formularios guardados incluyen tus datos de contacto y
                ubicación. Usa un dispositivo de confianza y elimina las copias
                cuando no las necesites.
              </p>
            </form>
          </div>
          <aside className="public-guide">
            <section className="public-guide-card" id="como-funciona">
              <span className="public-eyebrow">PASO A PASO</span>
              <h2>
                De tu comunidad
                <br />a la central.
              </h2>
              <ol>
                <li>
                  <span>1</span>
                  <div>
                    <strong>Describe la situación</strong>
                    <p>
                      Agrega la información necesaria para entender la
                      emergencia.
                    </p>
                  </div>
                </li>
                <li>
                  <span>2</span>
                  <div>
                    <strong>Indica dónde estás</strong>
                    <p>
                      Usa el GPS, el mapa o una referencia fácil de reconocer.
                    </p>
                  </div>
                </li>
                <li>
                  <span>3</span>
                  <div>
                    <strong>Espera la confirmación</strong>
                    <p>
                      Solo una respuesta de registro del servidor confirma la
                      recepción.
                    </p>
                  </div>
                </li>
              </ol>
              <div className="public-guide-note">
                <Radio size={18} />
                <p>
                  El navegador usa HTTP para comunicarse con el servidor
                  configurado. La red de dispositivos se integra por separado.
                </p>
              </div>
            </section>
            <section className="public-local-card">
              <WifiOff size={23} />
              <h2>¿Sin conexión?</h2>
              <p>
                Guarda el formulario en este dispositivo y recupéralo cuando
                puedas acceder al servidor de SOSNET.
              </p>
              <strong>No se enviará automáticamente.</strong>
              <small>
                El navegador puede indicar que no hay internet aunque un
                servidor local siga accesible.
              </small>
            </section>
            <section className="public-local-list">
              <h2>
                En este dispositivo <span>{localItems.length}</span>
              </h2>
              {localItems.length === 0 ? (
                <p>No hay formularios guardados.</p>
              ) : (
                localItems.map((item) => (
                  <article key={item.id}>
                    <strong>
                      {item.values.type || 'Formulario sin completar'}
                    </strong>
                    <small>
                      {item.values.name || 'Sin nombre'} ·{' '}
                      {new Date(item.updatedAt).toLocaleString('es-PY')}
                    </small>
                    <span>{labels[item.state]}</span>
                    <div>
                      <button
                        type="button"
                        onClick={() => restore(item)}
                        disabled={busy}
                      >
                        Abrir
                      </button>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => setDeleteCandidate(item.id)}
                      >
                        <X size={12} />
                        Eliminar copia
                      </button>
                    </div>
                    {deleteCandidate === item.id && <div className="public-delete-confirm">
                      <p>¿Eliminar esta copia del dispositivo? No se cancelará ninguna solicitud en el servidor.</p>
                      <div><button type="button" disabled={busy} onClick={async () => {
                        try {
                          await deleteLocalRequest(item.id)
                          await refreshLocal()
                          if (id === item.id && state === 'saved') setState('preparing')
                          setDeleteCandidate(null)
                        } catch (error) { setStorageError(error.message) }
                      }}>Sí, eliminar copia</button><button type="button" onClick={() => setDeleteCandidate(null)}>Conservar copia</button></div>
                    </div>}
                  </article>
                ))
              )}
            </section>
          </aside>
        </section>
      </main>
      <footer className="public-footer">
        <img src={logo} alt="SOSNET" width="115" />
        <span>Una red local para acercar la ayuda.</span>
        <span>
          {connection
            ? 'Red detectada · Servidor sin verificar'
            : 'Sin internet detectado · Revisa tu red local'}
        </span>
      </footer>
    </div>
  )
}
