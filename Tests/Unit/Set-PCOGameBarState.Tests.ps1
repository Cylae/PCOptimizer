$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Set-PCOGameBarState' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Disables GameDVR registry keys and captures previous values' {
            Mock Test-Path { return $true }
            Mock Get-ItemProperty {
                return [PSCustomObject]@{
                    GameDVR_Enabled   = 1
                    AppCaptureEnabled = 1
                    AllowGameDVR      = 1
                }
            }
            Mock Set-PCORegistryDword { }

            $res = Set-PCOGameBarState
            $res.Count | Should -Be 3
            Should -Invoke Set-PCORegistryDword -Times 3 -Exactly
        }

        It 'Honors -WhatIf without making real registry modifications' {
            Mock Test-Path { return $true }
            Mock Get-ItemProperty { return [PSCustomObject]@{ GameDVR_Enabled = 1 } }
            Mock Set-ItemProperty { }

            $res = Set-PCOGameBarState -WhatIf
            $res.Count | Should -Be 0
            Should -Invoke Set-ItemProperty -Times 0 -Exactly
        }
    }
}
