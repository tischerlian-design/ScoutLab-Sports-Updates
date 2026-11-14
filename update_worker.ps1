param(
    [Parameter(Mandatory=$true)][string]$Repo,
    [Parameter(Mandatory=$true)][string]$Branch
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$progressPath = Join-Path $root '.update-progress.json'
$stage = Join-Path $root ('.update-staging-' + [Guid]::NewGuid().ToString('N'))
$allowedFiles = @('index.html','broadcast_rights_database.json','sw.js','manifest.webmanifest','server.ps1','update_worker.ps1','app-icon.svg','app-icon-192.png','app-icon-512.png','app-icon.ico','START_SCOUTLAB.vbs','INSTALL_SCOUTLAB.vbs','START_SCOUTLAB.bat','START_BROWSER.bat','INSTALL_SCOUTLAB.bat','CREATE_SHORTCUTS.ps1','START_SCOUTLAB_DEBUG.bat','README_DE.txt','MAKE_UPDATE_MANIFEST.ps1','PUBLISH_UPDATE.bat')
$http = $null
function Set-Progress {
    param([string]$State,[int]$Percent,[string]$Message,[string]$CurrentFile='',[int]$FilesDone=0,[int]$FilesTotal=0,[string]$Version='',[bool]$RestartRequired=$false)
    $payload = @{ state=$State; percent=[Math]::Max(0,[Math]::Min(100,$Percent)); message=$Message; currentFile=$CurrentFile; filesDone=$FilesDone; filesTotal=$FilesTotal; version=$Version; restartRequired=$RestartRequired; updatedAt=(Get-Date).ToString('o') }
    $json = $payload | ConvertTo-Json -Compress
    $tmp = $progressPath + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($tmp,$json,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $progressPath -Force
}
try {
    if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or $Branch -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Die Updatequelle enthält ungültige Angaben.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.Net.Http
    $http = [System.Net.Http.HttpClient]::new()
    $http.Timeout = [TimeSpan]::FromMinutes(3)
    $http.DefaultRequestHeaders.UserAgent.ParseAdd('ScoutLabSports/0.8.1 (in-app updater)')
    Set-Progress 'starting' 1 'Update-Manifest wird abgerufen …'
    $manifestUrl = "https://raw.githubusercontent.com/$Repo/$Branch/update-manifest.json?ts=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    $manifestJson = $http.GetStringAsync($manifestUrl).GetAwaiter().GetResult()
    $manifest = $manifestJson | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$manifest.version) -or $null -eq $manifest.files) { throw 'Das Update-Manifest hat ein ungültiges Format.' }
    $version = [string]$manifest.version
    try { $remoteVersion=[version]$version; $localJson=Get-Content -LiteralPath (Join-Path $root 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json; $localVersion=[version]$localJson.version } catch { throw 'Die Versionsnummer im Update-Manifest oder in version.json ist ungültig.' }
    if ($remoteVersion -le $localVersion) { Set-Progress 'completed' 100 'ScoutLab ist bereits aktuell.' '' 0 0 $version $false; exit 0 }
    $files = @($manifest.files)
    if ($files.Count -lt 4 -or $files.Count -gt $allowedFiles.Count) { throw 'Das Update-Manifest enthält eine unzulässige Anzahl Dateien.' }
    $names = @(); foreach($f in $files){$name=[string]$f.name;if($allowedFiles -notcontains $name){throw "Datei '$name' ist für Updates nicht freigegeben."};if($names -contains $name){throw "Datei '$name' steht doppelt im Update-Manifest."};if(([string]$f.sha256) -notmatch '^[A-Fa-f0-9]{64}$'){throw "SHA-256-Prüfsumme für '$name' fehlt oder ist ungültig."};$names += $name}
    foreach($required in @('index.html','broadcast_rights_database.json','server.ps1','update_worker.ps1')){if($names -notcontains $required){throw "Das Update-Manifest enthält die Pflichtdatei '$required' nicht."}}
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $totalBytes=0L; $done=0; $lastProgress=0
    foreach($file in $files){
        $name=[string]$file.name
        $url="https://raw.githubusercontent.com/$Repo/$Branch/$name"
        $response=$http.GetAsync($url,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            $response.EnsureSuccessStatusCode()
            $length=$response.Content.Headers.ContentLength
            if($null -ne $length -and $length -gt 12MB){throw "Datei '$name' überschreitet 12 MB."}
            $source=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $destPath=Join-Path $stage $name
            $target=[IO.File]::Create($destPath)
            try {
                $buffer=New-Object byte[] 65536; $read=0; $received=0L; $lastTick=[DateTime]::UtcNow
                while(($read=$source.Read($buffer,0,$buffer.Length)) -gt 0){
                    $target.Write($buffer,0,$read);$received += $read;$totalBytes += $read
                    if($totalBytes -gt 24MB){throw 'Das Update überschreitet die maximale Gesamtgröße von 24 MB.'}
                    $within=if($length -and $length -gt 0){[Math]::Min(1.0,$received/[double]$length)}else{0.5}
                    $pct=5+[int](84*(($done+$within)/[double]$files.Count))
                    if(([DateTime]::UtcNow-$lastTick).TotalMilliseconds -ge 250){Set-Progress 'downloading' $pct "Lade $name herunter …" $name $done $files.Count $version $false;$lastTick=[DateTime]::UtcNow}
                }
                $target.Flush()
            } finally { $target.Dispose();$source.Dispose() }
            $hash=(Get-FileHash -LiteralPath $destPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if($hash -ne ([string]$file.sha256).ToLowerInvariant()){throw "Prüfsummenfehler bei '$name'. Das Update wurde nicht installiert."}
        } finally { $response.Dispose() }
        $done++;$pct=5+[int](84*($done/[double]$files.Count));Set-Progress 'verifying' $pct "Datei geprüft: $name" $name $done $files.Count $version $false
    }
    $restartRequired=$false
    if($names -contains 'server.ps1'){
        $localServer=Join-Path $root 'server.ps1';$stagedServer=Join-Path $stage 'server.ps1'
        if((Test-Path -LiteralPath $localServer) -and (Test-Path -LiteralPath $stagedServer)){
            $localServerHash=(Get-FileHash -LiteralPath $localServer -Algorithm SHA256).Hash
            $stagedServerHash=(Get-FileHash -LiteralPath $stagedServer -Algorithm SHA256).Hash
            $restartRequired=($localServerHash -ne $stagedServerHash)
        } else { $restartRequired=$true }
    }
    Set-Progress 'installing' 92 'Geprüfte Dateien werden installiert …' '' $done $files.Count $version $restartRequired
    $applied=@()
    try {
        foreach($name in $names){
            $destination=Join-Path $root $name;$backup=$destination+'.scoutlab-backup'
            if(Test-Path -LiteralPath $backup){Remove-Item -LiteralPath $backup -Force}
            $hadOriginal=Test-Path -LiteralPath $destination
            if($hadOriginal){Move-Item -LiteralPath $destination -Destination $backup -Force}
            try {Move-Item -LiteralPath (Join-Path $stage $name) -Destination $destination -Force;$applied += [pscustomobject]@{name=$name;hadOriginal=$hadOriginal}}
            catch {if($hadOriginal -and (Test-Path -LiteralPath $backup)){Move-Item -LiteralPath $backup -Destination $destination -Force};throw}
        }
        $versionJson=@{version=$version;updatedAt=(Get-Date).ToString('o')}|ConvertTo-Json -Compress
        [IO.File]::WriteAllText((Join-Path $root 'version.json'),$versionJson,[Text.UTF8Encoding]::new($false))
        foreach($item in $applied){$backup=(Join-Path $root $item.name)+'.scoutlab-backup';if(Test-Path -LiteralPath $backup){Remove-Item -LiteralPath $backup -Force}}
    } catch {
        for($i=$applied.Count-1;$i -ge 0;$i--){$item=$applied[$i];$destination=Join-Path $root $item.name;$backup=$destination+'.scoutlab-backup';if(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination -Force};if($item.hadOriginal -and (Test-Path -LiteralPath $backup)){Move-Item -LiteralPath $backup -Destination $destination -Force}}
        throw
    }
    Set-Progress 'completed' 100 "ScoutLab $version wurde installiert." '' $done $files.Count $version $restartRequired
} catch {
    try { Set-Progress 'failed' 0 $_.Exception.Message '' 0 0 '' $false } catch { }
} finally {
    if($null -ne $http){$http.Dispose()}
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
}
