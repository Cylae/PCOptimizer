# PCOptimizer Architecture & Design

This document details the architectural layout, design principles, and data lifecycle of the `PCOptimizer` PowerShell module.

## Architectural Overview

`PCOptimizer` is designed around a modular, non-monolithic PowerShell architecture adhering to modern PowerShell scripting standards:

```
PCOptimizer/
│
├── PCOptimizer.psd1                 # Module manifest (SemVer, author, requirements)
├── PCOptimizer.psm1                 # Module loader (dot-sourcing Private/ and Public/)
│
├── Public/                          # Exported user-facing cmdlets
│   ├── Invoke-PCOptimization.ps1    # Main workflow coordinator (Alias: Optimize-PC)
│   ├── Restore-PCOptimization.ps1   # Revert engine
│   ├── Get-PCOptimizationState.ps1  # State inspector and loader
│   ├── Get-NvidiaGpuStatus.ps1      # Safe GPU telemetry reader
│   ├── Export-MSIAfterburnerProfile # Afterburner guidance exporter
│   ├── Optimize-Gpu.ps1             # Modular GPU coordinator
│   ├── Optimize-Cpu.ps1             # Modular CPU coordinator
│   └── Optimize-GamingFeatures.ps1  # Modular gaming subsystem coordinator
│
└── Private/                         # Encapsulated internal helpers
    ├── Write-PCOLog.ps1             # Dual console/file structured logger
    ├── Get-PCOString.ps1            # Centralized string catalog
    ├── Test-PCOAdmin.ps1            # Elevated administrator validator
    ├── Test-PCOPlatform.ps1         # OS build and platform validator
    ├── Set-PCORegistryDword.ps1     # Idempotent DWORD writer with prior capture
    ├── Remove-PCORegistryValue.ps1  # Safe registry value remover
    ├── Invoke-PCOPowerCfg.ps1       # Process wrapper for powercfg.exe
    ├── Find-PCONvidiaSmi.ps1        # nvidia-smi path resolver
    ├── ConvertFrom-PCONvidiaSmiOutput.ps1 # Strict CSV telemetry parser
    ├── Set-PCONvidiaPowerLimit.ps1  # Power limit applicator with verification
    ├── Enable-PCOHags.ps1           # HAGS registry activator
    ├── Enable-PCOMsiMode.ps1        # Message Signaled Interrupts activator
    ├── Set-PCOGameBarState.ps1      # GameDVR registry optimizer
    ├── Set-PCOPowerPlan.ps1         # Windows High Performance plan activator
    ├── Set-PCOProcessorScheduling.ps1 # Core parking and boost mode tuner
    ├── Remove-PCOP0Tweak.ps1        # Residual P0 cleaner
    ├── Enable-PCOP0Mode.ps1         # Opt-in P0 registry modifier
    ├── Save-PCOState.ps1            # Atomic JSON state snapshot writer
    └── Restore-PCORegistryState.ps1 # Generalized registry snapshot reverter
```

## Core Design Principles

### 1. Reversibility First
No system mutation occurs without first capturing the antecedent value. Every public function that modifies registry entries, power schemes, or GPU clock states persists the previous state to `$BackupPath\state.json`. `Restore-PCOptimization` reads this state file and reverses each individual mutation.

### 2. Idempotency & `-WhatIf` (ShouldProcess)
All modifying functions declare `[CmdletBinding(SupportsShouldProcess)]`. Re-running an optimization does not duplicate keys, double-apply changes, or throw errors if a setting is already at the optimal value. Passing `-WhatIf` or `-DryRun` traces all proposed actions with zero system changes.

### 3. Graceful Hardware Degradation
If `nvidia-smi` or an NVIDIA GPU is not detected, the module logs an informational warning and proceeds with CPU and system optimizations. The GPU routines fail gracefully and never throw unhandled exceptions.

### 4. Verification & Automatic Rollback
When adjusting GPU power limit clamps via `nvidia-smi -pl`, the driver may intermittently discard values if they violate thermal or VBIOS limits. `Set-PCONvidiaPowerLimit` performs a timed read-back verification. If the applied limit fails to match the requested target, it rolls back to factory default limits immediately and alerts the user.

### 5. Structured State Schema
The state file `state.json` is strictly versioned with `SchemaVersion = "1.0.0"`. It captures execution timestamp, OS build, PowerShell version, machine name, and isolated blocks for each component:

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
      "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\PCI\\VEN_10DE...\\Device Parameters\\Interrupt Management\\MessageSignaledInterruptProperties",
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
