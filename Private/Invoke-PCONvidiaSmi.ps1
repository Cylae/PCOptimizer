<#
.SYNOPSIS
    Executes nvidia-smi with specified arguments.
.DESCRIPTION
    Wraps invocations of nvidia-smi.exe to capture standard output and error.
.PARAMETER SmiPath
    Path to nvidia-smi.exe.
.PARAMETER Arguments
    Array of argument strings.
.OUTPUTS
    [PSCustomObject] Containing ExitCode, Output, and Success status.
#>
function Invoke-PCONvidiaSmi {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SmiPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    try {
        $output = & $SmiPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Output   = $output
            Success  = ($exitCode -eq 0)
        }
    } catch {
        return [PSCustomObject]@{
            ExitCode = -1
            Output   = @($_.Exception.Message)
            Success  = $false
        }
    }
}
