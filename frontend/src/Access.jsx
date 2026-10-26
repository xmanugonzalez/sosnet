import { useState } from 'react'
import { ArrowRight, Eye, EyeOff, LifeBuoy, ShieldCheck, Radio } from 'lucide-react'
import logo from './assets/logo.png'

const accounts = {
  operator: { email: 'operador@sosnet.local', password: 'OperadorDemo123', name: 'Operador de central', label: 'Operador' },
  admin: { email: 'admin@sosnet.local', password: 'AdminDemo123', name: 'Administrador', label: 'Administrador' },
}

export default function Access({ onLogin }) {
  const [role, setRole] = useState('operator')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [visible, setVisible] = useState(false)
  const [error, setError] = useState('')
  const account = accounts[role]
  function selectRole(value) { setRole(value); setEmail(''); setPassword(''); setError('') }
  function submit(event) {
    event.preventDefault()
    if (email.trim().toLowerCase() !== account.email || password !== account.password) {
      setError('Los datos no corresponden a este acceso. Revisa el correo, la contraseña y el rol seleccionado.')
      return
    }
    onLogin({ role, name: account.name })
  }
  return <div className="access-page">
    <section className="access-story">
      <img src={logo} alt="SOSNET" className="access-logo" />
      <span className="access-kicker"><Radio size={16} /> RED LOCAL DE EMERGENCIAS</span>
      <h1>Cuando más importa,<br />seguimos conectados.</h1>
      <p>Un punto de encuentro entre quienes necesitan ayuda y quienes están listos para responder.</p>
      <div className="access-path"><span>Comunidad</span><span>Red SOSNET</span><span>Central de rescate</span></div>
      <small>Prototipo para comunidades de Paraguay</small>
    </section>
    <section className="access-form-section">
      <div className="access-form-card">
        <span className="eyebrow">BIENVENIDO A LA CENTRAL</span>
        <h2>Tu lugar para ayudar.</h2>
        <p className="access-intro">Selecciona tu acceso para comenzar.</p>
        <div className="role-picker" aria-label="Tipo de acceso">
          <button type="button" aria-pressed={role === 'operator'} onClick={() => selectRole('operator')}><LifeBuoy size={21}/><strong>Operador</strong><small>Atender emergencias</small></button>
          <button type="button" aria-pressed={role === 'admin'} onClick={() => selectRole('admin')}><ShieldCheck size={21}/><strong>Administrador</strong><small>Gestionar la central</small></button>
        </div>
        <form onSubmit={submit}>
          <h3>Acceso de {role === 'admin' ? 'administrador' : 'operador'}</h3>
          <label className="form-field">Correo electrónico<input type="email" autoComplete="username" value={email} onChange={e => { setEmail(e.target.value); setError('') }} required placeholder="tu.usuario@sosnet.local" /></label>
          <label className="form-field">Contraseña<span className="password-field"><input type={visible ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={e => { setPassword(e.target.value); setError('') }} required /><button type="button" aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'} onClick={() => setVisible(!visible)}>{visible ? <EyeOff size={18}/> : <Eye size={18}/>}</button></span></label>
          {error && <p className="form-error" role="alert">{error}</p>}
          <button className="primary-button login-submit" type="submit">Ingresar como {account.label.toLowerCase()}<ArrowRight size={17}/></button>
        </form>
        <div className="demo-access"><strong>Acceso de demostración</strong><p>Usa únicamente estos datos de ejemplo. No ingreses contraseñas personales.</p><dl><div><dt>Correo</dt><dd>{account.email}</dd></div><div><dt>Contraseña</dt><dd>{account.password}</dd></div></dl><button type="button" onClick={() => { setEmail(account.email); setPassword(account.password); setError('') }}>Completar datos de prueba</button></div>
        <p className="access-footnote">Prototipo visual: la autenticación y los permisos del servidor todavía no están conectados.</p>
      </div>
    </section>
  </div>
}
