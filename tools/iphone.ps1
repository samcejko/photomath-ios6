# Helpers for talking to the jailbroken iPhone (rootless jailbreak: Dopamine, palera1n) over SSH (dot-source this file).
#   . .\tools\iphone.ps1
#   Invoke-IPhone 'uname -a'
#   Install-IPhonePackage -DebPath .\packages\com.samcejko.shuttercalc_1.0.2_iphoneos-arm64.deb   (needs root)
#   Get-IPhoneSnapshot -Name home          # launches the app, asks it for a picture of its windows, fetches the PNG
#   Send-IPhoneCommand 'keyboard'          # one of the app's debug URL commands (see the app delegate)
#   Get-IPhoneCrashLogs

$AppName = 'ShutterCalc'
$AppBundleId = 'com.samcejko.shuttercalc'
$AppUrlScheme = 'shuttercalc'

$script:IPhoneKey = Join-Path $env:USERPROFILE '.ssh\iphone'
$script:IPhoneDefaultHost = '192.168.1.197'
$script:IPhoneUser = 'root'
$script:IPhoneLocalCfg = Join-Path $PSScriptRoot 'local.json'
if (Test-Path $script:IPhoneLocalCfg) {
    try {
        $c = Get-Content $script:IPhoneLocalCfg -Raw | ConvertFrom-Json
        if ($c.iphone) { $script:IPhoneDefaultHost = $c.iphone }
        if ($c.iphoneUser) { $script:IPhoneUser = $c.iphoneUser }
    } catch {}
}
# Preamble of every script: the jailbreak's tools on the PATH; uiopen talks to mobile's SpringBoard, so root runs it as mobile
$script:IPhonePath = @'
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:$PATH
if [ "$(id -u)" = 0 ]; then uiopen() { sudo -n -u mobile /var/jb/usr/bin/uiopen "$@"; }; fi
'@

function Get-IPhoneSshArgs {
    $args = @('-oStrictHostKeyChecking=accept-new', '-oConnectTimeout=10', '-oLogLevel=ERROR', '-oServerAliveInterval=5', '-oServerAliveCountMax=4')
    if (Test-Path $script:IPhoneKey) { $args += @('-i', $script:IPhoneKey, '-oBatchMode=yes') }
    $args
}

function Resolve-IPhoneHost([string]$IPhoneHost) {
    if (-not $IPhoneHost) { $IPhoneHost = $script:IPhoneDefaultHost }
    if (-not $IPhoneHost) { throw 'No iPhone address: pass -IPhoneHost or set "iphone" in tools/local.json' }
    $IPhoneHost
}

function Resolve-IPhoneUser([string]$User) { if ($User) { $User } else { $script:IPhoneUser } }

# Runs one command line on the iPhone and returns stdout+stderr as plain strings (never throws on stderr output).
function Invoke-IPhone {
    param([Parameter(Mandatory = $true)][string]$Command, [string]$IPhoneHost = '', [string]$User = '')
    $ErrorActionPreference = 'Continue'
    $IPhoneHost = Resolve-IPhoneHost $IPhoneHost
    $User = Resolve-IPhoneUser $User
    $sshArgs = Get-IPhoneSshArgs
    & ssh.exe @sshArgs "$User@$IPhoneHost" $Command 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
}

# Runs a whole shell script on the iPhone (sent through stdin, so quotes and $ need no escaping).
function Invoke-IPhoneScript {
    param([Parameter(Mandatory = $true)][string]$Script, [string]$IPhoneHost = '', [string]$User = '')
    $IPhoneHost = Resolve-IPhoneHost $IPhoneHost
    $User = Resolve-IPhoneUser $User
    $tmp = Join-Path $env:TEMP ("iphone-" + [guid]::NewGuid().ToString('n') + ".sh")
    [IO.File]::WriteAllText($tmp, ($script:IPhonePath + "`n" + $Script).Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $keyArg = if (Test-Path $script:IPhoneKey) { "-i `"$($script:IPhoneKey)`" -oBatchMode=yes" } else { '' }
    try {
        cmd /c "ssh $keyArg -oStrictHostKeyChecking=accept-new -oConnectTimeout=10 -oLogLevel=ERROR $User@$IPhoneHost sh -s < `"$tmp`" 2>&1" | ForEach-Object { "$_" }
    } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

function Copy-ToIPhone {
    param([Parameter(Mandatory = $true)][string]$LocalPath, [Parameter(Mandatory = $true)][string]$RemotePath, [string]$IPhoneHost = '', [string]$User = '')
    $ErrorActionPreference = 'Continue'
    $IPhoneHost = Resolve-IPhoneHost $IPhoneHost
    $User = Resolve-IPhoneUser $User
    $sshArgs = Get-IPhoneSshArgs
    & scp.exe -O @sshArgs $LocalPath "${User}@${IPhoneHost}:$RemotePath" 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    if ($LASTEXITCODE -ne 0) { throw "scp failed for $LocalPath" }
}

function Copy-FromIPhone {
    param([Parameter(Mandatory = $true)][string]$RemotePath, [Parameter(Mandatory = $true)][string]$LocalPath, [string]$IPhoneHost = '', [string]$User = '')
    $ErrorActionPreference = 'Continue'
    $IPhoneHost = Resolve-IPhoneHost $IPhoneHost
    $User = Resolve-IPhoneUser $User
    $sshArgs = Get-IPhoneSshArgs
    & scp.exe -O @sshArgs -r "${User}@${IPhoneHost}:$RemotePath" $LocalPath 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    if ($LASTEXITCODE -ne 0) { throw "scp failed for $RemotePath" }
}

# Installs the arm64 .deb (rootless: /var/jb) with dpkg and tells the home screen about it.
function Install-IPhonePackage {
    param([Parameter(Mandatory = $true)][string]$DebPath, [string]$IPhoneHost = '')
    if (-not (Test-Path $DebPath)) { throw "no such file: $DebPath" }
    $IPhoneHost = Resolve-IPhoneHost $IPhoneHost
    $who = Invoke-IPhone -IPhoneHost $IPhoneHost -Command 'id -u' | Select-Object -Last 1
    if ("$who" -match 'ssh:|Connection|refused|timed out|denied') { throw "cannot reach $IPhoneHost over SSH ($("$who".Trim())): is the phone awake and on the Wi-Fi?" }
    if ("$who".Trim() -ne '0') { throw "Install-IPhonePackage needs root on the phone (got uid '$who')" }
    $remote = "/tmp/$($AppName.ToLower()).deb"
    Write-Host "Installing $DebPath on $IPhoneHost ..."
    Copy-ToIPhone -IPhoneHost $IPhoneHost -LocalPath $DebPath -RemotePath $remote
    $out = Invoke-IPhoneScript -IPhoneHost $IPhoneHost -Script @"
killall $AppName 2>/dev/null
dpkg -i $remote 2>&1 && { uicache -p /var/jb/Applications/$AppName.app 2>/dev/null || uicache -a 2>/dev/null; echo DEB_OK; }
rm -f $remote
"@
    Write-Host ($out -join "`n")
    if (($out -join "`n") -notmatch 'DEB_OK') { throw 'dpkg failed' }
    Write-Host "Done. Launch with Start-IPhoneApp."
}

# The app's data container
function Get-IPhoneContainer {
    param([string]$IPhoneHost = '')
    $out = Invoke-IPhoneScript -IPhoneHost $IPhoneHost -Script @"
c=`$(uicache -i $AppBundleId 2>/dev/null | sed -n 's/^Container Path: //p')
if [ -n "`$c" ] && [ -d "`$c" ]; then echo "`$c"; else
  for d in /var/mobile/Containers/Data/Application/*; do
    grep -q '$AppBundleId' "`$d/.com.apple.mobile_container_manager.metadata.plist" 2>/dev/null && echo "`$d"
  done
fi
"@
    "$(@($out | Where-Object { $_ -like '/var/mobile/*' -or $_ -like '/private/var/mobile/*' } | Select-Object -Last 1))".Trim()
}

function Start-IPhoneApp {
    param([string]$IPhoneHost = '', [int]$WaitSeconds = 4)
    Invoke-IPhoneScript -IPhoneHost $IPhoneHost -Script "uiopen --bundleid $AppBundleId; sleep $WaitSeconds; ps -A -o pid,rss,comm | grep '/$AppName.app/' | grep -v grep || echo 'NOT RUNNING'"
}

function Stop-IPhoneApp { param([string]$IPhoneHost = '') Invoke-IPhone -IPhoneHost $IPhoneHost -Command "killall $AppName 2>/dev/null; echo stopped" }

function Test-IPhoneAppRunning {
    param([string]$IPhoneHost = '')
    $out = Invoke-IPhone -IPhoneHost $IPhoneHost -Command "ps -A -o comm | grep '/$AppName.app/' | grep -v grep | head -n 1"
    [bool](($out -join '') -match [regex]::Escape("$AppName.app"))
}

# Sends one of the app's URL commands, e.g. 'snapshot', 'keyboard', 'settings'
function Send-IPhoneCommand {
    param([Parameter(Mandatory = $true)][string]$Command, [string]$IPhoneHost = '', [int]$WaitSeconds = 2)
    if (-not $AppUrlScheme) { throw "$AppName has no URL scheme" }
    Invoke-IPhoneScript -IPhoneHost $IPhoneHost -Script "uiopen --url '${AppUrlScheme}:$Command'; sleep $WaitSeconds; echo sent"
}

# Fetches snapshot PNG from container/tmp/screen.png
function Get-IPhoneSnapshot {
    param([string]$Name = 'shot', [string]$IPhoneHost = '', [string]$OutDir = '', [switch]$NoLaunch)
    if (-not $AppUrlScheme) { throw "$AppName has no URL scheme, so no snapshot command" }
    if (-not $OutDir) { $OutDir = Join-Path (Get-Location) 'packages\shots-iphone' }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    if (-not $NoLaunch -and -not (Test-IPhoneAppRunning -IPhoneHost $IPhoneHost)) {
        $null = Start-IPhoneApp -IPhoneHost $IPhoneHost -WaitSeconds 4
    }
    $container = Get-IPhoneContainer -IPhoneHost $IPhoneHost
    if (-not $container) { throw "no data container for ${AppBundleId}: the app did not launch" }
    $out = Invoke-IPhoneScript -IPhoneHost $IPhoneHost -Script @"
rm -f '$container/tmp/screen.png'
uiopen --url '${AppUrlScheme}:snapshot'
i=0; while [ `$i -lt 20 ] && [ ! -f '$container/tmp/screen.png' ]; do sleep 0.25; i=`$((i+1)); done
sleep 0.5
ls -la '$container/tmp/screen.png' 2>&1
"@
    $local = Join-Path $OutDir "$Name.png"
    Remove-Item $local -ErrorAction SilentlyContinue
    if (($out -join '') -notmatch 'screen\.png' -or ($out -join '') -match 'No such file') { throw "no snapshot written: $($out -join ' | ')" }
    Copy-FromIPhone -IPhoneHost $IPhoneHost -RemotePath "$container/tmp/screen.png" -LocalPath $local
    Get-Item $local
}
