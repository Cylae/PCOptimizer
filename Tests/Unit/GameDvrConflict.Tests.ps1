$modulePath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\PCOptimizer.psd1')
Import-Module -Name $modulePath.Path -Force

Describe 'Game DVR & Game Bar Conflict Regression' {
    InModuleScope 'PCOptimizer' {
        BeforeEach {
            Mock Write-PCOLog { }
            Mock Invoke-PCOPowerCfg { return [PSCustomObject]@{ Success = $true; ExitCode = 0 } }
        }

        It 'Does not re-enable AppCaptureEnabled in Set-PCOProcessorScheduling' {
            $setRegistryCalls = @()
            Mock Set-PCORegistryDword {
                param($Path, $Name, $Value)
                $script:setRegistryCalls += [PSCustomObject]@{
                    Path  = $Path
                    Name  = $Name
                    Value = $Value
                }
            }

            $script:setRegistryCalls = @()
            $null = Set-PCOProcessorScheduling -Quiet

            # Verify that GameMode was enabled without touching AppCaptureEnabled
            $appCaptureWrites = $script:setRegistryCalls | Where-Object { $_.Name -eq 'AppCaptureEnabled' }
            $appCaptureWrites.Count | Should -Be 0

            # Verify GameMode auto switches are still enabled
            $autoGameModeWrites = $script:setRegistryCalls | Where-Object { $_.Name -eq 'AutoGameModeEnabled' }
            $autoGameModeWrites.Count | Should -BeGreaterThan 0
            $autoGameModeWrites[0].Value | Should -Be 1
        }
    }
}
