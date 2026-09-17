$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Universal Hardware Detection & Architecture Classification' {
    InModuleScope 'PCOptimizer' {
        Context 'CPU Architecture Classification' {
            It 'Correctly classifies AMD Ryzen 9 5950X as Zen 3 Dual-CCD' {
                Mock Get-CimInstance {
                    param($ClassName)
                    if ($ClassName -eq 'Win32_Processor') {
                        return [PSCustomObject]@{
                            Name                      = 'AMD Ryzen 9 5950X 16-Core Processor'
                            Manufacturer              = 'AuthenticAMD'
                            NumberOfCores             = 16
                            NumberOfLogicalProcessors = 32
                        }
                    }
                    if ($ClassName -eq 'Win32_ComputerSystem') {
                        return [PSCustomObject]@{ TotalPhysicalMemory = 64GB }
                    }
                    return @()
                }

                $hw = Get-PCOSystemHardware
                $hw.CPU.Vendor | Should -Be 'AMD'
                $hw.CPU.Family | Should -Be 'AMD Zen 3 (Ryzen 5000)'
                $hw.CPU.Cores | Should -Be 16
                $hw.CPU.Threads | Should -Be 32
                $hw.CPU.IsMultiCcd | Should -BeTrue
                $hw.CPU.IsX3D | Should -BeFalse
            }

            It 'Correctly classifies AMD Ryzen 7 7800X3D as Zen 4 3D V-Cache' {
                Mock Get-CimInstance {
                    param($ClassName)
                    if ($ClassName -eq 'Win32_Processor') {
                        return [PSCustomObject]@{
                            Name                      = 'AMD Ryzen 7 7800X3D 8-Core Processor'
                            Manufacturer              = 'AuthenticAMD'
                            NumberOfCores             = 8
                            NumberOfLogicalProcessors = 16
                        }
                    }
                    return @()
                }

                $hw = Get-PCOSystemHardware
                $hw.CPU.Vendor | Should -Be 'AMD'
                $hw.CPU.Family | Should -Be 'AMD Zen 4 (Ryzen 7000/8000)'
                $hw.CPU.IsX3D | Should -BeTrue
                $hw.CPU.IsMultiCcd | Should -BeFalse
            }

            It 'Correctly classifies Intel Core i9-14900K as Hybrid Raptor Lake' {
                Mock Get-CimInstance {
                    param($ClassName)
                    if ($ClassName -eq 'Win32_Processor') {
                        return [PSCustomObject]@{
                            Name                      = 'Intel(R) Core(TM) i9-14900K'
                            Manufacturer              = 'GenuineIntel'
                            NumberOfCores             = 24
                            NumberOfLogicalProcessors = 32
                        }
                    }
                    return @()
                }

                $hw = Get-PCOSystemHardware
                $hw.CPU.Vendor | Should -Be 'Intel'
                $hw.CPU.Family | Should -Be 'Intel Core 13th/14th Gen (Raptor Lake / Refresh)'
                $hw.CPU.IsHybrid | Should -BeTrue
            }

            It 'Correctly classifies Intel Core Ultra 9 285K as Arrow Lake' {
                Mock Get-CimInstance {
                    param($ClassName)
                    if ($ClassName -eq 'Win32_Processor') {
                        return [PSCustomObject]@{
                            Name                      = 'Intel(R) Core(TM) Ultra 9 285K'
                            Manufacturer              = 'GenuineIntel'
                            NumberOfCores             = 24
                            NumberOfLogicalProcessors = 24
                        }
                    }
                    return @()
                }

                $hw = Get-PCOSystemHardware
                $hw.CPU.Vendor | Should -Be 'Intel'
                $hw.CPU.Family | Should -Be 'Intel Core Ultra (Series 2 / Arrow Lake)'
                $hw.CPU.IsHybrid | Should -BeTrue
            }
        }

        Context 'GPU Classification & Architecture Calibration' {
            It 'Classifies NVIDIA Ada Lovelace RTX 4090 and assigns appropriate V/F curve' {
                Mock Find-PCONvidiaSmi { return 'mock-smi.exe' }
                Mock Test-Path { return $true }
                Mock Invoke-PCONvidiaSmi {
                    return [PSCustomObject]@{
                        Success = $true
                        ExitCode = 0
                        Output  = "NVIDIA GeForce RTX 4090, 560.94, 450.00, 450.00, 500.00, 42.0, 2750.0"
                    }
                }
                Mock Get-CimInstance { return @() }

                $hw = Get-PCOSystemHardware
                $hw.GPUs.Count | Should -Be 1
                $gpu = $hw.GPUs[0]
                $gpu.Architecture | Should -Be 'NVIDIA Ada Lovelace (RTX 40-Series)'
                $gpu.RecommendedUndervolt.TargetVoltageMv | Should -Be 975
                $gpu.RecommendedUndervolt.TargetClockMhz | Should -Be 2750
            }

            It 'Classifies NVIDIA Blackwell RTX 5090 and assigns futureproof V/F curve' {
                Mock Find-PCONvidiaSmi { return 'mock-smi.exe' }
                Mock Test-Path { return $true }
                Mock Invoke-PCONvidiaSmi {
                    return [PSCustomObject]@{
                        Success = $true
                        ExitCode = 0
                        Output  = "NVIDIA GeForce RTX 5090, 600.12, 600.00, 600.00, 650.00, 40.0, 2850.0"
                    }
                }
                Mock Get-CimInstance { return @() }

                $hw = Get-PCOSystemHardware
                $hw.GPUs.Count | Should -Be 1
                $gpu = $hw.GPUs[0]
                $gpu.Architecture | Should -Be 'NVIDIA Blackwell (RTX 50-Series)'
                $gpu.RecommendedUndervolt.TargetVoltageMv | Should -Be 950
                $gpu.RecommendedUndervolt.TargetClockMhz | Should -Be 2850
            }
        }

        Context 'Hardware Spec Database & Fallback' {
            It 'Finds known GPU specifications from internal database' {
                $spec = Find-PCOHardwareSpec -ComponentName 'RTX 4080 SUPER'
                $spec.Vendor | Should -Be 'NVIDIA'
                $spec.Architecture | Should -Be 'Ada Lovelace'
                $spec.StockTdpWatts | Should -Be 320.0
                $spec.SilentTdpWatts | Should -Be 260.0
            }

            It 'Finds AMD Radeon RX 7900 XTX specifications' {
                $spec = Find-PCOHardwareSpec -ComponentName 'Radeon RX 7900 XTX'
                $spec.Vendor | Should -Be 'AMD'
                $spec.Architecture | Should -Be 'RDNA 3'
                $spec.StockTdpWatts | Should -Be 355.0
            }

            It 'Provides sensible heuristic fallback for future or unknown hardware' {
                $spec = Find-PCOHardwareSpec -ComponentName 'Future GeForce RTX 6090'
                $spec.Vendor | Should -Be 'NVIDIA'
                $spec.StockTdpWatts | Should -Be 220.0
                $spec.Source | Should -Be 'HeuristicEstimator'
            }
        }
    }
}
