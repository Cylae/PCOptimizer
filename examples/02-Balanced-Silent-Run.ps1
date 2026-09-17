<#
.SYNOPSIS
    Example 2: Balanced Performance + Acoustic Silence.
.DESCRIPTION
    Applies the default PCOptimizer profile:
      - Enables HAGS and MSI mode.
      - Disables Xbox Game Bar / Game DVR background capture.
      - Sets Windows High Performance scheme with Core Parking.
      - Sets GPU Power Limit to 92% (SilentFactor = 0.92) to reduce fan RPMs.
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PCOptimizer.psd1') -Force

# Execute standard balanced optimization
Invoke-PCOptimization -SilentFactor 0.92
