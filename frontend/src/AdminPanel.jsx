import { useState } from 'react'
import { Plus, Settings, ShieldCheck, Users } from 'lucide-react'

export default function AdminPanel({ tab, operators, setOperators, settings, setSettings, activity, recordActivity }) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [error, setError] = useState('')
  const [draft, setDraft] = useState(settings)
  const [saved, setSaved] = useState(false)
  function addOperator(e) {
    e.preventDefault()
    if (!name.trim()) { setError('Escribe el nombre del operador.'); return }
    if (operators.some(o => o.email.toLowerCase() === email.trim().toLowerCase())) { setError('Ya existe un operador con ese correo.'); return }
    setOperators([...operators, { id: crypto.randomUUID(), name: name.trim(), email: email.trim(), active: true }])
    recordActivity(`Se agregó a ${name.trim()} al directorio de operadores de ejemplo.`)
    setName(''); setEmail(''); setError('')
  }
  if (tab === 'Operadores') return <section className="panel admin-panel">
    <div className="section-heading"><div><h2>Equipo de la central</h2><p>Organiza el directorio de operadores de esta demostración.</p></div><Users size={23}/></div>
    <div className="admin-content"><div className="admin-info">Este directorio no crea cuentas de acceso. El alta de usuarios y la asignación de contraseñas se conectarán al backend.</div>
      <form className="operator-form" onSubmit={addOperator}><label className="form-field">Nombre completo<input required maxLength={80} value={name} onChange={e => setName(e.target.value)} /></label><label className="form-field">Correo electrónico<input type="email" required maxLength={120} value={email} onChange={e => setEmail(e.target.value)} /></label><button className="primary-button" type="submit"><Plus size={17}/>Agregar al directorio</button></form>
      {error && <p role="alert" className="form-error">{error}</p>}
      <div className="operator-directory">{operators.map(o => <article key={o.id}><span className="avatar">{o.name.slice(0, 2).toUpperCase()}</span><div><strong>{o.name}</strong><small>{o.email}</small></div><span className={`badge ${o.active ? 'resolved' : 'pending'}`}>{o.active ? 'Activo' : 'Inactivo'}</span><button className="secondary-button" onClick={() => { setOperators(operators.map(item => item.id === o.id ? { ...item, active: !item.active } : item)); recordActivity(`Se marcó a ${o.name} como ${o.active ? 'inactivo' : 'activo'} en el directorio.`) }}>{o.active ? 'Desactivar' : 'Activar'}</button></article>)}</div>
    </div>
  </section>
  if (tab === 'Configuración') return <section className="panel admin-panel"><div className="section-heading"><div><h2>Configuración de la central</h2><p>Personaliza la identificación de tu centro de operaciones.</p></div><Settings size={23}/></div><form className="admin-content settings-form" onSubmit={e => { e.preventDefault(); if (!draft.name.trim() || !draft.location.trim()) return; setSettings({ name: draft.name.trim(), location: draft.location.trim() }); recordActivity('Se actualizó la identificación de la central.'); setSaved(true) }}><label className="form-field">Nombre de la central<input required maxLength={60} value={draft.name} onChange={e => {setDraft({ ...draft, name: e.target.value }); setSaved(false)}} /></label><label className="form-field">Ciudad / comunidad<input required maxLength={80} value={draft.location} onChange={e => {setDraft({ ...draft, location: e.target.value }); setSaved(false)}} /></label><button type="submit" className="primary-button">Guardar configuración</button>{saved && <p className="settings-saved" role="status">Configuración actualizada para esta sesión.</p>}<div className="admin-info"><strong>Próximas funciones</strong><p>Registro de dispositivos, asignación de zonas de cobertura y copias de seguridad. Estas funciones todavía no están disponibles.</p></div></form></section>
  return <section className="panel admin-panel"><div className="section-heading"><div><h2>Actividad de la sesión</h2><p>Consulta los cambios realizados durante esta demostración.</p></div><ShieldCheck size={23}/></div><div className="admin-content"><div className="admin-info">Registro temporal de esta sesión. La auditoría permanente y la identificación de usuarios requieren integración con el servidor.</div><ol className="activity-list">{activity.map(item => <li key={item.id}><span className="activity-dot"/><div><strong>{item.description}</strong><small>{item.actor} · {item.time}</small></div></li>)}</ol>{activity.length === 0 && <p>Aún no hay actividad registrada.</p>}</div></section>
}
