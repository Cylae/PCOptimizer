$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Enable-PCOHags' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Captures previous HAGS state and applies HwSchMode = 2' {
            Mock Test-Path { return $true }
            Mock Get-ItemProperty {
                return [PSCustomObject]@{ HwSchMode = 1 }
            }
            Mock Set-PCORegistryDword {
                return [PSCustomObject]@{ Path = 'HKLM:\...'; Name = 'HwSchMode'; Previous = 1; Applied = 2 }
            }

            $res = Enable-PCOHags
            $res.Previous | Should -Be 1
            $res.Applied | Should -Be 2
            Should -Invoke Set-PCORegistryDword -Times 1 -Exactly
        }

        It 'Is idempotent when HAGS is already enabled (HwSchMode = 2)' {
            Mock Test-Path { return $true }
            Mock Get-ItemProperty {
                return [PSCustomObject]@{ HwSchMode = 2 }
            }
            Mock Set-PCORegistryDword { }

            $res = Enable-PCOHags
            $res.Previous | Should -Be 2
            $res.Applied | Should -Be 2
            Should -Invoke Set-PCORegistryDword -Times 0 -Exactly
        }

        It 'Supports -WhatIf without side effects' {
            Mock Test-Path { return $true }
            Mock Get-ItemProperty { return [PSCustomObject]@{ HwSchMode = 1 } }
            Mock Set-ItemProperty { }

            $res = Enable-PCOHags -WhatIf
            $res.Applied | Should -Be 2
            Should -Invoke Set-ItemProperty -Times 0 -Exactly
        }
    }
}
