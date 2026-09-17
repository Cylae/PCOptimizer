<#
.SYNOPSIS
    Enables Hardware-Accelerated GPU Scheduling (HAGS).
.DESCRIPTION
    Configures the HwSchMode DWORD registry value to 2 under the GraphicsDrivers registry key.
    Records previous state for rollback.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Captures the previous and applied HAGS state.
#>
function Enable-PCOHags {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'HAGS is an acronym for Hardware-Accelerated GPU Scheduling')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $graphicsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    Write-PCOLog -Message (Get-PCOString -Key 'HagsEnabling') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $existing = $null
    if (Test-Path -Path $graphicsKey) {
        try {
            $item = Get-ItemProperty -Path $graphicsKey -Name 'HwSchMode' -ErrorAction Stop
            if ($item.PSObject.Properties.Name -contains 'HwSchMode') {
                $existing = $item.HwSchMode
            }
        } catch {
            $existing = $null
        }
    }

    if ($existing -eq 2) {
        Write-PCOLog -Message (Get-PCOString -Key 'HagsAlreadyEnabled') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        return [PSCustomObject]@{
            Previous = $existing
            Applied  = 2
        }
    }

    if ($PSCmdlet.ShouldProcess($graphicsKey, "Set HwSchMode = 2 (Enable HAGS)")) {
        $null = Set-PCORegistryDword -Path $graphicsKey -Name 'HwSchMode' -Value 2
        Write-PCOLog -Message (Get-PCOString -Key 'HagsEnabled') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    return [PSCustomObject]@{
        Previous = $existing
        Applied  = 2
    }
}
