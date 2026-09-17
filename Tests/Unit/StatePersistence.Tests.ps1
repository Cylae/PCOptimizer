$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'State Persistence & Validation' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
            $script:tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PCO_Test_$(Get-Random)"
            $null = New-Item -Path $script:tempDir -ItemType Directory -Force
        }

        AfterEach {
            if ($script:tempDir -and (Test-Path -Path $script:tempDir)) {
                Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Saves and serializes state with SchemaVersion 1.0.0' {
            $stateObj = [PSCustomObject]@{
                HAGS = @{ Previous = 1; Applied = 2 }
            }

            $savedFile = Save-PCOState -State $stateObj -BackupPath $script:tempDir
            Test-Path -Path $savedFile | Should -BeTrue

            $loadedState = Get-PCOptimizationState -BackupPath $script:tempDir
            $loadedState.SchemaVersion | Should -Be '1.0.0'
            $loadedState.HAGS.Previous | Should -Be 1
            $loadedState.HAGS.Applied | Should -Be 2
            $loadedState.Timestamp | Should -Not -BeNullOrEmpty
        }

        It 'Returns default state object when state.json is absent' {
            $emptyDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PCO_Empty_$(Get-Random)"
            $state = Get-PCOptimizationState -BackupPath $emptyDir
            $state.SchemaVersion | Should -Be '1.0.0'
            $state.Timestamp | Should -BeNullOrEmpty
        }

        It 'Gracefully recovers when state.json is corrupt and does not throw' {
            $stateFile = Join-Path -Path $script:tempDir -ChildPath 'state.json'
            Set-Content -Path $stateFile -Value "CORRUPTED_NON_JSON_DATA{{{" -Force

            {
                $corruptRecovered = Get-PCOptimizationState -BackupPath $script:tempDir
                $corruptRecovered.SchemaVersion | Should -Be '1.0.0'
                $corruptRecovered.Timestamp | Should -BeNullOrEmpty
            } | Should -Not -Throw
        }
    }
}
