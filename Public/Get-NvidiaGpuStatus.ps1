<#
.SYNOPSIS
    Queries and returns telemetry and capability metrics for installed NVIDIA GPUs.
.DESCRIPTION
    Invokes nvidia-smi with structured query parameters, parses CSV telemetry,
    and returns strongly typed GPU status objects. If nvidia-smi is absent, returns $null without error.
.PARAMETER SmiPath
    Optional explicit path to nvidia-smi.exe. If omitted, automatic resolution is used.
.OUTPUTS
    [PSCustomObject[]] Array of GPU status records containing Name, Driver, PowerLimit,
    DefaultLimit, MaxLimit, Temperature, GraphicsClock, and SmiPath.
#>
function Get-NvidiaGpuStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SmiPath
    )

    $resolvedSmi = if ($SmiPath) { $SmiPath } else { Find-PCONvidiaSmi }
    if (-not $resolvedSmi -or -not (Test-Path -Path $resolvedSmi)) {
        return $null
    }

    try {
        $smiResult = Invoke-PCONvidiaSmi -SmiPath $resolvedSmi -Arguments @(
            '--query-gpu=name,driver_version,power.limit,power.default_limit,power.max_limit,temperature.gpu,clocks.gr',
            '--format=csv,noheader,nounits'
        )

        if (-not $smiResult.Success -or -not $smiResult.Output) {
            return $null
        }

        $gpus = ConvertFrom-PCONvidiaSmiOutput -RawOutput $smiResult.Output -AllowUnsupported
        foreach ($gpu in $gpus) {
            $gpu | Add-Member -NotePropertyName 'SmiPath' -NotePropertyValue $resolvedSmi -Force
        }

        return $gpus
    } catch {
        return $null
    }
}
