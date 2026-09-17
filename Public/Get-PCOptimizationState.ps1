<#
.SYNOPSIS
    Retrieves and validates the current or saved optimization state snapshot.
.DESCRIPTION
    Loads state.json from the designated backup path. Validates schema fields,
    safely handles corrupt or unreadable files, and falls back to a clean state model.
.PARAMETER BackupPath
    Directory path containing state.json. Defaults to '$env:ProgramData\PCOptimizer'.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Validated state object.
#>
function Get-PCOptimizationState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BackupPath = "$env:ProgramData\PCOptimizer",

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    $stateFile = Join-Path -Path $BackupPath -ChildPath 'state.json'

    # Fallback to legacy path ONLY if using the default backup path and the modern state file does not exist
    if ($BackupPath -eq "$env:ProgramData\PCOptimizer" -and -not (Test-Path -Path $stateFile)) {
        $legacyPath = Join-Path -Path "$env:ProgramData\RTX3070-5950X-Optimizer" -ChildPath 'state.json'
        if (Test-Path -Path $legacyPath) {
            $stateFile = $legacyPath
        }
    }

    if (Test-Path -Path $stateFile) {
        try {
            $rawContent = Get-Content -Path $stateFile -Raw -Encoding utf8 -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($rawContent)) {
                $obj = $rawContent | ConvertFrom-Json -ErrorAction Stop

                $standardProps = @('SchemaVersion', 'Timestamp', 'Environment', 'HAGS', 'Msi', 'GameBar', 'PowerPlan', 'PowerLimit', 'P0', 'Cpu')
                foreach ($prop in $standardProps) {
                    if (-not ($obj.PSObject.Properties.Name -contains $prop)) {
                        $defaultVal = if ($prop -eq 'SchemaVersion') { '1.0.0' } else { $null }
                        $obj | Add-Member -NotePropertyName $prop -NotePropertyValue $defaultVal -Force
                    }
                }
                if (-not $obj.SchemaVersion) {
                    $obj.SchemaVersion = '1.0.0'
                }
                return $obj
            }
        } catch {
            Write-PCOLog -Message (Get-PCOString -Key 'RevertCorruptState' -Arguments @($_.Exception.Message)) -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
        }
    }

    return [PSCustomObject]@{
        SchemaVersion = '1.0.0'
        Timestamp     = $null
        Environment   = $null
        HAGS          = $null
        Msi           = @()
        GameBar       = @()
        PowerPlan     = $null
        PowerLimit    = $null
        P0            = @()
        Cpu           = [PSCustomObject]@{}
    }
}
