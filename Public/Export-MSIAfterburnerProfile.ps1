<#
.SYNOPSIS
    Exports an MSI Afterburner undervolting guidance and curve configuration guide.
.DESCRIPTION
    Generates a reference document with recommended target voltages and clocks for RTX 30-series
    GPUs to achieve maximum acoustic silence and thermal efficiency without sacrificing FPS.
.PARAMETER DestinationPath
    Destination file path for the guide. Defaults to '$env:ProgramData\PCOptimizer\MSIAfterburner_Profile.txt'.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [string] Path of the exported guide file.
#>
function Export-MSIAfterburnerProfile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DestinationPath = "$env:ProgramData\PCOptimizer\MSIAfterburner_Profile.txt",

        [Parameter(Mandatory = $false)]
        [object]$GpuInfo,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $parentDir = Split-Path -Path $DestinationPath -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        $null = New-Item -Path $parentDir -ItemType Directory -Force
    }

    # Resolve GPU if not provided
    $targetGpu = $GpuInfo
    if (-not $targetGpu) {
        try {
            $hw = Get-PCOSystemHardware
            if ($hw -and $hw.GPUs -and $hw.GPUs.Count -gt 0) {
                $targetGpu = $hw.GPUs[0]
            }
        } catch {
            $null = $_
        }
    }

    $gpuName = if ($targetGpu -and $targetGpu.Name) { $targetGpu.Name } else { 'Universal Graphics Card' }
    $gpuArch = if ($targetGpu -and $targetGpu.Architecture) { $targetGpu.Architecture } else { 'Universal Architecture' }
    $vendor  = if ($targetGpu -and $targetGpu.Vendor) { $targetGpu.Vendor } else { 'NVIDIA' }

    $minMv    = 900
    $maxMv    = 925
    $minClock = 1900
    $maxClock = 1950
    $memOffset = 500
    $notes     = 'Target 900-925 mV for optimal acoustics and power efficiency.'

    if ($targetGpu -and $targetGpu.RecommendedUndervolt) {
        $uv = $targetGpu.RecommendedUndervolt
        if ($uv.MinVoltageMv -and $uv.TargetVoltageMv) {
            $minMv = $uv.MinVoltageMv
            $maxMv = $uv.TargetVoltageMv
        } elseif ($uv.TargetVoltageMv) {
            $minMv = [math]::Max(700, $uv.TargetVoltageMv - 25)
            $maxMv = $uv.TargetVoltageMv
        }

        if ($uv.MinClockMhz -and $uv.TargetClockMhz) {
            $minClock = $uv.MinClockMhz
            $maxClock = $uv.TargetClockMhz
        } elseif ($uv.TargetClockMhz) {
            $minClock = [math]::Max(1000, $uv.TargetClockMhz - 25)
            $maxClock = [math]::Max(1000, $uv.TargetClockMhz + 25)
        }

        if ($null -ne $uv.MemoryOffsetMhz) { $memOffset = $uv.MemoryOffsetMhz }
        if ($uv.Notes)           { $notes = $uv.Notes }
    }

    $targetMv = $maxMv
    $targetMhz = $maxClock

    $content = @"
================================================================================
PCOPTIMIZER GPU UNDERVOLT & FREQUENCY TUNING GUIDE
Detected Hardware: $gpuName
Architecture:      $gpuArch
================================================================================

Recommended Operating Targets:
  - Core Voltage: $minMv mV - $maxMv mV
  - Core Clock:   $minClock MHz - $maxClock MHz
  - Memory Clock: Stock (+0 MHz) or moderate (+$memOffset MHz based on silicon)
  - Architectural Note: $notes

Step-by-Step Curve Editor Setup:
"@

    if ($vendor -eq 'AMD') {
        $content += @"
AMD SOFTWARE: ADRENALIN EDITION STEP-BY-STEP SETUP:
  1. Open AMD Software: Adrenalin Edition.
  2. Navigate to Performance -> Tuning -> Manual Tuning -> Custom.
  3. Enable GPU Tuning and Voltage (mV) control.
  4. Lower the maximum voltage slider by 30-60 mV (e.g. from stock down towards target).
  5. Enable VRAM Tuning -> set Memory Timing to 'Fast Timing'.
  6. Enable Power Tuning -> set Power Limit to -5% to -10% for silent acoustics.
  7. Click 'Apply Changes' in the top-right corner. Save profile as 'PCOptimizer-Silent.xml'.
"@
    } elseif ($vendor -eq 'Intel') {
        $content += @"
INTEL ARC CONTROL STEP-BY-STEP SETUP:
  1. Open Intel Arc Control (Alt + I).
  2. Navigate to Performance -> Tuning.
  3. Set GPU Voltage Offset to -25 mV to -45 mV.
  4. Adjust Power Limit to the recommended silent TDP target.
  5. Configure Fan Curve for whisper-quiet idle and smooth ramping under load.
  6. Save and apply tuning profile.
"@
    } else {
        $content += @"
MSI AFTERBURNER STEP-BY-STEP SETUP:
  1. Download and open MSI Afterburner (4.6.5 or later).
  2. Press Ctrl + F to open the Voltage/Frequency (V/F) Curve Editor.
  3. Locate the point at $targetMv mV on the horizontal axis.
  4. Drag that point up to $targetMhz MHz on the vertical axis.
  5. Select the point and press Shift + Enter, or select and flatten all points to the right.
  6. Click the checkmark (Apply) in the main Afterburner window. The curve will lock flat.
  7. If desired, set Memory Clock to +$memOffset MHz.
  8. Save the profile to Profile Slot 1.
  9. Click the Windows startup icon in MSI Afterburner to automatically apply at boot.
"@
    }

    $content += @"

Stability Testing & Validation:
  - Run a 30-minute GPU stress test (3DMark Time Spy / Steel Nomad, Unigine Superposition, or Cyberpunk 2077).
  - Monitor GPU Hotspot and Core temperatures with HWiNFO64.
  - If a driver crash occurs, raise voltage by +10-15 mV or decrease clock by 25 MHz until fully stable.
================================================================================
"@

    if ($PSCmdlet.ShouldProcess($DestinationPath, "Export MSI Afterburner tuning profile")) {
        Set-Content -Path $DestinationPath -Value $content -Encoding utf8 -Force
    }

    Write-PCOLog -Message (Get-PCOString -Key 'AfterburnerProfileExported' -Arguments @($DestinationPath)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    return $DestinationPath
}
