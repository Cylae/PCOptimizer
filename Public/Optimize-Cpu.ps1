<#
.SYNOPSIS
    Orchestrates CPU optimizations including power plan, throttling, core parking, and boost mode.
.DESCRIPTION
    Applies system power plan configurations and processor core scheduling optimizations.
    Configures the Windows High Performance scheme, adjusts core parking limits according to
    silence targets, and sets processor performance boost to Efficient Aggressive.
.PARAMETER State
    The current state object into which previous values and applied changes are recorded.
.PARAMETER AggressiveSilence
    When specified, core parking drops minimum unparked cores to 5% instead of default 10%.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Updated state object containing CPU snapshot records.
#>
function Optimize-Cpu {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegates ShouldProcess to child cmdlets')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$State,

        [Parameter(Mandatory = $false)]
        [switch]$AggressiveSilence,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )


    # 1. High Performance Power Plan configuration
    $ppResult = Set-PCOPowerPlan -LogFile $LogFile -Quiet:$Quiet
    $State | Add-Member -NotePropertyName 'PowerPlan' -NotePropertyValue @{
        PreviousSchemeGuid = $ppResult.PreviousSchemeGuid
        AppliedSchemeGuid  = $ppResult.AppliedSchemeGuid
        AspmDisabled       = $ppResult.AspmDisabled
    } -Force

    # 2. Processor scheduling & core parking
    $cpuResult = Set-PCOProcessorScheduling -AggressiveSilence:$AggressiveSilence -LogFile $LogFile -Quiet:$Quiet
    $State | Add-Member -NotePropertyName 'Cpu' -NotePropertyValue $cpuResult -Force

    return $State
}
