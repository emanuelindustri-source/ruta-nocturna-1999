param(
    [switch]$VerboseTools
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Report-Item {
    param([string]$Name, [bool]$Ok, [string]$Value, [bool]$WarningOnly = $false)
    $prefix = if ($Ok) { '[OK]' } elseif ($WarningOnly) { '[WARN]' } else { '[FAIL]' }
    Write-Host "$prefix $Name :: $Value"
    if (-not $Ok) {
        if ($WarningOnly) { $warnings.Add($Name) } else { $failures.Add($Name) }
    }
}

$toolPaths = @{
    'Godot console' = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe'
    'Godot GUI' = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64.exe'
    'Godot wrapper' = (Join-Path $root 'tools\dev\godot.ps1')
    'Blender' = 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe'
    'ADB' = 'C:\Android\platform-tools\adb.exe'
    'Android SDK' = 'C:\Android'
    'Java 17' = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.21.10002-hotspot'
    'debug keystore' = 'C:\Android\debug.keystore'
    'Python 3.14' = 'C:\Users\Sr_Hidalgo\AppData\Local\Programs\Python\Python314\python.exe'
    'Project venv' = (Join-Path $root '.venv\Scripts\python.exe')
    'GitHub CLI' = 'C:\Program Files\GitHub CLI\gh.exe'
}

Write-Host "`n=== Ruta Nocturna: 1999 · bootstrap ===" -ForegroundColor Yellow
Write-Host "Proyecto: $root`n"

foreach ($entry in $toolPaths.GetEnumerator()) {
    $exists = Test-Path -LiteralPath $entry.Value
    $warningOnly = $entry.Key -in @('Blender', 'ADB', 'debug keystore', 'GitHub CLI')
    Report-Item $entry.Key $exists $entry.Value $warningOnly
    if ($VerboseTools -and $exists) { Get-Item -LiteralPath $entry.Value | Select-Object FullName, Length | Format-List }
}

Write-Host "`n--- Versiones ---"
try {
    $godotVersion = (& 'C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --version 2>&1 | Out-String).Trim()
    Report-Item 'Godot version' ($godotVersion -match '4\.7\.2') $godotVersion
} catch {
    Report-Item 'Godot version' $false $_.Exception.Message
}

$venvPython = Join-Path $root '.venv\Scripts\python.exe'
if (Test-Path -LiteralPath $venvPython) {
    $pyVersion = (& $venvPython --version 2>&1 | Out-String).Trim()
    Report-Item 'Python venv' $true $pyVersion
    $moduleCheck = & $venvPython -c "import jsonschema, PIL, pypdf, docx, fontTools; print('deps OK')" 2>&1
    Report-Item 'Python dependencies' ($LASTEXITCODE -eq 0) ($moduleCheck | Out-String).Trim()
} else {
    Report-Item 'Python venv' $false 'Falta .venv; ejecutar python -m venv .venv e instalar requirements-dev.lock'
}

$ghPath = 'C:\Program Files\GitHub CLI\gh.exe'
if (Test-Path -LiteralPath $ghPath) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $auth = (& $ghPath auth status 2>&1 | Out-String).Trim()
    $authExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $authenticated = $authExit -eq 0
    Report-Item 'GitHub authentication' $authenticated ($(if ($authenticated) { 'Sesión de gh activa' } else { 'gh existe, pero no hay sesión iniciada; ejecutar gh auth login antes de publicar' })) $true
} else {
    Report-Item 'GitHub authentication' $false 'gh no está instalado en la ruta esperada' $true
}

if (Test-Path -LiteralPath 'C:\Android\platform-tools\adb.exe') {
    $devices = (& 'C:\Android\platform-tools\adb.exe' devices -l 2>&1 | Out-String).Trim()
    $hasDevice = $devices -match '\sdevice\s'
    Report-Item 'ADB device' $hasDevice ($(if ($hasDevice) { ($devices -split "`n" | Select-Object -Last 1).Trim() } else { 'Sin dispositivo autorizado' })) $true
}

$sdkPlatforms = Get-ChildItem -LiteralPath 'C:\Android\platforms' -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
Write-Host ('[INFO] SDK platforms: ' + ($sdkPlatforms -join ', '))
if ($sdkPlatforms -notcontains 'android-36') {
    Write-Host '[WARN] Android 36 no está instalado; es necesario para Google Play a partir de agosto de 2026.'
    $warnings.Add('android-36')
}

$freeGb = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$diskStatus = if ($freeGb -ge 20) { '[OK]' } elseif ($freeGb -ge 10) { '[WARN]' } else { '[FAIL]' }
Write-Host "$diskStatus Espacio libre en C: $freeGb GB"
if ($freeGb -lt 10) { $failures.Add('disk') }

Write-Host "`n--- Git ---"
Push-Location $root
try {
    if (Test-Path -LiteralPath (Join-Path $root '.git')) {
        $branch = (git branch --show-current 2>&1 | Out-String).Trim()
        $status = (git status --short 2>&1 | Out-String).Trim()
        Report-Item 'Git repository' $true "Rama $branch; $([math]::Max(0, ($status -split "`n").Count)) cambios locales"
    } else {
        Report-Item 'Git repository' $false 'Falta .git'
    }
} finally {
    Pop-Location
}

Write-Host "`nResumen: $($failures.Count) fallos críticos, $($warnings.Count) advertencias." -ForegroundColor $(if ($failures.Count -gt 0) { 'Red' } else { 'Green' })
if ($failures.Count -gt 0) { exit 1 }
exit 0
