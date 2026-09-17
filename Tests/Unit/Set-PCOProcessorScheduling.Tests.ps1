$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Set-PCOProcessorScheduling' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
            Mock Set-PCORegistryDword { }
            Mock Invoke-PCOPowerCfg {
                return [PSCustomObject]@{ ExitCode = 0; Output = ''; Success = $true }
            }
        }

        It 'Sets standard core parking to 10% when AggressiveSilence is omitted' {
            $res = Set-PCOProcessorScheduling
            $res.CoreParkingMinPercent | Should -Be 10
            $res.CoreParkingMaxPercent | Should -Be 100
            $res.BoostMode | Should -Be 4
        }

        It 'Sets aggressive core parking to 5% when AggressiveSilence is specified' {
            $res = Set-PCOProcessorScheduling -AggressiveSilence
            $res.CoreParkingMinPercent | Should -Be 5
            $res.CoreParkingMaxPercent | Should -Be 100
            $res.BoostMode | Should -Be 4
        }
    }
}
