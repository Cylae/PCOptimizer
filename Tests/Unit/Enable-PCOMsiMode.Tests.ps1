$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Enable-PCOMsiMode' {
    InModuleScope 'PCOptimizer' {
        if (-not (Get-Command -Name 'Get-PnpDevice' -ErrorAction SilentlyContinue)) {
            function script:Get-PnpDevice { }
        }

        BeforeEach {
            Mock Write-PCOLog { }
        }

        It 'Enables MSI mode on detected NVIDIA display adapters' {
            Mock Get-PnpDevice {
                return @(
                    [PSCustomObject]@{
                        InstanceId   = 'PCI\VEN_10DE&DEV_2484&SUBSYS_00000000&REV_A1\4&12345678&0&0008'
                        FriendlyName = 'NVIDIA GeForce RTX 3070'
                    }
                )
            }
            Mock Test-Path { return $true }
            Mock Get-ItemProperty { return [PSCustomObject]@{ MSISupported = 0 } }
            Mock Set-PCORegistryDword { }

            $entries = Enable-PCOMsiMode
            $entries.Count | Should -Be 1
            $entries[0].DeviceName | Should -Be 'NVIDIA GeForce RTX 3070'
            $entries[0].Previous | Should -Be 0
            $entries[0].Applied | Should -Be 1
            Should -Invoke Set-PCORegistryDword -Times 1 -Exactly
        }

        It 'Degrades gracefully when no NVIDIA devices are present' {
            Mock Get-PnpDevice { return @() }
            Mock Set-PCORegistryDword { }

            $entries = Enable-PCOMsiMode
            $entries.Count | Should -Be 0
            Should -Invoke Set-PCORegistryDword -Times 0 -Exactly
        }
    }
}
