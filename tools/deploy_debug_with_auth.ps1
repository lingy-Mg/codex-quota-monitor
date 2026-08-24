[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Serial,
    [string]$AuthPath = (Join-Path $env:USERPROFILE '.codex\auth.json'),
    [switch]$SkipBuild
)

# This is deliberately a development-only transfer path. It never passes
# credentials in shell arguments, output, logs, or application preferences.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageName = 'com.codexmonitor.tablet'
$apkPath = Join-Path $PSScriptRoot '..\build\app\outputs\flutter-apk\app-debug.apk'
$temporaryRemotePath = '/data/local/tmp/codex-monitor-auth.json'
$privateRemotePath = 'files/.adb-auth-import.json'

function Invoke-AdbQuietly {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & adb -s $Serial @Arguments *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'ADB command failed. Verify the selected device is connected and authorized.'
    }
}

if (-not (Test-Path -LiteralPath $AuthPath -PathType Leaf)) {
    throw 'auth.json was not found at the selected path.'
}

$state = (& adb -s $Serial get-state 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $state -ne 'device') {
    throw 'The selected ADB serial is not an authorized, ready device.'
}

if (-not $SkipBuild) {
    & flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Debug APK build failed.' }
}
if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw 'Debug APK is missing. Run without -SkipBuild first.'
}

Invoke-AdbQuietly install -r $apkPath
try {
    # push keeps token material out of command arguments and console output.
    Invoke-AdbQuietly push $AuthPath $temporaryRemotePath
    # Do not invoke an intermediate shell: some Android builds reset run-as
    # working-directory access for child shells. Direct run-as commands retain
    # the app-private context.
    Invoke-AdbQuietly shell run-as $packageName cp $temporaryRemotePath $privateRemotePath
    Invoke-AdbQuietly shell run-as $packageName chmod 600 $privateRemotePath
} finally {
    # It is safe to attempt cleanup even if the private copy/import failed.
    & adb -s $Serial shell rm -f $temporaryRemotePath *> $null
}

Invoke-AdbQuietly shell am start -n "$packageName/.MainActivity"
Write-Host "Debug build deployed to $Serial. auth.json was staged for one-time secure import."
