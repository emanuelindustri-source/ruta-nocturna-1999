param(
    [switch]$SkipGodot
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$py = Join-Path $root '.venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $py)) {
    throw 'No existe .venv. Ejecutar bootstrap y crear el entorno Python.'
}

Push-Location $root
try {
    Write-Host '--- Contratos ---'
    & $py 'tools\validate_schemas.py'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '--- Localización ---'
    & $py 'tools\validate_localization.py'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '--- Roadmap ---'
    & $py 'tools\release\sync_roadmap.py' --check
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '--- Salud ---'
    $healthArgs = @('tools\health_check.py', '--end')
    if ($SkipGodot) { $healthArgs += '--skip-godot' }
    & $py @healthArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
