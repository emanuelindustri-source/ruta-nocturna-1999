param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$console = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe'
$gui = 'C:\Dev\Godot\Godot_v4.7.2-stable_win64.exe'

if (-not (Test-Path -LiteralPath $console)) {
    if (-not (Test-Path -LiteralPath $gui)) {
        throw "No se encontró Godot 4.7.2 en C:\Dev\Godot."
    }
    $console = $gui
}

Push-Location $root
try {
    if ($GodotArgs.Count -eq 0) {
        & $console --path $root
    } else {
        & $console @GodotArgs
    }
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $exitCode
