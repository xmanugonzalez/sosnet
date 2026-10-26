import { randomBytes } from 'node:crypto'
import { copyFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const insecureSecrets = new Set([
  '',
  'dev-only-secret',
  'cambiar-en-produccion',
  'dev-only-jwt-secret-change-me-1234567890',
])

function envValue(source, key) {
  const matches = [...source.matchAll(new RegExp(`^(?:export[ \\t]+)?${key}[ \\t]*=(.*)$`, 'gm'))]
  const raw = matches.at(-1)?.[1].trim() ?? ''
  if (raw.startsWith('"') || raw.startsWith("'")) {
    const end = raw.lastIndexOf(raw[0])
    return end > 0 ? raw.slice(1, end) : raw
  }
  return raw.replace(/\s+#.*$/, '').trim()
}

function setEnvValue(source, key, value) {
  const newline = source.includes('\r\n') ? '\r\n' : '\n'
  const lines = source.split(/\r?\n/)
  const assignment = new RegExp(`^(?:export[ \\t]+)?${key}[ \\t]*=`)
  let found = false
  const updated = lines.map(line => {
    if (!assignment.test(line)) return line
    found = true
    return `${key}=${value}`
  })
  if (!found) {
    if (updated.at(-1) === '') updated.pop()
    updated.push(`${key}=${value}`, '')
  }
  return updated.join(newline)
}

export function repairDevSecrets(source, generate = () => randomBytes(48).toString('hex')) {
  let content = source
  let secret = envValue(source, 'SECRET_KEY')
  const jwt = envValue(source, 'JWT_SECRET_KEY')
  if (insecureSecrets.has(secret)) {
    secret = generate()
    content = setEnvValue(content, 'SECRET_KEY', secret)
  }
  if (insecureSecrets.has(jwt) || jwt === secret) {
    let jwtSecret = generate()
    while (jwtSecret === secret) jwtSecret = generate()
    content = setEnvValue(content, 'JWT_SECRET_KEY', jwtSecret)
  }
  return { content, changed: content !== source }
}

export function prepareDevEnv(root, log = console.log) {
  const repaired = []
  for (const directory of ['', 'backend', 'frontend']) {
    const label = directory ? `${directory}/.env` : '.env'
    const target = resolve(root, label)
    if (!existsSync(target)) {
      copyFileSync(resolve(root, directory, '.env.example'), target)
      log(`[SOSNET] Creado ${label} desde el ejemplo.`)
    }
    if (directory === 'frontend') continue
    const { content, changed } = repairDevSecrets(readFileSync(target, 'utf8'))
    if (changed) {
      writeFileSync(target, content, { mode: 0o600 })
      repaired.push(label)
      log(`[SOSNET] Claves locales de seguridad configuradas en ${label}.`)
    }
  }
  return repaired
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  prepareDevEnv(resolve(dirname(fileURLToPath(import.meta.url)), '..'))
}
