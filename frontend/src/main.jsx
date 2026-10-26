import { StrictMode, Suspense, lazy } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'

const App = lazy(() => import('./App.jsx'))
const SosForm = lazy(() => import('./SosForm.jsx'))
const path = window.location.pathname.replace(/\/+$/, '') || '/'
const isSosForm = path === '/' || path === '/sos'
const isCentral = path === '/admin' || path.startsWith('/admin/')

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <Suspense
      fallback={
        <p role="status" style={{ padding: 32 }}>
          Cargando SOSNET…
        </p>
      }
    >
      {isSosForm ? (
        <SosForm />
      ) : isCentral ? (
        <App />
      ) : (
        <main>
          <h1>Página no encontrada</h1>
          <a href="/">Ir al formulario SOS</a>
        </main>
      )}
    </Suspense>
  </StrictMode>,
)
