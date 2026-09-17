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
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $parentDir = Split-Path -Path $DestinationPath -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        $null = New-Item -Path $parentDir -ItemType Directory -Force
    }

    $content = @"
================================================================================
MSI AFTERBURNER UNDERVOLT & FREQUENCY TARGET GUIDE (RTX 3070 / AMPERE)
================================================================================

Recommended Operating Targets:
  - Core Voltage: 900 mV - 925 mV
  - Core Clock:   1900 MHz - 1950 MHz
  - Memory Clock: Stock (+0 MHz) or moderate (+200 MHz to +500 MHz based on silicon)

Step-by-Step Curve Editor Setup:
  1. Open MSI Afterburner.
  2. Press Ctrl + F to open the Voltage/Frequency Curve Editor.
  3. Locate the point at 900 mV or 925 mV on the horizontal axis.
  4. Drag that point up to 1900-1950 MHz.
  5. Select the point and press Shift + Enter, or drag all points to the right of it flat.
  6. Click the checkmark (Apply) in the main Afterburner window. The curve will flatten.
  7. Save the profile to Profile Slot 1.
  8. Enable the Windows startup icon in MSI Afterburner to apply at boot.

Stability Testing & Validation:
  - Run a 30-minute GPU stress test (Unigine Superposition 4K Optimized, 3DMark Time Spy, or Cyberpunk 2077).
  - Monitor GPU Hotspot and Core temperatures with HWiNFO64.
  - If a driver crash or artifact occurs, raise voltage in small increments (+10 to +15 mV)
    or lower core frequency by 25 MHz until fully stable.
================================================================================
"@

    if ($PSCmdlet.ShouldProcess($DestinationPath, "Export MSI Afterburner tuning profile")) {
        Set-Content -Path $DestinationPath -Value $content -Encoding utf8 -Force
    }

    Write-PCOLog -Message (Get-PCOString -Key 'AfterburnerProfileExported' -Arguments @($DestinationPath)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    return $DestinationPath
}
