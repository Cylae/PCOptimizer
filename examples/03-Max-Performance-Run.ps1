<#
.SYNOPSIS
    Example 3: Maximum Performance Mode.
.DESCRIPTION
    Applies aggressive optimization settings:
      - Forces GPU power limit to hardware maximum ceiling (-MaxPerf).
      - Forces P0 state on NVIDIA GPU (-ForceP0) with opt-in warning.
      - Sets aggressive CPU silence parking (-AggressiveSilence).
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PCOptimizer.psd1') -Force

# Execute maximum performance optimization
Invoke-PCOptimization -MaxPerf -ForceP0 -AggressiveSilence
