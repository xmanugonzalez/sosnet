import { spawn } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { createServer } from 'node:net'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { setTimeout as delay } from 'node:timers/promises'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const windows = process.platform === 'win32'
const python = resolve(root, 'backend/.venv', windows ? 'Scripts/python.exe' : 'bin/python')
const children = new Set()
let stopping = false

function launch(command, args, cwd = root) {
  const child = spawn(command, args, { cwd, stdio: 'inherit', windowsHide: true })
  children.add(child)
  child.once('close', () => children.delete(child))
  return child
}

function run(command, args) {
  return new Promise((resolveRun, reject) => {
    const child = launch(command, args)
    child.once('error', reject)
    child.once('close', code => code === 0 ? resolveRun() : reject(new Error(`${command} terminó con código ${code}.`)))
  })
}

async function findPython() {
  const candidates = windows ? [['py', ['-3']], ['python', []], ['python3', []]] : [['python3', []], ['python', []]]
  for (const [command, args] of candidates) {
    try {
      await run(command, [...args, '-c', 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'])
      return [command, args]
    } catch { /* Probar el siguiente intérprete disponible. */ }
  }
  throw new Error('Instala Python 3.11 o superior (con venv y pip) y agrégalo al PATH.')
}

async function backendContainerRunning() {
  try {
    const output = await new Promise((resolveOutput, reject) => {
      const child = spawn('docker', ['compose', 'ps', '--status', 'running', '--services'], {
        stdio: ['ignore', 'pipe', 'ignore'],
        windowsHide: true,
      })
      let text = ''
      child.stdout.on('data', chunk => { text += chunk })
      child.once('error', reject)
      child.once('close', code => resolveOutput(code === 0 ? text : ''))
    })
    return output.split(/\r?\n/).map(name => name.trim()).includes('backend')
  } catch {
    return false
  }
}

async function prepareDependencies(withPython = true) {
  for (const directory of ['', 'backend', 'frontend']) {
    const target = resolve(root, directory, '.env')
    if (!existsSync(target)) {
      copyFileSync(resolve(root, directory, '.env.example'), target)
      console.log(`[SOSNET] Creado ${directory ? `${directory}/` : ''}.env desde el ejemplo.`)
    }
  }
  if (withPython) {
    if (!existsSync(python)) {
      console.log('[SOSNET] Creando entorno virtual Python…')
      const [command, args] = await findPython()
      await run(command, [...args, '-m', 'venv', resolve(root, 'backend/.venv')])
    }
    if (stopping) return
    const requirements = resolve(root, 'backend/requirements-dev.txt')
    const pythonStamp = resolve(root, 'backend/.venv/.sosnet-dependencies')
    const pythonHash = createHash('sha256')
      .update(readFileSync(requirements))
      .update(readFileSync(resolve(root, 'backend/requirements.txt'))).digest('hex')
    if (!existsSync(pythonStamp) || readFileSync(pythonStamp, 'utf8') !== pythonHash) {
      console.log('[SOSNET] Instalando dependencias Python…')
      await run(python, ['-m', 'pip', 'install', '-r', requirements])
      if (stopping) return
      writeFileSync(pythonStamp, pythonHash)
    }
  }
  const frontendStamp = resolve(root, 'frontend/node_modules/.sosnet-dependencies')
  const frontendHash = createHash('sha256')
    .update(readFileSync(resolve(root, 'frontend/package.json')))
    .update(readFileSync(resolve(root, 'frontend/package-lock.json'))).digest('hex')
  if (!existsSync(resolve(root, 'frontend/node_modules/vite/bin/vite.js')) || !existsSync(frontendStamp) || readFileSync(frontendStamp, 'utf8') !== frontendHash) {
    console.log('[SOSNET] Instalando dependencias del frontend…')
    if (windows) {
      await run(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', 'npm --prefix frontend ci --no-audit --no-fund'])
    } else {
      await run('npm', ['--prefix', 'frontend', 'ci', '--no-audit', '--no-fund'])
    }
    if (stopping) return
    writeFileSync(frontendStamp, frontendHash)
  }
}

async function stop(code = 0) {
  if (stopping) return
  stopping = true
  process.exitCode = code
  for (const child of children) {
    if (!child.pid) continue
    if (windows) {
      await new Promise(resolveStop => {
        const killer = spawn('taskkill', ['/pid', String(child.pid), '/T', '/F'], { stdio: 'ignore', windowsHide: true })
        killer.once('error', resolveStop)
        killer.once('close', resolveStop)
      })
    } else {
      child.kill('SIGTERM')
    }
  }
  console.log('\nSOSNET detenido. Si MySQL está activo, puedes detenerlo con: npm run db:stop (sus datos se conservan).')
}

process.on('SIGINT', () => void stop())
process.on('SIGTERM', () => void stop())

function watch(child, name) {
  child.once('error', error => {
    console.error(`[${name}] ${error.message}`)
    void stop(1)
  })
  child.once('close', code => {
    if (!stopping) {
      console.error(`[${name}] El servicio terminó (${code}).`)
      void stop(code || 1)
    }
  })
}

async function backendAvailable(attempts = 1) {
  for (let attempt = 0; attempt < attempts && !stopping; attempt++) {
    try {
      const response = await fetch('http://127.0.0.1:5000/api/health', { signal: AbortSignal.timeout(1000) })
      if (response.ok) return true
    } catch { /* El backend todavía está iniciando. */ }
    if (attempt < attempts - 1) await delay(1000)
  }
  return false
}

async function waitForBackend() {
  if (await backendAvailable(60)) return
  if (!stopping) throw new Error('El backend no respondió en http://localhost:5000/api/health dentro del tiempo esperado.')
}

function checkPort(port) {
  return new Promise((resolvePort, reject) => {
    const server = createServer()
    server.once('error', () => reject(new Error(`El puerto ${port} no está disponible. Detén el servidor que lo ocupa antes de iniciar SOSNET.`)))
    server.listen(port, '127.0.0.1', () => server.close(resolvePort))
  })
}

try {
  await checkPort(1010)

  console.log('[SOSNET] Comprobando Docker. Docker Desktop debe estar iniciado.')
  await run('docker', ['info', '--format', '{{.ServerVersion}}'])
  if (!stopping) {
    console.log('[SOSNET] Iniciando MySQL y esperando su healthcheck…')
    try {
      await run('docker', ['compose', 'up', '-d', '--wait', '--wait-timeout', '600', 'mysql'])
    } catch (error) {
      if (!stopping) {
        console.error('[SOSNET] MySQL no quedó listo. Últimos logs del contenedor:')
        await run('docker', ['compose', 'logs', '--tail', '60', 'mysql']).catch(() => {})
      }
      throw error
    }
  }
  const dockerBackend = await backendContainerRunning()
  if (!stopping) await prepareDependencies(!dockerBackend)
  if (!stopping && !dockerBackend) {
    await checkPort(5000)
    console.log('[SOSNET] Iniciando Flask local…')
    // Sin reloader: evita duplicar el lector serial y permite detener todo desde esta terminal.
    watch(launch(python, ['-m', 'flask', '--app', 'run.py', 'run', '--debug', '--no-reload', '--host', '127.0.0.1', '--port', '5000'], resolve(root, 'backend')), 'Flask')
  } else if (!stopping) {
    console.log('[SOSNET] Backend Docker en ejecución; se reutiliza en http://localhost:5000.')
    if (!(await backendAvailable(3))) {
      console.log('[SOSNET] El backend Docker no responde; reiniciándolo…')
      await run('docker', ['compose', 'restart', 'backend'])
    }
  }
  if (!stopping) await waitForBackend()
  if (!stopping) {
    console.log('[SOSNET] API lista: http://localhost:5000/api/health')
    console.log('[SOSNET] Frontend: http://localhost:1010 · Ctrl+C para detener los servidores.')
    watch(launch(process.execPath, [resolve(root, 'frontend/node_modules/vite/bin/vite.js'), '--host', '127.0.0.1', '--port', '1010', '--strictPort'], resolve(root, 'frontend')), 'Vite')
  }
} catch (error) {
  if (!stopping) {
    console.error(`[SOSNET] ${error.message}`)
    await stop(1)
  }
}
