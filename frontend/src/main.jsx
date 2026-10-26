import { StrictMode, Suspense, lazy } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'

const App = lazy(() => import('./App.jsx'))
const PublicApp = lazy(() => import('./public/PublicApp.jsx'))
const path = window.location.pathname.replace(/\/+$/, '') || '/'
const isPublic = path === '/' || path === '/sos'
const isAdmin = path === '/admin' || path.startsWith('/admin/')

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <Suspense
      fallback={
        <p role="status" style={{ padding: 32 }}>
          Cargando SOSNET…
        </p>
      }
    >
      {isPublic ? (
        <PublicApp />
      ) : isAdmin ? (
        <App />
      ) : (
        <main>
          <h1>Página no encontrada</h1>
          <a href="/">Volver a SOSNET</a>
        </main>
      )}
    </Suspense>
  </StrictMode>,
)
