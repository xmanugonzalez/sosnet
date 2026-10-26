import { createElement, useCallback, useEffect, useState } from 'react'
import logo from './assets/logo.png'
import Access from './Access.jsx'
import AdminPanel from './AdminPanel.jsx'
import {
  Activity,
  AlertTriangle,
  ArrowDownLeft,
  ArrowRight,
  Bell,
  Check,
  CheckCircle2,
  ChevronRight,
  ClipboardList,
  Clock3,
  Filter,
  HeartPulse,
  LayoutDashboard,
  LifeBuoy,
  List,
  LogOut,
  MapPin,
  Menu,
  Radio,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  Users,
  Waves,
  X,
} from 'lucide-react'

const API_URL = import.meta.env.VITE_API_URL || '/api'

const STATUS_LABELS = {
  pending: 'Pendiente',
  in_progress: 'En atención',
  resolved: 'Resuelta',
}
const STATUS_CLASS = { pending: 'pending', in_progress: 'active', resolved: 'resolved' }
const PRIORITY_LABELS = { alta: 'Alta', media: 'Media', baja: 'Baja' }
const PRIORITY_CLASS = { alta: 'high', media: 'medium', baja: 'low' }

const FILTERS = [
  { key: 'all', label: 'Todas' },
  { key: 'pending', label: 'Pendientes' },
  { key: 'in_progress', label: 'En atención' },
  { key: 'resolved', label: 'Resueltas' },
]

function mapEmergency(emergency) {
  const received = new Date(emergency.received_at)
  const validDate = !Number.isNaN(received.getTime())

  return {
    id: `SOS-${String(emergency.id).padStart(3, '0')}`,
    rawId: emergency.id,
    name: emergency.reporter_name || 'Sin nombre',
    location: emergency.location || 'Ubicación no indicada',
    reference: emergency.message,
    type: emergency.emergency_type,
    people: emergency.people ?? 1,
    priorityKey: emergency.priority || 'media',
    statusKey: emergency.status || 'pending',
    time: validDate
      ? received.toLocaleTimeString('es-PY', { hour: '2-digit', minute: '2-digit' })
      : '--:--',
    date: validDate ? received.toLocaleDateString('es-PY') : '',
    node: emergency.device_id,
    latitude: emergency.latitude,
    longitude: emergency.longitude,
    x: 25 + ((emergency.id * 37) % 55),
    y: 25 + ((emergency.id * 53) % 50),
  }
}

function Badge({ statusKey }) {
  return (
    <span className={`badge ${STATUS_CLASS[statusKey] || 'pending'}`}>
      <i />
      {STATUS_LABELS[statusKey] || 'Pendiente'}
    </span>
  )
}

export default function App() {
  const [reports, setReports] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [lastUpdated, setLastUpdated] = useState(null)
  const [tab, setTab] = useState('Resumen')
  const [filter, setFilter] = useState('all')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState(null)
  const [menu, setMenu] = useState(false)
  const [notice, setNotice] = useState('')
  const [changing, setChanging] = useState(false)
  const [session, setSession] = useState(null)
  const [operators, setOperators] = useState([
    {
      id: 'demo-operator',
      name: 'Operador de central',
      email: 'operador@sosnet.local',
      active: true,
    },
  ])
  const [settings, setSettings] = useState({
    name: 'Central de rescate',
    location: 'Asunción, Paraguay',
  })
  const [activity, setActivity] = useState([])
  const isAdmin = session?.role === 'admin'
  const adminTabs = ['Operadores', 'Configuración', 'Actividad']

  function recordActivity(description, actor = session?.name) {
    setActivity((items) => [
      {
        id: crypto.randomUUID(),
        description,
        actor,
        time: new Date().toLocaleTimeString('es-PY', { hour: '2-digit', minute: '2-digit' }),
      },
      ...items,
    ])
  }

  function login(user) {
    setSession(user)
    setTab('Resumen')
    recordActivity(
      `Inicio de sesión de ${user.role === 'admin' ? 'administrador' : 'operador'}.`,
      user.name,
    )
  }

  function logout() {
    recordActivity('Se cerró la sesión.')
    setSession(null)
    setSelected(null)
    setTab('Resumen')
    setMenu(false)
    setNotice('')
    setQuery('')
    setFilter('all')
  }

  const loadEmergencies = useCallback(async () => {
    try {
      const response = await fetch(`${API_URL}/emergencies`)
      if (!response.ok) throw new Error('La central no respondió')
      const data = await response.json()
      setReports(data.map(mapEmergency))
      setError('')
      setLastUpdated(new Date())
    } catch {
      setError('No se pudieron cargar las solicitudes. Verifica la conexión con la central.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadEmergencies()
    const interval = setInterval(loadEmergencies, 15000)
    return () => clearInterval(interval)
  }, [loadEmergencies])

  const filtered = reports.filter(
    (report) =>
      (filter === 'all' || report.statusKey === filter) &&
      `${report.id} ${report.name} ${report.location} ${report.type}`
        .toLowerCase()
        .includes(query.toLowerCase()),
  )
  const current = reports.find((report) => report.id === selected)
  const pendingCount = reports.filter((report) => report.statusKey === 'pending').length

  function changeStatus(statusKey) {
    if (!current || !session) return
    setChanging(true)
    fetch(`${API_URL}/emergencies/${current.rawId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: statusKey }),
    })
      .then(async (response) => {
        if (!response.ok) throw new Error()
        const updated = await response.json()
        setReports((previous) =>
          previous.map((report) =>
            report.rawId === updated.id ? mapEmergency(updated) : report,
          ),
        )
        recordActivity(`${current.id}: estado actualizado a ${STATUS_LABELS[statusKey]}.`)
        setNotice(`Estado actualizado: ${STATUS_LABELS[statusKey]}.`)
        setSelected(null)
      })
      .catch(() =>
        setNotice('No se pudo actualizar el estado. Verifica la conexión con la central.'),
      )
      .finally(() => setChanging(false))
  }

  function navigate(value) {
    if (adminTabs.includes(value) && !isAdmin) return
    setTab(value)
    setMenu(false)
  }

  if (!session) return <Access onLogin={login} />

  const stats = [
    {
      label: 'Solicitudes recibidas',
      value: reports.length,
      detail: 'Registradas en la central',
      icon: ArrowDownLeft,
      color: 'neutral',
    },
    {
      label: 'Pendientes',
      value: reports.filter((report) => report.statusKey === 'pending').length,
      detail: 'Necesitan una primera respuesta',
      icon: Clock3,
      color: 'orange',
    },
    {
      label: 'En atención',
      value: reports.filter((report) => report.statusKey === 'in_progress').length,
      detail: 'Con asistencia en seguimiento',
      icon: LifeBuoy,
      color: 'blue',
    },
    {
      label: 'Resueltas',
      value: reports.filter((report) => report.statusKey === 'resolved').length,
      detail: 'Asistencia finalizada',
      icon: CheckCircle2,
      color: 'green',
    },
  ]

  return (
    <div className="app-shell">
      <aside className={`sidebar ${menu ? 'open' : ''}`}>
        <a
          className="brand"
          href="#"
          onClick={() => navigate('Resumen')}
          aria-label="SOSNET, inicio"
        >
          <img
            className="brand-logo"
            src={logo}
            alt="SOSNET"
            width="2172"
            height="724"
          />
        </a>
        <div className="workspace">
          <span className="workspace-icon">
            <ShieldCheck size={20} />
          </span>
          <div>
            {settings.name}
            <small>{settings.location}</small>
          </div>
          <span className="live-dot" />
        </div>
        <p className="nav-label">CENTRO DE OPERACIONES</p>
        <nav aria-label="Navegación principal">
          {[
            { name: 'Resumen', icon: LayoutDashboard },
            { name: 'Solicitudes', icon: List },
            { name: 'Red de dispositivos', icon: Radio },
            ...(isAdmin
              ? [
                  { name: 'Operadores', icon: Users },
                  { name: 'Configuración', icon: Settings },
                  { name: 'Actividad', icon: ClipboardList },
                ]
              : []),
          ].map(({ name, icon: Icon }) => (
            <button
              key={name}
              className={`nav-item ${tab === name ? 'selected' : ''}`}
              onClick={() => navigate(name)}
            >
              {createElement(Icon, { size: 19, 'aria-hidden': true })}
              {name}
              {name === 'Solicitudes' && <span className="nav-count">{pendingCount}</span>}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="offline-card">
            <Radio size={20} />
            <strong>La ayuda sigue conectada.</strong>
            <p>Una red local para estar cerca, incluso sin internet.</p>
            <span>PROTOTIPO · ESP-NOW</span>
          </div>
          <div className="operator">
            <span className="avatar">{isAdmin ? 'AD' : 'OP'}</span>
            <div>
              {session.name}
              <small>{isAdmin ? 'Administración' : 'Atención de emergencias'}</small>
            </div>
            <button
              className="icon-button logout-button"
              onClick={logout}
              aria-label="Cerrar sesión"
              title="Cerrar sesión"
            >
              <LogOut size={18} />
            </button>
          </div>
        </div>
      </aside>

      <div className="main-shell">
        <header className="topbar">
          <div className="breadcrumb">
            <button
              className="mobile-menu icon-button"
              aria-label="Abrir menú"
              onClick={() => setMenu(!menu)}
            >
              <Menu size={21} />
            </button>
            <a
              className="mobile-brand"
              href="#"
              onClick={() => navigate('Resumen')}
              aria-label="SOSNET, inicio"
            >
              <img src={logo} alt="SOSNET" width="2172" height="724" />
            </a>
            <span>Centro de operaciones</span>
            <ChevronRight size={14} />
            <strong>{tab}</strong>
          </div>
          <div className="topbar-right">
            <a
              href="/sos"
              className="inline-flex items-center gap-2 rounded-lg bg-red-500 px-3 py-2 text-xs font-semibold text-white transition hover:bg-red-600"
            >
              <LifeBuoy size={15} /> Formulario SOS
            </a>
            <button
              className="icon-button"
              onClick={loadEmergencies}
              aria-label="Actualizar solicitudes"
              title="Actualizar solicitudes"
            >
              <RefreshCw size={17} />
            </button>
            <span className="demo-label">
              <i />
              Datos locales
            </span>
            <span className="top-divider" />
            <span className="role-indicator">{isAdmin ? 'Administrador' : 'Operador'}</span>
            <button
              className="icon-button"
              onClick={logout}
              aria-label="Cerrar sesión"
              title="Cerrar sesión"
            >
              <LogOut size={17} />
            </button>
          </div>
        </header>

        <main>
          <div className="page-heading">
            <div>
              <div className="eyebrow">CADA SOLICITUD CUENTA</div>
              <h1>
                {adminTabs.includes(tab)
                  ? tab
                  : tab === 'Resumen'
                    ? 'Panorama de emergencias'
                    : tab === 'Solicitudes'
                      ? 'Solicitudes de emergencia'
                      : 'Red de dispositivos'}
              </h1>
              <p>
                {adminTabs.includes(tab)
                  ? 'Herramientas de administración para organizar tu central.'
                  : tab === 'Red de dispositivos'
                    ? 'Conoce el recorrido de las solicitudes hasta tu central.'
                    : 'Toda la información que necesitas para coordinar la ayuda.'}
              </p>
            </div>
            <span className="local-label">
              <Radio size={16} /> Operación en red local
            </span>
          </div>

          <div className="demo-banner">
            <LifeBuoy size={18} />
            <span>
              <strong>Estás en el prototipo.</strong> Las solicitudes enviadas desde el formulario
              SOS se guardan en la base de datos de esta central.
            </span>
          </div>

          {error && (
            <div className="mb-4 flex items-center gap-2 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-xs text-red-700">
              <AlertTriangle size={16} />
              {error}
              <button className="ml-auto font-semibold underline" onClick={loadEmergencies}>
                Reintentar
              </button>
            </div>
          )}

          {notice && (
            <div className="notice" role="status">
              <CheckCircle2 size={17} />
              {notice}
              <button aria-label="Cerrar aviso" onClick={() => setNotice('')}>
                <X size={16} />
              </button>
            </div>
          )}

          {isAdmin && adminTabs.includes(tab) ? (
            <AdminPanel
              key={tab}
              tab={tab}
              operators={operators}
              setOperators={setOperators}
              settings={settings}
              setSettings={setSettings}
              activity={activity}
              recordActivity={recordActivity}
            />
          ) : tab === 'Red de dispositivos' ? (
            <section className="panel network-panel">
              <div className="section-heading">
                <div>
                  <h2>Una red, tres puntos de conexión</h2>
                  <p>Recorrido previsto para el primer prototipo</p>
                </div>
                <span className="subtle-tag">Esquema de ejemplo</span>
              </div>
              <div className="network-flow">
                {['Emisor', 'Repetidor', 'Receptor'].map((name, index) => (
                  <article key={name}>
                    <span className="node-symbol">
                      <Radio size={28} />
                    </span>
                    <small>ESP32 · 0{index + 1}</small>
                    <h3>{name}</h3>
                    <p>
                      {
                        [
                          'Recibe el formulario SOS desde el celular por Wi-Fi local.',
                          'Retransmite la solicitud mediante ESP-NOW.',
                          'Entrega la solicitud a la central mediante USB.',
                        ][index]
                      }
                    </p>
                    <span className="subtle-tag">Sin telemetría conectada</span>
                  </article>
                ))}
              </div>
              <div className="network-note">
                <ShieldCheck size={20} />
                <p>
                  La conexión real de los dispositivos estará disponible al integrar el hardware.
                  Este esquema no indica cobertura ni disponibilidad.
                </p>
              </div>
            </section>
          ) : (
            <>
              <section className="stats" aria-label="Resumen de solicitudes">
                {stats.map(({ label, value, detail, icon: Icon, color }) => (
                  <article className={`stat-card ${color}`} key={label}>
                    <div>
                      <span>{label}</span>
                      <span className="stat-icon">
                        {createElement(Icon, { size: 19, 'aria-hidden': true })}
                      </span>
                    </div>
                    <strong>{String(value).padStart(2, '0')}</strong>
                    <small>{detail}</small>
                  </article>
                ))}
              </section>

              {tab === 'Resumen' && (
                <section className="overview-grid">
                  <div className="panel map-panel">
                    <div className="section-heading">
                      <div>
                        <h2>Un vistazo al territorio</h2>
                        <p>Selecciona un punto para ver la solicitud</p>
                      </div>
                      <span className="subtle-tag">
                        <MapPin size={12} /> Vista ilustrativa
                      </span>
                    </div>
                    <div className="map-canvas">
                      <div className="map-grid" />
                      <div className="river" />
                      <span className="river-label">RÍO PARAGUAY</span>
                      <div className="road road-one" />
                      <div className="road road-two" />
                      <div className="road road-three" />
                      <span className="map-place place-one">BAÑADO SUR</span>
                      <span className="map-place place-two">SANTA ANA</span>
                      <span className="map-place place-three">SAN CAYETANO</span>
                      {reports.map((report) => (
                        <button
                          key={report.id}
                          className={`map-pin ${STATUS_CLASS[report.statusKey] || 'pending'}`}
                          style={{ left: `${report.x}%`, top: `${report.y}%` }}
                          onClick={() => setSelected(report.id)}
                          aria-label={`Ver ${report.id}: ${report.type}`}
                        >
                          <MapPin size={18} fill="currentColor" />
                          <span>{report.id.slice(-3)}</span>
                        </button>
                      ))}
                      <span className="map-caption">
                        Posiciones referenciales · Sin escala geográfica
                      </span>
                    </div>
                    <div className="map-legend">
                      <span>
                        <i className="dot-orange" />
                        Pendiente
                      </span>
                      <span>
                        <i className="dot-blue" />
                        En atención
                      </span>
                      <span>
                        <i className="dot-green" />
                        Resuelta
                      </span>
                    </div>
                  </div>

                  <div className="panel priority-panel">
                    <div className="section-heading">
                      <div>
                        <h2>Atención prioritaria</h2>
                        <p>Solicitudes que necesitan tu atención</p>
                      </div>
                      <span className="priority-symbol">
                        <Bell size={18} />
                      </span>
                    </div>
                    <div className="priority-list">
                      {reports
                        .filter(
                          (report) =>
                            report.priorityKey === 'alta' && report.statusKey !== 'resolved',
                        )
                        .map((report) => (
                          <button
                            key={report.id}
                            className="priority-item"
                            onClick={() => setSelected(report.id)}
                          >
                            <div className="priority-item-top">
                              <span className="priority high">Prioridad alta</span>
                              <small>{report.time}</small>
                            </div>
                            <h3>{report.type}</h3>
                            <p>
                              <MapPin size={13} />
                              {report.location}
                            </p>
                            <div className="priority-item-bottom">
                              <span>
                                <Users size={14} />
                                {report.people} personas
                              </span>
                              <ArrowRight size={17} />
                            </div>
                          </button>
                        ))}
                      {reports.filter(
                        (report) =>
                          report.priorityKey === 'alta' && report.statusKey !== 'resolved',
                      ).length === 0 && (
                        <div className="empty-priority">
                          <CheckCircle2 />
                          <p>No hay solicitudes de prioridad alta por atender.</p>
                        </div>
                      )}
                    </div>
                    <div className="priority-footer">
                      <ShieldCheck size={15} />
                      Cada respuesta hace la diferencia.
                    </div>
                  </div>
                </section>
              )}

              <section className="panel requests-panel">
                <div className="section-heading">
                  <div>
                    <h2>
                      {tab === 'Resumen' ? 'Últimas solicitudes' : 'Todas las solicitudes'}
                      <span className="total-tag">{reports.length}</span>
                    </h2>
                    <p>Consulta los detalles y da seguimiento a cada emergencia.</p>
                  </div>
                  <label className="search">
                    <Search size={17} />
                    <input
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      placeholder="Buscar solicitud…"
                      aria-label="Buscar por código, nombre, ubicación o emergencia"
                    />
                  </label>
                </div>
                <div className="filter-bar">
                  <div className="filter-tabs" aria-label="Filtrar por estado">
                    {FILTERS.map(({ key, label }) => (
                      <button
                        key={key}
                        aria-pressed={filter === key}
                        className={filter === key ? 'chosen' : ''}
                        onClick={() => setFilter(key)}
                      >
                        {label}
                        <span>
                          {key === 'all'
                            ? reports.length
                            : reports.filter((report) => report.statusKey === key).length}
                        </span>
                      </button>
                    ))}
                  </div>
                  <span className="filter-hint">
                    <Filter size={14} />
                    Por estado
                  </span>
                </div>
                <div className="table-scroll">
                  <table>
                    <thead>
                      <tr>
                        <th>Solicitud</th>
                        <th>Emergencia / ubicación</th>
                        <th>Personas</th>
                        <th>Prioridad</th>
                        <th>Estado</th>
                        <th>
                          <span className="sr-only">Acción</span>
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {filtered.map((report) => (
                        <tr key={report.id}>
                          <td>
                            <strong className="report-id">{report.id}</strong>
                            <small>Recibida a las {report.time}</small>
                          </td>
                          <td>
                            <div className="emergency-cell">
                              <span
                                className={`emergency-icon ${
                                  report.type === 'Asistencia médica' ? 'medical' : ''
                                }`}
                              >
                                {report.type === 'Asistencia médica' ? (
                                  <HeartPulse size={19} />
                                ) : report.type === 'Inundación' ? (
                                  <Waves size={19} />
                                ) : (
                                  <LifeBuoy size={19} />
                                )}
                              </span>
                              <div>
                                <strong>{report.type}</strong>
                                <small>{report.location}</small>
                              </div>
                            </div>
                          </td>
                          <td>
                            <span className="people">
                              <Users size={15} />
                              {report.people}
                            </span>
                          </td>
                          <td>
                            <span
                              className={`priority ${
                                PRIORITY_CLASS[report.priorityKey] || 'medium'
                              }`}
                            >
                              <i />
                              {PRIORITY_LABELS[report.priorityKey] || 'Media'}
                            </span>
                          </td>
                          <td>
                            <Badge statusKey={report.statusKey} />
                          </td>
                          <td>
                            <button
                              className="detail-button"
                              onClick={() => setSelected(report.id)}
                            >
                              Ver detalle
                              <ChevronRight size={14} />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filtered.length === 0 && (
                    <div className="empty-state">
                      <Search size={26} />
                      <h3>
                        {reports.length === 0
                          ? 'Todavía no hay solicitudes'
                          : 'No encontramos solicitudes'}
                      </h3>
                      <p>
                        {reports.length === 0
                          ? 'Las alertas enviadas desde el formulario SOS aparecerán aquí.'
                          : 'Prueba con otra búsqueda o cambia el filtro de estado.'}
                      </p>
                      {reports.length === 0 ? (
                        <a href="/sos">Abrir formulario SOS</a>
                      ) : (
                        <button
                          onClick={() => {
                            setQuery('')
                            setFilter('all')
                          }}
                        >
                          Limpiar filtros
                        </button>
                      )}
                    </div>
                  )}
                </div>
                <div className="table-footer">
                  Mostrando {filtered.length} de {reports.length} solicitudes
                  <span>
                    {loading
                      ? 'Cargando…'
                      : lastUpdated
                        ? `Actualizado ${lastUpdated.toLocaleTimeString('es-PY', {
                            hour: '2-digit',
                            minute: '2-digit',
                          })}`
                        : 'Datos de la central'}
                  </span>
                </div>
              </section>
            </>
          )}

          <footer className="page-footer">
            <span>
              <Activity size={14} />
              SOSNET · Comunicación que acerca la ayuda
            </span>
            <span>Prototipo de red local de emergencias</span>
          </footer>
        </main>
      </div>

      {current && (
        <div className="modal-backdrop" onClick={() => setSelected(null)}>
          <section
            className="detail-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="detail-title"
            onClick={(event) => event.stopPropagation()}
            onKeyDown={(event) => {
              if (event.key === 'Escape') setSelected(null)
            }}
          >
            <button
              autoFocus
              className="modal-close icon-button"
              onClick={() => setSelected(null)}
              aria-label="Cerrar detalle"
            >
              <X size={22} />
            </button>
            <span className="eyebrow">SOLICITUD RECIBIDA</span>
            <h2 id="detail-title">
              {current.id} · {current.type}
            </h2>
            <div className="detail-badges">
              <Badge statusKey={current.statusKey} />
              <span className="priority">
                Prioridad {(PRIORITY_LABELS[current.priorityKey] || 'Media').toLowerCase()}
              </span>
            </div>
            <div className="detail-message">
              <strong>Mensaje de la persona afectada</strong>
              <p>{current.reference}</p>
            </div>
            <dl>
              <div>
                <dt>Persona de contacto</dt>
                <dd>{current.name}</dd>
              </div>
              <div>
                <dt>Ubicación de referencia</dt>
                <dd>{current.location}</dd>
              </div>
              <div>
                <dt>Personas que necesitan ayuda</dt>
                <dd>{current.people} personas</dd>
              </div>
              <div>
                <dt>Recibida por la central</dt>
                <dd>
                  {current.date} {current.time} · {current.node}
                </dd>
              </div>
              {current.latitude != null && current.longitude != null && (
                <div>
                  <dt>Coordenadas GPS</dt>
                  <dd>
                    {current.latitude}, {current.longitude}
                  </dd>
                </div>
              )}
            </dl>
            <p className="detail-help">
              El estado indica el seguimiento en la central. Recibir una solicitud no significa
              que la ayuda haya llegado.
            </p>
            <div className="status-actions">
              {current.statusKey === 'pending' && (
                <button
                  className="primary-button"
                  onClick={() => changeStatus('in_progress')}
                  disabled={changing}
                >
                  <LifeBuoy size={17} />
                  Iniciar atención
                </button>
              )}
              {current.statusKey === 'in_progress' && (
                <button
                  className="primary-button"
                  onClick={() => changeStatus('resolved')}
                  disabled={changing}
                >
                  <Check size={17} />
                  Marcar como resuelta
                </button>
              )}
              {isAdmin && current.statusKey === 'resolved' && (
                <button
                  className="secondary-button"
                  onClick={() => changeStatus('pending')}
                  disabled={changing}
                >
                  Reabrir solicitud
                </button>
              )}
              <button className="secondary-button" onClick={() => setSelected(null)}>
                Cerrar
              </button>
            </div>
            <small className="demo-footnote">
              Los cambios se guardan en la base de datos de la central.
            </small>
          </section>
        </div>
      )}
    </div>
  )
}
