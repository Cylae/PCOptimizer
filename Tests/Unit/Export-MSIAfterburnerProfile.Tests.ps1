$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Export-MSIAfterburnerProfile' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
            Mock Get-PCOSystemHardware {
                return [PSCustomObject]@{
                    CPU = [PSCustomObject]@{
                        Name = 'AMD Ryzen 9 5950X 16-Core Processor'
                        Family = 'AMD Zen 3 (Ryzen 5000)'
                        Vendor = 'AMD'
                    }
                    GPUs = @(
                        [PSCustomObject]@{
                            Name = 'NVIDIA GeForce RTX 3070'
                            Vendor = 'NVIDIA'
                            Architecture = 'NVIDIA Ampere (RTX 30-Series)'
                            RecommendedUndervolt = [PSCustomObject]@{
                                MinVoltageMv = 900
                                TargetVoltageMv = 925
                                MinClockMhz = 1900
                                TargetClockMhz = 1950
                                MemoryOffsetMhz = 500
                                Notes = 'Ampere Samsung 8N node achieves dramatic acoustic silence at 900-925 mV @ 1900-1950 MHz.'
                            }
                        }
                    )
                }
            }
            $script:tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PCO_AB_$(Get-Random)"
            $null = New-Item -Path $script:tempDir -ItemType Directory -Force
        }

        AfterEach {
            if ($script:tempDir -and (Test-Path -Path $script:tempDir)) {
                Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Generates Afterburner tuning guidance with recommended targets' {
            $dest = Join-Path -Path $script:tempDir -ChildPath 'MSIAfterburner_Profile.txt'
            $exportedPath = Export-MSIAfterburnerProfile -DestinationPath $dest
            Test-Path -Path $exportedPath | Should -BeTrue

            $content = Get-Content -Path $exportedPath -Raw
            $content | Should -Match '900 mV - 925 mV'
            $content | Should -Match '1900 MHz - 1950 MHz'
            $content | Should -Match 'Curve Editor'
        }

        It 'Generates baseline Afterburner guidance when no GPU is detected on host' {
            Mock Get-PCOSystemHardware {
                return [PSCustomObject]@{
                    CPU  = [PSCustomObject]@{ Name = 'Generic CPU'; Vendor = 'Generic' }
                    GPUs = @()
                }
            }

            $dest = Join-Path -Path $script:tempDir -ChildPath 'MSIAfterburner_NoGpu.txt'
            $exportedPath = Export-MSIAfterburnerProfile -DestinationPath $dest
            Test-Path -Path $exportedPath | Should -BeTrue

            $content = Get-Content -Path $exportedPath -Raw
            $content | Should -Match '900 mV - 925 mV'
            $content | Should -Match '1900 MHz - 1950 MHz'
            $content | Should -Match 'Curve Editor'
        }

        It 'Adapts guidance when an AMD Radeon GPU is configured' {
            $amdGpu = [PSCustomObject]@{
                Name = 'AMD Radeon RX 7900 XTX'
                Vendor = 'AMD'
                Architecture = 'AMD RDNA 3 (Radeon RX 7000-Series)'
                RecommendedUndervolt = [PSCustomObject]@{
                    MinVoltageMv = 1000
                    TargetVoltageMv = 1050
                    MinClockMhz = 2450
                    TargetClockMhz = 2500
                    MemoryOffsetMhz = 0
                    Notes = 'Use AMD Software Adrenalin: Voltage offset -40 mV to -70 mV.'
                }
            }

            $dest = Join-Path -Path $script:tempDir -ChildPath 'MSIAfterburner_AMD.txt'
            $exportedPath = Export-MSIAfterburnerProfile -DestinationPath $dest -GpuInfo $amdGpu
            Test-Path -Path $exportedPath | Should -BeTrue

            $content = Get-Content -Path $exportedPath -Raw
            $content | Should -Match '1000 mV - 1050 mV'
            $content | Should -Match 'AMD SOFTWARE: ADRENALIN EDITION'
        }

        It 'Adapts guidance when an Intel Arc GPU is configured' {
            $arcGpu = [PSCustomObject]@{
                Name = 'Intel Arc A770'
                Vendor = 'Intel'
                Architecture = 'Intel Arc Alchemist (A-Series)'
                RecommendedUndervolt = [PSCustomObject]@{
                    MinVoltageMv = 900
                    TargetVoltageMv = 950
                    MinClockMhz = 2100
                    TargetClockMhz = 2200
                    MemoryOffsetMhz = 0
                    Notes = 'Use Intel Arc Control: Voltage offset -30 mV.'
                }
            }

            $dest = Join-Path -Path $script:tempDir -ChildPath 'MSIAfterburner_Arc.txt'
            $exportedPath = Export-MSIAfterburnerProfile -DestinationPath $dest -GpuInfo $arcGpu
            Test-Path -Path $exportedPath | Should -BeTrue

            $content = Get-Content -Path $exportedPath -Raw
            $content | Should -Match 'INTEL ARC CONTROL'
        }

        It 'Supports -WhatIf and does not write to disk' {
            $dest = Join-Path -Path $script:tempDir -ChildPath 'MSIAfterburner_WhatIf.txt'
            $null = Export-MSIAfterburnerProfile -DestinationPath $dest -WhatIf
            Test-Path -Path $dest | Should -BeFalse
        }
    }
}
