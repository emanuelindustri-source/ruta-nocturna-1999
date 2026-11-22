param(
    [switch]$Apply,
    [int]$KeepBuilds = 2,
    [switch]$IncludeGlobalCaches
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent $PSScriptRoot
$referenceRoot = 'C:\Dev\fotos de ejemplo'
$candidates = New-Object System.Collections.Generic.List[object]
$freeBefore = (Get-PSDrive C).Free

function Add-Candidate {
    param([string]$Path, [string]$Reason)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path
        $size = if ($item.PSIsContainer) {
            (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        } else { $item.Length }
        $candidates.Add([pscustomobject]@{ Path = $Path; Reason = $Reason; Bytes = [int64]($size) })
    }
}

Write-Host '=== Limpieza segura de Ruta Nocturna 1999 ===' -ForegroundColor Yellow
Write-Host "Proyecto: $root"
Write-Host "Modo: $(if ($Apply) { 'APLICAR' } else { 'DRY RUN (sin borrar)' })"
Write-Host "Espacio libre antes: $([math]::Round($freeBefore / 1GB, 2)) GB`n"

Add-Candidate (Join-Path $root 'build\temp') 'Temporales de builds y renders'
Add-Candidate (Join-Path $root 'build\reference') 'Hojas de contacto y texto extraído de referencias'
Add-Candidate (Join-Path $root 'build\logs\android-smoke') 'Logs ADB antiguos'

foreach ($ext in @('*.apk', '*.aab')) {
    $files = Get-ChildItem -LiteralPath (Join-Path $root 'build') -Filter $ext -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepBuilds
    foreach ($file in $files) { $candidates.Add([pscustomobject]@{ Path = $file.FullName; Reason = 'Build intermedia antigua'; Bytes = $file.Length }) }
}

$blend1 = Get-ChildItem -LiteralPath $root -Filter '*.blend1' -File -Recurse -ErrorAction SilentlyContinue
foreach ($file in $blend1) { $candidates.Add([pscustomobject]@{ Path = $file.FullName; Reason = 'Respaldo temporal de Blender'; Bytes = $file.Length }) }

$logCutoff = (Get-Date).AddDays(-30)
$oldLogs = Get-ChildItem -LiteralPath (Join-Path $root 'build\logs') -Filter '*.log' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $logCutoff }
foreach ($file in $oldLogs) { $candidates.Add([pscustomobject]@{ Path = $file.FullName; Reason = 'Log con más de 30 días'; Bytes = $file.Length }) }

if ($candidates.Count -eq 0) {
    Write-Host 'No hay candidatos para limpiar.'
} else {
    $grouped = $candidates | Group-Object Path | ForEach-Object { $_.Group | Select-Object -First 1 }
    $total = ($grouped | Measure-Object Bytes -Sum).Sum
    $grouped | Sort-Object Bytes -Descending | Format-Table @{N='MB';E={[math]::Round($_.Bytes/1MB,2)}}, Reason, Path -AutoSize | Out-Host
    Write-Host "Total recuperable: $([math]::Round($total/1MB,2)) MB"
}

if ($IncludeGlobalCaches) {
    Write-Host "`n[WARN] Se solicitó incluir caché global de Gradle." -ForegroundColor Yellow
    Write-Host 'La caché global acelera builds futuras. Solo se borrará con confirmación interactiva.'
    if ($Apply) {
        $answer = Read-Host 'Escribe BORRAR para eliminar la caché global de Gradle'
        if ($answer -eq 'BORRAR') {
            $gradleCache = Join-Path $env:USERPROFILE '.gradle\caches'
            if (Test-Path -LiteralPath $gradleCache) { Add-Candidate $gradleCache 'Caché global de Gradle (petición explícita)' }
        } else {
            Write-Host 'Caché global conservada.'
        }
    }
}

if ($referenceRoot -and (Test-Path -LiteralPath $referenceRoot) -and ($candidates.Path -contains $referenceRoot)) {
    throw 'Protección activada: la biblioteca de referencias no se debe borrar.'
}

if (-not $Apply) {
    Write-Host "`nDry run completado. Repetir con -Apply para eliminar los candidatos seguros." -ForegroundColor Cyan
    exit 0
}

$grouped = $candidates | Group-Object Path | ForEach-Object { $_.Group | Select-Object -First 1 }
foreach ($candidate in $grouped) {
    if ($candidate.Path -like "$referenceRoot*") { continue }
    try {
        Remove-Item -LiteralPath $candidate.Path -Recurse -Force -ErrorAction Stop
        Write-Host "[OK] Eliminado: $($candidate.Path)"
    } catch {
        Write-Host "[WARN] No se pudo eliminar $($candidate.Path): $($_.Exception.Message)"
    }
}

$freeAfter = (Get-PSDrive C).Free
Write-Host "`nEspacio libre después: $([math]::Round($freeAfter / 1GB, 2)) GB"
Write-Host "Recuperado: $([math]::Round(($freeAfter - $freeBefore) / 1MB, 2)) MB"
Write-Host 'Nunca se tocaron assets, datos, docs, .git ni la biblioteca externa.' -ForegroundColor Green
