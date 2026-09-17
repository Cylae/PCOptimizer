<#
.SYNOPSIS
    Safely writes a DWORD value to the Windows Registry with prior value capture.
.DESCRIPTION
    Reads any existing value before modification to ensure complete reversibility,
    creates the parent key path if missing, and honors -WhatIf / -Confirm.
.PARAMETER Path
    The registry key path (e.g., 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').
.PARAMETER Name
    The registry value name.
.PARAMETER Value
    The integer DWORD value to set.
.OUTPUTS
    [PSCustomObject] Object capturing Path, Name, Previous value, and Applied value.
#>
function Set-PCORegistryDword {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 2)]
        [int]$Value
    )

    $previous = $null
    if (Test-Path -Path $Path) {
        try {
            $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            if ($item.PSObject.Properties.Name -contains $Name) {
                $previous = $item.$Name
            }
        } catch {
            $previous = $null
        }
    }

    if ($PSCmdlet.ShouldProcess($Path, "Set DWORD value '$Name' = $Value")) {
        if (-not (Test-Path -Path $Path)) {
            $null = New-Item -Path $Path -Force
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    }

    return [PSCustomObject]@{
        Path     = $Path
        Name     = $Name
        Previous = $previous
        Applied  = $Value
    }
}
