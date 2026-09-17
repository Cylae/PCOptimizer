<#
.SYNOPSIS
    Applies an NVIDIA GPU power limit clamp via nvidia-smi with verification and automatic rollback.
.DESCRIPTION
    Invokes nvidia-smi -pl, waits for the driver to acknowledge the change, verifies that the
    power limit persisted, and automatically rolls back to factory defaults if the driver
    rejected or discarded the value.
.PARAMETER SmiPath
    Path to nvidia-smi.exe.
.PARAMETER TargetWatts
    Target power limit in Watts.
.PARAMETER DefaultWatts
    Factory default power limit in Watts used for rollback on failure.
.PARAMETER VerificationDelaySeconds
    Seconds to wait before reading back power limit. Defaults to 5 seconds.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Contains TargetWatts, AppliedWatts, RolledBack status, and Success.
#>
function Set-PCONvidiaPowerLimit {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SmiPath,

        [Parameter(Mandatory = $true)]
        [double]$TargetWatts,

        [Parameter(Mandatory = $true)]
        [double]$DefaultWatts,

        [Parameter(Mandatory = $false)]
        [int]$VerificationDelaySeconds = 5,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $target = [math]::Round($TargetWatts)
    $default = [math]::Round($DefaultWatts)

    if (-not (Test-Path -Path $SmiPath)) {
        Write-PCOLog -Message "nvidia-smi executable not found at: '$SmiPath'" -Level 'ERROR' -LogFile $LogFile -Quiet:$Quiet
        return [PSCustomObject]@{
            TargetWatts  = $target
            AppliedWatts = $default
            RolledBack   = $false
            Success      = $false
        }
    }

    if (-not $PSCmdlet.ShouldProcess("NVIDIA GPU", "Set power limit to $target W (Rollback default: $default W)")) {
        return [PSCustomObject]@{
            TargetWatts  = $target
            AppliedWatts = $target
            RolledBack   = $false
            Success      = $true
        }
    }

    Write-PCOLog -Message (Get-PCOString -Key 'PowerLimitApplying' -Arguments @($target)) -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $res = Invoke-PCONvidiaSmi -SmiPath $SmiPath -Arguments @('-pl', "$target")
    if ($res.Output) {
        foreach ($line in $res.Output) {
            Write-PCOLog -Message $line.ToString() -Level 'INFO' -LogFile $LogFile -Quiet:$Quiet
        }
    }

    if (-not $res.Success) {
        Write-PCOLog -Message "Failed to invoke nvidia-smi: $($res.Output -join ' ')" -Level 'ERROR' -LogFile $LogFile -Quiet:$Quiet
        return [PSCustomObject]@{
            TargetWatts  = $target
            AppliedWatts = $default
            RolledBack   = $true
            Success      = $false
        }
    }

    if ($VerificationDelaySeconds -gt 0) {
        Start-Sleep -Seconds $VerificationDelaySeconds
    }

    # Verify application
    $verifyGpu = $null
    try {
        $verifyRes = Invoke-PCONvidiaSmi -SmiPath $SmiPath -Arguments @(
            '--query-gpu=name,driver_version,power.limit,power.default_limit,power.max_limit,temperature.gpu,clocks.gr',
            '--format=csv,noheader,nounits'
        )
        if ($verifyRes.Success -and $verifyRes.Output) {
            $parsed = ConvertFrom-PCONvidiaSmiOutput -RawOutput $verifyRes.Output
            if ($parsed.Count -gt 0) {
                $verifyGpu = $parsed[0]
            }
        }
    } catch {
        $verifyGpu = $null
    }

    if ($null -eq $verifyGpu -or [math]::Abs($verifyGpu.PowerLimit - $target) -gt 1.0) {
        Write-PCOLog -Message (Get-PCOString -Key 'PowerLimitVerificationFailed' -Arguments @($default)) -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
        $rollbackRes = Invoke-PCONvidiaSmi -SmiPath $SmiPath -Arguments @('-pl', "$default")
        if ($rollbackRes.Success) {
            Write-PCOLog -Message (Get-PCOString -Key 'PowerLimitRevertedToDefault' -Arguments @($default)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        } else {
            Write-PCOLog -Message "Rollback to default limit failed: $($rollbackRes.Output -join ' ')" -Level 'ERROR' -LogFile $LogFile -Quiet:$Quiet
        }

        return [PSCustomObject]@{
            TargetWatts  = $target
            AppliedWatts = $default
            RolledBack   = $true
            Success      = $false
        }
    }

    Write-PCOLog -Message (Get-PCOString -Key 'PowerLimitApplied' -Arguments @($target)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    return [PSCustomObject]@{
        TargetWatts  = $target
        AppliedWatts = $target
        RolledBack   = $false
        Success      = $true
    }
}
