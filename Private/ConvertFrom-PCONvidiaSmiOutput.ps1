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
        [object]$RawOutput
    )

    if ($null -eq $RawOutput) {
        return @()
    }

    $lines = @()
    if ($RawOutput -is [string]) {
        $lines = $RawOutput -split "(`r?`n)" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
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
        # nvidia-smi csv output is comma-separated
        $parts = $line -split ',' | ForEach-Object { $_.Trim() }

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

        $numericValues = @{}
        $fields = @(
            @{ Index = 2; Name = 'PowerLimit';    Min = 1.0 }
            @{ Index = 3; Name = 'DefaultLimit';  Min = 1.0 }
            @{ Index = 4; Name = 'MaxLimit';      Min = 1.0 }
            @{ Index = 5; Name = 'Temperature';   Min = 0.0 }
            @{ Index = 6; Name = 'GraphicsClock'; Min = 0.0 }
        )

        foreach ($field in $fields) {
            $rawVal = $parts[$field.Index]
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
            Name          = $name
            Driver        = $driver
            PowerLimit    = $numericValues['PowerLimit']
            DefaultLimit  = $numericValues['DefaultLimit']
            MaxLimit      = $numericValues['MaxLimit']
            Temperature   = $numericValues['Temperature']
            GraphicsClock = $numericValues['GraphicsClock']
        }
    }

    return $results
}
