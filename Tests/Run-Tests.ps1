<#
.SYNOPSIS
    Runs the PCOptimizer Pester unit test suite using modern Pester 5+.
.DESCRIPTION
    Ensures Pester 5+ is loaded in preference to legacy inbox versions, configures
    the test runner, and outputs structured results.
.PARAMETER Detailed
    Emits detailed per-test output.
#>
[CmdletBinding()]
param(
    [switch]$Detailed,
    [string]$Path
)

# Strip out WindowsPowerShell legacy paths to isolate against Pester 3.4.0
$paths = $env:PSModulePath -split ';' | Where-Object { $_ -notlike '*WindowsPowerShell*' }
$env:PSModulePath = $paths -join ';'

# Unload any existing Pester module from current session
Get-Module -Name 'Pester' | Remove-Module -Force -ErrorAction SilentlyContinue

# Import modern Pester (5.0+)
Import-Module -Name 'Pester' -MinimumVersion '5.0.0' -Force

$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

$config = [PesterConfiguration]::Default
$config.Run.Path = if ($Path) { $Path } else { (Join-Path -Path $PSScriptRoot -ChildPath 'Unit') }
$config.Run.Exit = $true
$config.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }

Invoke-Pester -Configuration $config
