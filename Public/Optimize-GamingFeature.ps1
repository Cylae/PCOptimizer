<#
.SYNOPSIS
    Orchestrates Windows gaming feature optimizations.
.DESCRIPTION
    Disables background Xbox Game Bar and Game DVR recording hooks to eliminate
    unnecessary rendering latency and frame pacing jitter.
.PARAMETER State
    The current state object into which previous values and applied changes are recorded.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Updated state object containing Game Bar snapshot records.
#>
function Optimize-GamingFeature {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegates ShouldProcess to child cmdlets')]
    [Alias('Optimize-GamingFeatures')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$State,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )


    $gbEntries = Set-PCOGameBarState -LogFile $LogFile -Quiet:$Quiet
    $State | Add-Member -NotePropertyName 'GameBar' -NotePropertyValue $gbEntries -Force

    return $State
}
