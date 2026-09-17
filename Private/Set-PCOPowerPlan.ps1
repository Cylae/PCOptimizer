<#
.SYNOPSIS
    Activates and configures the Windows High Performance AC power scheme.
.DESCRIPTION
    Switches active power scheme to High Performance (8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c),
    sets processor throttle min to 5% and max to 100%, and disables PCIe ASPM for low latency.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Containing PreviousSchemeGuid, AppliedSchemeGuid, and ASPM status.
#>
function Set-PCOPowerPlan {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    Write-PCOLog -Message (Get-PCOString -Key 'PowerPlanConfiguring') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $highGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'

    # Get active scheme
    $currentRes = Invoke-PCOPowerCfg -Arguments @('/getactivescheme')
    $prevGuid = $null
    if ($currentRes.Output) {
        $match = [regex]::Match($currentRes.Output, '[0-9a-fA-F-]{36}')
        if ($match.Success) {
            $prevGuid = $match.Value
        }
    }

    $aspmOk = $false
    if ($PSCmdlet.ShouldProcess("Windows Power Scheme", "Activate High Performance scheme ($highGuid)")) {
        # Activate High Performance scheme
        $null = Invoke-PCOPowerCfg -Arguments @('/setactive', $highGuid)

        # Set processor throttling bounds
        $null = Invoke-PCOPowerCfg -Arguments @('/setacvalueindex', $highGuid, 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', '5')
        $null = Invoke-PCOPowerCfg -Arguments @('/setacvalueindex', $highGuid, 'SUB_PROCESSOR', 'PROCTHROTTLEMAX', '100')
        Write-PCOLog -Message (Get-PCOString -Key 'PowerPlanThrottleConfigured') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet

        # Disable PCIe ASPM
        $aspmRes = Invoke-PCOPowerCfg -Arguments @('/setacvalueindex', $highGuid, 'SUB_PCIEXPRESS', 'ASPM', '0')
        $aspmOk = $aspmRes.Success
        if ($aspmOk) {
            Write-PCOLog -Message (Get-PCOString -Key 'PowerPlanAspmDisabled') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        } else {
            Write-PCOLog -Message (Get-PCOString -Key 'PowerPlanAspmNotSupported') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
        }

        # Re-commit scheme
        $null = Invoke-PCOPowerCfg -Arguments @('/setactive', $highGuid)
        Write-PCOLog -Message (Get-PCOString -Key 'PowerPlanActive' -Arguments @($highGuid)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    return [PSCustomObject]@{
        PreviousSchemeGuid = $prevGuid
        AppliedSchemeGuid  = $highGuid
        AspmDisabled       = $aspmOk
    }
}
