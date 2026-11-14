param([Parameter(Mandatory=$true)][string]$Version)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version muss dem Format 0.8.1 entsprechen.' }
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = @('index.html','broadcast_rights_database.json','sw.js','manifest.webmanifest','server.ps1','update_worker.ps1','app-icon.svg','app-icon-192.png','app-icon-512.png','app-icon.ico','START_SCOUTLAB.bat','START_BROWSER.bat','START_SCOUTLAB.vbs','INSTALL_SCOUTLAB.bat','INSTALL_SCOUTLAB.vbs','CREATE_SHORTCUTS.ps1','START_SCOUTLAB_DEBUG.bat','README_DE.txt','MAKE_UPDATE_MANIFEST.ps1','PUBLISH_UPDATE.bat')
$items = @()
foreach ($name in $files) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Datei fehlt: $name" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $items += @{ name = $name; sha256 = $hash }
}
$manifest = @{ version = $Version; updatedAt = (Get-Date).ToString('yyyy-MM-dd'); files = $items }
$json = $manifest | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $root 'update-manifest.json'), $json, [Text.UTF8Encoding]::new($false))
Write-Host "Update-Manifest fuer $Version erstellt." -ForegroundColor Green
