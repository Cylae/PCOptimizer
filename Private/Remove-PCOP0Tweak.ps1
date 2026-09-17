<#
.SYNOPSIS
    Removes legacy or stale DisableDynamicPstate (forced P0) registry tweaks.
.DESCRIPTION
    Scans the Windows display class keys for NVIDIA driver installations and removes
    the DisableDynamicPstate value if present, returning the GPU to standard dynamic P-states.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [string[]] Paths from which DisableDynamicPstate was removed.
#>
function Remove-PCOP0Tweak {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    Write-PCOLog -Message (Get-PCOString -Key 'P0ScanningStale') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $classKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $cleanedPaths = @()

    if ($PSCmdlet.ShouldProcess($classKey, "Scan and remove residual DisableDynamicPstate tweaks")) {
        if (Test-Path -Path $classKey) {
            $subkeys = Get-ChildItem -Path $classKey -ErrorAction SilentlyContinue
            foreach ($key in $subkeys) {
                try {
                    $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
                    if ($props.PSObject.Properties.Name -contains 'DriverDesc' -and
                        $props.DriverDesc -match 'NVIDIA' -and
                        $props.PSObject.Properties.Name -contains 'DisableDynamicPstate') {

                        $remRes = Remove-PCORegistryValue -Path $key.PSPath -Name 'DisableDynamicPstate'
                        if ($remRes.Removed) {
                            $cleanedPaths += $key.PSPath
                            Write-PCOLog -Message (Get-PCOString -Key 'P0StaleRemoved' -Arguments @($key.PSChildName)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
                        }
                    }
                } catch {
                    Write-PCOLog -Message "Skipped inaccessible subkey $($key.PSChildName): $($_.Exception.Message)" -Level 'DEBUG' -LogFile $LogFile -Quiet:$Quiet
                }
            }
        }

        if ($cleanedPaths.Count -eq 0) {
            Write-PCOLog -Message (Get-PCOString -Key 'P0NoStaleFound') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        }
    }

    return $cleanedPaths
}
