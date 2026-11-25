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

$logDir = Join-Path $root 'build\logs\world'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir 'biomes_latest.log'

Push-Location $root
try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    $rawImport = & $console --headless --path $root --editor --quit 2>&1
    $importCode = $LASTEXITCODE
    $importOutput = @($rawImport | ForEach-Object { $_.ToString() })

    $rawOutput = & $console --headless --path $root 'res://tests/world/WorldBiomesTest.tscn' 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $output = @($rawOutput | ForEach-Object { $_.ToString() })
    $combined = @('[BIOMES] Paso de importacion de Godot (headless)') + $importOutput + @('[BIOMES] Escena WorldBiomesTest.tscn') + $output
    $combined | Tee-Object -FilePath $logPath | Write-Host
} finally {
    Pop-Location
}

if ($importCode -ne 0) {
    Write-Host "La importacion de Godot fallo (exit $importCode). Log: $logPath"
    exit 1
}

$successMarker = ($output | Select-String -SimpleMatch '[BIOMES] SUPERADO' -Quiet)
if ($exitCode -ne 0 -or -not $successMarker) {
    Write-Host "Prueba de kits de biomas y POIs FALLO. Log: $logPath"
    exit 1
}
Write-Host "Prueba de kits de biomas y POIs OK. Log: $logPath"
exit 0
