<#
.SYNOPSIS
    Safely removes a value property from the Windows Registry with prior value capture.
.DESCRIPTION
    Reads the value before removal and honors -WhatIf / -Confirm.
.PARAMETER Path
    The registry key path.
.PARAMETER Name
    The registry value name to delete.
.OUTPUTS
    [PSCustomObject] Object capturing Path, Name, Previous value, and whether it was removed.
#>
function Remove-PCORegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Name
    )

    $previous = $null
    $exists = $false
    if (Test-Path -Path $Path) {
        try {
            $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            if ($item.PSObject.Properties.Name -contains $Name) {
                $previous = $item.$Name
                $exists = $true
            }
        } catch {
            $previous = $null
        }
    }

    $removed = $false
    if ($exists) {
        if ($PSCmdlet.ShouldProcess($Path, "Remove value property '$Name'")) {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
            $removed = $true
        }
    }

    return [PSCustomObject]@{
        Path     = $Path
        Name     = $Name
        Previous = $previous
        Removed  = $removed
    }
}
