$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Remove-PCOP0Tweak' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Removes DisableDynamicPstate on NVIDIA subkeys' {
            Mock Test-Path { return $true }
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        PSPath      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000'
                        PSChildName = '0000'
                    }
                )
            }
            Mock Get-ItemProperty {
                return [PSCustomObject]@{
                    DriverDesc            = 'NVIDIA GeForce RTX 3070'
                    DisableDynamicPstate  = 1
                }
            }
            Mock Remove-PCORegistryValue {
                return [PSCustomObject]@{ Path = '...'; Name = 'DisableDynamicPstate'; Removed = $true }
            }

            $res = Remove-PCOP0Tweak
            $res.Count | Should -Be 1
            Should -Invoke Remove-PCORegistryValue -Times 1 -Exactly
        }

        It 'Returns cleanly when no stale P0 tweaks are found' {
            Mock Test-Path { return $true }
            Mock Get-ChildItem { return @() }
            Mock Remove-PCORegistryValue { }

            $res = Remove-PCOP0Tweak
            $res.Count | Should -Be 0
            Should -Invoke Remove-PCORegistryValue -Times 0 -Exactly
        }
    }
}
