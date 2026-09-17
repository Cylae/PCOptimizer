<#
.SYNOPSIS
    Enables forced P0 performance state on NVIDIA display adapters.
.DESCRIPTION
    Sets DisableDynamicPstate = 1 on detected NVIDIA display adapter driver keys.
    Prints an explicit opt-in warning regarding idle temperatures and fan acoustics.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject[]] Array of modified driver subkeys and prior states.
#>
function Enable-PCOP0Mode {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    Write-PCOLog -Message (Get-PCOString -Key 'P0OptInWarning') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
    Write-PCOLog -Message (Get-PCOString -Key 'P0Enabling') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $classKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $entries = @()

    if ($PSCmdlet.ShouldProcess($classKey, "Enable forced P0 mode (DisableDynamicPstate = 1)")) {
        if (Test-Path -Path $classKey) {
            $subkeys = Get-ChildItem -Path $classKey -ErrorAction SilentlyContinue
            foreach ($key in $subkeys) {
                try {
                    $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
                    if ($props.PSObject.Properties.Name -contains 'DriverDesc' -and $props.DriverDesc -match 'NVIDIA') {
                        $existing = $null
                        if ($props.PSObject.Properties.Name -contains 'DisableDynamicPstate') {
                            $existing = $props.DisableDynamicPstate
                        }

                        $null = Set-PCORegistryDword -Path $key.PSPath -Name 'DisableDynamicPstate' -Value 1
                        $entries += [PSCustomObject]@{
                            Path     = $key.PSPath
                            Previous = $existing
                            Applied  = 1
                        }
                    }
                } catch {
                    Write-PCOLog -Message "Skipped inaccessible subkey $($key.PSChildName): $($_.Exception.Message)" -Level 'DEBUG' -LogFile $LogFile -Quiet:$Quiet
                }
            }
        }

        if ($entries.Count -gt 0) {
            Write-PCOLog -Message (Get-PCOString -Key 'P0Enabled') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        }
    }

    return $entries
}
