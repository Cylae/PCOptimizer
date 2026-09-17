$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'ConvertFrom-PCONvidiaSmiOutput' {
    InModuleScope 'PCOptimizer' {
        It 'Parses a valid 7-column nvidia-smi CSV output line' {
            $sample = "NVIDIA GeForce RTX 3070, 560.94, 220.00, 220.00, 240.00, 45.0, 1920.0"
            $res = ConvertFrom-PCONvidiaSmiOutput -RawOutput $sample

            $res.Count | Should -Be 1
            $res[0].Name | Should -Be 'NVIDIA GeForce RTX 3070'
            $res[0].Driver | Should -Be '560.94'
            $res[0].PowerLimit | Should -Be 220.0
            $res[0].DefaultLimit | Should -Be 220.0
            $res[0].MaxLimit | Should -Be 240.0
            $res[0].Temperature | Should -Be 45.0
            $res[0].GraphicsClock | Should -Be 1920.0
        }

        It 'Parses multiple GPU output lines' {
            $samples = @(
                "NVIDIA GeForce RTX 3070, 560.94, 220.00, 220.00, 240.00, 42.0, 1900.0",
                "NVIDIA GeForce RTX 3060, 560.94, 170.00, 170.00, 185.00, 38.0, 1800.0"
            )
            $res = ConvertFrom-PCONvidiaSmiOutput -RawOutput $samples
            $res.Count | Should -Be 2
            $res[0].Name | Should -Be 'NVIDIA GeForce RTX 3070'
            $res[1].Name | Should -Be 'NVIDIA GeForce RTX 3060'
        }

        It 'Throws FormatException when column count is not 7' {
            $badSample = "NVIDIA GeForce RTX 3070, 560.94, 220.00, 220.00"
            { ConvertFrom-PCONvidiaSmiOutput -RawOutput $badSample } | Should -Throw -ExceptionType ([System.FormatException])
        }

        It 'Throws FormatException when a numeric field contains non-numeric data' {
            $badSample = "NVIDIA GeForce RTX 3070, 560.94, NOT_A_NUMBER, 220.00, 240.00, 45.0, 1920.0"
            { ConvertFrom-PCONvidiaSmiOutput -RawOutput $badSample } | Should -Throw -ExceptionType ([System.FormatException])
        }

        It 'Throws ArgumentOutOfRangeException when power limits are below allowable threshold' {
            $badSample = "NVIDIA GeForce RTX 3070, 560.94, 0.00, 220.00, 240.00, 45.0, 1920.0"
            { ConvertFrom-PCONvidiaSmiOutput -RawOutput $badSample } | Should -Throw -ExceptionType ([System.ArgumentOutOfRangeException])
        }

        It 'Returns an empty collection for null or whitespace input without throwing' {
            $res1 = ConvertFrom-PCONvidiaSmiOutput -RawOutput $null
            $res1.Count | Should -Be 0

            $res2 = ConvertFrom-PCONvidiaSmiOutput -RawOutput "   `r`n   "
            $res2.Count | Should -Be 0
        }
    }
}
