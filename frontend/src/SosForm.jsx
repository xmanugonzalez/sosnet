import { createElement, useEffect, useRef, useState } from 'react'
import {
  AlertTriangle, Check, CheckCircle2, ChevronDown, Clock3,
  FileText, HeartPulse, House, Info, LifeBuoy, LoaderCircle, MapPin,
  MessageSquareText, Minus, Navigation, Package, Plus, Radio, RadioTower,
  Send, ShieldCheck, TreePine, Users, Waves,
} from 'lucide-react'
import emblem from './assets/favicon.png'
import './sos-form.css'

const API_URL = import.meta.env.VITE_API_URL || '/api'
const TYPES = [
  { value: 'Inundación', icon: Waves },
  { value: 'Asistencia médica', icon: HeartPulse },
  { value: 'Evacuación', icon: LifeBuoy },
  { value: 'Suministros', icon: Package },
  { value: 'Otra', icon: AlertTriangle },
]
const PRIORITIES = [
  { value: 'baja', label: 'Baja', hint: 'Podemos esperar' },
  { value: 'media', label: 'Media', hint: 'Necesitamos ayuda pronto' },
  { value: 'alta', label: 'Alta', hint: 'Estamos en peligro' },
]

function BrandHeader() {
  return (
    <header className="sos-brand-header">
      <a className="sos-brand-lockup" href="/" aria-label="SOSNET, formulario de auxilio">
        <img src={emblem} alt="" width="76" height="76" />
        <span>
          <strong>SOS<span>NET</span></strong>
          <span className="sos-brand-caption">Comunicación de emergencias<br /><b>Red local, sin depender de internet</b></span>
        </span>
      </a>
    </header>
  )
}

function LandscapeFooter({ success }) {
  return (
    <footer className="sos-landscape-footer">
      <div className="sos-landscape" aria-hidden="true">
        <TreePine className="land-tree land-tree-one" />
        <House className="land-house land-house-one" />
        <TreePine className="land-tree land-tree-two" />
        <House className="land-house land-house-two" />
        <RadioTower className="land-tower" />
        <TreePine className="land-tree land-tree-three" />
      </div>
      {success && <p>Tu seguridad es nuestra prioridad</p>}
    </footer>
  )
}

export default function SosForm() {
  const [type, setType] = useState('Inundación')
  const [people, setPeople] = useState(1)
  const [name, setName] = useState('')
  const [location, setLocation] = useState('')
  const [message, setMessage] = useState('')
  const [priority, setPriority] = useState('media')
  const [coords, setCoords] = useState(null)
  const [locationState, setLocationState] = useState('idle')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState('')
  const [locationError, setLocationError] = useState('')
  const [receipt, setReceipt] = useState(null)
  const locationRef = useRef(null)
  const errorRef = useRef(null)
  const successRef = useRef(null)
  const formTitleRef = useRef(null)
  const hadReceipt = useRef(false)
  const inFlight = useRef(false)
  const selectedIcon = TYPES.find(option => option.value === type)?.icon || LifeBuoy

  useEffect(() => {
    if (receipt) {
      successRef.current?.focus()
      hadReceipt.current = true
    }
    else if (error) errorRef.current?.focus()
    else if (hadReceipt.current) {
      formTitleRef.current?.focus()
      hadReceipt.current = false
    }
  }, [receipt, error])

  function requestLocation() {
    if (!navigator.geolocation) { setLocationState('error'); return }
    setLocationState('loading')
    navigator.geolocation.getCurrentPosition(
      position => {
        setCoords({
          latitude: Number(position.coords.latitude.toFixed(7)),
          longitude: Number(position.coords.longitude.toFixed(7)),
        })
        setLocationState('ok')
      },
      () => setLocationState('error'),
      { enableHighAccuracy: true, timeout: 10000 },
    )
  }

  async function handleSubmit(event) {
    event.preventDefault()
    if (inFlight.current) return
    setError('')
    if (!location.trim()) {
      setLocationError('Escribí una ubicación o un punto de referencia para que puedan encontrarte.')
      locationRef.current?.focus()
      return
    }
    setLocationError('')
    inFlight.current = true
    setSending(true)
    const payload = {
      emergency_type: type,
      message: message.trim() || 'Solicitud de emergencia',
      reporter_name: name.trim() || null,
      location: location.trim(),
      people,
      priority,
      latitude: coords?.latitude ?? null,
      longitude: coords?.longitude ?? null,
      device_id: 'FORMULARIO-SOS',
    }
    try {
      const response = await fetch(`${API_URL}/emergencies`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(20000),
      })
      const data = await response.json().catch(() => null)
      if (!response.ok) throw new Error(data?.error || 'La central no pudo registrar la solicitud. Conservamos tus datos para que puedas volver a intentarlo.')
      if (data?.id === undefined || data.id === null || data.id === '') {
        throw new Error('La central no devolvió un número de solicitud. Verificá la recepción con la central antes de volver a enviar.')
      }
      setReceipt({
        id: data.id,
        receivedAt: data.received_at || null,
        type: data.emergency_type || payload.emergency_type,
        location: data.location || payload.location,
        people: data.people ?? payload.people,
        priority: data.priority || payload.priority,
      })
      window.scrollTo({ top: 0, behavior: 'instant' })
    } catch (submitError) {
      setError(
        submitError.name === 'TimeoutError'
          ? 'No recibimos confirmación de la central a tiempo. Tus datos siguen aquí; verificá la recepción antes de volver a enviar.'
          : submitError instanceof TypeError
            ? 'No se pudo conectar con la central. Comprobá la conexión a la red local y volvé a intentarlo. Tus datos siguen aquí.'
            : submitError.message,
      )
    } finally {
      inFlight.current = false
      setSending(false)
    }
  }

  function resetForm() {
    setReceipt(null); setType('Inundación'); setPeople(1); setName('')
    setLocation(''); setMessage(''); setPriority('media'); setCoords(null)
    setLocationState('idle'); setError(''); setLocationError('')
    window.scrollTo({ top: 0, behavior: 'instant' })
  }

  const receivedDate = receipt?.receivedAt ? new Date(receipt.receivedAt) : null
  const receivedLabel = receivedDate && !Number.isNaN(receivedDate.getTime())
    ? new Intl.DateTimeFormat('es-PY', { dateStyle: 'medium', timeStyle: 'short' }).format(receivedDate)
    : 'No informada por la central'

  return (
    <main className="sos-page">
      <div className="sos-app">
        <BrandHeader />
        <section className={`sos-sheet ${receipt ? 'sos-sheet-success' : ''}`} aria-labelledby={receipt ? 'sos-success-title' : 'sos-title'}>
          {receipt ? (
            <div className="sos-confirmation">
              <div className="sos-success-heading">
                <span className="sos-success-symbol"><Check size={48} strokeWidth={3.5} aria-hidden="true" /></span>
                <h1 id="sos-success-title" ref={successRef} tabIndex={-1}>¡Solicitud registrada!</h1>
                <p>Tu mensaje de auxilio llegó a la central SOSNET y quedó registrado.</p>
                <span className="sos-folio">Solicitud SOS-{String(receipt.id).padStart(3, '0')}</span>
              </div>
              <dl className="sos-receipt">
                <div><dt><Clock3 size={20} aria-hidden="true" />Fecha y hora</dt><dd>{receivedLabel}</dd></div>
                <div><dt><Radio size={20} aria-hidden="true" />Estado</dt><dd><span className="sos-received-badge"><CheckCircle2 size={14} aria-hidden="true" />Registrada</span></dd></div>
                <div><dt><FileText size={20} aria-hidden="true" />Emergencia</dt><dd>{receipt.type}</dd></div>
                <div className="sos-receipt-location"><dt><MapPin size={20} aria-hidden="true" />Ubicación</dt><dd>{receipt.location}</dd></div>
                <div><dt><Users size={20} aria-hidden="true" />Personas afectadas</dt><dd>{receipt.people}</dd></div>
                <div><dt><AlertTriangle size={20} aria-hidden="true" />Prioridad</dt><dd>{PRIORITIES.find(option => option.value === receipt.priority)?.label || 'Media'}</dd></div>
              </dl>
              <aside className="sos-safety-note"><Info size={24} aria-hidden="true" /><div><strong>Mantenete en un lugar seguro.</strong><p>La central podrá coordinar la asistencia. El registro no confirma que un equipo ya esté en camino.</p></div></aside>
              <button className="sos-another" type="button" onClick={resetForm}>Enviar otra solicitud<Plus size={18} aria-hidden="true" /></button>
            </div>
          ) : (
            <>
              <div className="sos-form-heading">
                <h1 id="sos-title" ref={formTitleRef} tabIndex={-1}>Solicitar auxilio</h1>
                <p>Completá el formulario para enviar una solicitud de emergencia a la central.</p>
              </div>
              <form className="sos-request-form" onSubmit={handleSubmit} aria-busy={sending}>
                <fieldset className="sos-fields" disabled={sending}>
                  <legend className="sr-only">Datos de la solicitud de auxilio</legend>
                  <div className="sos-field">
                    <label htmlFor="sos-type">Tipo de emergencia</label>
                    <div className="sos-input-wrap sos-type-control">
                      {createElement(selectedIcon, { size: 22, 'aria-hidden': true })}
                      <select id="sos-type" value={type} onChange={event => setType(event.target.value)}>
                        {TYPES.map(option => <option key={option.value} value={option.value}>{option.value}</option>)}
                      </select>
                      <ChevronDown className="sos-select-chevron" size={19} aria-hidden="true" />
                    </div>
                  </div>
                  <div className="sos-field">
                    <label htmlFor="sos-location">Ubicación <span className="sos-required" aria-hidden="true">*</span></label>
                    <div className="sos-input-wrap">
                      <MapPin size={21} aria-hidden="true" />
                      <input id="sos-location" ref={locationRef} value={location} onChange={event => { setLocation(event.target.value); if (locationError) setLocationError('') }} onBlur={() => { if (location && !location.trim()) setLocationError('Escribí una ubicación válida.') }} required maxLength={200} autoComplete="street-address" placeholder="Barrio, calle o punto de referencia" aria-invalid={Boolean(locationError)} aria-describedby={locationError ? 'sos-location-error' : 'sos-location-hint'} />
                    </div>
                    {locationError ? <p id="sos-location-error" className="sos-field-error" role="alert">{locationError}</p> : <p className="sos-field-hint" id="sos-location-hint">Indicá una referencia para que puedan encontrarte.</p>}
                    <button className="sos-gps-button" type="button" onClick={requestLocation} disabled={locationState === 'loading'}>
                      {locationState === 'ok' ? <CheckCircle2 size={16} aria-hidden="true" /> : <Navigation size={16} aria-hidden="true" />}
                      {locationState === 'loading' ? 'Obteniendo ubicación…' : locationState === 'ok' ? 'Ubicación GPS agregada' : 'Agregar ubicación GPS (opcional)'}
                    </button>
                    <p className="sos-location-status" role="status">{locationState === 'error' ? 'No se pudo obtener el GPS. Podés continuar con la ubicación escrita.' : locationState === 'ok' ? 'Las coordenadas se incluirán en tu solicitud.' : ''}</p>
                  </div>
                  <div className="sos-field">
                    <label htmlFor="sos-people">Personas afectadas</label>
                    <div className="sos-people-row">
                      <span className="sos-people-icon"><Users size={24} aria-hidden="true" /></span>
                      <div className="sos-stepper">
                        <button type="button" disabled={people <= 1} onClick={() => setPeople(current => Math.max(1, current - 1))} aria-label="Quitar una persona"><Minus size={22} aria-hidden="true" /></button>
                        <input id="sos-people" type="number" inputMode="numeric" min={1} max={1000} required value={people} onChange={event => setPeople(event.target.value === '' ? '' : Number(event.target.value))} onBlur={() => setPeople(current => Math.min(1000, Math.max(1, Number(current) || 1)))} />
                        <button type="button" disabled={people >= 1000} onClick={() => setPeople(current => Math.min(1000, Number(current) + 1))} aria-label="Agregar una persona"><Plus size={22} aria-hidden="true" /></button>
                      </div>
                    </div>
                  </div>
                  <div className="sos-field">
                    <label htmlFor="sos-message">Descripción <span className="sos-optional">(opcional)</span></label>
                    <div className="sos-input-wrap sos-textarea-wrap"><MessageSquareText size={22} aria-hidden="true" /><textarea id="sos-message" value={message} onChange={event => setMessage(event.target.value)} maxLength={500} rows={3} placeholder="Contanos qué ocurre y qué ayuda necesitan." aria-describedby="sos-message-count" /></div>
                    <p className="sos-character-count" id="sos-message-count">{message.length}/500</p>
                  </div>
                  <details className="sos-additional">
                    <summary>Datos adicionales<span>Opcional</span><ChevronDown size={18} aria-hidden="true" /></summary>
                    <div className="sos-additional-content">
                      <div className="sos-field"><label htmlFor="sos-name">Tu nombre</label><input className="sos-name-input" id="sos-name" value={name} onChange={event => setName(event.target.value)} maxLength={120} autoComplete="name" placeholder="Nombre de la persona de contacto" /></div>
                      <fieldset className="sos-priority-options"><legend>Prioridad de la solicitud</legend>{PRIORITIES.map(option => <label key={option.value}><input type="radio" name="sos-priority" value={option.value} checked={priority === option.value} onChange={() => setPriority(option.value)} /><span><strong>{option.label}</strong><small>{option.hint}</small></span></label>)}</fieldset>
                    </div>
                  </details>
                </fieldset>
                {error && <div className="sos-request-error" role="alert" ref={errorRef} tabIndex={-1}><AlertTriangle size={21} aria-hidden="true" /><p>{error}</p></div>}
                <button className="sos-send-button" type="submit" disabled={sending}>{sending ? <LoaderCircle className="sos-spinner" size={22} aria-hidden="true" /> : <Send size={22} aria-hidden="true" />}{sending ? 'Enviando solicitud…' : 'Enviar solicitud SOS'}</button>
                <p className="sos-form-notice"><ShieldCheck size={15} aria-hidden="true" /><span>Tu solicitud se registra en la central local. Este prototipo no reemplaza a los servicios oficiales de emergencia.</span></p>
              </form>
            </>
          )}
          <LandscapeFooter success={Boolean(receipt)} />
        </section>
      </div>
    </main>
  )
}
