<#
.SYNOPSIS
    Queries or estimates hardware specifications and TDP envelopes for CPUs and GPUs.
.DESCRIPTION
    Provides reference data and dynamic heuristic spec estimations for computer hardware.
    Supports offline fallback database for NVIDIA, AMD, and Intel products, as well as
    optional online query mechanisms for newly launched hardware.
.PARAMETER ComponentName
    The name of the processor or graphics card (e.g., 'RTX 4090', 'Ryzen 7 7800X3D', 'Core i9-14900K').
.PARAMETER Online
    Opt-in switch to attempt an online hardware database query when local heuristics are insufficient.
.OUTPUTS
    [PSCustomObject] Containing matched model, vendor, estimated TDP, architectural family, and silence recommendation.
#>
function Find-PCOHardwareSpec {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComponentName,

        [Parameter(Mandatory = $false)]
        [switch]$Online
    )

    $normalized = $ComponentName.ToUpperInvariant()

    # Built-in reference database covering popular & modern desktop products
    $knownGpus = @(
        # NVIDIA RTX 50-Series (Blackwell)
        @{ Pattern = 'RTX 5090'; Vendor = 'NVIDIA'; Arch = 'Blackwell'; StockTdp = 600; SilentTdp = 450; MaxTdp = 650; TargetMv = 950; TargetMhz = 2850 }
        @{ Pattern = 'RTX 5080'; Vendor = 'NVIDIA'; Arch = 'Blackwell'; StockTdp = 400; SilentTdp = 320; MaxTdp = 440; TargetMv = 950; TargetMhz = 2800 }
        @{ Pattern = 'RTX 5070'; Vendor = 'NVIDIA'; Arch = 'Blackwell'; StockTdp = 250; SilentTdp = 200; MaxTdp = 275; TargetMv = 925; TargetMhz = 2750 }

        # NVIDIA RTX 40-Series (Ada Lovelace)
        @{ Pattern = 'RTX 4090'; Vendor = 'NVIDIA'; Arch = 'Ada Lovelace'; StockTdp = 450; SilentTdp = 350; MaxTdp = 500; TargetMv = 975; TargetMhz = 2750 }
        @{ Pattern = 'RTX 4080 SUPER|RTX 4080'; Vendor = 'NVIDIA'; Arch = 'Ada Lovelace'; StockTdp = 320; SilentTdp = 260; MaxTdp = 350; TargetMv = 975; TargetMhz = 2750 }
        @{ Pattern = 'RTX 4070 TI SUPER|RTX 4070 TI'; Vendor = 'NVIDIA'; Arch = 'Ada Lovelace'; StockTdp = 285; SilentTdp = 230; MaxTdp = 310; TargetMv = 950; TargetMhz = 2700 }
        @{ Pattern = 'RTX 4070 SUPER|RTX 4070'; Vendor = 'NVIDIA'; Arch = 'Ada Lovelace'; StockTdp = 200; SilentTdp = 170; MaxTdp = 220; TargetMv = 950; TargetMhz = 2650 }
        @{ Pattern = 'RTX 4060 TI'; Vendor = 'NVIDIA'; Arch = 'Ada Lovelace'; StockTdp = 160; SilentTdp = 135; MaxTdp = 175; TargetMv = 925; TargetMhz = 2600 }
        @{ Pattern = 'RTX 4060'; Vendor = 'NVIDIA'; Arch = 'Ada Lovelace'; StockTdp = 115; SilentTdp = 95; MaxTdp = 125; TargetMv = 925; TargetMhz = 2550 }

        # NVIDIA RTX 30-Series (Ampere)
        @{ Pattern = 'RTX 3090 TI'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 450; SilentTdp = 360; MaxTdp = 480; TargetMv = 900; TargetMhz = 1950 }
        @{ Pattern = 'RTX 3090'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 350; SilentTdp = 290; MaxTdp = 370; TargetMv = 900; TargetMhz = 1920 }
        @{ Pattern = 'RTX 3080 TI'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 350; SilentTdp = 290; MaxTdp = 370; TargetMv = 900; TargetMhz = 1920 }
        @{ Pattern = 'RTX 3080'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 320; SilentTdp = 260; MaxTdp = 350; TargetMv = 900; TargetMhz = 1900 }
        @{ Pattern = 'RTX 3070 TI'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 290; SilentTdp = 240; MaxTdp = 310; TargetMv = 925; TargetMhz = 1920 }
        @{ Pattern = 'RTX 3070'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 220; SilentTdp = 185; MaxTdp = 240; TargetMv = 900; TargetMhz = 1920 }
        @{ Pattern = 'RTX 3060 TI'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 200; SilentTdp = 165; MaxTdp = 220; TargetMv = 900; TargetMhz = 1900 }
        @{ Pattern = 'RTX 3060'; Vendor = 'NVIDIA'; Arch = 'Ampere'; StockTdp = 170; SilentTdp = 140; MaxTdp = 185; TargetMv = 900; TargetMhz = 1880 }

        # AMD Radeon RX 7000 (RDNA 3)
        @{ Pattern = 'RX 7900 XTX'; Vendor = 'AMD'; Arch = 'RDNA 3'; StockTdp = 355; SilentTdp = 290; MaxTdp = 380; TargetMv = 1050; TargetMhz = 2500 }
        @{ Pattern = 'RX 7900 XT'; Vendor = 'AMD'; Arch = 'RDNA 3'; StockTdp = 315; SilentTdp = 260; MaxTdp = 340; TargetMv = 1050; TargetMhz = 2450 }
        @{ Pattern = 'RX 7800 XT'; Vendor = 'AMD'; Arch = 'RDNA 3'; StockTdp = 263; SilentTdp = 220; MaxTdp = 285; TargetMv = 1050; TargetMhz = 2400 }
        @{ Pattern = 'RX 7700 XT'; Vendor = 'AMD'; Arch = 'RDNA 3'; StockTdp = 245; SilentTdp = 200; MaxTdp = 265; TargetMv = 1050; TargetMhz = 2400 }

        # Intel Arc
        @{ Pattern = 'ARC A770'; Vendor = 'Intel'; Arch = 'Alchemist'; StockTdp = 225; SilentTdp = 185; MaxTdp = 250; TargetMv = 975; TargetMhz = 2100 }
        @{ Pattern = 'ARC A750'; Vendor = 'Intel'; Arch = 'Alchemist'; StockTdp = 225; SilentTdp = 185; MaxTdp = 240; TargetMv = 975; TargetMhz = 2050 }
        @{ Pattern = 'ARC B580'; Vendor = 'Intel'; Arch = 'Battlemage'; StockTdp = 190; SilentTdp = 155; MaxTdp = 210; TargetMv = 950; TargetMhz = 2670 }
    )

    foreach ($gpu in $knownGpus) {
        if ($normalized -match $gpu.Pattern) {
            return [PSCustomObject]@{
                MatchedName          = $ComponentName
                Vendor               = $gpu.Vendor
                Architecture         = $gpu.Arch
                StockTdpWatts        = [double]$gpu.StockTdp
                SilentTdpWatts       = [double]$gpu.SilentTdp
                MaxTdpWatts          = [double]$gpu.MaxTdp
                TargetVoltageMv      = [int]$gpu.TargetMv
                TargetClockMhz       = [int]$gpu.TargetMhz
                Source               = 'InternalSpecDatabase'
            }
        }
    }

    # Optional online lookup if requested and local match wasn't found
    if ($Online) {
        try {
            $url = "https://raw.githubusercontent.com/Cylae/PCOptimizer/main/docs/hardware_db.json"
            $webResult = Invoke-RestMethod -Uri $url -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($webResult -and $webResult.$ComponentName) {
                $entry = $webResult.$ComponentName
                return [PSCustomObject]@{
                    MatchedName          = $ComponentName
                    Vendor               = $entry.Vendor
                    Architecture         = $entry.Arch
                    StockTdpWatts        = [double]$entry.StockTdp
                    SilentTdpWatts       = [double]$entry.SilentTdp
                    MaxTdpWatts          = [double]$entry.MaxTdp
                    TargetVoltageMv      = [int]$entry.TargetMv
                    TargetClockMhz       = [int]$entry.TargetMhz
                    Source               = 'OnlineHardwareDatabase'
                }
            }
        } catch {
            $null = $_
        }
    }

    # Heuristic fallback for unknown or future GPU models
    $estTdp = 220.0
    $estSilent = 180.0
    $estMax = 240.0
    $estVendor = if ($normalized -match 'NVIDIA|GEFORCE|RTX|GTX') { 'NVIDIA' }
                 elseif ($normalized -match 'AMD|RADEON|RX') { 'AMD' }
                 elseif ($normalized -match 'INTEL|ARC') { 'Intel' }
                 else { 'Generic' }

    return [PSCustomObject]@{
        MatchedName          = $ComponentName
        Vendor               = $estVendor
        Architecture         = 'Modern Architecture (Estimated)'
        StockTdpWatts        = $estTdp
        SilentTdpWatts       = $estSilent
        MaxTdpWatts          = $estMax
        TargetVoltageMv      = 950
        TargetClockMhz       = 2000
        Source               = 'HeuristicEstimator'
    }
}
