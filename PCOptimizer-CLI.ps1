<#
.SYNOPSIS
    Standalone CLI launcher for PCOptimizer with guided wizard and command-line support.
.DESCRIPTION
    Launches the PCOptimizer guided assistant, allowing the user to select their silence vs. performance
    preference with a visual gauge or command-line parameters.
.PARAMETER Help
    Displays the interactive help and tuning guide.
.PARAMETER Level
    Performance level (1 = Maximum Silence, 5 = Extreme Performance).
.PARAMETER SilenceBias
    Continuous preference percentage (0 = Max Performance, 100 = Max Silence).
.PARAMETER DryRun
    Simulates changes without modifying registry or hardware parameters.
.PARAMETER Revert
    Restores the system to its pre-optimization state snapshot.
.PARAMETER NonInteractive
    Runs headlessly using the chosen or default level without interactive prompts.
.PARAMETER BackupPath
    Directory path for state snapshot and logs. Defaults to '$env:ProgramData\PCOptimizer'.
.EXAMPLE
    .\PCOptimizer-CLI.ps1 -Help
.EXAMPLE
    .\PCOptimizer-CLI.ps1 -DryRun
.EXAMPLE
    .\PCOptimizer-CLI.ps1 -Level 2
#>
[CmdletBinding(DefaultParameterSetName = 'Interactive', SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [Alias('h', '?')]
    [switch]$Help,

    [Parameter(Mandatory = $false, ParameterSetName = 'Interactive')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Headless')]
    [ValidateRange(1, 5)]
    [int]$Level = 3,

    [Parameter(Mandatory = $false, ParameterSetName = 'Interactive')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Headless')]
    [ValidateRange(0, 100)]
    [int]$SilenceBias,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, ParameterSetName = 'Revert')]
    [switch]$Revert,

    [Parameter(Mandatory = $false, ParameterSetName = 'Headless')]
    [switch]$NonInteractive,

    [Parameter(Mandatory = $false)]
    [string]$BackupPath = "$env:ProgramData\PCOptimizer"
)

# Ensure modern PowerShell (7.4+)
if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 4)) {
    Write-Error "PCOptimizer requires PowerShell 7.4 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Import module
$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'PCOptimizer.psd1'
if (Test-Path -Path $manifestPath) {
    Import-Module -Name $manifestPath -Force
} else {
    Write-Error "Could not locate module manifest at: $manifestPath"
    exit 1
}

# Forward to Start-PCOptimizerWizard
$wizardParams = @{}
if ($Help) { $wizardParams['Help'] = $true }
if ($PSBoundParameters.ContainsKey('Level')) { $wizardParams['Level'] = $Level }
if ($PSBoundParameters.ContainsKey('SilenceBias')) { $wizardParams['SilenceBias'] = $SilenceBias }
if ($DryRun) { $wizardParams['DryRun'] = $true }
if ($Revert) { $wizardParams['Revert'] = $true }
if ($NonInteractive) { $wizardParams['NonInteractive'] = $true }
if ($PSBoundParameters.ContainsKey('BackupPath')) { $wizardParams['BackupPath'] = $BackupPath }

Start-PCOptimizerWizard @wizardParams
