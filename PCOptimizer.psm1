#Requires -Version 7.4

# Dot-source all internal helper scripts from Private/
$privateScripts = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($script in $privateScripts) {
    . $script.FullName
}

# Dot-source all public cmdlet scripts from Public/
$publicScripts = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($script in $publicScripts) {
    . $script.FullName
}

# Export functions and aliases
Export-ModuleMember -Function @(
    'Invoke-PCOptimization',
    'Restore-PCOptimization',
    'Get-PCOptimizationState',
    'Get-NvidiaGpuStatus',
    'Export-MSIAfterburnerProfile',
    'Optimize-Gpu',
    'Optimize-Cpu',
    'Optimize-GamingFeature',
    'Start-PCOptimizerWizard'
) -Alias @(
    'Optimize-PC',
    'Optimize-GamingFeatures',
    'Invoke-PCOptimizerCLI'
)
