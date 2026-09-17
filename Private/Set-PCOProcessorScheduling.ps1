<#
.SYNOPSIS
    Configures CPU core parking, Processor Boost Mode, and Windows Game Mode.
.DESCRIPTION
    Optimizes processor core utilization for low acoustic noise at idle while maintaining
    full boost capability under load. Tailored for AMD Ryzen 9 5950X / multi-core processors.
.PARAMETER AggressiveSilence
    When specified, drops minimum unparked cores to 5% instead of default 10%.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject] Summary of CPU scheduling parameters configured.
#>
function Set-PCOProcessorScheduling {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$AggressiveSilence,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    Write-PCOLog -Message (Get-PCOString -Key 'CpuOptimizing') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $highGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $minCores = if ($AggressiveSilence) { 5 } else { 10 }
    $coreParkingSuccess = $false
    $boostSuccess = $false
    $gameModeSuccess = $false

    if ($PSCmdlet.ShouldProcess("Processor Scheduling ($highGuid)", "Configure core parking ($minCores%) and boost mode")) {
        # Core Parking
        $cpMinRes = Invoke-PCOPowerCfg -Arguments @('/setacvalueindex', $highGuid, 'SUB_PROCESSOR', 'CPMINCORES', "$minCores")
        $cpMaxRes = Invoke-PCOPowerCfg -Arguments @('/setacvalueindex', $highGuid, 'SUB_PROCESSOR', 'CPMAXCORES', '100')
        $coreParkingSuccess = ($cpMinRes.Success -and $cpMaxRes.Success)

        if ($coreParkingSuccess) {
            Write-PCOLog -Message (Get-PCOString -Key 'CoreParkingConfigured' -Arguments @($minCores)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        } else {
            Write-PCOLog -Message (Get-PCOString -Key 'CoreParkingNotSupported') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
        }

        # Processor Boost Mode (Unhide in registry then set to Efficient Aggressive = 4)
        $boostPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\be337238-0d82-4146-a960-4f3749d470c7'
        try {
            $null = Set-PCORegistryDword -Path $boostPath -Name 'Attributes' -Value 2
            $boostRes = Invoke-PCOPowerCfg -Arguments @('/setacvalueindex', $highGuid, 'SUB_PROCESSOR', 'PERFBOOSTMODE', '4')
            if ($boostRes.Success) {
                $boostSuccess = $true
                Write-PCOLog -Message (Get-PCOString -Key 'BoostModeConfigured') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
            } else {
                Write-PCOLog -Message (Get-PCOString -Key 'BoostModeNotSupported') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
            }
        } catch {
            Write-PCOLog -Message (Get-PCOString -Key 'BoostModeNotSupported') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
        }

        # Windows Game Mode
        try {
            $null = Set-PCORegistryDword -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1
            $null = Set-PCORegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 1
            $null = Set-PCORegistryDword -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1
            $gameModeSuccess = $true
            Write-PCOLog -Message (Get-PCOString -Key 'GameModeEnabled') -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        } catch {
            Write-PCOLog -Message "Could not configure Game Mode: $($_.Exception.Message)" -Level 'DEBUG' -LogFile $LogFile -Quiet:$Quiet
        }

        $null = Invoke-PCOPowerCfg -Arguments @('/setactive', $highGuid)
    }

    return [PSCustomObject]@{
        CoreParkingMinPercent = $minCores
        CoreParkingMaxPercent = 100
        CoreParkingConfigured = $coreParkingSuccess
        BoostMode             = if ($boostSuccess) { 4 } else { $null }
        GameModeEnabled       = $gameModeSuccess
    }
}
