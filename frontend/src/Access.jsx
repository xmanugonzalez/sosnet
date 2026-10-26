import { useRef, useState } from 'react'
import { ArrowRight, Eye, EyeOff, Mail, LockKeyhole, LoaderCircle } from 'lucide-react'
import { apiFetch, setToken } from './api.js'
import logo from './assets/logo-sin-letra.png'
import './access.css'

export default function Access({ onLogin }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [visible, setVisible] = useState(false)
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const submittingRef = useRef(false)

  async function submit(event) {
    event.preventDefault()
    if (submittingRef.current) return
    submittingRef.current = true
    setError('')
    setSubmitting(true)
    try {
      const data = await apiFetch('/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          identifier: email.trim(),
          password,
        }),
      })
      setToken(data.token)
      onLogin(data.user)
    } catch (loginError) {
      setError(loginError.message || 'No se pudo iniciar sesión.')
    } finally {
      submittingRef.current = false
      setSubmitting(false)
    }
  }

  return (
    <main className="central-access">
      <section className="central-story" aria-labelledby="central-story-title">
        <a href="/" className="central-wordmark" aria-label="SOSNET, ir al formulario SOS">
          <div className="central-brand-line">
            <img className="central-logo" src={logo} alt="" width="1280" height="1280" />
            <strong><span>SOS</span>NET</strong>
          </div>
          <span>Red local de emergencias</span>
        </a>
        <div className="central-story-copy">
          <span className="central-story-rule" aria-hidden="true" />
          <h1 id="central-story-title">Tecnología que<br />conecta cuando<br /><span>más se necesita.</span></h1>
          <p>Una red local de comunicación para que las comunidades puedan solicitar ayuda y los equipos de rescate puedan responder.</p>
        </div>
      </section>
      <section className="central-login" aria-labelledby="central-login-title">
        <div className="central-login-card">
          <p className="central-eyebrow">Acceso a la central</p>
          <h2 id="central-login-title">Inicia sesión</h2>
          <p className="central-intro">Ingresa tus credenciales para acceder al sistema de gestión de emergencias.</p>
          <form onSubmit={submit} aria-busy={submitting}>
            <fieldset disabled={submitting} className="central-credentials">
              <legend className="sr-only">Credenciales de acceso a la central</legend>
              <label className="central-field" htmlFor="central-email">Correo electrónico</label>
              <div className="central-input">
                <Mail size={19} aria-hidden="true" />
                <input id="central-email" type="text" inputMode="email" autoCapitalize="none" spellCheck={false} autoComplete="username" value={email}
                  onChange={event => { setEmail(event.target.value); setError('') }}
                  required placeholder="tu.usuario@sosnet.local" />
              </div>
              <label className="central-field" htmlFor="central-password">Contraseña</label>
              <div className="central-input">
                <LockKeyhole size={19} aria-hidden="true" />
                <input id="central-password" type={visible ? 'text' : 'password'} autoComplete="current-password" value={password}
                  onChange={event => { setPassword(event.target.value); setError('') }}
                  required placeholder="Ingresa tu contraseña" />
                <button className="central-password-toggle" type="button" aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'} aria-pressed={visible} onClick={() => setVisible(!visible)}>
                  {visible ? <EyeOff size={19} aria-hidden="true" /> : <Eye size={19} aria-hidden="true" />}
                </button>
              </div>
              <details className="central-recovery">
                <summary>¿Olvidaste tu contraseña?</summary>
                <p>Contacta al administrador de tu central para recuperar el acceso a tu cuenta.</p>
              </details>
              {error && <p className="central-error" role="alert">{error}</p>}
              <button className="central-submit" type="submit">
                {submitting ? 'Verificando acceso…' : 'Iniciar sesión'}
                {submitting ? <LoaderCircle className="central-spinner" size={20} aria-hidden="true" /> : <ArrowRight size={20} aria-hidden="true" />}
              </button>
            </fieldset>
          </form>
        </div>
      </section>
    </main>
  )
}
