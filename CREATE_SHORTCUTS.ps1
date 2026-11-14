$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$server = Join-Path $root 'server.ps1'
$icon = Join-Path $root 'app-icon.ico'
if (-not (Test-Path -LiteralPath $server -PathType Leaf)) { throw "server.ps1 fehlt im Installationsordner: $server" }
$powerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $server + '"'
$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$programs = [Environment]::GetFolderPath('Programs')
$menu = Join-Path $programs 'ScoutLab Sports'
if (-not (Test-Path -LiteralPath $menu)) { New-Item -ItemType Directory -Path $menu -Force | Out-Null }
$targets = @(
    (Join-Path $desktop 'ScoutLab Sports.lnk'),
    (Join-Path $menu 'ScoutLab Sports.lnk')
)
foreach ($shortcutPath in $targets) {
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powerShell
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $root
    if (Test-Path -LiteralPath $icon) { $shortcut.IconLocation = $icon }
    $shortcut.Description = 'ScoutLab Sports – European Match Centre'
    $shortcut.Save()
}
Write-Host 'Desktop- und Startmenue-Verknuepfung wurden erstellt.' -ForegroundColor Green
