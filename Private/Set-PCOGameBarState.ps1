<#
.SYNOPSIS
    Disables Xbox Game Bar and Game DVR background capture.
.DESCRIPTION
    Sets registry DWORD flags across user and local machine policy keys to disable
    GameDVR background video capture and telemetry overhead.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject[]] Array of modified registry keys and prior states.
#>
function Set-PCOGameBarState {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    Write-PCOLog -Message (Get-PCOString -Key 'GameBarDisabling') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $targets = @(
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR' }
    )

    $entries = @()
    if ($PSCmdlet.ShouldProcess("Xbox Game Bar / DVR", "Disable background recording and telemetry")) {
        foreach ($target in $targets) {
            $existing = $null
            if (Test-Path -Path $target.Path) {
                try {
                    $prop = Get-ItemProperty -Path $target.Path -Name $target.Name -ErrorAction Stop
                    if ($prop.PSObject.Properties.Name -contains $target.Name) {
                        $existing = $prop.($target.Name)
                    }
                } catch {
                    $existing = $null
                }
            }

            $null = Set-PCORegistryDword -Path $target.Path -Name $target.Name -Value 0
            $entries += [PSCustomObject]@{
                Path     = $target.Path
                Name     = $target.Name
                Previous = $existing
                Applied  = 0
            }
        }

        Write-PCOLog -Message (Get-PCOString -Key 'GameBarDisabled') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
    }

    return $entries
}
