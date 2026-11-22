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
while (((Get-Date) - $started).TotalSeconds -lt $BootTimeoutSeconds) {
    Start-Sleep -Seconds 2
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

Write-Host ("[OK] Smoke Android superado. Logs en {0}" -f $logDir)
exit 0
