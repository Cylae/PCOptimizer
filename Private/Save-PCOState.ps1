<#
.SYNOPSIS
    Persists the optimization state snapshot to a versioned JSON state file.
.DESCRIPTION
    Validates, serializes, and atomically writes the state object to state.json under BackupPath.
    Includes SchemaVersion and environment telemetry for rollback safety.
.PARAMETER State
    The state object to serialize.
.PARAMETER BackupPath
    Directory path where state.json is saved.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [string] Path to the saved state file.
#>
function Save-PCOState {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$State,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $stateFilePath = Join-Path -Path $BackupPath -ChildPath 'state.json'
    Write-PCOLog -Message (Get-PCOString -Key 'StateSaving' -Arguments @($stateFilePath)) -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    # Ensure required metadata properties
    $State | Add-Member -NotePropertyName 'SchemaVersion' -NotePropertyValue '1.0.0' -Force
    $State | Add-Member -NotePropertyName 'Timestamp' -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
    $envInfo = @{
        OSVersion    = [System.Environment]::OSVersion.VersionString
        PSVersion    = $PSVersionTable.PSVersion.ToString()
        ComputerName = [System.Environment]::MachineName
    }
    $State | Add-Member -NotePropertyName 'Environment' -NotePropertyValue $envInfo -Force

    if ($PSCmdlet.ShouldProcess($stateFilePath, "Save optimization state snapshot")) {
        if (-not (Test-Path -Path $BackupPath)) {
            $null = New-Item -Path $BackupPath -ItemType Directory -Force
        }

        $json = $State | ConvertTo-Json -Depth 10
        $tmpFile = "$stateFilePath.tmp"

        # Atomic write pattern
        Set-Content -Path $tmpFile -Value $json -Encoding utf8 -Force
        Move-Item -Path $tmpFile -Destination $stateFilePath -Force
    }

    Write-PCOLog -Message (Get-PCOString -Key 'StateSaved') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    return $stateFilePath
}
