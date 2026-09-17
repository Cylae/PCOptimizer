$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Security, Input Validation & Regression Battery' {
    InModuleScope 'PCOptimizer' {
        Context 'CSV Telemetry & Formula Injection Hardening' {
            It 'Sanitizes formula injection prefixes in GPU names' {
                $maliciousPayloads = @(
                    "=cmd|' /C calc'!A0, 560.94, 220.00, 220.00, 240.00, 45.0, 1920.0",
                    "@SUM(1+1)*cmd|' /C notepad'!A0, 560.94, 220.00, 220.00, 240.00, 45.0, 1920.0",
                    "-2+3+cmd|' /C calc'!A0, 560.94, 220.00, 220.00, 240.00, 45.0, 1920.0",
                    "+cmd|' /C calc'!A0, 560.94, 220.00, 220.00, 240.00, 45.0, 1920.0"
                )

                foreach ($payload in $maliciousPayloads) {
                    $res = ConvertFrom-PCONvidiaSmiOutput -RawOutput $payload
                    $res.Count | Should -Be 1
                    $res[0].Name.StartsWith("'") | Should -BeTrue
                }
            }

            It 'Properly parses quoted GPU names containing commas without column splitting corruption' {
                $sampleWithComma = '"NVIDIA RTX A5000, 16GB", 560.94, 230.00, 230.00, 250.00, 42.0, 1800.0'
                $res = ConvertFrom-PCONvidiaSmiOutput -RawOutput $sampleWithComma
                $res.Count | Should -Be 1
                $res[0].Name | Should -Be 'NVIDIA RTX A5000, 16GB'
                $res[0].PowerLimit | Should -Be 230.0
                $res[0].MaxLimit | Should -Be 250.0
            }

            It 'Handles [Not Supported] telemetry cleanly when -AllowUnsupported is specified' {
                $unsupportedSample = "NVIDIA GeForce RTX 3050 Laptop GPU, 560.94, [Not Supported], [Not Supported], [Not Supported], 45.0, 1750.0"
                $res = ConvertFrom-PCONvidiaSmiOutput -RawOutput $unsupportedSample -AllowUnsupported
                $res.Count | Should -Be 1
                $res[0].PowerManagementSupported | Should -BeFalse
                $res[0].PowerLimit | Should -Be 0.0
                $res[0].Temperature | Should -Be 45.0
            }

            It 'Still strictly throws FormatException on invalid non-numeric data when AllowUnsupported is absent' {
                $badSample = "NVIDIA GeForce RTX 3070, 560.94, BAD_DATA, 220.00, 240.00, 45.0, 1920.0"
                { ConvertFrom-PCONvidiaSmiOutput -RawOutput $badSample } | Should -Throw -ExceptionType ([System.FormatException])
            }
        }

        Context 'Process Execution & PowerCfg Security' {
            It 'Handles arguments safely without shell injection' {
                $res = Invoke-PCOPowerCfg -Arguments @('/getactivescheme')
                $res | Should -Not -BeNullOrEmpty
                $res.Arguments | Should -Be '/getactivescheme'
            }
        }
    }
}
