[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[ChatGPT Chrome Repair] $Message" -ForegroundColor Cyan
}

function Get-PluginVersion([string]$PluginPath) {
    $manifest = Join-Path $PluginPath '.codex-plugin\plugin.json'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Plugin manifest not found: $manifest"
    }
    return (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).version
}

$app = Get-AppxPackage -Name 'OpenAI.Codex'
if (-not $app) {
    throw 'The OpenAI Codex desktop app is not installed for this Windows user.'
}

$officialRoot = Join-Path $app.InstallLocation 'app\resources\plugins\openai-bundled\plugins'
$cacheBase = Join-Path $env:USERPROFILE '.codex\plugins\cache'
$cacheRoot = Join-Path $cacheBase 'openai-bundled'
$resolvedCacheBase = [System.IO.Path]::GetFullPath($cacheBase)
$resolvedCacheRoot = [System.IO.Path]::GetFullPath($cacheRoot)

if (-not $resolvedCacheRoot.StartsWith($resolvedCacheBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Cache path safety validation failed.'
}

$pluginNames = @('chrome', 'browser')
$officialVersions = @{}

foreach ($name in $pluginNames) {
    $source = Join-Path $officialRoot $name
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Official bundled plugin not found: $source"
    }
    $officialVersions[$name] = Get-PluginVersion $source
}

if ($officialVersions.chrome -ne $officialVersions.browser) {
    throw "Bundled plugin versions differ: chrome=$($officialVersions.chrome), browser=$($officialVersions.browser)"
}

$version = $officialVersions.chrome
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$changed = $false

Write-Step "Codex app version: $($app.Version)"
Write-Step "Bundled browser plugin version: $version"

foreach ($name in $pluginNames) {
    $source = Join-Path $officialRoot $name
    $parent = Join-Path $cacheRoot $name
    $destination = Join-Path $parent $version
    $latest = Join-Path $parent 'latest'
    $currentTarget = $null

    if (Test-Path -LiteralPath $latest) {
        $latestItem = Get-Item -LiteralPath $latest -Force
        $currentTarget = @($latestItem.Target)[0]
    }

    $needsRepair = $Force -or -not (Test-Path -LiteralPath $destination -PathType Container)
    $needsRepair = $needsRepair -or ($currentTarget -ne $destination)

    if (-not $needsRepair) {
        $cachedVersion = Get-PluginVersion $latest
        $needsRepair = ($cachedVersion -ne $version)
    }

    if (-not $needsRepair) {
        Write-Step "$name is already current."
        continue
    }

    Write-Step "Repairing $name..."
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
        Copy-Item -LiteralPath $source -Destination $destination -Recurse
    } else {
        $cachedVersion = Get-PluginVersion $destination
        if ($cachedVersion -ne $version) {
            throw "Existing cache directory has an unexpected version: $destination"
        }
    }

    foreach ($relativePath in @('.codex-plugin\plugin.json', 'scripts\browser-client.mjs')) {
        $officialFile = Join-Path $source $relativePath
        $cachedFile = Join-Path $destination $relativePath
        if (Test-Path -LiteralPath $officialFile -PathType Leaf) {
            $officialHash = (Get-FileHash -LiteralPath $officialFile -Algorithm SHA256).Hash
            $cachedHash = (Get-FileHash -LiteralPath $cachedFile -Algorithm SHA256).Hash
            if ($officialHash -ne $cachedHash) {
                throw "Integrity check failed for $name\$relativePath"
            }
        }
    }

    if (Test-Path -LiteralPath $latest) {
        $backupName = "latest-backup-$stamp"
        Rename-Item -LiteralPath $latest -NewName $backupName
        Write-Step "Backed up the old $name link as $backupName."
    }

    New-Item -ItemType Junction -Path $latest -Target $destination | Out-Null
    $changed = $true
    Write-Step "$name latest now points to $version."
}

if ($changed) {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -in @('extension-host', 'codex-computer-use-swift') } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Step 'Browser-control helper processes were restarted.'
    Write-Host ''
    Write-Host 'Repair completed. Fully restart Codex and Chrome before testing browser control.' -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host 'No repair was needed. The bundled plugins and cache already match.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Version validation' -ForegroundColor White

$appVersionPrefix = (($app.Version.ToString() -split '\.')[0..1] -join '.')
$pluginVersionPrefix = (($version -split '\.')[0..1] -join '.')
$pluginMatchesApp = ($appVersionPrefix -eq $pluginVersionPrefix)
$restartCodex = $false
$restartChrome = $changed

$runningCodex = @(Get-Process -Name 'ChatGPT' -ErrorAction SilentlyContinue)
$oldCodexProcesses = @($runningCodex | Where-Object {
    $_.Path -and -not $_.Path.StartsWith($app.InstallLocation, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($oldCodexProcesses.Count -gt 0) {
    $restartCodex = $true
}

$nativeManifest = Join-Path $env:LOCALAPPDATA 'OpenAI\extension\com.openai.codexextension.json'
$expectedHostSuffix = '.codex\plugins\cache\openai-bundled\chrome\latest\extension-host\windows\x64\extension-host.exe'
$nativeHostValid = $false
if (Test-Path -LiteralPath $nativeManifest -PathType Leaf) {
    $nativeHost = (Get-Content -LiteralPath $nativeManifest -Raw | ConvertFrom-Json).path
    $nativeHostValid = $nativeHost.EndsWith($expectedHostSuffix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $nativeHost -PathType Leaf)
}

$chromeLatest = Join-Path $cacheRoot 'chrome\latest'
$latestWriteTime = (Get-Item -LiteralPath $chromeLatest -Force).LastWriteTime
$activeHosts = @(Get-Process -Name 'extension-host' -ErrorAction SilentlyContinue)
if (@($activeHosts | Where-Object { $_.StartTime -lt $latestWriteTime }).Count -gt 0) {
    $restartChrome = $true
}

$validationRows = @(
    [PSCustomObject]@{ Check = 'Installed Codex'; Result = $app.Version.ToString(); Status = 'OK' }
    [PSCustomObject]@{ Check = 'Bundled plugins'; Result = $version; Status = $(if ($pluginMatchesApp) { 'OK' } else { 'MISMATCH' }) }
    [PSCustomObject]@{ Check = 'Chrome cache latest'; Result = (Get-PluginVersion (Join-Path $cacheRoot 'chrome\latest')); Status = 'OK' }
    [PSCustomObject]@{ Check = 'Browser cache latest'; Result = (Get-PluginVersion (Join-Path $cacheRoot 'browser\latest')); Status = 'OK' }
    [PSCustomObject]@{ Check = 'Native host'; Result = $(if ($nativeHostValid) { 'Uses chrome\latest' } else { 'Missing or stale registration' }); Status = $(if ($nativeHostValid) { 'OK' } else { 'CHECK SETTINGS' }) }
)
$validationRows | Format-Table -AutoSize

if (-not $pluginMatchesApp) {
    Write-Warning "The Codex app ($($app.Version)) and bundled plugin ($version) version families differ. Update or reinstall Codex, then run this script again."
}
if (-not $nativeHostValid) {
    Write-Warning 'The Chrome native-host registration is missing or stale. Reinstall the Chrome connection from Codex Settings > Computer use.'
}
if ($restartCodex) {
    Write-Warning 'An older Codex process is still running. Fully quit Codex, including its tray process, and reopen it.'
}
if ($restartChrome) {
    Write-Warning 'Chrome may still be using the previous browser-control process. Fully quit and reopen Chrome.'
}
if ($pluginMatchesApp -and $nativeHostValid -and -not $restartCodex -and -not $restartChrome) {
    Write-Host 'All version and runtime checks passed.' -ForegroundColor Green
}


