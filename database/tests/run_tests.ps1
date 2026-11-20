param(
    [int]$Port = 55432,
    [string]$Container = "sosnet-pg-test",
    [switch]$SkipBackend,
    [switch]$Keep
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$database = Join-Path $root "database"
$backend = Join-Path $root "backend"
$python = Join-Path $backend ".venv\Scripts\python.exe"

$sqlTests = @(
    "01_objects.sql",
    "02_constraints.sql",
    "03_procedures_triggers.sql",
    "04_views_functions.sql",
    "05_rls.sql",
    "06_transactions.sql"
)

function Wait-Postgres {
    param([string]$Name)
    for ($i = 0; $i -lt 120; $i++) {
        $output = (docker exec $Name psql -U sosnet_admin -d sosnet_test -tAc `
            "SELECT (SELECT count(*) FROM public.usuarios) || ':' || (SELECT count(*) FROM public.tipos_emergencia)" 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $output -match '^3:5') {
            return
        }
        Start-Sleep -Seconds 2
    }
    throw "PostgreSQL no terminó la inicialización en el contenedor $Name."
}

$created = $false
try {
    docker rm -fv $Container 2>$null | Out-Null
    Write-Host "[SOSNET] Iniciando $Container en el puerto $Port..." -ForegroundColor Cyan
    docker run -d --name $Container `
        -e POSTGRES_DB=sosnet_test `
        -e POSTGRES_USER=sosnet_admin `
        -e POSTGRES_PASSWORD=sosnet_admin_dev `
        -e SOSNET_API_PASSWORD=sosnet_api_dev `
        -e SOSNET_REPORT_PASSWORD=sosnet_reporte_dev `
        -p "${Port}:5432" `
        -v "${database}:/docker-entrypoint-initdb.d:ro" `
        postgres:17-alpine | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No se pudo iniciar el contenedor PostgreSQL." }
    $created = $true

    Wait-Postgres -Name $Container

    Write-Host "[SOSNET] Ejecutando pruebas SQL..." -ForegroundColor Cyan
    foreach ($test in $sqlTests) {
        Write-Host "  - $test"
        docker exec -i $Container psql -U sosnet_admin -d sosnet_test `
            -v ON_ERROR_STOP=1 -f "/docker-entrypoint-initdb.d/tests/$test"
        if ($LASTEXITCODE -ne 0) {
            throw "Falló la prueba SQL $test."
        }
    }

    if (-not $SkipBackend) {
        if (-not (Test-Path -LiteralPath $python)) {
            throw "No existe backend/.venv. Ejecuta npm run dev una vez o crea el entorno virtual."
        }

        Write-Host "[SOSNET] Ejecutando pruebas de integración Flask + PostgreSQL..." -ForegroundColor Cyan
        $env:TEST_DATABASE_URL = "postgresql+psycopg://sosnet_api:sosnet_api_dev@127.0.0.1:$Port/sosnet_test"
        $env:TEST_ADMIN_DATABASE_URL = "postgresql+psycopg://sosnet_admin:sosnet_admin_dev@127.0.0.1:$Port/sosnet_test"
        Push-Location $backend
        try {
            & $python -m pytest -q
            if ($LASTEXITCODE -ne 0) { throw "Fallaron las pruebas del backend." }
        }
        finally {
            Pop-Location
        }
    }

    Write-Host "[SOSNET] Todas las pruebas terminaron correctamente." -ForegroundColor Green
}
finally {
    if ($created -and -not $Keep) {
        docker rm -fv $Container 2>$null | Out-Null
    }
    elseif ($Keep) {
        Write-Host "[SOSNET] Contenedor conservado: $Container (puerto $Port)." -ForegroundColor Yellow
    }
}
