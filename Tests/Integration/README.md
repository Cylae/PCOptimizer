# Integration & Manual Hardware Testing Protocol

Full verification of kernel-level GPU scheduling, hardware power limit clamping, and UEFI ACPI power schemes requires elevated privileges on physical Windows hardware with an AMD Ryzen CPU and an NVIDIA GeForce RTX GPU.

This document provides the standard numbered testing protocol to be executed on physical hardware.

---

## Test Environment Specification

- **Target CPU:** AMD Ryzen 9 5950X (or Zen 3 multi-CCD processor)
- **Target GPU:** NVIDIA GeForce RTX 3070 (or Ampere/Ada Lovelace GPU)
- **Target OS:** Windows 11 23H2+ (or Windows 10 21H2+)
- **PowerShell Version:** PowerShell 7.4+

---

## Numbered Integration Test Cases

### Test 1: Platform & Elevation Gatekeeper
1. Open a non-elevated PowerShell 7 session.
2. Attempt to run:
   ```powershell
   Import-Module ./PCOptimizer.psd1 -Force
   Invoke-PCOptimization
   ```
3. **Expected Result:** Throws a `SecurityException` stating administrative privileges are required. No state file or logs should be created.
4. **Execution Status:** Automated in Unit Test Suite & validated locally.

---

### Test 2: Dry-Run / Zero-Side-Effect Simulation
1. Open an elevated Administrator PowerShell 7 session.
2. Run:
   ```powershell
   Invoke-PCOptimization -DryRun
   ```
3. Inspect current registry keys and active power scheme:
   ```powershell
   Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode'
   powercfg /getactivescheme
   ```
4. **Expected Result:** Console displays simulated actions with `[WhatIf]`. No registry values, power schemes, or GPU power limits are altered on the system.
5. **Execution Status:** Automated in Unit Test Suite.

---

### Test 3: Standard Performance + Silence Run on Physical Hardware
1. Run in an elevated session:
   ```powershell
   Invoke-PCOptimization -SilentFactor 0.92
   ```
2. Verify registry and system changes:
   - **HAGS:** `Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode'` equals `2`.
   - **MSI Mode:** Inspect NVIDIA display adapter subkey `...\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties\MSISupported` equals `1`.
   - **Game Bar:** `Get-ItemPropertyValue 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled'` equals `0`.
   - **Power Plan:** `powercfg /getactivescheme` matches `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` (High performance).
   - **GPU Power Limit:** `nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits` reports `202` W (92% of 220W).
   - **State Persistence:** `$env:ProgramData\PCOptimizer\state.json` exists, is valid JSON, and has `SchemaVersion: "1.0.0"`.
3. **Execution Status:** Requires physical elevated RTX 3070 / Ryzen hardware. (Simulated via mocks in automated unit suite).

---

### Test 4: Revert Verification
1. Following Test 3, execute:
   ```powershell
   Invoke-PCOptimization -Revert
   ```
2. Check that all values return to pre-optimization values:
   - HAGS returns to prior value (or property removed if it did not exist).
   - MSI mode returns to prior value.
   - Game Bar returns to prior values.
   - Active power scheme returns to prior active GUID.
   - GPU power limit returns to factory default (e.g., 220W).
3. **Execution Status:** Requires physical elevated hardware. (Simulated via mocks in automated unit suite).

---

### Test 5: Hardware Absence & Graceful Degradation
1. Run on a machine without an NVIDIA GPU or with the NVIDIA driver disabled in Device Manager.
2. Run `Invoke-PCOptimization`.
3. **Expected Result:** Logs `[WARN] No NVIDIA GPU detected or nvidia-smi unavailable. Skipping GPU power limit tuning.` and successfully executes CPU and Windows gaming optimizations without crashing.
4. **Execution Status:** Automated in Unit Test Suite.

---

### Test 6: Opt-In Force-P0 and Thermal Warning
1. In an elevated session, run:
   ```powershell
   Invoke-PCOptimization -ForceP0
   ```
2. **Expected Result:**
   - Prints warning: `[WARN] WARNING: Forcing P0 mode prevents GPU core/memory downclocking at idle, increasing power consumption and idle temperatures.`
   - Sets `DisableDynamicPstate = 1` under display class keys.
3. Re-running standard `Invoke-PCOptimization` (without `-ForceP0`) automatically cleans up the stale P0 tweak.
4. **Execution Status:** Automated in Unit Test Suite.

---

### Test 7: Post-Reboot Verification
1. Reboot the PC after running Test 3.
2. Confirm via Windows Settings -> Display -> Graphics -> Default Graphics Settings that Hardware-Accelerated GPU Scheduling is indicated as "On".
3. Validate MSI mode persistence using device manager or MSI Utility v3.
4. **Execution Status:** Requires human operator on target PC.
