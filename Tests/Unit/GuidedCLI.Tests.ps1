$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Start-PCOptimizerWizard & Guided CLI' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-Host { }
            Mock Write-PCOLog { }
            Mock Get-PCOSystemHardware {
                return [PSCustomObject]@{
                    CPU = [PSCustomObject]@{
                        Name       = 'AMD Ryzen 9 5950X'
                        Family     = 'AMD Zen 3 (Ryzen 5000)'
                        Cores      = 16
                        Threads    = 32
                        IsMultiCcd = $true
                        IsX3D      = $false
                        IsHybrid   = $false
                    }
                    GPUs = @(
                        [PSCustomObject]@{
                            Name                     = 'NVIDIA GeForce RTX 3070'
                            Architecture             = 'NVIDIA Ampere (RTX 30-Series)'
                            Driver                   = '560.94'
                            CurrentPowerLimitWatts   = 220
                            DefaultPowerLimitWatts   = 220
                            MaxPowerLimitWatts       = 240
                            PowerManagementSupported = $true
                        }
                    )
                    SystemInfo = [PSCustomObject]@{
                        MachineName = 'TEST-PC'
                        Build       = 22631
                        TotalRamGb  = 32.0
                    }
                }
            }
        }

        It 'Renders help text when -Help switch is provided without executing optimization' {
            Mock Invoke-PCOptimization { }
            $res = Start-PCOptimizerWizard -Help
            $res | Should -BeNullOrEmpty
            Should -Invoke Invoke-PCOptimization -Times 0 -Exactly
        }

        It 'Maps Level 1 to MaxSilence and AggressiveSilence' {
            Mock Invoke-PCOptimization {
                param($MaxSilence, $AggressiveSilence)
                return [PSCustomObject]@{
                    MaxSilence        = $MaxSilence
                    AggressiveSilence = $AggressiveSilence
                }
            }

            $res = Start-PCOptimizerWizard -Level 1 -NonInteractive
            $res.MaxSilence | Should -BeTrue
            $res.AggressiveSilence | Should -BeTrue
        }

        It 'Maps Level 2 to BalancedSilence' {
            Mock Invoke-PCOptimization {
                param($BalancedSilence)
                return [PSCustomObject]@{ BalancedSilence = $BalancedSilence }
            }

            $res = Start-PCOptimizerWizard -Level 2 -NonInteractive
            $res.BalancedSilence | Should -BeTrue
        }

        It 'Maps Level 3 to SilentFactor 0.92' {
            Mock Invoke-PCOptimization {
                param($SilentFactor)
                return [PSCustomObject]@{ SilentFactor = $SilentFactor }
            }

            $res = Start-PCOptimizerWizard -Level 3 -NonInteractive
            $res.SilentFactor | Should -Be 0.92
        }

        It 'Maps Level 4 to SilentFactor 1.0' {
            Mock Invoke-PCOptimization {
                param($SilentFactor)
                return [PSCustomObject]@{ SilentFactor = $SilentFactor }
            }

            $res = Start-PCOptimizerWizard -Level 4 -NonInteractive
            $res.SilentFactor | Should -Be 1.0
        }

        It 'Maps Level 5 to MaxPerf' {
            Mock Invoke-PCOptimization {
                param($MaxPerf)
                return [PSCustomObject]@{ MaxPerf = $MaxPerf }
            }

            $res = Start-PCOptimizerWizard -Level 5 -NonInteractive
            $res.MaxPerf | Should -BeTrue
        }

        It 'Correctly translates continuous SilenceBias percentage to discrete levels' {
            Mock Invoke-PCOptimization {
                param($MaxSilence)
                return [PSCustomObject]@{ MaxSilence = $MaxSilence }
            }

            $res = Start-PCOptimizerWizard -SilenceBias 90 -NonInteractive
            $res.MaxSilence | Should -BeTrue
        }

        It 'Dispatches to Restore-PCOptimization when -Revert switch is provided' {
            Mock Restore-PCOptimization {
                return [PSCustomObject]@{ Success = $true; RestoredTimestamp = '2026-09-17' }
            }

            $res = Start-PCOptimizerWizard -Revert -NonInteractive
            $res.Success | Should -BeTrue
            Should -Invoke Restore-PCOptimization -Times 1 -Exactly
        }
    }
}
