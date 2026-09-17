$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Invoke-PCOptimization' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
            Mock Write-Host { }
            $script:tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PCO_Main_$(Get-Random)"
            $null = New-Item -Path $script:tempDir -ItemType Directory -Force
        }

        AfterEach {
            if ($script:tempDir -and (Test-Path -Path $script:tempDir)) {
                Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Rejects out-of-range SilentFactor values' {
            { Invoke-PCOptimization -SilentFactor 0.0 -BackupPath $script:tempDir } | Should -Throw
            { Invoke-PCOptimization -SilentFactor 1.5 -BackupPath $script:tempDir } | Should -Throw
        }

        It 'Throws SecurityException when running without elevation' {
            Mock Test-PCOPlatform { return [PSCustomObject]@{ IsSupported = $true } }
            Mock Test-PCOAdmin { return $false }

            { Invoke-PCOptimization -BackupPath $script:tempDir } | Should -Throw -ExceptionType ([System.Security.SecurityException])
        }

        It 'Throws PlatformNotSupportedException on unsupported platforms' {
            Mock Test-PCOPlatform { return [PSCustomObject]@{ IsSupported = $false; Message = 'Non-Windows OS' } }

            { Invoke-PCOptimization -BackupPath $script:tempDir } | Should -Throw -ExceptionType ([System.PlatformNotSupportedException])
        }

        It 'Executes complete optimization workflow when elevated' {
            Mock Test-PCOPlatform { return [PSCustomObject]@{ IsSupported = $true } }
            Mock Test-PCOAdmin { return $true }
            Mock Optimize-Gpu { param($State) return $State }
            Mock Optimize-GamingFeature { param($State) return $State }
            Mock Optimize-Cpu { param($State) return $State }
            Mock Export-MSIAfterburnerProfile { return 'mock.txt' }
            Mock Save-PCOState { return 'state.json' }

            $res = Invoke-PCOptimization -BackupPath $script:tempDir -Quiet
            $res | Should -Not -BeNullOrEmpty
            Should -Invoke Optimize-Gpu -Times 1 -Exactly
            Should -Invoke Optimize-GamingFeature -Times 1 -Exactly
            Should -Invoke Optimize-Cpu -Times 1 -Exactly
            Should -Invoke Save-PCOState -Times 1 -Exactly
        }

        It 'Is idempotent when executed multiple consecutive times' {
            Mock Test-PCOPlatform { return [PSCustomObject]@{ IsSupported = $true } }
            Mock Test-PCOAdmin { return $true }
            Mock Optimize-Gpu { param($State) return $State }
            Mock Optimize-GamingFeature { param($State) return $State }
            Mock Optimize-Cpu { param($State) return $State }
            Mock Export-MSIAfterburnerProfile { return 'mock.txt' }
            Mock Save-PCOState { return 'state.json' }

            {
                Invoke-PCOptimization -BackupPath $script:tempDir -Quiet
                Invoke-PCOptimization -BackupPath $script:tempDir -Quiet
            } | Should -Not -Throw
        }

        It 'Directs to Restore-PCOptimization when -Revert switch is supplied' {
            Mock Test-PCOPlatform { return [PSCustomObject]@{ IsSupported = $true } }
            Mock Test-PCOAdmin { return $true }
            Mock Restore-PCOptimization {
                return [PSCustomObject]@{ Success = $true; RestoredTimestamp = '2026-09-17' }
            }

            $res = Invoke-PCOptimization -Revert -BackupPath $script:tempDir -Quiet
            $res.Success | Should -BeTrue
            Should -Invoke Restore-PCOptimization -Times 1 -Exactly
        }
    }
}
