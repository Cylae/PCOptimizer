$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Set-PCONvidiaPowerLimit' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Test-Path { return $true }
            Mock Start-Sleep { }
            Mock Write-PCOLog { }
        }

        It 'Applies power limit target when verification succeeds' {
            Mock Invoke-PCONvidiaSmi {
                param($SmiPath, $Arguments)
                $argStr = $Arguments -join ' '
                if ($argStr -like '*--query-gpu*') {
                    return [PSCustomObject]@{
                        ExitCode = 0
                        Output   = @("NVIDIA GeForce RTX 3070, 560.94, 202.00, 220.00, 240.00, 42.0, 1900.0")
                        Success  = $true
                    }
                }
                return [PSCustomObject]@{ ExitCode = 0; Output = @("Power limit set"); Success = $true }
            }

            $res = Set-PCONvidiaPowerLimit -SmiPath 'C:\Mock\nvidia-smi.exe' -TargetWatts 202.4 -DefaultWatts 220.0 -VerificationDelaySeconds 0
            $res.Success | Should -BeTrue
            $res.RolledBack | Should -BeFalse
            $res.AppliedWatts | Should -Be 202.0
        }

        It 'Triggers rollback to default limit when verification fails' {
            Mock Invoke-PCONvidiaSmi {
                param($SmiPath, $Arguments)
                $argStr = $Arguments -join ' '
                if ($argStr -like '*--query-gpu*') {
                    return [PSCustomObject]@{
                        ExitCode = 0
                        Output   = @("NVIDIA GeForce RTX 3070, 560.94, 220.00, 220.00, 240.00, 42.0, 1900.0")
                        Success  = $true
                    }
                }
                return [PSCustomObject]@{ ExitCode = 0; Output = @("OK"); Success = $true }
            }

            $res = Set-PCONvidiaPowerLimit -SmiPath 'C:\Mock\nvidia-smi.exe' -TargetWatts 202.0 -DefaultWatts 220.0 -VerificationDelaySeconds 0
            $res.Success | Should -BeFalse
            $res.RolledBack | Should -BeTrue
            $res.AppliedWatts | Should -Be 220.0
        }

        It 'Supports -WhatIf and makes no system modifications' {
            $res = Set-PCONvidiaPowerLimit -SmiPath 'C:\Mock\nvidia-smi.exe' -TargetWatts 202.0 -DefaultWatts 220.0 -VerificationDelaySeconds 0 -WhatIf
            $res.Success | Should -BeTrue
            $res.RolledBack | Should -BeFalse
        }
    }
}
