$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Export-MSIAfterburnerProfile' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
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

        It 'Supports -WhatIf and does not write to disk' {
            $dest = Join-Path -Path $script:tempDir -ChildPath 'MSIAfterburner_WhatIf.txt'
            $null = Export-MSIAfterburnerProfile -DestinationPath $dest -WhatIf
            Test-Path -Path $dest | Should -BeFalse
        }
    }
}
