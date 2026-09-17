<#
.SYNOPSIS
    Tests whether the current platform and OS build meet PCOptimizer system requirements.
.DESCRIPTION
    Ensures execution is occurring on Windows 10 build 19044 (21H2) or higher, including Windows 11.
.OUTPUTS
    [PSCustomObject] containing compatibility status and OS version metrics.
#>
function Test-PCOPlatform {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if (-not $IsWindows) {
        return [PSCustomObject]@{
            IsSupported = $false
            OSVersion   = [System.Environment]::OSVersion.VersionString
            Build       = 0
            Message     = (Get-PCOString -Key 'NonWindowsPlatform')
        }
    }

    $osVersion = [System.Environment]::OSVersion.Version
    $build = $osVersion.Build

    # Windows 10 21H2 is build 19044. Windows 11 is build 22000+.
    $minBuild = 19044
    if ($build -lt $minBuild) {
        return [PSCustomObject]@{
            IsSupported = $false
            OSVersion   = $osVersion.ToString()
            Build       = $build
            Message     = (Get-PCOString -Key 'UnsupportedWindowsVersion' -Arguments @($build))
        }
    }

    return [PSCustomObject]@{
        IsSupported = $true
        OSVersion   = $osVersion.ToString()
        Build       = $build
        Message     = 'Platform is supported.'
    }
}
