$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Set-PCOPowerPlan' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Captures active power scheme and activates High Performance scheme' {
            $mockOutput = "Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)"
            Mock Invoke-PCOPowerCfg {
                param($Arguments)
                $argString = $Arguments -join ' '
                if ($argString -like '*/getactivescheme*') {
                    return [PSCustomObject]@{ ExitCode = 0; Output = $mockOutput; Success = $true }
                }
                return [PSCustomObject]@{ ExitCode = 0; Output = ''; Success = $true }
            }

            $res = Set-PCOPowerPlan
            $res.PreviousSchemeGuid | Should -Be '381b4222-f694-41f0-9685-ff5bb260df2e'
            $res.AppliedSchemeGuid | Should -Be '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            $res.AspmDisabled | Should -BeTrue
        }

        It 'Handles ASPM locked or unsupported failure gracefully without throwing' {
            Mock Invoke-PCOPowerCfg {
                param($Arguments)
                $argString = $Arguments -join ' '
                if ($argString -like '*SUB_PCIEXPRESS*ASPM*') {
                    return [PSCustomObject]@{ ExitCode = 1; Output = 'Error setting value'; Success = $false }
                }
                return [PSCustomObject]@{ ExitCode = 0; Output = 'Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e'; Success = $true }
            }

            $res = Set-PCOPowerPlan
            $res.AspmDisabled | Should -BeFalse
        }
    }
}
