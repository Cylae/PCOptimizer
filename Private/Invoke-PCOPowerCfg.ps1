<#
.SYNOPSIS
    Executes Windows powercfg.exe with structured return code and output handling.
.DESCRIPTION
    Wraps powercfg.exe calls to capture exit codes and output while honoring -WhatIf / -Confirm.
.PARAMETER Arguments
    The argument array or string passed to powercfg.exe.
.OUTPUTS
    [PSCustomObject] Containing ExitCode, Output, Arguments, and Success status.
#>
function Invoke-PCOPowerCfg {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$Arguments
    )

    $argString = $Arguments -join ' '
    if (-not $PSCmdlet.ShouldProcess("powercfg.exe", "Execute: powercfg $argString")) {
        return [PSCustomObject]@{
            ExitCode  = 0
            Output    = '[WhatIf] Execution suppressed'
            Arguments = $argString
            Success   = $true
        }
    }

    try {
        $pinfo = [System.Diagnostics.ProcessStartInfo]::new()
        $pinfo.FileName = 'powercfg.exe'
        $pinfo.Arguments = $argString
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($pinfo)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $combinedOutput = ($stdout + "`n" + $stderr).Trim()
        $exitCode = $process.ExitCode

        return [PSCustomObject]@{
            ExitCode  = $exitCode
            Output    = $combinedOutput
            Arguments = $argString
            Success   = ($exitCode -eq 0)
        }
    } catch {
        return [PSCustomObject]@{
            ExitCode  = -1
            Output    = $_.Exception.Message
            Arguments = $argString
            Success   = $false
        }
    }
}
