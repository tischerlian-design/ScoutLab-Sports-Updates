# ScoutLab Sports 0.8.3 – lokaler App- und GitHub-Updatehelfer
# Bindet ausschließlich an 127.0.0.1. Erlaubt nur fest definierte Sportdaten-Endpunkte.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8765
$updateToken = [Guid]::NewGuid().ToString('N')
$appVersion = '0.8.3'
$updateConfigPath = Join-Path $root 'update_config.json'
$versionPath = Join-Path $root 'version.json'
$progressPath = Join-Path $root '.update-progress.json'
$logDir = Join-Path $env:LOCALAPPDATA 'ScoutLabSports'
$logPath = Join-Path $logDir 'scoutlab.log'
try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { }
function Write-ScoutLog { param([string]$Message) try { Add-Content -LiteralPath $logPath -Value ("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message") -Encoding UTF8 } catch { } }

try { Add-Type -AssemblyName System.Net.Http } catch { }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$http = [System.Net.Http.HttpClient]::new()
$http.Timeout = [TimeSpan]::FromSeconds(22)
$http.DefaultRequestHeaders.UserAgent.ParseAdd('ScoutLabSports/0.8.3 (local Windows app helper)')
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)

function Send-Response {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$Status,
        [string]$ContentType,
        [byte[]]$Bytes
    )
    $reason = switch ($Status) {
        200 { 'OK' }
        400 { 'Bad Request' }
        403 { 'Forbidden' }
        404 { 'Not Found' }
        502 { 'Bad Gateway' }
        504 { 'Gateway Timeout' }
        default { 'Error' }
    }
    $header = "HTTP/1.1 $Status $reason`r`nContent-Type: $ContentType`r`nContent-Length: $($Bytes.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headBytes, 0, $headBytes.Length)
    if ($Bytes.Length -gt 0) { $Stream.Write($Bytes, 0, $Bytes.Length) }
    $Stream.Flush()
}

function Send-JsonError {
    param([System.Net.Sockets.NetworkStream]$Stream, [int]$Status, [string]$Message)
    $json = @{ error = $Message } | ConvertTo-Json -Compress
    Send-Response -Stream $Stream -Status $Status -ContentType 'application/json; charset=utf-8' -Bytes ([System.Text.Encoding]::UTF8.GetBytes($json))
}


function Get-CurrentVersion {
    try {
        if (Test-Path -LiteralPath $versionPath) {
            $v = (Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8 | ConvertFrom-Json).version
            if ($v) { return [string]$v }
        }
    } catch { }
    return $appVersion
}

function Get-UpdateConfig {
    try {
        if (Test-Path -LiteralPath $updateConfigPath) {
            return (Get-Content -LiteralPath $updateConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
    } catch { }
    return $null
}

function Get-QueryMap {
    param([string]$Target)
    $map = @{}
    $qIndex = $Target.IndexOf('?')
    if ($qIndex -lt 0) { return $map }
    $query = $Target.Substring($qIndex + 1)
    foreach ($part in $query.Split('&')) {
        if (-not $part) { continue }
        $pair = $part.Split('=', 2)
        $key = [Uri]::UnescapeDataString($pair[0].Replace('+', '%20'))
        $value = if ($pair.Length -gt 1) { [Uri]::UnescapeDataString($pair[1].Replace('+', '%20')) } else { '' }
        $map[$key] = $value
    }
    return $map
}

function Get-UpdateManifest {
    $config = Get-UpdateConfig
    if ($null -eq $config -or [string]::IsNullOrWhiteSpace([string]$config.repo)) {
        return [pscustomobject]@{ configured = $false; currentVersion = (Get-CurrentVersion); latestVersion = $null; repo = ''; branch = 'main'; message = 'Keine Updatequelle eingerichtet.'; manifest = $null }
    }
    $repo = [string]$config.repo
    $branch = [string]$config.branch
    if ($repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or $branch -notmatch '^[A-Za-z0-9_.-]+$') {
        throw 'Die gespeicherte GitHub-Repository-Adresse ist ungültig.'
    }
    $url = "https://raw.githubusercontent.com/$repo/$branch/update-manifest.json?ts=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    $json = $http.GetStringAsync($url).GetAwaiter().GetResult()
    $manifest = $json | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$manifest.version) -or $null -eq $manifest.files) {
        throw 'Das GitHub-Update-Manifest hat ein ungültiges Format.'
    }
    return [pscustomobject]@{ configured = $true; currentVersion = (Get-CurrentVersion); latestVersion = [string]$manifest.version; repo = $repo; branch = $branch; message = 'Updatequelle erreichbar.'; manifest = $manifest }
}

function Invoke-RemoteUpdate {
    param([switch]$Apply)
    $info = Get-UpdateManifest
    if (-not $info.configured) { return $info }
    try {
        $remoteVersion = [version]$info.latestVersion
        $localVersion = [version]$info.currentVersion
    } catch { throw 'Versionsnummer im Update-Manifest ist ungültig. Verwende z. B. 0.8.3.' }
    if ($remoteVersion -le $localVersion) {
        $info.message = 'ScoutLab ist auf dem aktuellen Stand.'
        return $info
    }
    if (-not $Apply) {
        $info.message = 'Eine neue Version ist verfügbar.'
        return $info
    }

    $allowedFiles = @('index.html', 'broadcast_rights_database.json', 'sw.js', 'manifest.webmanifest', 'server.ps1', 'app-icon.svg', 'app-icon-192.png', 'app-icon-512.png', 'app-icon.ico', 'START_SCOUTLAB.vbs', 'INSTALL_SCOUTLAB.vbs', 'START_SCOUTLAB.bat', 'START_BROWSER.bat', 'INSTALL_SCOUTLAB.bat', 'CREATE_SHORTCUTS.ps1', 'START_SCOUTLAB_DEBUG.bat', 'README_DE.txt')
    if (@($info.manifest.files).Count -gt $allowedFiles.Count) { throw 'Das Update-Manifest enthält zu viele Dateien.' }
    $stage = Join-Path $root ('.update-staging-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $downloaded = @()
    $totalBytes = 0L
    try {
        foreach ($file in @($info.manifest.files)) {
            $name = [string]$file.name
            if ($allowedFiles -notcontains $name) { throw "Datei '$name' ist für Updates nicht freigegeben." }
            if ($downloaded -contains $name) { throw "Datei '$name' steht doppelt im Update-Manifest." }
            $expected = [string]$file.sha256
            if ($expected -notmatch '^[A-Fa-f0-9]{64}$') { throw "SHA-256-Prüfsumme für '$name' fehlt oder ist ungültig." }
            $assetUrl = "https://raw.githubusercontent.com/$($info.repo)/$($info.branch)/$name"
            $bytes = $http.GetByteArrayAsync($assetUrl).GetAwaiter().GetResult()
            if ($bytes.Length -gt 12MB) { throw "Datei '$name' überschreitet 12 MB." }
            $totalBytes += $bytes.Length
            if ($totalBytes -gt 24MB) { throw 'Das Updatepaket überschreitet 24 MB.' }
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $actual = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
            if ($actual -ne $expected.ToLowerInvariant()) { throw "Prüfsummenfehler bei '$name'. Das Update wurde nicht installiert." }
            $stagedPath = Join-Path $stage $name
            [IO.File]::WriteAllBytes($stagedPath, $bytes)
            $downloaded += $name
        }
        if ($downloaded -notcontains 'index.html' -or $downloaded -notcontains 'broadcast_rights_database.json') {
            throw 'Das Manifest muss index.html und broadcast_rights_database.json enthalten.'
        }
        # Dateien als Transaktion austauschen: Bei einem Schreibfehler werden bereits
        # ersetzte Dateien aus ihren Backups wiederhergestellt.
        $applied = @()
        try {
            foreach ($name in $downloaded) {
                $destination = Join-Path $root $name
                $backup = $destination + '.scoutlab-backup'
                if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
                $hadOriginal = Test-Path -LiteralPath $destination
                if ($hadOriginal) { Move-Item -LiteralPath $destination -Destination $backup -Force }
                try {
                    Move-Item -LiteralPath (Join-Path $stage $name) -Destination $destination -Force
                    $applied += [pscustomobject]@{ name = $name; hadOriginal = $hadOriginal }
                } catch {
                    if ($hadOriginal -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $destination -Force }
                    throw
                }
            }
            $versionJson = @{ version = $info.latestVersion; updatedAt = (Get-Date).ToString('o') } | ConvertTo-Json -Compress
            [IO.File]::WriteAllText($versionPath, $versionJson, [Text.Encoding]::UTF8)
            foreach ($item in $applied) {
                $backup = (Join-Path $root $item.name) + '.scoutlab-backup'
                if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
            }
        } catch {
            for ($i = $applied.Count - 1; $i -ge 0; $i--) {
                $item = $applied[$i]
                $destination = Join-Path $root $item.name
                $backup = $destination + '.scoutlab-backup'
                if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
                if ($item.hadOriginal -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $destination -Force }
            }
            throw
        }
        return [pscustomobject]@{ configured = $true; updated = $true; restartRequired = ($downloaded -contains 'server.ps1'); currentVersion = $info.latestVersion; latestVersion = $info.latestVersion; version = $info.latestVersion; repo = $info.repo; branch = $info.branch; files = $downloaded; message = "ScoutLab $($info.latestVersion) wurde installiert." }
    }
    finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Get-UpdateProgress {
    try {
        if (Test-Path -LiteralPath $progressPath -PathType Leaf) {
            return (Get-Content -LiteralPath $progressPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
    } catch { }
    return [pscustomobject]@{ state = 'idle'; percent = 0; message = 'Bereit für Updates.'; currentFile = ''; version = $null; restartRequired = $false }
}

function Start-UpdateWorker {
    $info = Invoke-RemoteUpdate
    if (-not $info.configured) { return $info }
    if ([version]$info.latestVersion -le [version]$info.currentVersion) {
        return [pscustomobject]@{ started = $false; updated = $false; message = 'ScoutLab ist bereits aktuell.'; latestVersion = $info.latestVersion }
    }
    $existing = Get-UpdateProgress
    if ([string]$existing.state -in @('starting','downloading','verifying','installing')) {
        return [pscustomobject]@{ started = $true; alreadyRunning = $true; version = $existing.version; message = 'Ein Update läuft bereits.' }
    }
    $workerPath = Join-Path $root 'update_worker.ps1'
    if (-not (Test-Path -LiteralPath $workerPath -PathType Leaf)) { throw 'Der integrierte Update-Worker fehlt. Bitte ScoutLab einmal neu installieren.' }
    $initial = @{ state='starting'; percent=0; message='Update wird gestartet …'; currentFile=''; version=$info.latestVersion; restartRequired=$false; updatedAt=(Get-Date).ToString('o') } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($progressPath, $initial, [Text.UTF8Encoding]::new($false))
    $powershellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
    # Repo und Branch sind zuvor streng auf URL-sichere Zeichen begrenzt.
    $argumentLine = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $workerPath + '" -Repo ' + $info.repo + ' -Branch ' + $info.branch
    $process = Start-Process -FilePath $powershellExe -ArgumentList $argumentLine -WindowStyle Hidden -PassThru
    if ($null -eq $process) { throw 'Der Updateprozess konnte nicht gestartet werden.' }
    return [pscustomobject]@{ started = $true; version = $info.latestVersion; message = 'Update-Download wurde gestartet.' }
}

function Handle-Client {
    param([System.Net.Sockets.TcpClient]$Client)
    $stream = $null
    try {
        $stream = $Client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) { return }
        $parts = $requestLine.Split(' ')
        if ($parts.Length -lt 2 -or $parts[0] -ne 'GET') {
            Send-JsonError $stream 400 'Nur GET-Anfragen sind erlaubt.'
            return
        }
        $target = $parts[1]
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line -or $line -eq '') { break }
        }


        if ($target -eq '/update/progress') {
            $progress = Get-UpdateProgress
            $json = $progress | ConvertTo-Json -Compress
            Send-Response $stream 200 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
            return
        }
        if ($target -eq '/update/status') {
            try {
                $info = Invoke-RemoteUpdate
                $progress = Get-UpdateProgress
                $statusData = [ordered]@{ configured=$info.configured; currentVersion=$info.currentVersion; latestVersion=$info.latestVersion; repo=$info.repo; branch=$info.branch; message=$info.message; progress=$progress }
                $json = $statusData | ConvertTo-Json -Depth 5 -Compress
                Send-Response $stream 200 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
            } catch { Send-JsonError $stream 502 ('Updatequelle nicht erreichbar: ' + $_.Exception.Message) }
            return
        }
        if ($target.Split('?')[0] -eq '/update/apply') {
            try {
                $query = Get-QueryMap $target
                if ([string]$query['token'] -ne $updateToken) { throw 'Updateaktion nicht autorisiert.' }
                $info = Start-UpdateWorker
                $json = $info | ConvertTo-Json -Depth 5 -Compress
                Send-Response $stream 200 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
            } catch { Send-JsonError $stream 502 ('Update fehlgeschlagen: ' + $_.Exception.Message) }
            return
        }
        if ($target.StartsWith('/update/configure?', [StringComparison]::Ordinal)) {
            try {
                $query = Get-QueryMap $target
                $repo = [string]$query['repo']
                $branch = [string]$query['branch']
                if ([string]$query['token'] -ne $updateToken) { throw 'Updatekonfiguration nicht autorisiert.' }
                if ($repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Repository muss im Format Besitzer/Name angegeben werden.' }
                if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'main' }
                if ($branch -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Der Branch-Name enthält ungültige Zeichen.' }
                $configJson = @{ repo = $repo; branch = $branch; provider = 'GitHub public raw content' } | ConvertTo-Json -Compress
                [IO.File]::WriteAllText($updateConfigPath, $configJson, [Text.Encoding]::UTF8)
                $json = @{ configured = $true; repo = $repo; branch = $branch; message = 'GitHub-Updatequelle gespeichert. Prüfe jetzt das Update-Manifest.' } | ConvertTo-Json -Compress
                Send-Response $stream 200 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
            } catch { Send-JsonError $stream 400 $_.Exception.Message }
            return
        }

        if ($target -eq '/health') {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true,"helper":"ScoutLab Sports 0.8.3"}')
            Send-Response $stream 200 'application/json; charset=utf-8' $bytes
            return
        }


        if ($target.StartsWith('/proxybatch?urls=', [StringComparison]::Ordinal)) {
            $encoded = $target.Substring('/proxybatch?urls='.Length)
            $rawJson = [Uri]::UnescapeDataString($encoded.Replace('+', '%20'))
            $urls = @($rawJson | ConvertFrom-Json)
            if ($urls.Count -lt 1 -or $urls.Count -gt 12) {
                Send-JsonError $stream 400 'Die gebündelte Abfrage muss 1 bis 12 URLs enthalten.'
                return
            }
            $tasks = @()
            foreach ($raw in $urls) {
                $uri = $null
                if (-not [Uri]::TryCreate([string]$raw, [UriKind]::Absolute, [ref]$uri)) {
                    Send-JsonError $stream 400 'Eine Zieladresse im Paket ist ungültig.'
                    return
                }
                $allowed = $false
                if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'sportscore.com' -and
                    ($uri.AbsolutePath -in @('/api/v1/fixtures/','/api/v1/search/','/api/v1/h2h/','/api/widget/matches/','/api/widget/match/','/api/widget/team/','/api/widget/standings/','/api/widget/topscorers/'))) {
                    $allowed = $true
                }
                if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'api.openligadb.de' -and
                    ($uri.AbsolutePath -match '^/getavailableleagues(?:/\d{4})?$' -or $uri.AbsolutePath -match '^/getmatchdata/[A-Za-z0-9_-]+(?:/\d{4})?$' -or $uri.AbsolutePath -match '^/getbltable/[A-Za-z0-9_-]+/\d{4}$' -or $uri.AbsolutePath -match '^/getgoalgetters/[A-Za-z0-9_-]+/\d{4}$' -or $uri.AbsolutePath -match '^/getmatchesbyteamid/\d+/\d+/\d+$' -or $uri.AbsolutePath -match '^/getmatchdata/\d+/\d+$')) {
                    $allowed = $true
                }
                if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'geocoding-api.open-meteo.com' -and $uri.AbsolutePath -eq '/v1/search') { $allowed = $true }
                if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'api.open-meteo.com' -and $uri.AbsolutePath -eq '/v1/forecast') { $allowed = $true }
                if (-not $allowed) {
                    Send-JsonError $stream 403 'Eine Datenquelle im Paket ist nicht freigegeben.'
                    return
                }
                $tasks += $http.GetAsync($uri)
            }
            try {
                [System.Threading.Tasks.Task]::WhenAll([System.Threading.Tasks.Task[]]$tasks).GetAwaiter().GetResult()
                $items = @()
                foreach ($task in $tasks) {
                    $response = $task.Result
                    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    $items += [pscustomobject]@{ status = [int]$response.StatusCode; body = $body }
                    $response.Dispose()
                }
                $json = ConvertTo-Json -InputObject @($items) -Depth 5 -Compress
                Send-Response $stream 200 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
            }
            catch {
                Send-JsonError $stream 502 ('Gebündelter API-Abruf fehlgeschlagen: ' + $_.Exception.Message)
            }
            return
        }

        if ($target.StartsWith('/proxy?url=', [StringComparison]::Ordinal)) {
            $encoded = $target.Substring('/proxy?url='.Length)
            $rawUrl = [Uri]::UnescapeDataString($encoded.Replace('+', '%20'))
            $uri = $null
            if (-not [Uri]::TryCreate($rawUrl, [UriKind]::Absolute, [ref]$uri)) {
                Send-JsonError $stream 400 'Ungültige Zieladresse.'
                return
            }
            $allowed = $false
            if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'sportscore.com' -and
                ($uri.AbsolutePath -in @('/api/v1/fixtures/','/api/v1/search/','/api/v1/h2h/','/api/widget/matches/','/api/widget/match/','/api/widget/team/','/api/widget/standings/','/api/widget/topscorers/'))) {
                $allowed = $true
            }
            if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'api.openligadb.de' -and
                ($uri.AbsolutePath -match '^/getavailableleagues(?:/\d{4})?$' -or $uri.AbsolutePath -match '^/getmatchdata/[A-Za-z0-9_-]+(?:/\d{4})?$' -or $uri.AbsolutePath -match '^/getbltable/[A-Za-z0-9_-]+/\d{4}$' -or $uri.AbsolutePath -match '^/getgoalgetters/[A-Za-z0-9_-]+/\d{4}$' -or $uri.AbsolutePath -match '^/getmatchesbyteamid/\d+/\d+/\d+$' -or $uri.AbsolutePath -match '^/getmatchdata/\d+/\d+$')) {
                $allowed = $true
            }
            if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'geocoding-api.open-meteo.com' -and $uri.AbsolutePath -eq '/v1/search') { $allowed = $true }
            if ($uri.Scheme -eq 'https' -and $uri.Host -eq 'api.open-meteo.com' -and $uri.AbsolutePath -eq '/v1/forecast') { $allowed = $true }
            if (-not $allowed) {
                Send-JsonError $stream 403 'Diese Datenquelle ist aus Sicherheitsgründen nicht freigegeben.'
                return
            }
            try {
                $response = $http.GetAsync($uri).GetAwaiter().GetResult()
                $body = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
                $status = [int]$response.StatusCode
                $contentType = 'application/json; charset=utf-8'
                if ($response.Content.Headers.ContentType) { $contentType = $response.Content.Headers.ContentType.ToString() }
                Send-Response $stream $status $contentType $body
                $response.Dispose()
            }
            catch [System.Threading.Tasks.TaskCanceledException] {
                Send-JsonError $stream 504 'Zeitüberschreitung beim Abruf der Sportdaten-API.'
            }
            catch {
                Send-JsonError $stream 502 ('Sportdaten-API nicht erreichbar: ' + $_.Exception.Message)
            }
            return
        }

        $asset = $null
        switch ($target.Split('?')[0]) {
            '/' { $asset = 'index.html' }
            '/index.html' { $asset = 'index.html' }
            '/sw.js' { $asset = 'sw.js' }
            '/manifest.webmanifest' { $asset = 'manifest.webmanifest' }
            '/broadcast_rights_database.json' { $asset = 'broadcast_rights_database.json' }
            '/app-icon.svg' { $asset = 'app-icon.svg' }
            '/app-icon-192.png' { $asset = 'app-icon-192.png' }
            '/app-icon-512.png' { $asset = 'app-icon-512.png' }
            '/app-icon.ico' { $asset = 'app-icon.ico' }
            '/github-update-template.zip' { $asset = 'github-update-template.zip' }
            '/version.json' { $asset = 'version.json' }
            default { $asset = $null }
        }
        if ($null -eq $asset) {
            Send-JsonError $stream 404 'Datei nicht gefunden.'
            return
        }
        $fullPath = Join-Path $root $asset
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            Send-JsonError $stream 404 'Programmdatei fehlt im entpackten Ordner.'
            return
        }
        $contentType = switch ([IO.Path]::GetExtension($fullPath).ToLowerInvariant()) {
            '.html' { 'text/html; charset=utf-8' }
            '.js' { 'application/javascript; charset=utf-8' }
            '.webmanifest' { 'application/manifest+json; charset=utf-8' }
            '.json' { 'application/json; charset=utf-8' }
            '.svg' { 'image/svg+xml' }
            '.png' { 'image/png' }
            '.ico' { 'image/x-icon' }
            '.zip' { 'application/zip' }
            default { 'application/octet-stream' }
        }
        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        if ($asset -eq 'index.html') {
            $page = [System.Text.Encoding]::UTF8.GetString($bytes)
            $page = $page.Replace('__LOCAL_UPDATE_TOKEN__', $updateToken)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($page)
        }
        Send-Response $stream 200 $contentType $bytes
    }
    catch {
        # Einzelne Browser-Verbindungen dürfen den lokalen Server nicht beenden.
        try { if ($null -ne $stream) { Send-JsonError $stream 502 'Lokaler Serverfehler.' } } catch { }
    }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $Client.Close()
    }
}

function Start-ScoutLabWindow {
    $url = "http://127.0.0.1:$port/"
    $edgeCandidates = @()
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    foreach ($base in @($programFilesX86, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace([string]$base)) { continue }
        $edgeCandidates += (Join-Path $base 'Microsoft\Edge\Application\msedge.exe')
        $edgeCandidates += (Join-Path $base 'Google\Chrome\Application\chrome.exe')
    }
    $browser = $edgeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $browser) {
        try { $browser = (Get-Command msedge.exe -ErrorAction Stop).Source } catch { }
    }
    if (-not $browser) {
        try { $browser = (Get-Command chrome.exe -ErrorAction Stop).Source } catch { }
    }
    if ($browser) {
        $profile = Join-Path $env:LOCALAPPDATA 'ScoutLabSports\AppProfile'
        New-Item -ItemType Directory -Path $profile -Force | Out-Null
        $browserArgs = "--app=$url --user-data-dir=`"$profile`" --no-first-run --no-default-browser-check --disable-features=Translate"
        return Start-Process -FilePath $browser -ArgumentList $browserArgs -PassThru
    }
    # Fallback: Standardbrowser öffnen und Helfer im Hintergrund weiterlaufen lassen.
    Start-Process -FilePath $url | Out-Null
    return $null
}

function Test-ExistingScoutLab {
    $probe = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $probe.BeginConnect([System.Net.IPAddress]::Loopback, $port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(500)) { return $false }
        $probe.EndConnect($async)
        $probe.ReceiveTimeout = 700
        $probe.SendTimeout = 700
        $stream = $probe.GetStream()
        $request = [Text.Encoding]::ASCII.GetBytes("GET /health HTTP/1.1`r`nHost: 127.0.0.1`r`nConnection: close`r`n`r`n")
        $stream.Write($request, 0, $request.Length)
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII)
        $status = $reader.ReadLine()
        return ($status -like 'HTTP/1.1 200*')
    } catch { return $false }
    finally { $probe.Close() }
}

try {
    if (Test-ExistingScoutLab) {
        # Eine zweite Verknüpfung startet keinen zweiten Helfer, sondern öffnet nur die App.
        $null = Start-ScoutLabWindow
        return
    }
    $listener.Start()
    Write-ScoutLog 'Lokaler Helfer gestartet.'
    Write-Host 'ScoutLab Sports 0.8.3 – lokaler App- und Datenhelfer läuft.' -ForegroundColor Green
    Write-Host "Appadresse: http://127.0.0.1:$port/"
    Write-Host 'Updatequelle: Updates werden nur nach Bestätigung im App-Fenster installiert.'
    $browserProcess = Start-ScoutLabWindow
    Write-ScoutLog 'App-Fenster gestartet.'
    # Browser-Startprozesse können sich sofort beenden, wenn Edge/Chrome
    # das Fenster an einen bereits laufenden Browserprozess übergibt.
    # Deshalb niemals die Lebensdauer des lokalen Servers an HasExited koppeln.
    while ($listener.Server.IsBound) {
        if ($listener.Pending()) {
            $client = $listener.AcceptTcpClient()
            Handle-Client -Client $client
        } else {
            Start-Sleep -Milliseconds 120
        }
    }
}
catch [System.Net.Sockets.SocketException] {
    Write-ScoutLog ("Socket-/Portfehler: " + $_.Exception.Message)
    Write-Host "Port $port ist belegt oder konnte nicht geöffnet werden. Nutze START_SCOUTLAB_DEBUG.bat für Details." -ForegroundColor Red
}
catch {
    Write-ScoutLog ("Fataler Startfehler: " + $_.Exception.Message)
    Write-Host ("ScoutLab konnte nicht starten: " + $_.Exception.Message) -ForegroundColor Red
}
finally {
    Write-ScoutLog 'Lokaler Helfer beendet.'
    try { $listener.Stop() } catch { }
    $http.Dispose()
}
