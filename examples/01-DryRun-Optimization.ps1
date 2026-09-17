<#
.SYNOPSIS
    Example 1: Safe Preview / Dry-Run Mode.
.DESCRIPTION
    Runs PCOptimizer with -DryRun to preview every system modification that would occur
    without making any changes to the registry, power plan, or GPU firmware.
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PCOptimizer.psd1') -Force

# Execute simulated run
Invoke-PCOptimization -DryRun -Verbose
