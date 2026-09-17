$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Enable-PCOP0Mode' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Sets DisableDynamicPstate on NVIDIA driver subkeys' {
            Mock Test-Path { return $true }
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        PSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000'
                    }
                )
            }
            Mock Get-ItemProperty {
                return [PSCustomObject]@{
                    DriverDesc = 'NVIDIA GeForce RTX 3070'
                }
            }
            Mock Set-PCORegistryDword { }

            $res = Enable-PCOP0Mode
            $res.Count | Should -Be 1
            $res[0].Applied | Should -Be 1
            Should -Invoke Set-PCORegistryDword -Times 1 -Exactly
        }
    }
}
