<#
.SYNOPSIS
    Restores all system settings to their original state captured in state.json.
.DESCRIPTION
    Rolls back registry keys, active power scheme, MSI configurations, and GPU power limits
    using the snapshot recorded before optimization was performed.
.PARAMETER BackupPath
    Path to directory where state.json was stored. Defaults to '$env:ProgramData\PCOptimizer'.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Contains Success status and RestoredTimestamp.
#>
function Restore-PCOptimization {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BackupPath = "$env:ProgramData\PCOptimizer",

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $state = Get-PCOptimizationState -BackupPath $BackupPath -LogFile $LogFile -Quiet:$Quiet
    if (-not $state.Timestamp) {
        Write-PCOLog -Message (Get-PCOString -Key 'RevertNoState' -Arguments @($BackupPath)) -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
        return [PSCustomObject]@{
            Success           = $false
            RestoredTimestamp = $null
        }
    }

    if (-not $PSCmdlet.ShouldProcess("System Configuration ($BackupPath)", "Restore pre-optimization system state from $($state.Timestamp)")) {
        return [PSCustomObject]@{
            Success           = $true
            RestoredTimestamp = $state.Timestamp
        }
    }

    Write-PCOLog -Message (Get-PCOString -Key 'RevertStarting' -Arguments @($state.Timestamp)) -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    # 1. Restore HAGS
    if ($state.HAGS) {
        $graphicsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        $prevHags = if ($state.HAGS -is [System.Collections.IDictionary]) {
            $state.HAGS['Previous']
        } else {
            $state.HAGS.Previous
        }

        if ($null -eq $prevHags) {
            $null = Remove-PCORegistryValue -Path $graphicsKey -Name 'HwSchMode'
        } else {
            $null = Set-PCORegistryDword -Path $graphicsKey -Name 'HwSchMode' -Value ([int]$prevHags)
        }
        Write-PCOLog -Message (Get-PCOString -Key 'RevertHagsRestored' -Arguments @($prevHags)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    # 2. Restore MSI
    if ($state.Msi) {
        $msiCount = Restore-PCORegistryState -Entries @($state.Msi) -DefaultName 'MSISupported' -LogFile $LogFile -Quiet:$Quiet
        Write-PCOLog -Message (Get-PCOString -Key 'RevertMsiRestored' -Arguments @($msiCount)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    # 3. Restore Game Bar
    if ($state.GameBar) {
        $null = Restore-PCORegistryState -Entries @($state.GameBar) -LogFile $LogFile -Quiet:$Quiet
        Write-PCOLog -Message (Get-PCOString -Key 'RevertGameBarRestored') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    # 4. Restore Power Plan
    if ($state.PowerPlan) {
        $prevGuid = $null
        if ($state.PowerPlan -is [System.Collections.IDictionary]) {
            if ($state.PowerPlan.ContainsKey('PreviousSchemeGuid')) {
                $prevGuid = $state.PowerPlan['PreviousSchemeGuid']
            } elseif ($state.PowerPlan.ContainsKey('Previous')) {
                $prevGuid = $state.PowerPlan['Previous']
            }
        } else {
            if ($state.PowerPlan.PreviousSchemeGuid) {
                $prevGuid = $state.PowerPlan.PreviousSchemeGuid
            } elseif ($state.PowerPlan.Previous) {
                $prevGuid = $state.PowerPlan.Previous
            }
        }

        if ($prevGuid) {
            $null = Invoke-PCOPowerCfg -Arguments @('/setactive', $prevGuid)
            Write-PCOLog -Message (Get-PCOString -Key 'RevertPowerPlanRestored' -Arguments @($prevGuid)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        }
    }

    # 5. Restore GPU Power Limit
    if ($state.PowerLimit) {
        $prevWatts = $null
        if ($state.PowerLimit -is [System.Collections.IDictionary]) {
            if ($state.PowerLimit.ContainsKey('PreviousWatts')) {
                $prevWatts = $state.PowerLimit['PreviousWatts']
            } elseif ($state.PowerLimit.ContainsKey('Previous')) {
                $prevWatts = $state.PowerLimit['Previous']
            }
        } else {
            if ($state.PowerLimit.PreviousWatts) {
                $prevWatts = $state.PowerLimit.PreviousWatts
            } elseif ($state.PowerLimit.Previous) {
                $prevWatts = $state.PowerLimit.Previous
            }
        }

        if ($prevWatts) {
            $smi = Find-PCONvidiaSmi
            if ($smi) {
                try {
                    $smiRes = Invoke-PCONvidiaSmi -SmiPath $smi -Arguments @('-pl', "$([math]::Round([double]$prevWatts))")
                    if ($smiRes.Success) {
                        Write-PCOLog -Message (Get-PCOString -Key 'RevertPowerLimitRestored' -Arguments @($prevWatts)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
                    }
                } catch {
                    Write-PCOLog -Message "Failed to restore GPU power limit: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
                }
            }
        }
    }

    # 6. Restore P0
    if ($state.P0) {
        $null = Restore-PCORegistryState -Entries @($state.P0) -DefaultName 'DisableDynamicPstate' -LogFile $LogFile -Quiet:$Quiet
        Write-PCOLog -Message (Get-PCOString -Key 'RevertP0Restored') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    Write-PCOLog -Message (Get-PCOString -Key 'RevertCompleted') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet

    return [PSCustomObject]@{
        Success           = $true
        RestoredTimestamp = $state.Timestamp
    }
}
