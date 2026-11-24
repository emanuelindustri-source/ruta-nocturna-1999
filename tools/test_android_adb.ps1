param(
    [string]$ApkPath = 'build/exports/android/RutaNocturna1999.apk',
    [string]$Serial = '',
    [switch]$SkipBuild,
    [int]$BootTimeoutSeconds = 90,
    [int]$MonitorSeconds = 15
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent $PSScriptRoot
$adb = 'C:\Android\platform-tools\adb.exe'
$package = 'com.emanuelindustri.rutanoucturna1999'
$logDir = Join-Path $root 'build\logs\android-smoke'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMddTHHmmssZ'

function Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message"
    exit 1
}

if (-not (Test-Path -LiteralPath $adb)) {
    Fail "No existe ADB en $adb."
}

Write-Host '--- Dispositivos ADB ---'
$devicesRaw = & $adb devices -l 2>&1
$devicesRaw | Write-Host
$deviceLines = @($devicesRaw | Where-Object { $_ -match '^\S+\s+device(\s|$)' })
if ($deviceLines.Count -eq 0) {
    Fail 'No hay dispositivo ADB autorizado. Conecta el Redmi y acepta la depuracion USB.'
}
if ([string]::IsNullOrWhiteSpace($Serial)) {
    $Serial = ($deviceLines[0] -split '\s+')[0]
}
$authorized = @($devicesRaw | Where-Object { $_ -match ("^" + [regex]::Escape($Serial) + "\s+device(\s|$)") }).Count -gt 0
if (-not $authorized) {
    Fail "El dispositivo '$Serial' no esta autorizado."
}
Write-Host "[OK] Dispositivo autorizado: $Serial"

if (-not $SkipBuild) {
    Write-Host '--- Compilando APK debug ---'
    $exportScript = Join-Path $root 'tools\dev\export.ps1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $exportScript -Target android -Configuration debug
    if ($LASTEXITCODE -ne 0) {
        Fail "El export Android fallo (exit $LASTEXITCODE)."
    }
}

$apk = Join-Path $root $ApkPath
if (-not (Test-Path -LiteralPath $apk)) {
    Fail "No existe la APK $apk. Ejecuta tools\dev\export.ps1 -Target android."
}
$apkHash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
Write-Host ("[OK] APK {0} ({1:N0} bytes) SHA-256 {2}" -f $ApkPath, (Get-Item $apk).Length, $apkHash)

Write-Host '--- Instalando APK (-r) ---'
$install = & $adb -s $Serial install -r $apk 2>&1
$install | Write-Host
if ($LASTEXITCODE -ne 0 -or ($install -join ' ') -notmatch 'Success') {
    Fail "adb install fallo."
}

& $adb -s $Serial shell am force-stop $package 2>&1 | Out-Null
$clear = & $adb -s $Serial shell pm clear $package 2>&1
$clear | Write-Host
& $adb -s $Serial logcat -c 2>&1 | Out-Null

Write-Host '--- Abriendo la aplicacion ---'
$launch = & $adb -s $Serial shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1
$launch | Write-Host
if ($LASTEXITCODE -ne 0) {
    Fail 'monkey no pudo abrir la aplicacion.'
}

$started = Get-Date
$booted = $false
$bootLog = ''
$sessionFound = $false
$appPid = ''
$bootSeconds = $null
while (((Get-Date) - $started).TotalSeconds -lt $BootTimeoutSeconds) {
    Start-Sleep -Milliseconds 500
    $bootLog = (& $adb -s $Serial logcat -d -s godot:V 2>&1) -join "`n"
    $appPid = ((& $adb -s $Serial shell pidof $package 2>&1) -join '').Trim()
    $session = (& $adb -s $Serial shell run-as $package ls files/sesion_activa.json 2>&1) -join "`n"
    if ($session -match 'sesion_activa.json') {
        $sessionFound = $true
        $sessionText = (& $adb -s $Serial shell run-as $package cat files/sesion_activa.json 2>&1) -join "`n"
        $bootLog = $bootLog + "`n[SESSION] " + $sessionText
    }
    if ($sessionFound -or $bootLog -match 'BOOT_READY' -or $bootLog -match 'VERTICAL_SLICE_READY') {
        $booted = $true
        $bootSeconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
        break
    }
    if ($bootLog -match 'FATAL EXCEPTION|E/AndroidRuntime') {
        break
    }
}

$remaining = $MonitorSeconds - [int]((Get-Date) - $started).TotalSeconds
if ($remaining -gt 0) {
    Write-Host "--- Monitorizando logcat $MonitorSeconds s ---"
    Start-Sleep -Seconds $remaining
}

$fullLog = (& $adb -s $Serial logcat -d 2>&1) -join "`n"
$godotLog = (& $adb -s $Serial logcat -d -s godot:V 2>&1) -join "`n"
Set-Content -LiteralPath (Join-Path $logDir 'logcat.txt') -Value $fullLog -Encoding utf8
Set-Content -LiteralPath (Join-Path $logDir 'logcat-godot.txt') -Value $godotLog -Encoding utf8
Set-Content -LiteralPath (Join-Path $logDir 'boot.log') -Value $bootLog -Encoding utf8

Write-Host '--- Captura de pantalla ---'
& $adb -s $Serial shell screencap -p /sdcard/rn1999-smoke.png 2>&1 | Out-Null
& $adb -s $Serial pull /sdcard/rn1999-smoke.png (Join-Path $logDir 'screenshot.png') 2>&1 | Write-Host
& $adb -s $Serial shell rm /sdcard/rn1999-smoke.png 2>&1 | Out-Null
$screenshotOk = Test-Path -LiteralPath (Join-Path $logDir 'screenshot.png')

Write-Host '--- Memoria PSS ---'
$meminfo = (& $adb -s $Serial shell dumpsys meminfo $package 2>&1) -join "`n"
Set-Content -LiteralPath (Join-Path $logDir 'meminfo.txt') -Value $meminfo -Encoding utf8
$pssMb = $null
$totalLine = ($meminfo -split "`n" | Where-Object { $_ -match 'TOTAL PSS|TOTAL:' } | Select-Object -First 1)
if ($totalLine -match '(\d[\d,\.]*)') {
    $rawPss = [double](($matches[1]) -replace ',', '')
    if ($rawPss -gt 100000) { $rawPss = $rawPss / 1024.0 }
    $pssMb = [math]::Round($rawPss, 1)
}
$pssBudgetMb = 1228.8

$fatalPatterns = @('FATAL EXCEPTION', 'E/AndroidRuntime')
$warningPatterns = @('ERROR: Condition', 'Vulkan.*[Ee]rror', 'Godot Engine.*ERROR')
$fatal = @()
$warnings = @()
foreach ($pattern in $fatalPatterns) {
    if ($fullLog -match $pattern) { $fatal += $pattern }
}
foreach ($pattern in $warningPatterns) {
    if ($fullLog -match $pattern) { $warnings += $pattern }
}

$summary = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    device = $Serial
    package = $package
    apk = $ApkPath
    apk_sha256 = $apkHash
    booted = $booted
    boot_seconds = $bootSeconds
    boot_marker = ($sessionFound -or $bootLog -match 'BOOT_READY' -or $bootLog -match 'VERTICAL_SLICE_READY')
    session_marker = $sessionFound
    app_pid = $appPid
    fatal_patterns = $fatal
    warning_patterns = $warnings
    pss_mb = $pssMb
    pss_budget_mb = $pssBudgetMb
    screenshot = $screenshotOk
    log_dir = $logDir
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logDir 'latest.json') -Encoding utf8

Write-Host ("[INFO] PSS: {0} MB (presupuesto movil {1} MB)" -f $pssMb, $pssBudgetMb)
if (-not $booted) { Fail "La aplicacion no alcanzo el primer frame en $BootTimeoutSeconds s." }
if ($fatal.Count -gt 0) { Fail ("Errores fatales en logcat: " + ($fatal -join ', ')) }
if ($warnings.Count -gt 0) { Write-Host ("[WARN] Patrones de error no fatal: " + ($warnings -join ', ')) }
if (-not $screenshotOk) { Fail 'No se pudo capturar la pantalla.' }
if ($null -eq $pssMb) { Fail 'No se pudo leer el PSS con dumpsys meminfo.' }
if ($pssMb -gt $pssBudgetMb) { Fail "PSS $pssMb MB supera el presupuesto de $pssBudgetMb MB." }

# --- Ruta de rendimiento en dispositivo (F3.5) -------------------------------
# El marcador hace que DevicePerfProbe (servicio de escena) navegue a la
# rebanada y a la cabina, mida frame pacing, triangulos, carga y warm-up, y
# escriba files/perf_report.json. Sin marcador la app no cambia de comportamiento.
Write-Host '--- Ruta de rendimiento en dispositivo (F3.5) ---'
& $adb -s $Serial shell am force-stop $package 2>&1 | Out-Null
$markerPush = & $adb -s $Serial shell "run-as $package sh -c 'echo slice,cabin > files/perf_route.marker'" 2>&1
$markerPush | Write-Host
$markerCheck = (& $adb -s $Serial shell "run-as $package ls files/perf_route.marker" 2>&1) -join ' '
if ($markerCheck -notmatch 'perf_route.marker') {
    Fail "No se pudo escribir files/perf_route.marker con run-as: $markerCheck"
}
& $adb -s $Serial logcat -c 2>&1 | Out-Null
$relaunch = & $adb -s $Serial shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1
$relaunch | Write-Host
if ($LASTEXITCODE -ne 0) { Fail 'monkey no pudo reabrir la aplicacion para la ruta de rendimiento.' }

$perfStarted = Get-Date
$perfTimeoutSeconds = 240
$sliceCaptured = $false
$perfJson = ''
$perfReport = $null
$perfDone = $false
while (((Get-Date) - $perfStarted).TotalSeconds -lt $perfTimeoutSeconds) {
    Start-Sleep -Milliseconds 1000
    $rawReport = (& $adb -s $Serial shell "run-as $package cat files/perf_report.json" 2>&1) -join "`n"
    if ($rawReport -notmatch 'sections') { continue }
    $parsedReport = $null
    try { $parsedReport = $rawReport | ConvertFrom-Json } catch { $parsedReport = $null }
    if ($null -eq $parsedReport) { continue }
    $perfJson = $rawReport
    $perfReport = $parsedReport
    $sliceSection = @($parsedReport.sections | Where-Object { $_.scene -eq 'slice' })
    if (-not $sliceCaptured -and $sliceSection.Count -gt 0) {
        # La sonda esta midiendo la rebanada: captura y PSS representativos.
        & $adb -s $Serial shell screencap -p /sdcard/rn1999-slice.png 2>&1 | Out-Null
        & $adb -s $Serial pull /sdcard/rn1999-slice.png (Join-Path $logDir 'screenshot_slice.png') 2>&1 | Out-Null
        & $adb -s $Serial shell rm /sdcard/rn1999-slice.png 2>&1 | Out-Null
        $sliceMeminfo = (& $adb -s $Serial shell dumpsys meminfo $package 2>&1) -join "`n"
        Set-Content -LiteralPath (Join-Path $logDir 'meminfo_slice.txt') -Value $sliceMeminfo -Encoding utf8
        $sliceCaptured = $true
        Write-Host '[OK] Captura y PSS de la rebanada registrados.'
    }
    if ($parsedReport.done -eq $true) { $perfDone = $true; break }
}
if (-not $perfDone -or $null -eq $perfReport) {
    Fail "La ruta de rendimiento no termino en $perfTimeoutSeconds s. Reporte parcial: $($perfJson.Substring(0, [math]::Min(400, $perfJson.Length)))"
}

# Captura y PSS en la ultima escena (cabina) con la app ya en reposo de medida.
& $adb -s $Serial shell screencap -p /sdcard/rn1999-cabin.png 2>&1 | Out-Null
& $adb -s $Serial pull /sdcard/rn1999-cabin.png (Join-Path $logDir 'screenshot_cabin.png') 2>&1 | Out-Null
& $adb -s $Serial shell rm /sdcard/rn1999-cabin.png 2>&1 | Out-Null
$cabinScreenshotOk = Test-Path -LiteralPath (Join-Path $logDir 'screenshot_cabin.png')
$cabinMeminfo = (& $adb -s $Serial shell dumpsys meminfo $package 2>&1) -join "`n"
Set-Content -LiteralPath (Join-Path $logDir 'meminfo_cabin.txt') -Value $cabinMeminfo -Encoding utf8
$pssCabinMb = $null
$cabinTotalLine = ($cabinMeminfo -split "`n" | Where-Object { $_ -match 'TOTAL PSS|TOTAL:' } | Select-Object -First 1)
if ($cabinTotalLine -match '(\d[\d,\.]*)') {
    $rawPssCabin = [double](($matches[1]) -replace ',', '')
    if ($rawPssCabin -gt 100000) { $rawPssCabin = $rawPssCabin / 1024.0 }
    $pssCabinMb = [math]::Round($rawPssCabin, 1)
}
$pssSliceMb = $null
if (Test-Path -LiteralPath (Join-Path $logDir 'meminfo_slice.txt')) {
    $sliceMeminfoText = Get-Content -LiteralPath (Join-Path $logDir 'meminfo_slice.txt') -Raw
    $sliceTotalLine = ($sliceMeminfoText -split "`n" | Where-Object { $_ -match 'TOTAL PSS|TOTAL:' } | Select-Object -First 1)
    if ($sliceTotalLine -match '(\d[\d,\.]*)') {
        $rawPssSlice = [double](($matches[1]) -replace ',', '')
        if ($rawPssSlice -gt 100000) { $rawPssSlice = $rawPssSlice / 1024.0 }
        $pssSliceMb = [math]::Round($rawPssSlice, 1)
    }
}
Set-Content -LiteralPath (Join-Path $logDir 'perf_report.json') -Value $perfJson -Encoding utf8
# Limpieza defensiva del marcador (la app ya lo borra al terminar la ruta).
& $adb -s $Serial shell "run-as $package sh -c 'rm -f files/perf_route.marker files/perf_state.json'" 2>&1 | Out-Null

$perfBudgets = $perfReport.budgets
$perfErrors = @()
$perfSections = @()
foreach ($section in @($perfReport.sections)) {
    $perfSections += [pscustomobject]@{
        scene = $section.scene
        load_ms = $section.load_ms
        warmup_done = $section.warmup_done
        warmup_ms = $section.warmup_ms
        frame_ms_avg = $section.frame_ms_avg
        frame_ms_p95 = $section.frame_ms_p95
        frame_ms_max = $section.frame_ms_max
        fps_avg = $section.fps_avg
        jank_gt_frame_budget = $section.jank_gt_frame_budget
        jank_gt_100ms = $section.jank_gt_100ms
        primitives_avg = $section.primitives_avg
        draw_calls_avg = $section.draw_calls_avg
    }
    if ($section.warmup_done -ne $true) { $perfErrors += "warmup:$($section.scene)" }
    if ([double]$section.frame_ms_avg -gt [double]$perfBudgets.frame_budget_ms) {
        $perfErrors += "frame_ms_avg:$($section.scene)=$($section.frame_ms_avg)"
    }
    if ([double]$section.primitives_avg -gt [double]$perfBudgets.max_triangles) {
        $perfErrors += "triangulos:$($section.scene)=$($section.primitives_avg)"
    }
    if ([double]$section.load_ms -gt [double]$perfBudgets.max_load_ms) {
        $perfErrors += "carga:$($section.scene)=$($section.load_ms)"
    }
}
if ($null -eq $pssSliceMb) { $perfErrors += 'pss_slice:no_readable' }
elseif ($pssSliceMb -gt $pssBudgetMb) { $perfErrors += "pss_slice=$pssSliceMb" }
if ($null -eq $pssCabinMb) { $perfErrors += 'pss_cabin:no_readable' }
elseif ($pssCabinMb -gt $pssBudgetMb) { $perfErrors += "pss_cabin=$pssCabinMb" }
if (-not $cabinScreenshotOk) { $perfErrors += 'captura_cabin' }
if (-not $sliceCaptured) { $perfErrors += 'captura_slice' }

$summary | Add-Member -NotePropertyName perf -NotePropertyValue ([pscustomobject]@{
    done = $perfDone
    budgets = $perfBudgets
    sections = $perfSections
    pss_slice_mb = $pssSliceMb
    pss_cabin_mb = $pssCabinMb
    screenshot_slice = $sliceCaptured
    screenshot_cabin = $cabinScreenshotOk
    errors = $perfErrors
}) -Force
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logDir 'latest.json') -Encoding utf8

foreach ($section in $perfSections) {
    Write-Host ("[INFO] {0}: carga {1} ms, warm-up {2} ms, frame {3} ms (p95 {4}), {5} triangulos, {6} draw calls" -f `
        $section.scene, [math]::Round($section.load_ms, 1), [math]::Round($section.warmup_ms, 1), `
        [math]::Round($section.frame_ms_avg, 2), [math]::Round($section.frame_ms_p95, 2), `
        [math]::Round($section.primitives_avg, 0), [math]::Round($section.draw_calls_avg, 1))
}
Write-Host ("[INFO] PSS rebanada: {0} MB; PSS cabina: {1} MB (presupuesto {2} MB)" -f $pssSliceMb, $pssCabinMb, $pssBudgetMb)
if ($perfErrors.Count -gt 0) {
    Fail ("Ruta de rendimiento con errores: " + ($perfErrors -join ', '))
}

Write-Host ("[OK] Smoke Android superado. Logs en {0}" -f $logDir)
exit 0
