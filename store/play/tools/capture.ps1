param(
  [string]$ShotTab = '',
  [string]$ShotView = '',
  [string]$ShotLayout = '',
  [string]$Locale = '',
  [switch]$ForceViolation,
  [string]$OpenSeat = '',
  [int]$Width = 1080,
  [int]$Height = 1920,
  [Parameter(Mandatory=$true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

if (-not ('Win32Cap' -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class Win32Cap {
  [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc cb, IntPtr data);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO mi);

  public delegate bool MonitorEnumProc(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr data);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }

  public static List<RECT> Monitors() {
    var list = new List<RECT>();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr d) {
      var mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
      if (GetMonitorInfo(hMon, ref mi)) list.Add(mi.rcMonitor);
      return true;
    }, IntPtr.Zero);
    return list;
  }
}
'@
}

# DPI-aware (PER_MONITOR_AWARE_V2 = -4) : sans ça les coords des moniteurs sont
# virtualisées et la fenêtre atterrit sur le mauvais écran.
[void][Win32Cap]::SetProcessDpiAwarenessContext([IntPtr](-4))

$mons = [Win32Cap]::Monitors()
$portrait = $mons | Where-Object { ($_.Bottom - $_.Top) -gt ($_.Right - $_.Left) } | Select-Object -First 1
if (-not $portrait) { throw "Aucun moniteur portrait trouvé." }
$monW = $portrait.Right - $portrait.Left
$monH = $portrait.Bottom - $portrait.Top
if ($Width -gt $monW -or $Height -gt $monH) {
  throw "Fenêtre ${Width}x${Height} plus grande que le moniteur portrait ${monW}x${monH} : la zone hors écran serait capturée en noir."
}
$posX = $portrait.Left + [int](($monW - $Width) / 2)
$posY = $portrait.Top + [int](($monH - $Height) / 2)

$exe = Join-Path (Get-Location) 'build\windows\x64\runner\Debug\plandeclasse.exe'
if (-not (Test-Path $exe)) { throw "Exe introuvable : $exe" }

$env:PDC_SHOT_DEMO = '1'
$env:PDC_SHOT_TAB = $ShotTab
$env:PDC_SHOT_VIEW = $ShotView
$env:PDC_SHOT_LAYOUT = $ShotLayout
$env:PDC_SHOT_FORCE_VIOLATION = $(if ($ForceViolation) { '1' } else { '' })
$env:PDC_SHOT_OPEN_SEAT = $OpenSeat
$env:PDC_SHOT_LOCALE = $Locale

$proc = Start-Process -FilePath $exe -PassThru
try {
  $deadline = (Get-Date).AddSeconds(30)
  while (-not $proc.MainWindowHandle -or $proc.MainWindowHandle -eq 0) {
    if ((Get-Date) -gt $deadline) { throw "La fenêtre n'est jamais apparue." }
    Start-Sleep -Milliseconds 200
    $proc.Refresh()
  }
  $h = $proc.MainWindowHandle

  # Viser une ZONE CLIENT exacte : GetWindowRect - GetClientRect = bordures.
  # Deux passes, Windows arrondit parfois la première.
  for ($pass = 0; $pass -lt 2; $pass++) {
    $wr = New-Object Win32Cap+RECT; $cr = New-Object Win32Cap+RECT
    [void][Win32Cap]::GetWindowRect($h, [ref]$wr)
    [void][Win32Cap]::GetClientRect($h, [ref]$cr)
    $bw = ($wr.Right - $wr.Left) - ($cr.Right - $cr.Left)
    $bh = ($wr.Bottom - $wr.Top) - ($cr.Bottom - $cr.Top)
    [void][Win32Cap]::SetWindowPos($h, [IntPtr](-1), $posX, $posY, $Width + $bw, $Height + $bh, 0x0040)
    Start-Sleep -Milliseconds 700
  }

  # Laisser l'app finir son premier rendu (chargement asset démo + post-frame).
  Start-Sleep -Milliseconds 2500

  $cr = New-Object Win32Cap+RECT
  [void][Win32Cap]::GetClientRect($h, [ref]$cr)
  $cw = $cr.Right - $cr.Left; $ch = $cr.Bottom - $cr.Top
  if ($cw -ne $Width -or $ch -ne $Height) {
    Write-Host "  [!] zone client ${cw}x${ch} au lieu de ${Width}x${Height}"
  }
  $origin = New-Object Win32Cap+POINT
  [void][Win32Cap]::ClientToScreen($h, [ref]$origin)

  $bmp = New-Object System.Drawing.Bitmap($cw, $ch)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($origin.X, $origin.Y, 0, 0, (New-Object System.Drawing.Size($cw, $ch)))
  $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "  OK: $OutFile (${cw}x${ch})"
}
finally {
  if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
}
