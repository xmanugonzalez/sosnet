import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import SosForm from './SosForm.jsx'
import './index.css'

const path = window.location.pathname.replace(/\/+$/, '') || '/'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {path === '/sos' ? <SosForm /> : <App />}
  </StrictMode>,
)
