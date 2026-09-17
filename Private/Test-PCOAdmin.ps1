<#
.SYNOPSIS
    Tests whether the current PowerShell session has elevated Administrator privileges.
.DESCRIPTION
    Inspects the Windows Principal token to determine if the user belongs to the Built-In Administrator role.
.OUTPUTS
    [bool] $true if elevated; otherwise $false.
#>
function Test-PCOAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not $IsWindows) {
        return $false
    }

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}
