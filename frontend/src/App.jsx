import { createElement } from 'react'
import { Activity, Radio, Server } from 'lucide-react'

const services = [
  { name: 'API Flask', detail: 'Puerto 5000', icon: Server },
  { name: 'Receptor serial', detail: 'ESP32 por USB', icon: Radio },
  { name: 'Base de datos', detail: 'MySQL 8', icon: Activity },
]

export default function App() {
  return (
    <main className="min-h-screen bg-slate-950 px-6 py-16 text-slate-100">
      <div className="mx-auto max-w-5xl">
        <div className="mb-12 flex items-center gap-3">
          <div className="grid size-11 place-items-center rounded-xl bg-red-500 font-black text-white">S</div>
          <div>
            <p className="text-xl font-bold tracking-tight">SOSNET</p>
            <p className="text-sm text-slate-400">Red local de emergencias</p>
          </div>
        </div>

        <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-8 shadow-2xl shadow-red-950/20 md:p-12">
          <span className="inline-flex rounded-full bg-emerald-400/10 px-3 py-1 text-sm font-medium text-emerald-300">
            Entorno configurado
          </span>
          <h1 className="mt-6 max-w-3xl text-4xl font-bold tracking-tight md:text-6xl">
            Centro de gestión de emergencias
          </h1>
          <p className="mt-5 max-w-2xl text-lg leading-8 text-slate-400">
            La base técnica está lista para recibir alertas desde la red ESP-NOW, procesarlas y mostrarlas en tiempo real.
          </p>

          <div className="mt-10 grid gap-4 md:grid-cols-3">
            {services.map((service) => (
              <article key={service.name} className="rounded-2xl border border-slate-800 bg-slate-950/60 p-5">
                {createElement(service.icon, {
                  className: 'mb-5 size-6 text-red-400',
                  'aria-hidden': true,
                })}
                <h2 className="font-semibold">{service.name}</h2>
                <p className="mt-1 text-sm text-slate-500">{service.detail}</p>
              </article>
            ))}
          </div>
        </section>
      </div>
    </main>
  )
}

