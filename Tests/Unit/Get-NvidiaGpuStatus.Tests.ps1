$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Get-NvidiaGpuStatus' {
    InModuleScope 'PCOptimizer' {
        Context 'When nvidia-smi is not found on the system' {
            It 'Gracefully returns $null without throwing an error' {
                Mock Find-PCONvidiaSmi { return $null }
                $res = Get-NvidiaGpuStatus
                $res | Should -BeNullOrEmpty
            }
        }

        Context 'When nvidia-smi is present and returns valid telemetry' {
            It 'Parses and attaches SmiPath to returned GPU objects' {
                Mock Find-PCONvidiaSmi { return 'C:\Mock\nvidia-smi.exe' }
                Mock Test-Path { return $true }
                Mock Invoke-PCONvidiaSmi {
                    return [PSCustomObject]@{
                        ExitCode = 0
                        Output   = @("NVIDIA GeForce RTX 3070, 560.94, 220.00, 220.00, 240.00, 40.0, 1800.0")
                        Success  = $true
                    }
                }

                $res = Get-NvidiaGpuStatus -SmiPath 'C:\Mock\nvidia-smi.exe'
                $res | Should -Not -BeNullOrEmpty
                $res.Count | Should -Be 1
                $res[0].Name | Should -Be 'NVIDIA GeForce RTX 3070'
                $res[0].SmiPath | Should -Be 'C:\Mock\nvidia-smi.exe'
            }
        }
    }
}
