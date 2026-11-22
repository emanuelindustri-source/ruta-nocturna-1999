param(
    [ValidateSet('windows', 'android', 'all')]
    [string]$Target = 'all',
    [ValidateSet('debug', 'release')]
    [string]$Configuration = 'debug',
    [switch]$SkipImport
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$console = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $console)) {
    throw 'No se encontro Godot 4.7.2 en C:\Dev\Godot.'
}

$logDir = Join-Path $root 'build\logs\export'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMddTHHmmssZ'
$logPath = Join-Path $logDir ("export-{0}-{1}.log" -f $Target, $Configuration)

function Invoke-GodotExport {
    param([string]$Preset, [string]$Output)

    $absolute = Join-Path $root $Output
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $absolute) | Out-Null
    $flag = if ($Configuration -eq 'release') { '--export-release' } else { '--export-debug' }
    Write-Host "--- Exportando preset '$Preset' ($Configuration) ---"
    $raw = & $console --headless --path $root $flag $Preset $Output 2>&1
    $code = $LASTEXITCODE
    $raw | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $logPath -Append | Write-Host
    if ($code -ne 0) {
        throw "Godot devolvio exit $code al exportar '$Preset'."
    }
    if (-not (Test-Path -LiteralPath $absolute)) {
        throw "El export de '$Preset' no genero $absolute."
    }
    $item = Get-Item -LiteralPath $absolute
    if ($item.Length -lt 1MB) {
        throw "El artefacto de '$Preset' es sospechosamente pequeno ($($item.Length) bytes)."
    }
    $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
    Write-Host ("[OK] {0}: {1:N0} bytes, SHA-256 {2}" -f $Output, $item.Length, $hash)
    return [pscustomobject]@{
        preset = $Preset
        path = $Output
        bytes = $item.Length
        sha256 = $hash
        configuration = $Configuration
        exported_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
}

Push-Location $root
try {
    $ErrorActionPreference = 'Continue'
    if (-not $SkipImport) {
        Write-Host '--- Importacion headless previa al export ---'
        $importOutput = & $console --headless --path $root --editor --quit 2>&1
        $importCode = $LASTEXITCODE
        $importOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $logPath -Append | Write-Host
        if ($importCode -ne 0) {
            throw "La importacion de Godot fallo con exit $importCode."
        }
    }

    $results = @()
    if ($Target -in @('windows', 'all')) {
        $results += Invoke-GodotExport -Preset 'Windows Desktop' -Output 'build/exports/windows/RutaNocturna1999.exe'
    }
    if ($Target -in @('android', 'all')) {
        $results += Invoke-GodotExport -Preset 'Android' -Output 'build/exports/android/RutaNocturna1999.apk'
    }

    $manifestPath = Join-Path $logDir 'latest.json'
    $payload = [pscustomobject]@{
        generated_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        version = (Get-Content -Raw (Join-Path $root 'VERSION')).Trim()
        artifacts = $results
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "Manifiesto de export: $manifestPath"
    Write-Host 'Export OK.'
    exit 0
} catch {
    Write-Host "Export FALLO: $($_.Exception.Message)"
    Write-Host "Log: $logPath"
    exit 1
} finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
}
