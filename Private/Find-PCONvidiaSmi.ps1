<#
.SYNOPSIS
    Locates the nvidia-smi.exe executable on the system.
.DESCRIPTION
    Searches system PATH and standard NVIDIA installation directories for nvidia-smi.exe.
.OUTPUTS
    [string] Path to nvidia-smi.exe, or $null if not found.
#>
function Find-PCONvidiaSmi {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $cmd = Get-Command -Name 'nvidia-smi' -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -Path $cmd.Source)) {
        return $cmd.Source
    }

    $candidates = @(
        "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
        "$env:WINDIR\System32\nvidia-smi.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    return $null
}
