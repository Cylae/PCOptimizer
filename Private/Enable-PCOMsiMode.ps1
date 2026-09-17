<#
.SYNOPSIS
    Enables Message Signaled Interrupts (MSI mode) on NVIDIA display adapters.
.DESCRIPTION
    Queries present display adapters for NVIDIA devices, reads existing MSISupported registry
    values, and configures MSISupported = 1 to minimize interrupt latency.
.PARAMETER LogFile
    Optional log file path.
.PARAMETER Quiet
    Suppresses console output.
.OUTPUTS
    [PSCustomObject[]] Array of device MSI entries and previous values.
#>
function Enable-PCOMsiMode {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$VendorPattern = 'NVIDIA|AMD|Radeon|Intel',

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )

    Write-PCOLog -Message (Get-PCOString -Key 'MsiEnabling') -Level 'STEP' -LogFile $LogFile -Quiet:$Quiet

    $devices = @()
    try {
        $pnpDevices = Get-PnpDevice -Class Display -PresentOnly -ErrorAction Stop
        $devices = @($pnpDevices | Where-Object { $_.FriendlyName -match $VendorPattern })
    } catch {
        Write-PCOLog -Message "Failed to query display devices: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
    }

    $entries = @()
    foreach ($dev in $devices) {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $existing = $null
        if (Test-Path -Path $path) {
            try {
                $prop = Get-ItemProperty -Path $path -Name 'MSISupported' -ErrorAction Stop
                if ($prop.PSObject.Properties.Name -contains 'MSISupported') {
                    $existing = $prop.MSISupported
                }
            } catch {
                $existing = $null
            }
        }

        if ($PSCmdlet.ShouldProcess($dev.FriendlyName, "Enable Message Signaled Interrupts (MSISupported = 1)")) {
            $null = Set-PCORegistryDword -Path $path -Name 'MSISupported' -Value 1
            Write-PCOLog -Message (Get-PCOString -Key 'MsiEnabledOnDevice' -Arguments @($dev.FriendlyName)) -Level 'OK' -LogFile $LogFile -Quiet:$Quiet
        }

        $entries += [PSCustomObject]@{
            Path       = $path
            DeviceName = $dev.FriendlyName
            Previous   = $existing
            Applied    = 1
        }
    }

    if ($entries.Count -eq 0) {
        Write-PCOLog -Message (Get-PCOString -Key 'MsiNoDevices') -Level 'WARN' -LogFile $LogFile -Quiet:$Quiet
    }

    return $entries
}
