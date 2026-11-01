# OceanCleaner v1.1 - Residue reduction for DoomsDay / Ghost clients vs Ocean
# Developed by bruta / D3F4ULT
# Prefetch left intact (operator preference)
# Lab / educational use only. Run elevated.
# Usage: powershell -ExecutionPolicy Bypass -File OceanCleaner.ps1 [-Deep] [-Silent]

param(
    [switch]$Deep,
    [switch]$Silent,
    [string]$ClientName = "DoomsDay"
)

$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "System Maintenance"

function Write-Status($msg, $color = "Cyan") {
    if (-not $Silent) { Write-Host "[*] $msg" -ForegroundColor $color }
}
function Write-Ok($msg) {
    if (-not $Silent) { Write-Host "[+] $msg" -ForegroundColor Green }
}
function Write-Warn($msg) {
    if (-not $Silent) { Write-Host "[!] $msg" -ForegroundColor Yellow }
}

# ============================================================
# Kill leftover injectors / loaders (never kill clean javaw)
# ============================================================
function Kill-LeftoverProcesses {
    Write-Status "Killing leftover injector / loader processes..."
    $killed = 0
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $pn = $_.ProcessName.ToLower()
        if ($pn -match "^(doomsday|injector|loader|ghost|cheat|hack)") {
            try {
                Stop-Process -Id $_.Id -Force -ErrorAction Stop
                $killed++
            } catch {}
        }
        elseif ($pn -eq "java" -or $pn -eq "javaw") {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
                if ($cmd -and $cmd -match "(?i)(dooms|inject|ghost|cheat|hack|client\.jar|agent)") {
                    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
                    $killed++
                }
            } catch {}
        }
    }
    Write-Ok "Processes terminated: $killed"
}

# ============================================================
# Recent / JumpLists / AutomaticDestinations
# ============================================================
function Clear-Recent {
    Write-Status "Clearing Recent + Jump Lists..."
    $paths = @(
        "$env:APPDATA\Microsoft\Windows\Recent",
        "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
        "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
    )
    $count = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop
                    $count++
                } catch {}
            }
        }
    }
    Write-Ok "Recent / JumpList items cleared: $count"
}

# ============================================================
# Temp
# ============================================================
function Clear-Temp {
    Write-Status "Purging temp directories..."
    $temps = @($env:TEMP, $env:TMP, "$env:LOCALAPPDATA\Temp", "$env:SystemRoot\Temp")
    $count = 0
    foreach ($t in $temps) {
        if (Test-Path $t) {
            Get-ChildItem $t -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop
                    $count++
                } catch {}
            }
        }
    }
    Write-Ok "Temp items removed: $count"
}

# ============================================================
# UserAssist + RunMRU
# ============================================================
function Clear-UserAssist {
    Write-Status "Wiping UserAssist + RunMRU..."
    $count = 0
    $ua = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
    if (Test-Path $ua) {
        Get-ChildItem $ua -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction Stop
                $count++
            } catch {}
        }
    }
    $runmru = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    if (Test-Path $runmru) {
        Remove-ItemProperty -Path $runmru -Name "*" -ErrorAction SilentlyContinue
        $count++
    }
    Write-Ok "UserAssist / RunMRU cleaned: $count"
}

# ============================================================
# AppCompat / Layers (Shim-related)
# ============================================================
function Clear-ShimHints {
    Write-Status "Clearing AppCompat / Layers hints..."
    $keys = @(
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    )
    $count = 0
    foreach ($k in $keys) {
        if (Test-Path $k) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
                $name = $_.PSChildName
                if ($name -match "(?i)(java|javaw|dooms|doom|inject|ghost|cheat|hack|client|minecraft)") {
                    try {
                        Remove-Item $_.PSPath -Force -ErrorAction Stop
                        $count++
                    } catch {}
                }
            }
        }
    }
    Write-Ok "AppCompat entries scrubbed: $count"
}

# ============================================================
# BAM (Background Activity Moderator) - execution traces
# ============================================================
function Clear-BAM {
    Write-Status "Clearing BAM execution traces..."
    $bam = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    $count = 0
    if (Test-Path $bam) {
        Get-ChildItem $bam -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props) {
                $props.PSObject.Properties | Where-Object {
                    $_.Name -match "(?i)(dooms|doom|inject|ghost|cheat|hack|client|java|javaw)" -and
                    $_.Name -notmatch "^(PSPath|PSParentPath|PSChildName|PSDrive|PSProvider)$"
                } | ForEach-Object {
                    try {
                        Remove-ItemProperty -Path $props.PSPath -Name $_.Name -Force -ErrorAction Stop
                        $count++
                    } catch {}
                }
            }
        }
    }
    Write-Ok "BAM entries removed: $count"
}

# ============================================================
# Browser history note
# ============================================================
function Clear-BrowserTraces {
    Write-Status "Checking browser history presence..."
    $found = @()
    if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History") { $found += "Chrome" }
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History") { $found += "Edge" }
    $ff = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ff) {
        Get-ChildItem $ff -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if (Test-Path "$($_.FullName)\places.sqlite") { $found += "Firefox" }
        }
    }
    if ($found.Count -gt 0) {
        Write-Warn "Browser history DBs present ($($found -join ', ')). Manually clear downloads of client sites before SS."
    } else {
        Write-Ok "No common browser history DBs detected"
    }
}

# ============================================================
# Recycle Bin
# ============================================================
function Clear-RecycleBin {
    Write-Status "Emptying Recycle Bin..."
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Ok "Recycle Bin emptied"
    } catch {
        $shell = New-Object -ComObject Shell.Application
        $shell.NameSpace(0xA).Items() | ForEach-Object {
            Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Ok "Recycle Bin force-cleared"
    }
}

# ============================================================
# Minecraft residue
# ============================================================
function Clear-MinecraftResidue {
    Write-Status "Cleaning .minecraft residue..."
    $mc = "$env:APPDATA\.minecraft"
    if (-not (Test-Path $mc)) {
        Write-Warn ".minecraft not found"
        return
    }
    $count = 0
    if (Test-Path "$mc\logs") {
        Get-ChildItem "$mc\logs" -Filter "*.log*" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Set-Content $_.FullName -Value "" -Force
                $count++
            } catch {}
        }
    }
    $mods = "$mc\mods"
    if (Test-Path $mods) {
        Get-ChildItem $mods -Filter "*.jar" -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.Name.ToLower()
            if ($n -match "(dooms|doom|ghost|inject|cheat|hack|vape|wurst|meteor|impact|aristois|sigma|liquidbounce)") {
                try {
                    Remove-Item $_.FullName -Force
                    $count++
                    Write-Ok "Removed suspicious mod: $($_.Name)"
                } catch {}
            }
        }
    }
    if (Test-Path "$mc\crash-reports") {
        Get-ChildItem "$mc\crash-reports" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force
                $count++
            } catch {}
        }
    }
    Write-Ok "Minecraft residue cleaned: $count items"
}

# ============================================================
# ActivitiesCache
# ============================================================
function Clear-ActivitiesCache {
    Write-Status "Clearing ActivitiesCache (Timeline)..."
    $ac = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"
    $count = 0
    if (Test-Path $ac) {
        Get-ChildItem $ac -Recurse -Filter "*ActivitiesCache*" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                $count++
            } catch {}
        }
    }
    Write-Ok "ActivitiesCache items removed: $count"
}

# ============================================================
# Self-delete
# ============================================================
function Self-Clean {
    Write-Status "Scheduling self-removal..."
    $scriptPath = $MyInvocation.PSCommandPath
    if ($scriptPath -and (Test-Path $scriptPath)) {
        Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command `"Start-Sleep 4; Remove-Item -LiteralPath '$scriptPath' -Force -ErrorAction SilentlyContinue`"" -WindowStyle Hidden
        Write-Ok "Self-delete scheduled"
    }
}

# ============================================================
# MAIN
# ============================================================
Write-Host ""
Write-Host "  OceanCleaner v1.1  |  bruta / D3F4ULT" -ForegroundColor DarkCyan
Write-Host "  Residue reduction for ghost clients (Prefetch left intact)" -ForegroundColor DarkGray
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator. BAM + some registry keys will be incomplete."
    Write-Warn "Re-run elevated for full coverage."
}

Kill-LeftoverProcesses
Clear-Recent
Clear-Temp
Clear-UserAssist
Clear-ShimHints
if ($isAdmin) { Clear-BAM }
Clear-BrowserTraces
Clear-RecycleBin
Clear-MinecraftResidue
Clear-ActivitiesCache

if ($Deep) {
    Write-Status "Deep mode: Application event log..."
    try {
        wevtutil cl Application 2>$null
        Write-Ok "Application event log cleared"
    } catch {
        Write-Warn "Could not clear event log (need Admin)"
    }
}

Write-Host ""
Write-Ok "Scrub complete."
Write-Host ""
Write-Host "  Ocean still sees: Prefetch (left intact), Amcache, memory, RUIN." -ForegroundColor DarkGray
Write-Host "  Best results: unload client + this scrub + clean instance + reboot if time." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Recommended flow before SS:" -ForegroundColor DarkGray
Write-Host "  1. Self-destruct / unload DoomsDay completely" -ForegroundColor DarkGray
Write-Host "  2. Close Minecraft" -ForegroundColor DarkGray
Write-Host "  3. Run this script elevated" -ForegroundColor DarkGray
Write-Host "  4. Launch clean vanilla / Lunar / Feather only" -ForegroundColor DarkGray
Write-Host "  5. Run Ocean pin from the clean instance" -ForegroundColor DarkGray
Write-Host ""

if (-not $Silent) {
    Self-Clean
}
