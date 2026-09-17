<#
.SYNOPSIS
    Example 4: Complete System Revert.
.DESCRIPTION
    Reverses all modifications made by PCOptimizer and returns the system to its pre-optimization state.
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PCOptimizer.psd1') -Force

# Revert to snapshot state
Invoke-PCOptimization -Revert
