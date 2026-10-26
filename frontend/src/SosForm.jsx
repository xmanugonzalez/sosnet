import { createElement, useState } from 'react'
import {
  Activity,
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  HeartPulse,
  LifeBuoy,
  MapPin,
  Minus,
  Package,
  Plus,
  Radio,
  Send,
  Users,
  Waves,
} from 'lucide-react'

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
  const [folio, setFolio] = useState(null)

  function changePeople(delta) {
    setPeople((current) => Math.min(1000, Math.max(1, current + delta)))
  }

  function requestLocation() {
    if (!navigator.geolocation) {
      setLocationState('error')
      return
    }

    setLocationState('loading')
    navigator.geolocation.getCurrentPosition(
      (position) => {
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
    setError('')

    if (!location.trim()) {
      setError('Indica una ubicación o un punto de referencia para que puedan encontrarte.')
      return
    }

    setSending(true)
    try {
      const response = await fetch(`${API_URL}/emergencies`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          emergency_type: type,
          message: message.trim() || 'Solicitud de emergencia',
          reporter_name: name.trim() || null,
          location: location.trim(),
          people,
          priority,
          latitude: coords?.latitude ?? null,
          longitude: coords?.longitude ?? null,
          device_id: 'FORMULARIO-SOS',
        }),
      })

      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        throw new Error(data.error || 'La central no pudo registrar la solicitud.')
      }

      const data = await response.json()
      setFolio(data.id)
    } catch (submitError) {
      setError(
        submitError.message ||
          'No se pudo enviar la solicitud. Verifica que estés conectado a la red SOSNET.',
      )
    } finally {
      setSending(false)
    }
  }

  function resetForm() {
    setFolio(null)
    setType('Inundación')
    setPeople(1)
    setName('')
    setLocation('')
    setMessage('')
    setPriority('media')
    setCoords(null)
    setLocationState('idle')
    setError('')
  }

  if (folio !== null) {
    return (
      <main className="min-h-screen bg-slate-950 px-5 py-10 text-slate-100">
        <div className="mx-auto max-w-lg">
          <div className="mb-8 flex items-center gap-3">
            <div className="grid size-11 place-items-center rounded-xl bg-red-500 font-black text-white">
              S
            </div>
            <div>
              <p className="text-xl font-bold tracking-tight">SOSNET</p>
              <p className="text-sm text-slate-400">Red local de emergencias</p>
            </div>
          </div>

          <section className="rounded-3xl border border-emerald-500/30 bg-emerald-500/10 p-8 text-center">
            <span className="mx-auto grid size-16 place-items-center rounded-full bg-emerald-500/20 text-emerald-300">
              <CheckCircle2 size={36} />
            </span>
            <h1 className="mt-6 text-2xl font-bold">Solicitud registrada</h1>
            <p className="mt-3 text-sm leading-6 text-emerald-100/80">
              Tu pedido de ayuda llegó a la central. Un equipo podrá verlo y coordinar la
              asistencia.
            </p>
            <div className="mt-6 rounded-2xl border border-emerald-500/30 bg-slate-950/40 px-5 py-4">
              <p className="text-xs uppercase tracking-widest text-emerald-300/80">Folio</p>
              <p className="mt-1 text-3xl font-black tracking-tight">
                SOS-{String(folio).padStart(3, '0')}
              </p>
            </div>

            <p className="mt-6 text-xs leading-5 text-slate-400">
              Recibir la solicitud no significa que la ayuda ya esté en camino. Si tu vida corre
              peligro inmediato, busca un lugar seguro y avisa a las personas cercanas.
            </p>

            <button
              type="button"
              onClick={resetForm}
              className="mt-6 w-full rounded-xl bg-white/10 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/20"
            >
              Enviar otra solicitud
            </button>
          </section>

          <a
            href="/"
            className="mt-6 flex items-center justify-center gap-2 text-xs text-slate-500 transition hover:text-slate-300"
          >
            <ArrowLeft size={14} /> Volver al centro de operaciones
          </a>
        </div>
      </main>
    )
  }

  return (
    <main className="min-h-screen bg-slate-950 px-5 py-8 text-slate-100">
      <div className="mx-auto max-w-lg">
        <header className="mb-6 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="grid size-11 place-items-center rounded-xl bg-red-500 font-black text-white">
              S
            </div>
            <div>
              <p className="text-xl font-bold tracking-tight">SOSNET</p>
              <p className="text-xs text-slate-400">Solicitud de auxilio</p>
            </div>
          </div>
          <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-400/10 px-3 py-1.5 text-[11px] font-medium text-emerald-300">
            <Radio size={13} /> Red local
          </span>
        </header>

        <section className="mb-5 rounded-2xl border border-red-500/30 bg-gradient-to-br from-red-500/15 to-slate-900 p-5">
          <div className="flex items-start gap-3">
            <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-red-500 text-white">
              <LifeBuoy size={22} />
            </span>
            <div>
              <h1 className="text-xl font-bold">Necesito ayuda</h1>
              <p className="mt-1 text-sm leading-6 text-slate-300">
                Completa los datos. La solicitud se envía a la central de rescate por la red
                local, sin depender de internet.
              </p>
            </div>
          </div>
        </section>

        <form onSubmit={handleSubmit} className="space-y-5">
          <fieldset>
            <legend className="mb-2 text-sm font-semibold text-slate-200">
              ¿Qué está ocurriendo?
            </legend>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
              {TYPES.map(({ value, icon: Icon }) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setType(value)}
                  aria-pressed={type === value}
                  className={`flex items-center gap-2 rounded-xl border px-3 py-3 text-left text-xs font-semibold transition ${
                    type === value
                      ? 'border-red-400 bg-red-500/20 text-white'
                      : 'border-slate-800 bg-slate-900 text-slate-400 hover:border-slate-700'
                  }`}
                >
                  {createElement(Icon, { size: 18 })}
                  {value}
                </button>
              ))}
            </div>
          </fieldset>

          <div>
            <label htmlFor="sos-location" className="mb-2 block text-sm font-semibold text-slate-200">
              ¿Dónde están? <span className="text-red-400">*</span>
            </label>
            <div className="relative">
              <MapPin
                size={18}
                className="pointer-events-none absolute left-3 top-3.5 text-slate-500"
              />
              <input
                id="sos-location"
                value={location}
                onChange={(event) => setLocation(event.target.value)}
                required
                maxLength={200}
                placeholder="Barrio, calle, casa de referencia…"
                className="w-full rounded-xl border border-slate-800 bg-slate-900 py-3 pl-10 pr-4 text-sm text-white placeholder:text-slate-600 focus:border-red-400 focus:outline-none"
              />
            </div>
            <button
              type="button"
              onClick={requestLocation}
              disabled={locationState === 'loading'}
              className="mt-2 inline-flex items-center gap-1.5 text-xs font-medium text-sky-300 transition hover:text-sky-200 disabled:opacity-60"
            >
              <MapPin size={13} />
              {locationState === 'loading'
                ? 'Obteniendo ubicación…'
                : locationState === 'ok'
                  ? 'Ubicación GPS agregada'
                  : 'Agregar mi ubicación GPS (opcional)'}
            </button>
            {locationState === 'error' && (
              <p className="mt-1 text-xs text-amber-300">
                No se pudo obtener el GPS. Describe la ubicación manualmente.
              </p>
            )}
          </div>

          <div>
            <label className="mb-2 block text-sm font-semibold text-slate-200">
              ¿Cuántas personas necesitan ayuda?
            </label>
            <div className="flex items-center gap-4 rounded-xl border border-slate-800 bg-slate-900 px-4 py-2.5">
              <Users size={18} className="text-slate-500" />
              <button
                type="button"
                onClick={() => changePeople(-1)}
                aria-label="Quitar una persona"
                className="grid size-9 place-items-center rounded-lg bg-slate-800 text-white transition hover:bg-slate-700"
              >
                <Minus size={16} />
              </button>
              <span className="min-w-8 text-center text-2xl font-bold tabular-nums">{people}</span>
              <button
                type="button"
                onClick={() => changePeople(1)}
                aria-label="Agregar una persona"
                className="grid size-9 place-items-center rounded-lg bg-slate-800 text-white transition hover:bg-slate-700"
              >
                <Plus size={16} />
              </button>
              <span className="ml-auto text-xs text-slate-500">
                {people === 1 ? 'persona' : 'personas'}
              </span>
            </div>
          </div>

          <fieldset>
            <legend className="mb-2 text-sm font-semibold text-slate-200">Prioridad</legend>
            <div className="grid gap-2 sm:grid-cols-3">
              {PRIORITIES.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => setPriority(option.value)}
                  aria-pressed={priority === option.value}
                  className={`rounded-xl border px-3 py-3 text-left transition ${
                    priority === option.value
                      ? option.value === 'alta'
                        ? 'border-red-400 bg-red-500/20'
                        : option.value === 'media'
                          ? 'border-amber-400 bg-amber-500/15'
                          : 'border-emerald-400 bg-emerald-500/10'
                      : 'border-slate-800 bg-slate-900 hover:border-slate-700'
                  }`}
                >
                  <span className="block text-sm font-bold text-white">{option.label}</span>
                  <span className="mt-0.5 block text-[11px] text-slate-400">{option.hint}</span>
                </button>
              ))}
            </div>
          </fieldset>

          <div>
            <label htmlFor="sos-name" className="mb-2 block text-sm font-semibold text-slate-200">
              Tu nombre <span className="text-slate-500">(opcional)</span>
            </label>
            <input
              id="sos-name"
              value={name}
              onChange={(event) => setName(event.target.value)}
              maxLength={120}
              placeholder="Nombre de la persona de contacto"
              className="w-full rounded-xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-white placeholder:text-slate-600 focus:border-red-400 focus:outline-none"
            />
          </div>

          <div>
            <label htmlFor="sos-message" className="mb-2 block text-sm font-semibold text-slate-200">
              Detalles <span className="text-slate-500">(opcional)</span>
            </label>
            <textarea
              id="sos-message"
              value={message}
              onChange={(event) => setMessage(event.target.value)}
              maxLength={500}
              rows={3}
              placeholder="Ej.: hay niños y una persona mayor, el agua sube rápido."
              className="w-full resize-none rounded-xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-white placeholder:text-slate-600 focus:border-red-400 focus:outline-none"
            />
            <p className="mt-1 text-right text-[11px] text-slate-600">{message.length}/500</p>
          </div>

          {error && (
            <div
              role="alert"
              className="flex items-start gap-2 rounded-xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-200"
            >
              <AlertTriangle size={18} className="mt-0.5 shrink-0" />
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={sending}
            className="flex w-full items-center justify-center gap-2 rounded-2xl bg-red-500 px-5 py-4 text-base font-bold text-white shadow-lg shadow-red-950/40 transition hover:bg-red-600 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <Send size={19} />
            {sending ? 'Enviando solicitud…' : 'Enviar solicitud de auxilio'}
          </button>

          <p className="flex items-start gap-2 text-[11px] leading-5 text-slate-500">
            <Activity size={14} className="mt-0.5 shrink-0" />
            Prototipo académico. No reemplaza a los servicios de emergencia oficiales. Recibir la
            solicitud no confirma que la ayuda ya esté en camino.
          </p>
        </form>

        <a
          href="/"
          className="mt-8 flex items-center justify-center gap-2 text-xs text-slate-600 transition hover:text-slate-400"
        >
          <ArrowLeft size={14} /> Volver al centro de operaciones
        </a>
      </div>
    </main>
  )
}
