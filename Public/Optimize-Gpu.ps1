<#
.SYNOPSIS
    Orchestrates GPU optimizations including HAGS, MSI mode, power limit, and P0 state.
.DESCRIPTION
    Applies display and graphics tuning across NVIDIA GPU hardware. Automatically removes
    stale P0 tweaks, activates Hardware-Accelerated GPU Scheduling, configures Message Signaled
    Interrupts, sets calculated power limit targets with automatic rollback, and applies
    opt-in forced P0 states when explicitly requested.
.PARAMETER State
    The current state object into which previous values and applied changes are recorded.
.PARAMETER MaxPerf
    Forces GPU power limit to hardware maximum limit instead of silent mode target.
.PARAMETER SilentFactor
    Multiplicative factor applied to the GPU maximum power limit (0.01 - 1.0). Defaults to 0.92.
.PARAMETER ForceP0
    Opt-in switch to force P0 performance state. Emits thermal/noise warnings.
.PARAMETER VerificationDelaySeconds
    Seconds to wait when verifying power limit application. Defaults to 5.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Updated state object containing GPU snapshot records.
#>
function Optimize-Gpu {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegates ShouldProcess to child cmdlets')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$State,

        [Parameter(Mandatory = $false)]
        [switch]$MaxPerf,

        [Parameter(Mandatory = $false)]
        [switch]$MaxSilence,

        [Parameter(Mandatory = $false)]
        [switch]$BalancedSilence,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.01, 1.0)]
        [double]$SilentFactor = 0.92,

        [Parameter(Mandatory = $false)]
        [switch]$ForceP0,

        [Parameter(Mandatory = $false)]
        [int]$VerificationDelaySeconds = 5,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )


    $exclusiveCount = 0
    if ($MaxPerf) { $exclusiveCount++ }
    if ($MaxSilence) { $exclusiveCount++ }
    if ($BalancedSilence) { $exclusiveCount++ }

    if ($exclusiveCount -gt 1) {
        throw [System.ArgumentException]::new("The parameters -MaxPerf, -MaxSilence, and -BalancedSilence are mutually exclusive. Please specify only one.")
    }

    # 1. Clean up any residual P0 tweaks from prior runs
    $null = Remove-PCOP0Tweak -LogFile $LogFile -Quiet:$Quiet

    # 2. Enable HAGS
    $hagsState = Enable-PCOHags -LogFile $LogFile -Quiet:$Quiet
    $State | Add-Member -NotePropertyName 'HAGS' -NotePropertyValue $hagsState -Force

    # 3. Enable MSI mode on NVIDIA adapters
    $msiState = Enable-PCOMsiMode -LogFile $LogFile -Quiet:$Quiet
    $State | Add-Member -NotePropertyName 'Msi' -NotePropertyValue $msiState -Force

    # 4. Probe GPU for Power Limit tuning
    $gpuList = Get-NvidiaGpuStatus
    $gpu = if ($gpuList -and $gpuList.Count -gt 0) { $gpuList[0] } else { $null }

    if ($gpu) {
        Write-PCOLog -Message (Get-PCOString -Key 'GpuDetected' -Arguments @($gpu.Name, $gpu.Driver)) -Level 'INFO' -LogFile $LogFile -Quiet:$Quiet
        Write-PCOLog -Message (Get-PCOString -Key 'GpuMetrics' -Arguments @($gpu.PowerLimit, $gpu.DefaultLimit, $gpu.MaxLimit, $gpu.Temperature, $gpu.GraphicsClock)) -Level 'INFO' -LogFile $LogFile -Quiet:$Quiet

        $targetWatts = if ($MaxSilence) {
            [math]::Round($gpu.MaxLimit * 0.70)
        } elseif ($BalancedSilence) {
            [math]::Round($gpu.MaxLimit * 0.85)
        } elseif ($MaxPerf) {
            [math]::Round($gpu.MaxLimit)
        } else {
            [math]::Round($gpu.MaxLimit * $SilentFactor)
        }

        if ($gpu.PowerLimit -ge ($targetWatts - 0.5) -and $gpu.PowerLimit -le ($targetWatts + 0.5)) {
            Write-PCOLog -Message (Get-PCOString -Key 'PowerLimitAlreadyOptimal' -Arguments @($gpu.PowerLimit)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
            $State | Add-Member -NotePropertyName 'PowerLimit' -NotePropertyValue @{
                Previous          = $gpu.PowerLimit
                TargetWatts       = $targetWatts
                AppliedWatts      = $gpu.PowerLimit
                DefaultLimitWatts = $gpu.DefaultLimit
                MaxLimitWatts     = $gpu.MaxLimit
                RolledBack        = $false
            } -Force
        } else {
            $plResult = Set-PCONvidiaPowerLimit -SmiPath $gpu.SmiPath `
                -TargetWatts $targetWatts `
                -DefaultWatts $gpu.DefaultLimit `
                -VerificationDelaySeconds $VerificationDelaySeconds `
                -LogFile $LogFile -Quiet:$Quiet

            $State | Add-Member -NotePropertyName 'PowerLimit' -NotePropertyValue @{
                Previous          = $gpu.PowerLimit
                TargetWatts       = $targetWatts
                AppliedWatts      = $plResult.AppliedWatts
                DefaultLimitWatts = $gpu.DefaultLimit
                MaxLimitWatts     = $gpu.MaxLimit
                RolledBack        = $plResult.RolledBack
            } -Force
        }
    } else {
        Write-PCOLog -Message (Get-PCOString -Key 'NoNvidiaGpu') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
    }

    # 5. Opt-in Force P0
    if ($ForceP0) {
        $p0Entries = Enable-PCOP0Mode -LogFile $LogFile -Quiet:$Quiet
        $State | Add-Member -NotePropertyName 'P0' -NotePropertyValue $p0Entries -Force
    }

    return $State
}
