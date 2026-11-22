param(
    [string]$Owner = 'emanuelindustri-source',
    [string]$Repo = 'ruta-nocturna-1999',
    [switch]$SkipPages
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gh = 'C:\Program Files\GitHub CLI\gh.exe'

function Invoke-Checked {
    param([string[]]$Command, [string]$Failure)
    & $Command[0] @($Command[1..($Command.Count - 1)]) | Out-Host
    if ($LASTEXITCODE -ne 0) { throw $Failure }
}

if (-not (Test-Path -LiteralPath $gh)) { throw 'GitHub CLI no está instalado.' }
if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) { throw 'No hay repositorio Git local.' }

$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$auth = (& $gh auth status 2>&1 | Out-String).Trim()
$authExit = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($authExit -ne 0) {
    Write-Host $auth
    throw 'GitHub CLI no tiene sesión. Khristyan debe ejecutar: gh auth login'
}

Push-Location $root
try {
    $branch = (git branch --show-current).Trim()
    if ($branch -ne 'main') { throw "La rama actual es '$branch'; se esperaba 'main'." }

    $dirty = (git status --porcelain | Out-String).Trim()
    if ($dirty) {
        throw 'Hay cambios sin commit. Ejecuta el cierre de la subfase y vuelve a publicar.'
    }

    $repoSlug = "$Owner/$Repo"
    $existing = & $gh repo view $repoSlug --json name 2>$null
    $repoExists = $LASTEXITCODE -eq 0

    $remote = (git remote get-url origin 2>$null)
    if (-not $remote) {
        if ($repoExists) {
            Write-Host "[INFO] El repositorio $repoSlug ya existe. Configurando origin."
            git remote add origin "https://github.com/$repoSlug.git"
            if ($LASTEXITCODE -ne 0) { throw 'No se pudo configurar origin.' }
        } else {
            Write-Host "[INFO] Creando repositorio público $repoSlug y subiendo main."
            & $gh repo create $repoSlug --public --source . --remote origin --push
            if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el repositorio remoto.' }
            git push origin main --tags
            if ($LASTEXITCODE -ne 0) { throw 'No se pudieron subir los tags.' }
        }
    } else {
        Write-Host "[INFO] Origin existente: $remote"
        if ($remote -notmatch [regex]::Escape($repoSlug)) {
            throw "El origin no corresponde a $repoSlug. Revisa el remoto antes de continuar."
        }
        git push -u origin main --tags
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo hacer push de main y tags.' }
    }

    if (-not $SkipPages) {
        Write-Host '[INFO] Configurando GitHub Pages con GitHub Actions.'
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $pages = & $gh api "repos/$repoSlug/pages" 2>&1 | Out-String
        $pagesExit = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        if ($pagesExit -eq 0) {
            & $gh api --method PUT "repos/$repoSlug/pages" -f build_type=workflow | Out-Host
        } else {
            & $gh api --method POST "repos/$repoSlug/pages" -f build_type=workflow | Out-Host
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host '[WARN] No se pudo configurar Pages por API. Revisar Settings > Pages.' -ForegroundColor Yellow
        } else {
            Write-Host '[OK] Pages configurado para publicar desde GitHub Actions.' -ForegroundColor Green
        }
    }

    Write-Host "`n[OK] Repositorio: https://github.com/$repoSlug" -ForegroundColor Green
    Write-Host "[OK] Acciones:  https://github.com/$repoSlug/actions" -ForegroundColor Green
    Write-Host "[OK] Web:       https://$($Owner.ToLower()).github.io/$Repo/" -ForegroundColor Green
    Write-Host 'El despliegue de Pages puede tardar uno o dos minutos después del primer workflow.'
} finally {
    Pop-Location
}
