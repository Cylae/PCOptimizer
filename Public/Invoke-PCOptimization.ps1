<#
.SYNOPSIS
    Optimizes a Windows system for low latency, high gaming performance, and acoustic silence.
.DESCRIPTION
    Applies comprehensive, hardware-adaptive optimizations including HAGS, MSI mode,
    Windows High Performance power scheme, core parking, CPU boost modes, and GPU power limits
    with automatic rollback. Fully reversible via -Revert.
.PARAMETER Revert
    Restores previous configuration from saved state snapshot.
.PARAMETER MaxPerf
    Forces GPU power limit to hardware maximum limit instead of silent mode target.
.PARAMETER ForceP0
    Opt-in switch to force P0 performance state on NVIDIA GPUs. Emits thermal/noise warnings.
.PARAMETER SilentFactor
    Multiplicative factor applied to the GPU maximum power limit (0.01 - 1.0). Defaults to 0.92.
.PARAMETER AggressiveSilence
    When specified, core parking drops minimum unparked cores to 5% instead of default 10%.
.PARAMETER SkipGpu
    Skips all GPU-related optimizations.
.PARAMETER SkipCpu
    Skips all CPU and power scheme optimizations.
.PARAMETER SkipGamingFeatures
    Skips Game Bar and Game DVR registry modifications.
.PARAMETER BackupPath
    Directory path for state snapshot and logs. Defaults to '$env:ProgramData\PCOptimizer'.
.PARAMETER DryRun
    Simulates changes without modifying registry, power scheme, or GPU firmware.
.PARAMETER Quiet
    Suppresses console display (errors remain visible).
.PARAMETER VerificationDelaySeconds
    Seconds to wait when verifying power limit application. Defaults to 5.
.OUTPUTS
    [PSCustomObject] Snapshot of applied settings or revert status.
.EXAMPLE
    Invoke-PCOptimization
    Applies standard balanced performance and silence profile.
.EXAMPLE
    Invoke-PCOptimization -DryRun
    Previews all changes that would be executed without making any system changes.
.EXAMPLE
    Invoke-PCOptimization -Revert
    Restores the system to its pre-optimization state.
#>
function Invoke-PCOptimization {
    [CmdletBinding(DefaultParameterSetName = 'Optimize', SupportsShouldProcess)]
    [Alias('Optimize-PC')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Revert')]
        [switch]$Revert,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [switch]$MaxPerf,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [switch]$ForceP0,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [ValidateRange(0.01, 1.0)]
        [double]$SilentFactor = 0.92,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [switch]$AggressiveSilence,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [switch]$SkipGpu,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [switch]$SkipCpu,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [switch]$SkipGamingFeatures,

        [Parameter(Mandatory = $false)]
        [string]$BackupPath = "$env:ProgramData\PCOptimizer",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet,

        [Parameter(Mandatory = $false, ParameterSetName = 'Optimize')]
        [int]$VerificationDelaySeconds = 5
    )

    if ($DryRun) {
        $WhatIfPreference = $true
    }

    # Verify platform compatibility
    $platformCheck = Test-PCOPlatform
    if (-not $platformCheck.IsSupported) {
        throw [System.PlatformNotSupportedException]::new($platformCheck.Message)
    }

    # Verify administrator rights
    if (-not (Test-PCOAdmin)) {
        if ($DryRun -or $WhatIfPreference) {
            Write-PCOLog -Message "Running in DryRun/WhatIf mode without elevation. System modifications will be simulated." -Level 'WARN' -Quiet:$Quiet
        } else {
            throw [System.Security.SecurityException]::new((Get-PCOString -Key 'ElevationRequired'))
        }
    }

    # Ensure backup directory exists
    if (-not (Test-Path -Path $BackupPath)) {
        if (-not ($DryRun -or $WhatIfPreference)) {
            $null = New-Item -Path $BackupPath -ItemType Directory -Force
        }
    }

    $logFile = if (-not ($DryRun -or $WhatIfPreference)) {
        Join-Path -Path $BackupPath -ChildPath "log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    } else {
        $null
    }

    if (-not $Quiet) {
        Write-Host ''
        Write-Host '+--------------------------------------------------------------+' -ForegroundColor Cyan
        Write-Host '|             PCOptimizer - High-Performance PC Engine         |' -ForegroundColor Cyan
        Write-Host '|              Acoustic Silence + Latency Tuning               |' -ForegroundColor Cyan
        Write-Host '+--------------------------------------------------------------+' -ForegroundColor Cyan
        Write-Host ''
    }

    if ($logFile) {
        Write-PCOLog -Message (Get-PCOString -Key 'LogInitialized' -Arguments @($logFile)) -Level 'INFO' -LogFile $logFile -Quiet:$Quiet
    }

    # Handle Revert
    if ($Revert) {
        $revertResult = Restore-PCOptimization -BackupPath $BackupPath -LogFile $logFile -Quiet:$Quiet
        return $revertResult
    }

    # Optimization Workflow
    $state = Get-PCOptimizationState -BackupPath $BackupPath -LogFile $logFile -Quiet:$Quiet

    # 1. GPU Tuning
    if (-not $SkipGpu) {
        Write-PCOLog -Message '========== OPTIMIZING GPU (HAGS, MSI, POWER LIMIT) ==========' -Level 'STEP' -LogFile $logFile -Quiet:$Quiet
        $state = Optimize-Gpu -State $state `
            -MaxPerf:$MaxPerf `
            -SilentFactor $SilentFactor `
            -ForceP0:$ForceP0 `
            -VerificationDelaySeconds $VerificationDelaySeconds `
            -LogFile $logFile -Quiet:$Quiet
    }

    # 2. Gaming Features
    if (-not $SkipGamingFeatures) {
        Write-PCOLog -Message '========== OPTIMIZING GAMING SUBSYSTEM ==========' -Level 'STEP' -LogFile $logFile -Quiet:$Quiet
        $state = Optimize-GamingFeature -State $state -LogFile $logFile -Quiet:$Quiet
    }

    # 3. CPU & Power Plan Tuning
    if (-not $SkipCpu) {
        Write-PCOLog -Message '========== OPTIMIZING CPU & POWER PLAN ==========' -Level 'STEP' -LogFile $logFile -Quiet:$Quiet
        $state = Optimize-Cpu -State $state -AggressiveSilence:$AggressiveSilence -LogFile $logFile -Quiet:$Quiet
    }

    # 4. Generate MSI Afterburner tuning profile helper
    $profilePath = Join-Path -Path $BackupPath -ChildPath 'MSIAfterburner_Profile.txt'
    $null = Export-MSIAfterburnerProfile -DestinationPath $profilePath -LogFile $logFile -Quiet:$Quiet

    # 5. Persist snapshot state
    $null = Save-PCOState -State $state -BackupPath $BackupPath -LogFile $logFile -Quiet:$Quiet

    if (-not $Quiet) {
        Write-Host ''
        Write-Host '+--------------------------------------------------------------+' -ForegroundColor Green
        Write-Host '|                  OPTIMIZATION COMPLETED                      |' -ForegroundColor Green
        Write-Host '+--------------------------------------------------------------+' -ForegroundColor Green
        Write-Host ''
        Write-Host 'Applied Optimizations:' -ForegroundColor White
        Write-Host '  * Hardware-Accelerated GPU Scheduling (HAGS) enabled' -ForegroundColor Gray
        Write-Host '  * Message Signaled Interrupts (MSI Mode) enabled' -ForegroundColor Gray
        Write-Host '  * Xbox Game Bar & Background DVR disabled' -ForegroundColor Gray
        Write-Host '  * Windows High Performance Scheme + CPU throttling tuned' -ForegroundColor Gray
        Write-Host "  * GPU Power Target configured (SilentFactor = $SilentFactor)" -ForegroundColor Gray
        Write-Host '  * CPU Core Parking & Efficient Aggressive Boost configured' -ForegroundColor Gray
        Write-Host ''
        Write-Host '+--------------------------------------------------------------+' -ForegroundColor Yellow
        Write-Host '|  RESTART SYSTEM REQUIRED FOR HAGS & MSI CHANGES TO APPLY     |' -ForegroundColor Yellow
        Write-Host '+--------------------------------------------------------------+' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Recommended Follow-Up Steps (Post-Reboot):' -ForegroundColor White
        Write-Host '  A. MSI Afterburner Undervolt (Maximizes Silence & Clocks):' -ForegroundColor Cyan
        Write-Host "     1. Review guidance at: $profilePath" -ForegroundColor Gray
        Write-Host '     2. Open Curve Editor (Ctrl+F) -> Target 900-925 mV @ 1900-1950 MHz' -ForegroundColor Gray
        Write-Host '  B. AMD Ryzen BIOS Optimization (PBO & Curve Optimizer):' -ForegroundColor Cyan
        Write-Host '     1. Enable Precision Boost Overdrive (PBO)' -ForegroundColor Gray
        Write-Host '     2. Set Curve Optimizer -> Negative (All Cores -10 to -30 based on silicon)' -ForegroundColor Gray
        Write-Host ''
        Write-Host "To revert all changes: Invoke-PCOptimization -Revert -BackupPath '$BackupPath'" -ForegroundColor DarkGray
        Write-Host "Complete run log saved to: $logFile" -ForegroundColor DarkGray
        Write-Host ''
    }

    return $state
}
