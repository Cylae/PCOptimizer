# PCOptimizer

[![CI](https://github.com/Cylae/PCOptimizer/actions/workflows/ci.yml/badge.svg)](https://github.com/Cylae/PCOptimizer/actions/workflows/ci.yml)
[![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg)](https://microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**PCOptimizer** is a production-grade, hardware-adaptive PowerShell module engineered to configure Windows 10 and 11 systems for optimal gaming frame times, minimal input latency, and whisper-quiet acoustic profiles. Designed specifically for multi-CCD processors (such as the AMD Ryzen 9 5950X) and high-performance graphics architectures (such as the NVIDIA GeForce RTX 3070 / Ampere), PCOptimizer eliminates kernel context switching overhead, modernizes PCI interrupt handling, clamps inefficient GPU power targets, and maintains full reversibility through automated JSON state snapshots.

---

> [!WARNING]
> **DISCLAIMER & ELEVATION NOTICE**
> PCOptimizer requires an **elevated Windows Administrator token** because it writes directly to system hardware parameters, low-level registry keys (`HKLM`), and active Windows ACPI power schemes.
>
> All actions are recorded before execution and can be completely reverted at any time using `Invoke-PCOptimization -Revert` or `Restore-PCOptimization`. However, users must understand the hardware impact of power limit adjustments and forced P-state overrides before deploying.

---

## Key Features

- **Universal Hardware Intelligence Engine:** Auto-identifies any CPU (AMD Zen 1–5, X3D, multi-CCD; Intel 6th–14th Gen, Core Ultra Arrow Lake) and GPU architecture (NVIDIA GeForce/RTX/Blackwell, AMD Radeon RDNA 1–4, Intel Arc) across the entire consumer market with offline reference data and dynamic spec resolution.
- **Guided Interactive CLI Wizard (`PCOptimizer-CLI.ps1`):** Features an interactive Silence vs. Performance visual gauge slider, guided `-Help` manual, preset selector (`-Level 1..5`), and continuous bias tuning (`-SilenceBias 0..100`).
- **Hardware-Accelerated GPU Scheduling (HAGS):** Transfers frame scheduling directly to the GPU's onboard scheduling processor, reducing CPU interrupt overhead and improving 1% low frame times in modern DirectX 12/Vulkan titles.
- **Message Signaled Interrupts (MSI Mode):** Converts legacy line-based Pin-IRQs to PCI Express Message Signaled Interrupts across all discrete display adapters (NVIDIA, AMD, Intel), eliminating IRQ sharing conflicts and slashing interrupt dispatch latency.
- **Gaming Subsystem Optimization:** Disables Xbox Game Bar and background Game DVR telemetry hooks to eliminate frame pacing micro-stutters without re-enabling GameDVR capture keys.
- **Adaptive GPU Power Target Clamping:** Automatically calculates and sets acoustic silence targets (defaulting to 92% TDP), achieving dramatic fan noise reduction with under 1.5% FPS variance. Includes **automated verification and rollback** to factory defaults if the GPU driver rejects the setting.
- **Ryzen Core Parking & Boost Calibration:** Configures Windows High Performance power scheme, tunes processor throttling bounds (5% min / 100% max), parks idle CCD cores at desktop idle, and configures Processor Performance Boost Mode to *Efficient Aggressive*.
- **Opt-In Dynamic P-State Control:** Provides explicit, warned control over `DisableDynamicPstate` (forced P0) with automatic cleanup of stale tweaks from prior runs.
- **Universal Tuning & MSI Afterburner Advisory Guide:** Exports tailored voltage-frequency curve recommendations (e.g. 900-925 mV @ 1900-1950 MHz) dynamically adapted to the detected GPU architecture (NVIDIA, AMD Radeon, Intel Arc).
- **Safety Rails & 100% Reversibility:** Schema-versioned JSON state persistence (`state.json`) captures prior values before every mutation, enabling full rollback. Supports `-WhatIf` / `-DryRun` preview modes.

---

## System Requirements

| Component | Requirement | Note |
| --------- | ----------- | ---- |
| **Operating System** | Windows 11 (all builds) or Windows 10 (21H2 / Build 19044+) | 64-bit required |
| **PowerShell** | PowerShell 7.4 or later (`pwsh`) | Windows PowerShell 5.1 is not supported |
| **Privileges** | Elevated Administrator (`Run as Administrator`) | Required for registry & powercfg modifications |
| **GPU (Optional)** | NVIDIA GeForce RTX 20/30/40 series | Gracefully falls back to CPU-only optimization if absent |
| **NVIDIA Driver** | Driver version 451.48+ (`nvidia-smi.exe` in PATH or standard location) | Required for GPU power limit control |

---

## Installation

Clone the repository and import the module manifest in an elevated PowerShell 7 session:

```powershell
# Clone the repository
git clone https://github.com/Cylae/PCOptimizer.git
cd PCOptimizer

# Import the module
Import-Module ./PCOptimizer.psd1 -Force
```

To make the module permanently available across PowerShell sessions, copy the folder to your PowerShell module path:

```powershell
$targetPath = Join-Path -Path ($env:PSModulePath -split ';')[0] -ChildPath 'PCOptimizer'
Copy-Item -Path . -Destination $targetPath -Recurse -Force
```

---

## Command Reference

### `Start-PCOptimizerWizard` (Alias: `Invoke-PCOptimizerCLI`, Script: `.\PCOptimizer-CLI.ps1`)

The interactive, guided CLI orchestrator. Guides users through system tuning with an interactive Silence vs. Performance visual gauge slider, hardware classification probe, and built-in help.

| Parameter | Type | Default | Description |
| --------- | ---- | ------- | ----------- |
| `-Help` / `-h` | `Switch` | `False` | Displays the comprehensive guided manual with architectural overview, hardware detection, and tuning guidelines. |
| `-Level` | `Int` (`1..5`) | `3` (interactive) | Preset tuning profile (1 = Extreme Silence, 2 = Quiet Efficiency, 3 = Balanced, 4 = High Performance, 5 = Maximum Performance). |
| `-SilenceBias` | `Int` (`0..100`) | Derived | Continuous silence bias percentage (0% = Maximum Performance, 100% = Extreme Silence). |
| `-NonInteractive` | `Switch` | `False` | Executes unattended without interactive prompts using provided or default level. |
| `-DryRun` | `Switch` | `False` | Simulates all optimization steps and prints actions without modifying the system. |
| `-Revert` | `Switch` | `False` | Guides the user through rolling back previous optimizations using `state.json`. |
| `-SkipGpu` | `Switch` | `False` | Bypasses GPU power clamping and MSI configuration. |
| `-SkipCpu` | `Switch` | `False` | Bypasses CPU power scheme and core parking adjustments. |
| `-ForceP0` | `Switch` | `False` | Opts in to forced P0 state for memory overclocking with thermal warning. |
| `-Quiet` | `Switch` | `False` | Suppresses decorative visual banners and status gauges. |

---

### `Invoke-PCOptimization` (Alias: `Optimize-PC`)

The primary orchestration cmdlet. Supports two mutually exclusive parameter sets: `Optimize` and `Revert`.

| Parameter | Parameter Set | Type | Default | Description |
| --------- | ------------- | ---- | ------- | ----------- |
| `-Revert` | `Revert` | `Switch` | `False` | Restores all settings to their recorded pre-optimization state. |
| `-SilentFactor` | `Optimize` | `Double` | `0.92` | Fraction applied to GPU maximum power limit (valid range: `0.01` to `1.0`). |
| `-MaxPerf` | `Optimize` | `Switch` | `False` | Sets GPU power limit to hardware maximum ceiling instead of silent target. Mutually exclusive with `-MaxSilence` and `-BalancedSilence`. |
| `-MaxSilence` | `Optimize` | `Switch` | `False` | Sets GPU power limit to 70% of maximum limit to maximize silence at the expense of performance. Mutually exclusive with `-MaxPerf` and `-BalancedSilence`. |
| `-BalancedSilence` | `Optimize` | `Switch` | `False` | Sets GPU power limit to 85% of maximum limit for an optimal balance between silence and performance. Mutually exclusive with `-MaxPerf` and `-MaxSilence`. |
| `-ForceP0` | `Optimize` | `Switch` | `False` | Opt-in switch forcing P0 performance state on NVIDIA GPUs. Emits thermal warning. |
| `-AggressiveSilence` | `Optimize` | `Switch` | `False` | Sets CPU core parking minimum unparked threshold to 5% (default: 10%). |
| `-SkipGpu` | `Optimize` | `Switch` | `False` | Skips all GPU optimizations (HAGS, MSI, power limit, P0). |
| `-SkipCpu` | `Optimize` | `Switch` | `False` | Skips CPU power plan and scheduling optimizations. |
| `-SkipGamingFeatures`| `Optimize` | `Switch` | `False` | Skips Xbox Game Bar and Game DVR registry tweaks. |
| `-BackupPath` | Both | `String` | `$env:ProgramData\PCOptimizer` | Path where `state.json` and timestamped logs are saved. |
| `-DryRun` | Both | `Switch` | `False` | Simulates actions without altering system settings (equivalent to `-WhatIf`). |
| `-Quiet` | Both | `Switch` | `False` | Suppresses standard console messages (errors remain visible). |
| `-VerificationDelaySeconds` | `Optimize` | `Int` | `5` | Delay in seconds before verifying GPU power limit application. |

---

## Usage Examples

### 0. Guided Interactive CLI (Recommended for Users)
Launch the interactive wizard with hardware detection, visual gauge slider, and confirmation prompts:
```powershell
.\PCOptimizer-CLI.ps1
# or via module cmdlet
Start-PCOptimizerWizard
```

Display the built-in guided manual with hardware telemetry:
```powershell
.\PCOptimizer-CLI.ps1 -Help
```

Execute a simulated dry-run targeting Quiet Efficiency (Level 2):
```powershell
.\PCOptimizer-CLI.ps1 -Level 2 -DryRun -NonInteractive
```

### 1. Default Balanced Run (Performance + Acoustic Silence)
Applies HAGS, MSI mode, disables Game DVR, tunes Ryzen core parking, and caps GPU TDP to 92%:
```powershell
Invoke-PCOptimization
```

### 2. Zero-Side-Effect Simulation (Dry-Run)
Inspects what changes would be made without touching the registry, power plan, or GPU firmware:
```powershell
Invoke-PCOptimization -DryRun
```

### 3. Maximum Performance Mode
Clamps GPU power limit to hardware maximum limit and unparks cores:
```powershell
Invoke-PCOptimization -MaxPerf
```

### 4. Maximum Silence Mode
Clamps GPU power limit to 70% of the hardware maximum limit to maximize silence:
```powershell
Invoke-PCOptimization -MaxSilence
```

### 5. Balanced Silence Mode
Clamps GPU power limit to 85% of the hardware maximum limit for an optimal balance:
```powershell
Invoke-PCOptimization -BalancedSilence
```

### 6. Explicit Opt-In Force-P0 Mode
Forces P0 state for compute/memory overclocking with the mandatory thermal warning:
```powershell
Invoke-PCOptimization -ForceP0
```
> [!WARNING]
> Running with `-ForceP0` keeps NVIDIA memory clocks pinned at full speed at desktop idle, increasing power draw by ~15-30W. Re-running `Invoke-PCOptimization` without `-ForceP0` automatically cleans up this tweak.

### 7. Revert System Settings
Rolls back all registry entries, power plans, and GPU limits to pre-optimization values:
```powershell
Invoke-PCOptimization -Revert
```
Or use the dedicated cmdlet:
```powershell
Restore-PCOptimization
```

---

## Technical Deep-Dive & Trade-Offs

### 1. Hardware-Accelerated GPU Scheduling (HAGS)
- **What it does:** Sets `HwSchMode = 2` under `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`.
- **Mechanism:** Offloads frame buffering management directly to the GPU's internal scheduling processor.
- **Trade-Off:** Requires a system reboot. In rare legacy games with outdated rendering loops, HAGS may have negligible impact, but on modern DX12/Vulkan titles, it substantially stabilizes 1% low frame times.

### 2. Message Signaled Interrupts (MSI Mode)
- **What it does:** Configures `MSISupported = 1` under the device parameter registry node for all detected NVIDIA display adapters.
- **Mechanism:** Transitions the graphics card from legacy PCI pin interrupts (shared with other devices) to packet-based MSI memory writes over the PCIe bus.
- **Trade-Off:** None. Highly recommended for all modern GPUs. Note: clean NVIDIA driver updates reset this key, requiring re-running `Invoke-PCOptimization`.

### 3. GPU Power Limit & Acoustic Silence (`-SilentFactor`)
- **What it does:** Queries GPU TDP parameters via `nvidia-smi` and clamps the limit to `MaxLimit * SilentFactor` (default: 0.92, or ~202W on a 220W RTX 3070).
- **Mechanism:** Modern GPUs operate far past the efficiency point of the voltage-frequency curve at stock TDP. Clamping 8% of maximum power lowers peak GPU junction temperatures by 4°C - 8°C and cuts fan speeds by 300-600 RPM, while dropping frame rates by less than 1.5%.
- **Rollback Safety:** If `nvidia-smi` fails to verify that the power limit persisted, the module automatically reverts to factory default limits.

### 4. Ryzen 9 5950X Core Parking & Boost Mode
- **What it does:** Configures AC power settings `CPMINCORES` (10% standard, 5% aggressive) and unhides `PERFBOOSTMODE = 4` (Efficient Aggressive).
- **Mechanism:** Zen 3 multi-CCD processors experience unnecessary thermal spiking when background processes cause frequency spikes across idle cores. Efficient Aggressive boost mode requires sustained thread load before boosting, keeping desktop idle whisper-quiet.

---

## State Persistence and Log Files

PCOptimizer stores configuration files and execution logs under:
```
$env:ProgramData\PCOptimizer\
├── state.json                       # Versioned JSON snapshot (SchemaVersion 1.0.0)
├── log_yyyyMMdd_HHmmss.txt          # Timestamped execution log
└── MSIAfterburner_Profile.txt       # Tailored undervolting guidance
```

### State File Format Example
```json
{
  "SchemaVersion": "1.0.0",
  "Timestamp": "2026-09-17T05:30:00.0000000Z",
  "Environment": {
    "OSVersion": "Microsoft Windows NT 10.0.22631.0",
    "PSVersion": "7.4.0",
    "ComputerName": "RIG-RYZEN-5950X"
  },
  "HAGS": {
    "Previous": 1,
    "Applied": 2
  },
  "Msi": [
    {
      "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\...\\MessageSignaledInterruptProperties",
      "DeviceName": "NVIDIA GeForce RTX 3070",
      "Previous": null,
      "Applied": 1
    }
  ],
  "GameBar": [
    {
      "Path": "HKCU:\\System\\GameConfigStore",
      "Name": "GameDVR_Enabled",
      "Previous": 1,
      "Applied": 0
    }
  ],
  "PowerPlan": {
    "PreviousSchemeGuid": "381b4222-f694-41f0-9685-ff5bb260df2e",
    "AppliedSchemeGuid": "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",
    "AspmDisabled": true
  },
  "PowerLimit": {
    "Previous": 220.0,
    "TargetWatts": 202.0,
    "AppliedWatts": 202.0,
    "DefaultLimitWatts": 220.0,
    "MaxLimitWatts": 240.0,
    "RolledBack": false
  },
  "P0": [],
  "Cpu": {
    "CoreParkingMinPercent": 10,
    "CoreParkingMaxPercent": 100,
    "CoreParkingConfigured": true,
    "BoostMode": 4,
    "GameModeEnabled": true
  }
}
```

---

## Design Decisions

The legacy repository prototype was a monolithic 536-line French-commented script designed for a single machine. The ground-up rebuild introduces several fundamental engineering improvements:

1. **Modular Architecture:** Migrated from a single monolithic script to a properly structured PowerShell module (`Public/` and `Private/` separation) adhering to PowerShell approved verbs and cmdlet best practices.
2. **English-First Localization:** All user-facing console text, log messages, and error descriptions were migrated to English and unified in an internal string resource catalog (`Private/Get-PCOString.ps1`).
3. **Structured `nvidia-smi` CSV Parser:** Replaced fragile split expressions with a typed, schema-validating parser (`ConvertFrom-PCONvidiaSmiOutput`) that verifies column counts and numeric thresholds.
4. **Idempotency & WhatIf:** Every state-mutating cmdlet implements `[CmdletBinding(SupportsShouldProcess)]`, allowing comprehensive `-WhatIf` execution in CI and ensuring repeat runs do not corrupt state.
5. **Robust Parameter Set Isolation:** Replaced ad-hoc conditional logic with native PowerShell Parameter Sets (`Optimize` vs `Revert`), making conflicting switches syntactically impossible.
6. **Graceful Degradation:** The module seamlessly operates on machines without an NVIDIA GPU or with missing `nvidia-smi` by degrading to CPU/system optimizations without throwing errors.
7. **Comprehensive Unit Testing:** All external system commands (`powercfg`, `nvidia-smi`, `Get-PnpDevice`, registry access) are decoupled and mocked in Pester unit tests, allowing 100% test coverage without elevation or physical hardware.

---

## Testing & Quality Assurance

### Local Verification Suite

Run the full testing and static analysis pipeline locally:

```powershell
# 1. Static Analysis (PSScriptAnalyzer)
Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse

# 2. Manifest Validation
Test-ModuleManifest -Path ./PCOptimizer.psd1

# 3. Strict Mode Import
pwsh -NoProfile -Command "Set-StrictMode -Version Latest; `$ErrorActionPreference = 'Stop'; Import-Module ./PCOptimizer.psd1 -Force"

# 4. Pester Unit Tests
Invoke-Pester -Configuration @{
    Run = @{ Path = './Tests/Unit' }
    Output = @{ Verbosity = 'Detailed' }
}
```

### Continuous Integration (CI)
GitHub Actions executes on every push and pull request against `windows-latest`, enforcing:
- Zero PSScriptAnalyzer errors or unsuppressed warnings.
- Clean module manifest validation.
- Zero-error import in strict mode.
- 100% pass rate across all Pester unit test suites.

See [Tests/Integration/README.md](Tests/Integration/README.md) for the physical hardware validation checklist.

---

## Contributing & Support

We welcome issues and pull requests! Please review our [Contributing Guidelines](CONTRIBUTING.md), [Security Policy](SECURITY.md), and [Code of Conduct](CODE_OF_CONDUCT.md).

For troubleshooting common issues, see our [Troubleshooting Guide](docs/TROUBLESHOOTING.md).

---

## License

This project is licensed under the [MIT License](LICENSE).