@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PCOptimizer.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'c7b9e602-0e7d-4a15-b286-90bf9e348981'

    # Author of this module
    Author = 'Cylae'

    # Company or vendor of this module
    CompanyName = 'Cylae'

    # Copyright statement for this module
    Copyright = '(c) 2026 Cylae. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'High-performance, low-noise Windows systems optimization toolkit for gaming and demanding workloads.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.4'

    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-PCOptimization',
        'Restore-PCOptimization',
        'Get-PCOptimizationState',
        'Get-NvidiaGpuStatus',
        'Export-MSIAfterburnerProfile',
        'Optimize-Gpu',
        'Optimize-Cpu',
        'Optimize-GamingFeature',
        'Start-PCOptimizerWizard'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @(
        'Optimize-PC',
        'Optimize-GamingFeatures',
        'Invoke-PCOptimizerCLI'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Windows', 'Optimization', 'Performance', 'NVIDIA', 'Gaming', 'PowerPlan', 'Silence')
            LicenseUri = 'https://github.com/Cylae/PCOptimizer/blob/main/LICENSE'
            ProjectUri = 'https://github.com/Cylae/PCOptimizer'
        }
    }
}
