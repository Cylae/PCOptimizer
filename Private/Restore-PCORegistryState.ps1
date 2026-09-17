<#
.SYNOPSIS
    Restores captured registry key entries to their recorded prior values.
.DESCRIPTION
    Iterates through a collection of registry snapshots. If the prior value was null,
    the property is removed; otherwise, the recorded DWORD value is reapplied.
.PARAMETER Entries
    Collection of registry snapshot objects containing Path, Name, and Previous.
.PARAMETER DefaultName
    Default property name if Name is not present on an entry (e.g. 'MSISupported').
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [int] Number of registry keys processed.
#>
function Restore-PCORegistryState {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Entries,

        [Parameter(Mandatory = $false)]
        [string]$DefaultName,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    if ($null -eq $Entries -or $Entries.Count -eq 0) {
        return 0
    }

    $count = 0
    if ($PSCmdlet.ShouldProcess("Registry Entries ($($Entries.Count))", "Restore previous values")) {
        foreach ($entry in $Entries) {
            if (-not $entry -or -not $entry.Path) {
                continue
            }

            $propName = if ($entry.Name) { $entry.Name } else { $DefaultName }
            if (-not $propName) {
                continue
            }

            if ($null -eq $entry.Previous) {
                $null = Remove-PCORegistryValue -Path $entry.Path -Name $propName
            } else {
                $prevVal = [int]$entry.Previous
                $null = Set-PCORegistryDword -Path $entry.Path -Name $propName -Value $prevVal
            }
            $count++
        }
    }

    return $count
}
