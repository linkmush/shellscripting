<#
hardening_checks.ps1
PowerShell-script för insamling av Windows-data och enkla härdningskontroller.
Kör som Administrator för fullständig data.
#>
param(
    [string]$OutputDir = ".\out",
    [switch]$CollectLogs,
    [switch]$RunChecks
)

function Ensure-OutputDir {
    param($d)
    if (-not (Test-Path -Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

function Is-Administrator {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($current)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Ensure-OutputDir -d $OutputDir
$ts = Get-Date -Format yyyyMMdd_HHmmss
$log = Join-Path $OutputDir "run-$ts.log"
"Run started: $(Get-Date)" | Out-File -FilePath $log -Encoding utf8 -Append

if (-not (Is-Administrator)) {
    "Warning: script not running as Administrator. Some checks may fail or return incomplete data." | Out-File -FilePath $log -Encoding utf8 -Append
}

function Collect-EventLogs {
    param($outdir)
    $secOut = Join-Path $outdir "Security.evtx"
    try {
        wevtutil epl Security $secOut
    } catch {
        "Could not export Security log: $_" | Out-File -FilePath $log -Encoding utf8 -Append
    }
    $sysOut = Join-Path $outdir "System.evtx"
    try { wevtutil epl System $sysOut } catch {}
}

function Get-Installed-Updates {
    param($outdir)
    try {
        Get-HotFix | Select-Object Source, Description, HotFixID, InstalledOn | ConvertTo-Json -Depth 2 | Out-File (Join-Path $outdir "hotfixes.json") -Encoding utf8
    } catch {
        "Get-HotFix failed: $_" | Out-File -FilePath $log -Encoding utf8 -Append
    }
}

function Get-LocalAdmins {
    param($outdir)
    $adminsFile = Join-Path $outdir "local_admins.txt"
    try {
        if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
            Get-LocalGroupMember -Group "Administrators" | Out-File $adminsFile -Encoding utf8
        } else {
            net localgroup Administrators | Out-File $adminsFile -Encoding utf8
        }
    } catch { $_ | Out-File $adminsFile -Encoding utf8 }
}

function Get-FirewallStatus {
    param($outdir)
    try {
        Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | ConvertTo-Json | Out-File (Join-Path $outdir "firewall.json") -Encoding utf8
    } catch { $_ | Out-File -FilePath $log -Encoding utf8 -Append }
}

function Get-AuditPolicy {
    param($outdir)
    try {
        auditpol /get /category:* > (Join-Path $outdir "auditpol.txt")
    } catch { $_ | Out-File -FilePath $log -Encoding utf8 -Append }
}

# Main
if ($CollectLogs) {
    $colDir = Join-Path $OutputDir "col-$(Get-Date -Format yyyyMMdd_HHmmss)"
    Ensure-OutputDir -d $colDir
    Collect-EventLogs -outdir $colDir
    Get-Installed-Updates -outdir $colDir
    Get-LocalAdmins -outdir $colDir
    Get-FirewallStatus -outdir $colDir
    Get-AuditPolicy -outdir $colDir
    "Collected logs and checks into: $colDir" | Out-File -FilePath $log -Encoding utf8 -Append
}

if ($RunChecks) {
    $checkDir = Join-Path $OutputDir "checks"
    Ensure-OutputDir -d $checkDir
    # Exempelkontroller
    try {
        $uac = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction SilentlyContinue
        ($uac.EnableLUA) | Out-File (Join-Path $checkDir "uac.txt") -Encoding utf8
    } catch {}
    try {
        Get-NetFirewallProfile | Out-File (Join-Path $checkDir "firewall-profile.txt") -Encoding utf8
    } catch {}
    "Ran basic checks" | Out-File -FilePath $log -Encoding utf8 -Append
}

# Package results
try {
    $zipName = Join-Path $OutputDir ("results-$ts.zip")
    if (Test-Path $zipName) { Remove-Item $zipName }
    Compress-Archive -Path (Join-Path $OutputDir '*') -DestinationPath $zipName -Force
    "Created archive: $zipName" | Out-File -FilePath $log -Encoding utf8 -Append
} catch {
    "Could not create archive: $_" | Out-File -FilePath $log -Encoding utf8 -Append
}

"Run finished: $(Get-Date)" | Out-File -FilePath $log -Encoding utf8 -Append
