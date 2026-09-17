<#
.SYNOPSIS
    Retrieves a localized string from the PCOptimizer string catalog.
.DESCRIPTION
    Centralizes all user-facing console, log, and error strings for PCOptimizer.
    English is the default language.
.PARAMETER Key
    The string identifier key.
.PARAMETER Arguments
    Optional format arguments to inject into the string template.
.OUTPUTS
    [string] The formatted localized string.
#>
function Get-PCOString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Key,

        [Parameter(Mandatory = $false, Position = 1)]
        [object[]]$Arguments = @()
    )

    $stringCatalog = @{
        # General & Banner
        'BannerTitle'                   = 'PCOptimizer: Windows 11 / 10 Performance & Silence Optimizer'
        'BannerSubtitle'                = 'Hardware-Adaptive Optimization for AMD Ryzen + NVIDIA GeForce'
        'ElevationRequired'             = 'PCOptimizer requires administrative privileges. Please restart PowerShell as Administrator.'
        'NonWindowsPlatform'            = 'PCOptimizer is only supported on Windows 10 (21H2+) and Windows 11.'
        'UnsupportedWindowsVersion'     = 'Unsupported Windows build: {0}. Requires Windows 10 (19044+) or Windows 11.'

        # Logging
        'LogInitialized'                = 'Logging initialized to: {0}'

        # Hardware Detection
        'DetectingHardware'             = 'Probing system hardware configuration...'
        'GpuDetected'                   = 'NVIDIA GPU detected: {0} (Driver: {1})'
        'GpuMetrics'                    = 'Current Power Limit: {0} W | Default: {1} W | Max: {2} W | Temp: {3} C | Core Clock: {4} MHz'
        'NoNvidiaGpu'                   = 'No NVIDIA GPU detected or nvidia-smi unavailable. Skipping GPU power limit tuning.'

        # HAGS
        'HagsEnabling'                  = 'Enabling Hardware-Accelerated GPU Scheduling (HAGS)...'
        'HagsEnabled'                   = 'HAGS enabled (reduces CPU-GPU scheduling latency). System restart required.'
        'HagsAlreadyEnabled'            = 'HAGS is already enabled.'

        # MSI Mode
        'MsiEnabling'                   = 'Configuring Message Signaled Interrupts (MSI mode) on display adapters...'
        'MsiEnabledOnDevice'            = 'MSI mode enabled on: {0}'
        'MsiNoDevices'                  = 'No compatible NVIDIA display devices found for MSI configuration.'

        # Game Bar
        'GameBarDisabling'              = 'Disabling Xbox Game Bar and background Game DVR capture...'
        'GameBarDisabled'               = 'Xbox Game Bar and Game DVR background capture disabled.'

        # Power Plan
        'PowerPlanConfiguring'          = 'Configuring Windows High Performance AC power scheme...'
        'PowerPlanActive'               = 'High Performance power scheme activated ({0}).'
        'PowerPlanThrottleConfigured'   = 'Processor minimum throttle set to 5%, maximum set to 100%.'
        'PowerPlanAspmDisabled'         = 'PCIe ASPM disabled for minimum latency.'
        'PowerPlanAspmNotSupported'     = 'PCIe ASPM setting is locked or unavailable on this motherboard firmware.'

        # GPU Power Limit
        'PowerLimitOptimizing'          = 'Tuning GPU power limit target...'
        'PowerLimitAlreadyOptimal'      = 'GPU power limit is already at optimal target ({0} W).'
        'PowerLimitApplying'            = 'Applying GPU power limit: {0} W...'
        'PowerLimitApplied'             = 'GPU power limit successfully configured to {0} W.'
        'PowerLimitVerificationFailed'  = 'GPU power limit verification failed; driver rejected or reverted value. Rolling back to default ({0} W).'
        'PowerLimitRevertedToDefault'   = 'GPU power limit rolled back to factory default: {0} W.'

        # P0 Mode
        'P0ScanningStale'               = 'Scanning for legacy Force-P0 tweaks (DisableDynamicPstate)...'
        'P0StaleRemoved'                = 'Legacy DisableDynamicPstate tweak removed from: {0}'
        'P0NoStaleFound'                = 'No residual DisableDynamicPstate tweaks detected.'
        'P0OptInWarning'                = 'WARNING: Forcing P0 mode prevents GPU core/memory downclocking at idle, increasing power consumption and idle temperatures.'
        'P0Enabling'                    = 'Enabling forced P0 state (DisableDynamicPstate)...'
        'P0Enabled'                     = 'Forced P0 mode enabled on NVIDIA display adapters.'

        # CPU & Core Parking
        'CpuOptimizing'                 = 'Configuring CPU power parameters and core scheduling...'
        'CoreParkingConfigured'         = 'Core parking configured (Minimum active cores: {0}%).'
        'CoreParkingNotSupported'       = 'Core parking setting could not be modified (unsupported by firmware/edition).'
        'BoostModeConfigured'           = 'Processor Boost Mode configured to Efficient Aggressive.'
        'BoostModeNotSupported'         = 'Processor Boost Mode setting could not be modified.'
        'GameModeEnabled'               = 'Windows Game Mode enabled.'

        # MSI Afterburner Profile
        'AfterburnerProfileExported'    = 'MSI Afterburner undervolting guidance generated: {0}'

        # Revert
        'RevertStarting'                = 'Restoring system configuration from backup timestamp: {0}...'
        'RevertNoState'                 = 'No valid previous state found at {0}. Nothing to restore.'
        'RevertCorruptState'            = 'Previous state file is corrupt or unreadable: {0}.'
        'RevertHagsRestored'            = 'HAGS registry configuration restored to previous state ({0}).'
        'RevertMsiRestored'             = 'MSI mode restored for {0} device(s).'
        'RevertGameBarRestored'         = 'Xbox Game Bar / Game DVR configuration restored.'
        'RevertPowerPlanRestored'       = 'Windows power scheme restored to previous scheme ({0}).'
        'RevertPowerLimitRestored'      = 'GPU power limit restored to previous value ({0} W).'
        'RevertP0Restored'              = 'P0 state configuration restored.'
        'RevertCompleted'               = 'System rollback completed successfully. A system restart is recommended.'

        # State Saving
        'StateSaving'                   = 'Persisting optimization snapshot state to: {0}'
        'StateSaved'                    = 'Optimization snapshot state successfully saved.'

        # Post-Run Instructions
        'OptimizationCompleted'         = 'System optimization completed successfully.'
        'RestartRecommended'            = 'RESTART REQUIRED: You must restart your computer for HAGS and MSI changes to take effect.'
    }

    if ($stringCatalog.ContainsKey($Key)) {
        $template = $stringCatalog[$Key]
        if ($Arguments.Count -gt 0) {
            return ($template -f $Arguments)
        }
        return $template
    }

    return "[$Key]"
}
