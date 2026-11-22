param()

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$console = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $console)) {
    $console = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64.exe'
}
if (-not (Test-Path -LiteralPath $console)) {
    throw 'No se encontro Godot 4.7.2 en C:\Dev\Godot.'
}

$logDir = Join-Path $root 'build\logs\smoke'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir 'latest.log'

Push-Location $root
try {
    # Godot escribe warnings y errores por stderr. No convertir stderr en una
    # excepción de PowerShell: el smoke test decide con su código de salida.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $rawOutput = & $console --headless --path $root 'res://tests/smoke/SmokeTest.tscn' 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $output = @($rawOutput | ForEach-Object { $_.ToString() })
    $output | Tee-Object -FilePath $logPath | Write-Host
} finally {
    Pop-Location
}

$successMarker = ($output | Select-String -SimpleMatch '[SMOKE] OK' -Quiet)
if ($exitCode -ne 0 -or -not $successMarker) {
    Write-Host "Smoke test FALLO. Log: $logPath"
    exit 1
}
Write-Host "Smoke test OK. Log: $logPath"
exit 0
