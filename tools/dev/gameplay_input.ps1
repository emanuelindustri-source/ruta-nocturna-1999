param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('shot', 'click', 'move', 'hold', 'press', 'release', 'drag', 'rightdrag', 'key', 'close', 'state')]
    [string]$Action,
    [int]$X = 0,
    [int]$Y = 0,
    [int]$X2 = 0,
    [int]$Y2 = 0,
    [int]$Ms = 600,
    [string]$Key = '',
    [string]$Name = ''
)

# Driver de prueba de juego en PC (F3.5): mueve el cursor, hace clics, arrastres
# y teclas sobre la ventana REAL del build exportado, y guarda capturas que se
# revisan visualmente. Coordenadas en el area de cliente de la ventana del
# juego (0,0 = esquina superior izquierda del area de dibujo).
#
# Ejemplos:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\gameplay_input.ps1 -Action shot -Name 01_boot
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\gameplay_input.ps1 -Action click -X 640 -Y 480
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\gameplay_input.ps1 -Action key -Key ENTER

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$shotDir = Join-Path $root 'build\logs\gameplay'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

$win32 = @"
using System;
using System.Runtime.InteropServices;
public class RNWin32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern short GetKeyState(int nVirtKey);
    [DllImport("user32.dll")] public static extern uint GetDpiForSystem();
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }
}
"@
Add-Type -TypeDefinition $win32 -ErrorAction SilentlyContinue

function Get-GameWindow {
    $proc = Get-Process | Where-Object {
        $_.MainWindowTitle -like '*Ruta Nocturna*' -and $_.ProcessName -like '*RutaNocturna*'
    } | Select-Object -First 1
    if (-not $proc) { throw 'No se encontro la ventana del juego. Lanza el build exportado primero.' }
    return $proc
}

function Focus-Game([IntPtr]$hwnd) {
    # Ventana al frente del Z-order y con foco (con reintento: Windows puede
    # negar SetForegroundWindow mientras la consola del comando tiene foco).
    [RNWin32]::SetWindowPos($hwnd, [IntPtr]::new(-1), 0, 0, 0, 0, 0x0001 -bor 0x0002) | Out-Null
    [RNWin32]::ShowWindow($hwnd, 9) | Out-Null
    for ($try = 0; $try -lt 4; $try++) {
        $null = (New-Object -ComObject WScript.Shell).SendKeys('%')
        Start-Sleep -Milliseconds 60
        [RNWin32]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 150
        if ([RNWin32]::GetForegroundWindow() -eq $hwnd) { break }
    }
    # Deja que DWM recomponga la ventana tras salir de estado ocluido.
    Start-Sleep -Milliseconds 450
}

function Get-ClientRectInfo([IntPtr]$hwnd) {
    $rect = New-Object RNWin32+RECT
    $null = [RNWin32]::GetClientRect($hwnd, [ref]$rect)
    $origin = New-Object RNWin32+POINT
    $null = [RNWin32]::ClientToScreen($hwnd, [ref]$origin)
    return [pscustomobject]@{
        Width = $rect.Right
        Height = $rect.Bottom
        OriginX = $origin.X
        OriginY = $origin.Y
    }
}

function Move-Cursor([IntPtr]$hwnd, [int]$x, [int]$y) {
    $info = Get-ClientRectInfo $hwnd
    [RNWin32]::SetCursorPos($info.OriginX + $x, $info.OriginY + $y) | Out-Null
    Start-Sleep -Milliseconds 80
}

function Save-Shot([IntPtr]$hwnd, [string]$name) {
    $info = Get-ClientRectInfo $hwnd
    $bmp = New-Object System.Drawing.Bitmap($info.Width, $info.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($info.OriginX, $info.OriginY, 0, 0, $bmp.Size)
    $path = Join-Path $shotDir ("{0}.png" -f $name)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Output "SHOT $path"
}

$proc = Get-GameWindow
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) { throw 'La ventana del juego no tiene handle todavia.' }

switch ($Action) {
    'state' {
        $info = Get-ClientRectInfo $hwnd
        $dpi = [RNWin32]::GetDpiForSystem()
        Write-Output ("PID={0} TITLE='{1}' CLIENT={2}x{3} ORIGIN={4},{5} DPI={6} FOCUSED={7}" -f `
            $proc.Id, $proc.MainWindowTitle, $info.Width, $info.Height, $info.OriginX, $info.OriginY, $dpi, `
            ([RNWin32]::GetForegroundWindow() -eq $hwnd))
    }
    'shot' {
        Focus-Game $hwnd
        $label = if ($name) { $name } else { 'shot_' + (Get-Date -Format 'HHmmss') }
        Save-Shot $hwnd $label
    }
    'click' {
        Focus-Game $hwnd
        Move-Cursor $hwnd $X $Y
        [RNWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # LEFTDOWN
        Start-Sleep -Milliseconds 70
        [RNWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # LEFTUP
        Start-Sleep -Milliseconds 150
        Write-Output "CLICK $X,$Y"
    }
    'move' {
        Focus-Game $hwnd
        Move-Cursor $hwnd $X $Y
        Write-Output "MOVE $X,$Y"
    }
    'hold' {
        Focus-Game $hwnd
        Move-Cursor $hwnd $X $Y
        [RNWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds $Ms
        [RNWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 150
        Write-Output "HOLD ${Ms}ms en $X,$Y"
    }
    'press' {
        # Boton izquierdo mantenido (para capturar el estado durante un hold).
        Focus-Game $hwnd
        Move-Cursor $hwnd $X $Y
        [RNWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 120
        Write-Output "PRESS $X,$Y"
    }
    'release' {
        [RNWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 150
        Write-Output 'RELEASE'
    }
    'drag' {
        # Arrastre con boton izquierdo (gesto): de (X,Y) a (X2,Y2) en pasos.
        Focus-Game $hwnd
        Move-Cursor $hwnd $X $Y
        [RNWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 80
        $steps = 12
        for ($i = 1; $i -le $steps; $i++) {
            $nx = $X + [int](($X2 - $X) * $i / $steps)
            $ny = $Y + [int](($Y2 - $Y) * $i / $steps)
            Move-Cursor $hwnd $nx $ny
            Start-Sleep -Milliseconds 25
        }
        [RNWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 200
        Write-Output "DRAG $X,$Y -> $X2,$Y2"
    }
    'rightdrag' {
        # Mirar alrededor (rotacion de camara) con el boton derecho.
        Focus-Game $hwnd
        Move-Cursor $hwnd $X $Y
        [RNWin32]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)  # RIGHTDOWN
        Start-Sleep -Milliseconds 80
        $steps = 12
        for ($i = 1; $i -le $steps; $i++) {
            $nx = $X + [int](($X2 - $X) * $i / $steps)
            $ny = $Y + [int](($Y2 - $Y) * $i / $steps)
            Move-Cursor $hwnd $nx $ny
            Start-Sleep -Milliseconds 25
        }
        [RNWin32]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)  # RIGHTUP
        # Segundo RIGHTUP + micro-movimiento: evita que el modo mirada quede
        # activo si el primer evento se pierde durante el cambio de foco.
        Start-Sleep -Milliseconds 60
        [RNWin32]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 200
        Write-Output "RIGHTDRAG $X,$Y -> $X2,$Y2"
    }
    'key' {
        Focus-Game $hwnd
        $shell = New-Object -ComObject WScript.Shell
        $map = @{
            'ENTER' = '{ENTER}'; 'TAB' = '{TAB}'; 'ESC' = '{ESC}'; 'SPACE' = ' '
            'F12' = '{F12}'; 'F1' = '{F1}'; 'UP' = '{UP}'; 'DOWN' = '{DOWN}'
            'LEFT' = '{LEFT}'; 'RIGHT' = '{RIGHT}'; 'BACKSPACE' = '{BS}'
        }
        $sequence = if ($map.ContainsKey($Key.ToUpper())) { $map[$Key.ToUpper()] } else { $Key }
        $shell.SendKeys($sequence)
        Start-Sleep -Milliseconds 250
        Write-Output "KEY $Key"
    }
    'close' {
        Focus-Game $hwnd
        $proc.CloseMainWindow() | Out-Null
        Start-Sleep -Milliseconds 800
        if (-not $proc.HasExited) { $proc.Kill() }
        Write-Output "CLOSE pid=$($proc.Id) exited=$($proc.HasExited)"
    }
}
