#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    RTX 3070 + Ryzen 9 5950X - One-Click Optimizer (Version Modifiée)
.DESCRIPTION
    Optimisation automatique Performance + Silence
    avec options supplémentaires : SilentFactor, AggressiveSilence, rollback PowerLimit,
    génération d'un fichier d'aide MSI Afterburner, avertissements P0.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Revert,
    [switch]$MaxPerf,          # Power limit GPU au maximum
    [switch]$ForceP0,          # Force P0 permanent sur le GPU (option explicite)
    [double]$SilentFactor = 0.92,  # Facteur appliqué à MaxLimit pour mode silence (0.0-1.0)
    [switch]$AggressiveSilence,     # Réduit davantage les ressources CPU au repos
    [string]$BackupPath = "$env:ProgramData\RTX3070-5950X-Optimizer"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------
$StateDir    = $BackupPath
$StateFile   = Join-Path $StateDir 'state.json'
$LogFile     = Join-Path $StateDir "log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$GraphicsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$ClassKey    = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'

# ----------------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR','STEP')]
        [string]$Level = 'INFO'
    )
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'STEP'  { 'Cyan' }
        default { 'White' }
    }
    $prefix = switch ($Level) {
        'OK'    { '[OK]   ' }
        'WARN'  { '[WARN] ' }
        'ERROR' { '[ERR]  ' }
        'STEP'  { '[>>]   ' }
        default { '[INFO] ' }
    }
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $prefix$Message"
    Write-Host $line -ForegroundColor $color
    if (Test-Path $StateDir) {
        Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
    }
}

function Set-RegDword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
}

function Get-NvidiaSmi {
    $cmd = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
        "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
        "$env:WINDIR\System32\nvidia-smi.exe"
    )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-NvidiaGpu {
    $smi = Get-NvidiaSmi
    if (-not $smi) { return $null }
    try {
        $raw = & $smi --query-gpu=name,driver_version,power.limit,power.default_limit,power.max_limit,temperature.gpu,clocks.gr --format=csv,noheader,nounits 2>$null
        if (-not $raw) { return $null }
        $p = ($raw | Select-Object -First 1) -split '\s*,\s*'
        [PSCustomObject]@{
            Name          = $p[0].Trim()
            Driver        = $p[1].Trim()
            PowerLimit    = [double]$p[2]
            DefaultLimit  = [double]$p[3]
            MaxLimit      = [double]$p[4]
            Temperature   = [double]$p[5]
            GraphicsClock = [double]$p[6]
            Smi           = $smi
        }
    } catch {
        return $null
    }
}

function Get-State {
    if (Test-Path $StateFile) {
        try {
            $obj = Get-Content $StateFile -Raw | ConvertFrom-Json
            foreach ($prop in @('Timestamp','HAGS','Msi','GameBar','PowerPlan','PowerLimit','P0','Cpu')) {
                if (-not ($obj.PSObject.Properties.Name -contains $prop)) {
                    $obj | Add-Member -NotePropertyName $prop -NotePropertyValue $null -Force
                }
            }
            return $obj
        } catch {
            Write-Log 'État précédent corrompu → nouvelle sauvegarde.' 'WARN'
        }
    }

    return [PSCustomObject]@{
        Timestamp  = $null
        HAGS       = $null
        Msi        = @()
        GameBar    = @()
        PowerPlan  = $null
        PowerLimit = $null
        P0         = @()
        Cpu        = @{}
    }
}

function Save-State {
    param($State)
    if (-not (Test-Path $StateDir)) {
        New-Item -Path $StateDir -ItemType Directory -Force | Out-Null
    }
    $State.Timestamp = Get-Date -Format 's'
    $State | ConvertTo-Json -Depth 6 | Set-Content -Path $StateFile -Encoding utf8
}

# ----------------------------------------------------------------------
# GPU
# ----------------------------------------------------------------------
function Enable-HAGS {
    param($State)
    Write-Log 'Activation de Hardware-Accelerated GPU Scheduling (HAGS)...' 'STEP'
    $existing = $null
    try { $existing = (Get-ItemProperty $GraphicsKey -Name HwSchMode -ErrorAction Stop).HwSchMode } catch {}
    Set-RegDword -Path $GraphicsKey -Name 'HwSchMode' -Value 2
    Write-Log 'HAGS activé (réduit la latence CPU↔GPU)' 'OK'
    $State | Add-Member -NotePropertyName 'HAGS' -NotePropertyValue @{ Previous = $existing } -Force
    return $State
}

function Enable-MSI {
    param($State)
    Write-Log 'Activation du mode MSI sur le GPU (réduit la latence des interruptions)...' 'STEP'
    $devices = @(Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue |
                 Where-Object { $_.FriendlyName -match 'NVIDIA' })
    $entries = @()
    foreach ($dev in $devices) {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $existing = $null
        try { $existing = (Get-ItemProperty $path -Name MSISupported -ErrorAction Stop).MSISupported } catch {}
        Set-RegDword -Path $path -Name 'MSISupported' -Value 1
        $entries += @{ Path = $path; Previous = $existing }
        Write-Log "MSI activé sur : $($dev.FriendlyName)" 'OK'
    }
    if ($entries.Count -eq 0) {
        Write-Log 'Aucun GPU NVIDIA trouvé pour MSI' 'WARN'
    }
    $State | Add-Member -NotePropertyName 'Msi' -NotePropertyValue $entries -Force
    return $State
}

function Disable-GameBar {
    param($State)
    Write-Log 'Désactivation de Xbox Game Bar / Game DVR (réduit l''overhead)...' 'STEP'
    $targets = @(
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR' }
    )
    $entries = @()
    foreach ($t in $targets) {
        $existing = $null
        try { $existing = (Get-ItemProperty $t.Path -Name $t.Name -ErrorAction Stop).($t.Name) } catch {}
        Set-RegDword -Path $t.Path -Name $t.Name -Value 0
        $entries += @{ Path = $t.Path; Name = $t.Name; Previous = $existing }
    }
    Write-Log 'Game Bar / Game DVR désactivés' 'OK'
    $State | Add-Member -NotePropertyName 'GameBar' -NotePropertyValue $entries -Force
    return $State
}

function Set-PowerPlan {
    param($State)
    Write-Log 'Configuration du plan d''alimentation High Performance...' 'STEP'
    $high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $current = powercfg /getactivescheme 2>$null
    $prevGuid = [regex]::Match(($current | Out-String), '[0-9a-fA-F-]{36}').Value

    powercfg /setactive $high | Out-Null
    powercfg /setacvalueindex $high SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null
    powercfg /setacvalueindex $high SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null

    try {
        powercfg /setacvalueindex $high SUB_PCIEXPRESS ASPM 0 2>$null | Out-Null
        Write-Log 'PCIe ASPM désactivé (meilleure réactivité)' 'OK'
    } catch {
        Write-Log 'PCIe ASPM non modifiable sur ce système (normal)' 'WARN'
    }

    powercfg /setactive $high | Out-Null
    Write-Log 'Plan High Performance activé' 'OK'
    $State | Add-Member -NotePropertyName 'PowerPlan' -NotePropertyValue @{ Previous = $prevGuid } -Force
    return $State
}

function Set-PowerLimit {
    param($State)
    Write-Log 'Optimisation du Power Limit GPU...' 'STEP'
    $gpu = Get-NvidiaGpu
    if (-not $gpu) {
        Write-Log 'nvidia-smi introuvable → Power Limit non modifié' 'WARN'
        return $State
    }

    Write-Log "GPU détecté : $($gpu.Name)" 'INFO'
    Write-Log "Pilote      : $($gpu.Driver)" 'INFO'
    Write-Log "Power Limit actuel : $($gpu.PowerLimit) W | Défaut : $($gpu.DefaultLimit) W | Max : $($gpu.MaxLimit) W" 'INFO'
    Write-Log "Température : $($gpu.Temperature)°C | Clock : $($gpu.GraphicsClock) MHz" 'INFO'

    # Calcul de la cible selon SilentFactor ou MaxPerf
    if ($MaxPerf) {
        $target = [math]::Round($gpu.MaxLimit)
    } else {
        if ($SilentFactor -le 0 -or $SilentFactor -gt 1) {
            Write-Log "SilentFactor invalide ($SilentFactor) → utilisation de 0.92 par défaut" 'WARN'
            $SilentFactor = 0.92
        }
        $target = [math]::Round($gpu.MaxLimit * $SilentFactor)
    }

    if ($gpu.PowerLimit -ge ($target - 0.5)) {
        Write-Log "Power Limit déjà optimal ($($gpu.PowerLimit) W)" 'OK'
        return $State
    }

    Write-Log "Application du Power Limit → $target W..." 'STEP'
    & $gpu.Smi -pl $target 2>&1 | ForEach-Object { Write-Log "$_" 'INFO' }

    # Vérification simple et rollback si nécessaire
    Start-Sleep -Seconds 5
    $gpu2 = Get-NvidiaGpu
    if (-not $gpu2) {
        Write-Log 'Impossible de relire l''état GPU après modification → rollback au défaut' 'WARN'
        & $gpu.Smi -pl $gpu.DefaultLimit 2>&1 | ForEach-Object { Write-Log "$_" 'INFO' }
        return $State
    }

    if ([math]::Round($gpu2.PowerLimit) -ne $target) {
        Write-Log 'Échec application PowerLimit ou pilote a refusé → rollback au défaut' 'WARN'
        & $gpu.Smi -pl $gpu.DefaultLimit 2>&1 | ForEach-Object { Write-Log "$_" 'INFO' }
        $State | Add-Member -NotePropertyName 'PowerLimit' -NotePropertyValue @{
            Previous = $gpu.PowerLimit
            Attempted = $target
            Applied = $gpu.DefaultLimit
            Note = 'Rollback'
        } -Force
    } else {
        Write-Log "Power Limit configuré à $target W" 'OK'
        $State | Add-Member -NotePropertyName 'PowerLimit' -NotePropertyValue @{
            Previous = $gpu.PowerLimit
            Applied  = $target
        } -Force
    }
    return $State
}

function Remove-P0Tweak {
    Write-Log 'Recherche d''anciens tweaks P0 (DisableDynamicPstate)...' 'STEP'
    $found = $false
    $subkeys = Get-ChildItem -Path $ClassKey -ErrorAction SilentlyContinue
    foreach ($key in $subkeys) {
        try {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
            if ($props.PSObject.Properties.Name -contains 'DriverDesc' -and
                $props.DriverDesc -match 'NVIDIA' -and
                $props.PSObject.Properties.Name -contains 'DisableDynamicPstate') {
                Remove-ItemProperty -Path $key.PSPath -Name 'DisableDynamicPstate' -ErrorAction SilentlyContinue
                Write-Log "Ancien DisableDynamicPstate supprimé ($($key.PSChildName))" 'OK'
                $found = $true
            }
        } catch {}
    }
    if (-not $found) {
        Write-Log 'Aucun tweak P0 résiduel trouvé' 'OK'
    }
}

function Enable-P0 {
    param($State)
    Write-Log 'Activation forcée du P0 (DisableDynamicPstate)...' 'STEP'
    $entries = @()
    $subkeys = Get-ChildItem -Path $ClassKey -ErrorAction SilentlyContinue
    foreach ($key in $subkeys) {
        try {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
            if ($props.PSObject.Properties.Name -contains 'DriverDesc' -and $props.DriverDesc -match 'NVIDIA') {
                $existing = $null
                if ($props.PSObject.Properties.Name -contains 'DisableDynamicPstate') {
                    $existing = $props.DisableDynamicPstate
                }
                Set-RegDword -Path $key.PSPath -Name 'DisableDynamicPstate' -Value 1
                $entries += @{ Path = $key.PSPath; Previous = $existing }
            }
        } catch {}
    }
    Write-Log 'P0 permanent activé → plus de chaleur et de bruit à l''idle' 'WARN'
    $State | Add-Member -NotePropertyName 'P0' -NotePropertyValue $entries -Force
    return $State
}

# ----------------------------------------------------------------------
# CPU (5950X - Silence)
# ----------------------------------------------------------------------
function Optimize-Ryzen5950X {
    param($State)
    Write-Log '=== Optimisation Ryzen 9 5950X (priorité Silence) ===' 'STEP'

    $cpuChanges = @{}
    $high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'

    Write-Log 'Configuration Core Parking (silence à l''idle)...' 'STEP'
    try {
        if ($AggressiveSilence) {
            powercfg /setacvalueindex $high SUB_PROCESSOR CPMINCORES 5 2>$null | Out-Null
            Write-Log 'Core Parking configuré (min 5% - mode AggressiveSilence)' 'OK'
            $cpuChanges.CoreParking = '5%'
        } else {
            powercfg /setacvalueindex $high SUB_PROCESSOR CPMINCORES 10 2>$null | Out-Null
            Write-Log 'Core Parking configuré (min 10%)' 'OK'
            $cpuChanges.CoreParking = '10%'
        }
        powercfg /setacvalueindex $high SUB_PROCESSOR CPMAXCORES 100 2>$null | Out-Null
    } catch {
        Write-Log 'Core Parking non modifiable sur ce système (fréquent sur Windows 11 + Ryzen)' 'WARN'
    }

    Write-Log 'Configuration du Processor Boost Mode...' 'STEP'
    $boostPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\be337238-0d82-4146-a960-4f3749d470c7'
    try {
        Set-RegDword -Path $boostPath -Name 'Attributes' -Value 2
        powercfg /setacvalueindex $high SUB_PROCESSOR PERFBOOSTMODE 4 2>$null | Out-Null  # Efficient Aggressive
        Write-Log 'Boost Mode → Efficient Aggressive (meilleur silence)' 'OK'
        $cpuChanges.BoostMode = 4
    } catch {
        Write-Log 'Boost Mode non modifiable' 'WARN'
    }

    powercfg /setacvalueindex $high SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null
    powercfg /setacvalueindex $high SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    Write-Log 'Fréquence CPU min 5% / max 100%' 'OK'

    try {
        Set-RegDword -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1
        Set-RegDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 1 -ErrorAction SilentlyContinue
        Set-RegDword -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1
        Write-Log 'Windows Game Mode activé' 'OK'
        $cpuChanges.GameMode = $true
    } catch {}

    powercfg /setactive $high | Out-Null
    $State | Add-Member -NotePropertyName 'Cpu' -NotePropertyValue $cpuChanges -Force
    return $State
}

# ----------------------------------------------------------------------
# Revert
# ----------------------------------------------------------------------
function Invoke-Revert {
    $state = Get-State
    if (-not $state.Timestamp) {
        Write-Log 'Aucun état sauvegardé → rien à restaurer' 'WARN'
        return
    }

    Write-Log "Restauration de l'état du $($state.Timestamp)..." 'STEP'

    if ($state.HAGS) {
        if ($null -eq $state.HAGS.Previous) {
            Remove-ItemProperty $GraphicsKey -Name HwSchMode -ErrorAction SilentlyContinue
        } else {
            Set-RegDword $GraphicsKey 'HwSchMode' ([int]$state.HAGS.Previous)
        }
        Write-Log 'HAGS restauré' 'OK'
    }

    foreach ($e in @($state.Msi)) {
        if ($null -eq $e.Previous) {
            Remove-ItemProperty $e.Path -Name MSISupported -ErrorAction SilentlyContinue
        } else {
            Set-RegDword $e.Path 'MSISupported' ([int]$e.Previous)
        }
    }
    Write-Log 'MSI restauré' 'OK'

    foreach ($e in @($state.GameBar)) {
        if ($null -eq $e.Previous) {
            Remove-ItemProperty $e.Path -Name $e.Name -ErrorAction SilentlyContinue
        } else {
            Set-RegDword $e.Path $e.Name ([int]$e.Previous)
        }
    }
    Write-Log 'Game Bar restauré' 'OK'

    if ($state.PowerPlan -and $state.PowerPlan.Previous) {
        powercfg /setactive $state.PowerPlan.Previous | Out-Null
        Write-Log 'Plan d''alimentation restauré' 'OK'
    }

    # Restore PowerLimit if saved
    if ($state.PowerLimit -and $state.PowerLimit.Previous) {
        $smi = Get-NvidiaSmi
        if ($smi) {
            & $smi -pl ([math]::Round($state.PowerLimit.Previous)) 2>&1 | ForEach-Object { Write-Log "$_" 'INFO' }
            Write-Log 'Power Limit GPU restauré' 'OK'
        }
    }

    Write-Log 'Restauration terminée. Redémarre le PC.' 'OK'
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
Clear-Host
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║     RTX 3070 + Ryzen 9 5950X  •  One-Click Optimizer         ║' -ForegroundColor Cyan
Write-Host '║              Performance + Silence (Version Modifiée)        ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $StateDir)) {
    New-Item -Path $StateDir -ItemType Directory -Force | Out-Null
}

if ($Revert) {
    Invoke-Revert
    return
}

Write-Log 'Détection du matériel...' 'STEP'
$gpu = Get-NvidiaGpu
if ($gpu) {
    Write-Log "GPU trouvé : $($gpu.Name) (Pilote $($gpu.Driver))" 'OK'
} else {
    Write-Log 'Aucun GPU NVIDIA détecté → optimisation CPU uniquement' 'WARN'
}

$state = Get-State
Write-Log 'Sauvegarde de l''état actuel...' 'STEP'

Write-Host ''
Write-Log '========== OPTIMISATION GPU (RTX 3070) ==========' 'STEP'
Remove-P0Tweak
$state = Enable-HAGS -State $state
$state = Enable-MSI -State $state
$state = Disable-GameBar -State $state
$state = Set-PowerPlan -State $state
$state = Set-PowerLimit -State $state

if ($ForceP0) {
    Write-Log 'ATTENTION : Forcer P0 augmentera bruit et consommation au repos.' 'WARN'
    $state = Enable-P0 -State $state
}

# Génération d'un fichier d'aide MSI Afterburner (profil recommandé)
$profilePath = Join-Path $StateDir 'MSIAfterburner_Profile.txt'
@"
MSI Afterburner recommended target:
- Voltage: 900-925 mV
- Clock: 1900-1950 MHz
- Save profile and set to start with Windows.
Test stability with 30 min stress (Unigine/3DMark) and monitor temps.
If unstable, raise voltage in small steps (+10-20 mV).
"@ | Set-Content -Path $profilePath -Encoding utf8
Write-Log "Fichier d'aide MSI Afterburner créé : $profilePath" 'OK'

Write-Host ''
Write-Log '========== OPTIMISATION CPU (Ryzen 9 5950X) ==========' 'STEP'
$state = Optimize-Ryzen5950X -State $state

Save-State -State $state

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Green
Write-Host '║                    OPTIMISATION TERMINÉE                     ║' -ForegroundColor Green
Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''

Write-Host 'Ce qui a été fait automatiquement :' -ForegroundColor White
Write-Host '  • HAGS activé' -ForegroundColor Gray
Write-Host '  • Mode MSI activé (latence réduite)' -ForegroundColor Gray
Write-Host '  • Xbox Game Bar / Game DVR désactivés' -ForegroundColor Gray
Write-Host '  • Plan High Performance + réglages CPU' -ForegroundColor Gray
Write-Host "  • Power Limit GPU optimisé (SilentFactor = $SilentFactor)" -ForegroundColor Gray
Write-Host '  • Boost Mode CPU → Efficient Aggressive' -ForegroundColor Gray
Write-Host ''

Write-Host '┌──────────────────────────────────────────────────────────────┐' -ForegroundColor Yellow
Write-Host '│  1. REDÉMARRE LE PC MAINTENANT                               │' -ForegroundColor Yellow
Write-Host '│     (obligatoire pour HAGS + MSI)                            │' -ForegroundColor Yellow
Write-Host '└──────────────────────────────────────────────────────────────┘' -ForegroundColor Yellow
Write-Host ''

Write-Host 'Après le redémarrage, fais ces 2 choses pour maximiser silence + perf :' -ForegroundColor White
Write-Host ''
Write-Host '  A. MSI Afterburner (GPU) - le plus important pour le silence' -ForegroundColor Cyan
Write-Host '     1. Ouvre MSI Afterburner' -ForegroundColor Gray
Write-Host '     2. Ctrl + F → Curve Editor' -ForegroundColor Gray
Write-Host '     3. Cible recommandée : 900-925 mV @ 1900-1950 MHz' -ForegroundColor Gray
Write-Host '     4. Applique + sauvegarde le profil + démarre avec Windows' -ForegroundColor Gray
Write-Host ''
Write-Host '  B. BIOS (CPU) - optionnel mais très efficace' -ForegroundColor Cyan
Write-Host '     • PBO → Enabled' -ForegroundColor Gray
Write-Host '     • Curve Optimizer → Negative (All Cores -10 à -30, tester progressivement)' -ForegroundColor Gray
Write-Host '     • Ça baisse fortement la chaleur et le bruit du 5950X' -ForegroundColor Gray
Write-Host ''

Write-Host "Pour annuler toutes les modifications :" -ForegroundColor DarkGray
Write-Host "  .\Optimize-RTX3070.ps1 -Revert" -ForegroundColor DarkGray
Write-Host ''
Write-Host "Fichier d'aide MSI Afterburner : $profilePath" -ForegroundColor DarkGray
Write-Host "Log complet : $LogFile" -ForegroundColor DarkGray
Write-Host ''
