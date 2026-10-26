import { useEffect, useState } from 'react'
import { Plus, Settings, ShieldCheck, Users } from 'lucide-react'
import { apiFetch } from './api.js'

function formatWhen(value) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Sin fecha'
  return date.toLocaleString('es-PY', { dateStyle: 'short', timeStyle: 'short' })
}

export default function AdminPanel({
  tab,
  operators,
  settings,
  activity,
  currentUserId,
  onRefresh,
}) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [role, setRole] = useState('operador')
  const [operatorError, setOperatorError] = useState('')
  const [adding, setAdding] = useState(false)
  const [busyId, setBusyId] = useState(null)
  const [draft, setDraft] = useState(settings)
  const [settingsError, setSettingsError] = useState('')
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    setDraft(settings)
  }, [settings])

  async function addOperator(event) {
    event.preventDefault()
    setOperatorError('')
    if (!name.trim()) {
      setOperatorError('Escribe el nombre del operador.')
      return
    }
    if (password.length < 8) {
      setOperatorError('La contraseña debe tener al menos 8 caracteres.')
      return
    }

    setAdding(true)
    try {
      await apiFetch('/users', {
        method: 'POST',
        body: JSON.stringify({
          nombre: name.trim(),
          correo: email.trim(),
          password,
          rol: role,
        }),
      })
      await onRefresh()
      setName('')
      setEmail('')
      setPassword('')
      setRole('operador')
    } catch (error) {
      setOperatorError(error.message || 'No se pudo crear la cuenta.')
    } finally {
      setAdding(false)
    }
  }

  async function toggleActive(operator) {
    setOperatorError('')
    setBusyId(operator.id)
    try {
      await apiFetch(`/users/${operator.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ activo: !operator.active }),
      })
      await onRefresh()
    } catch (error) {
      setOperatorError(error.message || 'No se pudo actualizar la cuenta.')
    } finally {
      setBusyId(null)
    }
  }

  async function saveSettings(event) {
    event.preventDefault()
    setSettingsError('')
    setSaved(false)
    if (!draft.name.trim() || !draft.location.trim()) {
      setSettingsError('Completa el nombre y la ubicación de la central.')
      return
    }

    setSaving(true)
    try {
      await apiFetch('/settings', {
        method: 'PUT',
        body: JSON.stringify({
          name: draft.name.trim(),
          location: draft.location.trim(),
        }),
      })
      await onRefresh()
      setSaved(true)
    } catch (error) {
      setSettingsError(error.message || 'No se pudo guardar la configuración.')
    } finally {
      setSaving(false)
    }
  }

  if (tab === 'Operadores') {
    return (
      <section className="panel admin-panel">
        <div className="section-heading">
          <div>
            <h2>Equipo de la central</h2>
            <p>Crea cuentas y controla quién puede ingresar al sistema.</p>
          </div>
          <Users size={23} />
        </div>
        <div className="admin-content">
          <div className="admin-info">
            Las cuentas se guardan en la base de datos. Los operadores pueden atender
            solicitudes; los administradores también gestionan usuarios y configuración.
          </div>
          <form className="operator-form" onSubmit={addOperator}>
            <label className="form-field">
              Nombre completo
              <input
                required
                maxLength={100}
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </label>
            <label className="form-field">
              Correo electrónico
              <input
                type="email"
                required
                maxLength={120}
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
            </label>
            <label className="form-field">
              Contraseña inicial
              <input
                type="password"
                required
                minLength={8}
                maxLength={120}
                autoComplete="new-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
            </label>
            <label className="form-field operator-role">
              Rol
              <select value={role} onChange={(event) => setRole(event.target.value)}>
                <option value="operador">Operador</option>
                <option value="admin">Administrador</option>
              </select>
            </label>
            <button className="primary-button" type="submit" disabled={adding}>
              <Plus size={17} />
              {adding ? 'Creando…' : 'Agregar cuenta'}
            </button>
          </form>
          {operatorError && (
            <p role="alert" className="form-error">
              {operatorError}
            </p>
          )}
          <div className="operator-directory">
            {operators.map((operator) => (
              <article key={operator.id}>
                <span className="avatar">
                  {operator.name.slice(0, 2).toUpperCase()}
                </span>
                <div>
                  <strong>
                    {operator.name}
                    {operator.id === currentUserId && <span className="self-tag">Tú</span>}
                  </strong>
                  <small>
                    {operator.email} ·{' '}
                    {operator.role === 'admin' ? 'Administrador' : 'Operador'}
                  </small>
                </div>
                <span className={`badge ${operator.active ? 'resolved' : 'pending'}`}>
                  {operator.active ? 'Activo' : 'Inactivo'}
                </span>
                <button
                  className="secondary-button"
                  disabled={operator.id === currentUserId || busyId === operator.id}
                  onClick={() => toggleActive(operator)}
                >
                  {busyId === operator.id
                    ? 'Guardando…'
                    : operator.id === currentUserId
                      ? 'Tu cuenta'
                      : operator.active
                        ? 'Desactivar'
                        : 'Activar'}
                </button>
              </article>
            ))}
            {operators.length === 0 && <p>Aún no hay cuentas registradas.</p>}
          </div>
        </div>
      </section>
    )
  }

  if (tab === 'Configuración') {
    return (
      <section className="panel admin-panel">
        <div className="section-heading">
          <div>
            <h2>Configuración de la central</h2>
            <p>Personaliza la identificación de tu centro de operaciones.</p>
          </div>
          <Settings size={23} />
        </div>
        <form className="admin-content settings-form" onSubmit={saveSettings}>
          <label className="form-field">
            Nombre de la central
            <input
              required
              maxLength={100}
              value={draft.name}
              onChange={(event) => {
                setDraft({ ...draft, name: event.target.value })
                setSaved(false)
              }}
            />
          </label>
          <label className="form-field">
            Ciudad / comunidad
            <input
              required
              maxLength={150}
              value={draft.location}
              onChange={(event) => {
                setDraft({ ...draft, location: event.target.value })
                setSaved(false)
              }}
            />
          </label>
          <button type="submit" className="primary-button" disabled={saving}>
            {saving ? 'Guardando…' : 'Guardar configuración'}
          </button>
          {settingsError && (
            <p role="alert" className="form-error">
              {settingsError}
            </p>
          )}
          {saved && (
            <p className="settings-saved" role="status">
              Configuración guardada en la central.
            </p>
          )}
          <div className="admin-info">
            <strong>Próximas funciones</strong>
            <p>
              Registro de dispositivos, asignación de zonas de cobertura y copias de
              seguridad. Estas funciones todavía no están disponibles.
            </p>
          </div>
        </form>
      </section>
    )
  }

  return (
    <section className="panel admin-panel">
      <div className="section-heading">
        <div>
          <h2>Actividad de la central</h2>
          <p>Auditoría de accesos, cuentas, configuración y cambios de estado.</p>
        </div>
        <ShieldCheck size={23} />
      </div>
      <div className="admin-content">
        <div className="admin-info">
          El registro se conserva en la base de datos y asocia cada evento con la cuenta
          que lo realizó.
        </div>
        <ol className="activity-list">
          {activity.map((item) => (
            <li key={item.id}>
              <span className="activity-dot" />
              <div>
                <strong>{item.description}</strong>
                <small>
                  {item.actor} · {formatWhen(item.created_at)}
                </small>
              </div>
            </li>
          ))}
        </ol>
        {activity.length === 0 && <p>Aún no hay actividad registrada.</p>}
      </div>
    </section>
  )
}
