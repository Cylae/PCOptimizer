<#
.SYNOPSIS
    Parses and validates structured CSV output from nvidia-smi --query-gpu.
.DESCRIPTION
    Validates column count, ensures numeric fields are properly typed, and guards
    against malformed or partial output from nvidia-smi.
.PARAMETER RawOutput
    The raw output string or array of strings produced by nvidia-smi.
.OUTPUTS
    [PSCustomObject[]] Array of validated GPU telemetry objects.
#>
function ConvertFrom-PCONvidiaSmiOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [object]$RawOutput,

        [Parameter(Mandatory = $false)]
        [switch]$AllowUnsupported
    )

    if ($null -eq $RawOutput) {
        return @()
    }

    $lines = @()
    if ($RawOutput -is [string]) {
        $lines = $RawOutput -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    } elseif ($RawOutput -is [System.Collections.IEnumerable]) {
        foreach ($item in $RawOutput) {
            if ($item -and -not [string]::IsNullOrWhiteSpace($item.ToString())) {
                $lines += $item.ToString().Trim()
            }
        }
    }

    if ($lines.Count -eq 0) {
        return @()
    }

    $results = @()
    foreach ($line in $lines) {
        # Parse CSV line respecting quotes
        $csvRegex = ',(?=(?:[^"]*"[^"]*")*[^"]*$)'
        $parts = [regex]::Split($line, $csvRegex) | ForEach-Object {
            $val = $_.Trim()
            if ($val.StartsWith('"') -and $val.EndsWith('"') -and $val.Length -ge 2) {
                $val = $val.Substring(1, $val.Length - 2).Replace('""', '"')
            }
            $val
        }

        if ($parts.Count -ne 7) {
            throw [System.FormatException]::new(
                "nvidia-smi output returned $($parts.Count) columns (expected 7: name, driver, power.limit, default_limit, max_limit, temp, clocks). Raw line: '$line'"
            )
        }

        $name   = $parts[0]
        $driver = $parts[1]

        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.FormatException]::new("nvidia-smi output missing GPU name. Raw line: '$line'")
        }

        # Guard against CSV formula injection characters if telemetry is logged/exported
        $sanitizedName = $name
        if ($sanitizedName -match '^[=+\-@\t\r]') {
            $sanitizedName = "'" + $sanitizedName
        }

        $numericValues = @{}
        $powerSupported = $true
        $fields = @(
            @{ Index = 2; Name = 'PowerLimit';    Min = 1.0; IsPower = $true }
            @{ Index = 3; Name = 'DefaultLimit';  Min = 1.0; IsPower = $true }
            @{ Index = 4; Name = 'MaxLimit';      Min = 1.0; IsPower = $true }
            @{ Index = 5; Name = 'Temperature';   Min = 0.0; IsPower = $false }
            @{ Index = 6; Name = 'GraphicsClock'; Min = 0.0; IsPower = $false }
        )

        foreach ($field in $fields) {
            $rawVal = $parts[$field.Index]

            # Check for nvidia-smi unsupported indicators
            $isUnsupportedToken = ($rawVal -in @('[Not Supported]', '[N/A]', 'N/A', 'Unknown', '[Unknown]'))
            if ($AllowUnsupported -and $isUnsupportedToken) {
                if ($field.IsPower) {
                    $powerSupported = $false
                }
                $numericValues[$field.Name] = 0.0
                continue
            }

            $parsed = 0.0
            $success = [double]::TryParse(
                $rawVal,
                [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$parsed
            )
            if (-not $success) {
                throw [System.FormatException]::new(
                    "Field '$($field.Name)' with value '$rawVal' in nvidia-smi output is not a valid numeric float. Raw line: '$line'"
                )
            }
            if ($parsed -lt $field.Min) {
                throw [System.ArgumentOutOfRangeException]::new(
                    $field.Name,
                    "Field '$($field.Name)' with value $parsed is below the minimum allowable threshold of $($field.Min)."
                )
            }
            $numericValues[$field.Name] = $parsed
        }

        $results += [PSCustomObject]@{
            Name                     = $sanitizedName
            Driver                   = $driver
            PowerLimit               = $numericValues['PowerLimit']
            DefaultLimit             = $numericValues['DefaultLimit']
            MaxLimit                 = $numericValues['MaxLimit']
            Temperature              = $numericValues['Temperature']
            GraphicsClock            = $numericValues['GraphicsClock']
            PowerManagementSupported = $powerSupported
        }
    }

    return $results
}
