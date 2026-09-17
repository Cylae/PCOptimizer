$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Write-PCOLog' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            $script:tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PCO_Log_$(Get-Random)"
            $null = New-Item -Path $script:tempDir -ItemType Directory -Force
        }

        AfterEach {
            if ($script:tempDir -and (Test-Path -Path $script:tempDir)) {
                Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Appends formatted message to log file' {
            $logFile = Join-Path -Path $script:tempDir -ChildPath 'test.log'
            Write-PCOLog -Message 'Unit test message' -Level 'INFO' -LogFile $logFile -Quiet

            Test-Path -Path $logFile | Should -BeTrue
            $content = Get-Content -Path $logFile -Raw
            $content | Should -Match '\[INFO\] Unit test message'
        }

        It 'Suppresses console output when -Quiet is enabled for non-error levels' {
            Mock Write-Host { }
            Write-PCOLog -Message 'Silent info' -Level 'INFO' -Quiet
            Should -Invoke Write-Host -Times 0 -Exactly
        }

        It 'Displays error messages even when -Quiet is enabled' {
            Mock Write-Host { }
            Write-PCOLog -Message 'Critical failure' -Level 'ERROR' -Quiet
            Should -Invoke Write-Host -Times 1 -Exactly
        }
    }
}
