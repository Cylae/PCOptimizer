Describe 'Module Manifest & Import Verification' {
    BeforeAll {
        $script:manifestFullPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
    }

    It 'Validates PCOptimizer.psd1 manifest without errors' {
        { Test-ModuleManifest -Path $script:manifestFullPath.Path } | Should -Not -Throw
        $manifest = Test-ModuleManifest -Path $script:manifestFullPath.Path
        $manifest.Version.ToString() | Should -Be '1.0.0'
        $manifest.Author | Should -Be 'Cylae'
        $manifest.PowerShellVersion.ToString() | Should -Be '7.4'
    }

    It 'Declares all required exported public cmdlets' {
        $manifest = Test-ModuleManifest -Path $script:manifestFullPath.Path
        $expectedFunctions = @(
            'Invoke-PCOptimization',
            'Restore-PCOptimization',
            'Get-PCOptimizationState',
            'Get-NvidiaGpuStatus',
            'Export-MSIAfterburnerProfile',
            'Optimize-Gpu',
            'Optimize-Cpu',
            'Optimize-GamingFeature'
        )

        foreach ($fn in $expectedFunctions) {
            $manifest.ExportedFunctions.Keys | Should -Contain $fn
        }
    }

    It 'Exports the Optimize-PC alias' {
        $manifest = Test-ModuleManifest -Path $script:manifestFullPath.Path
        $manifest.ExportedAliases.Keys | Should -Contain 'Optimize-PC'
    }

    It 'Imports cleanly in Strict Mode with ErrorAction Stop' {
        $scriptBlock = {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = 'Stop'
            $manifestFullPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
            Import-Module -Name $manifestFullPath.Path -Force
        }
        $scriptBlock | Should -Not -Throw
    }
}
