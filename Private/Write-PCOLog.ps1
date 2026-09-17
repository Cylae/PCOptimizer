<#
.SYNOPSIS
    Emits structured, color-coded console messages and appends to a log file.
.DESCRIPTION
    Provides unified logging across PCOptimizer. Supports severity levels, console formatting,
    quiet-mode execution, and persistent file logging.
.PARAMETER Message
    The text message to log.
.PARAMETER Level
    The severity level: 'INFO', 'OK', 'WARN', 'ERROR', 'STEP', 'DEBUG'. Defaults to 'INFO'.
.PARAMETER LogFile
    Optional file path to append the log message to.
.PARAMETER Quiet
    Suppresses console output for non-error messages.
#>
function Write-PCOLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    # Honor debug output suppression unless verbose/debug preference is active
    if ($Level -eq 'DEBUG' -and $VerbosePreference -eq 'SilentlyContinue') {
        return
    }

    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'STEP'  { 'Cyan' }
        'DEBUG' { 'DarkGray' }
        default { 'White' }
    }

    $prefix = switch ($Level) {
        'OK'    { '[OK]   ' }
        'WARN'  { '[WARN] ' }
        'ERROR' { '[ERR]  ' }
        'STEP'  { '[>>]   ' }
        'DEBUG' { '[DBG]  ' }
        default { '[INFO] ' }
    }

    $timestamp = (Get-Date).ToString('HH:mm:ss')
    $formattedLine = "[$timestamp] $prefix$Message"

    # Write to console unless Quiet mode is requested (Errors always display)
    if (-not $Quiet -or $Level -eq 'ERROR') {
        Write-Host -Object $formattedLine -ForegroundColor $color
    }

    # Write to log file if path is supplied
    if ($LogFile) {
        try {
            $parentDir = Split-Path -Path $LogFile -Parent
            if ($parentDir -and -not (Test-Path -Path $parentDir)) {
                $null = New-Item -Path $parentDir -ItemType Directory -Force
            }
            Add-Content -Path $LogFile -Value $formattedLine -ErrorAction Stop
        } catch {
            # Avoid crashing if disk or logging directory is temporarily write-protected
            Write-Warning -Message "Failed to write to log file '$LogFile': $($_.Exception.Message)"
        }
    }
}
