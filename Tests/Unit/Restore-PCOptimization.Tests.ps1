$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Restore-PCOptimization' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Returns Success = $false when no state exists to restore' {
            Mock Get-PCOptimizationState {
                return [PSCustomObject]@{
                    Timestamp = $null
                }
            }

            $res = Restore-PCOptimization -BackupPath 'C:\NonExistent'
            $res.Success | Should -BeFalse
        }

        It 'Restores all components from saved state' {
            Mock Get-PCOptimizationState {
                return [PSCustomObject]@{
                    Timestamp = '2026-09-17T05:00:00Z'
                    HAGS      = @{ Previous = 1 }
                    Msi       = @(
                        @{ Path = 'HKLM:\...\MSI'; Name = 'MSISupported'; Previous = 0 }
                    )
                    GameBar   = @(
                        @{ Path = 'HKCU:\...\GameBar'; Name = 'GameDVR_Enabled'; Previous = 1 }
                    )
                    PowerPlan = @{ PreviousSchemeGuid = '381b4222-f694-41f0-9685-ff5bb260df2e' }
                    PowerLimit = @{ PreviousWatts = 220.0 }
                    P0        = @(
                        @{ Path = 'HKLM:\...\0000'; Name = 'DisableDynamicPstate'; Previous = $null }
                    )
                }
            }

            Mock Set-PCORegistryDword { }
            Mock Remove-PCORegistryValue { }
            Mock Restore-PCORegistryState { return 1 }
            Mock Invoke-PCOPowerCfg { return [PSCustomObject]@{ Success = $true } }
            Mock Find-PCONvidiaSmi { return 'C:\Mock\nvidia-smi.exe' }
            Mock Invoke-PCONvidiaSmi { return [PSCustomObject]@{ Success = $true } }

            $res = Restore-PCOptimization -BackupPath 'C:\Mock'
            $res.Success | Should -BeTrue
            $res.RestoredTimestamp | Should -Be '2026-09-17T05:00:00Z'

            Should -Invoke Set-PCORegistryDword -Times 1 -Exactly # For HAGS Previous = 1
            Should -Invoke Invoke-PCOPowerCfg -Times 1 -Exactly # For PowerScheme restore
        }
    }
}
