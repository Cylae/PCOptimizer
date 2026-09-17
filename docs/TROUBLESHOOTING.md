# Troubleshooting Guide

This document outlines common questions, error conditions, and troubleshooting steps when using `PCOptimizer`.

---

## 1. Permission and Elevation Errors

### Symptom
```
[ERR] PCOptimizer requires administrative privileges. Please restart PowerShell as Administrator.
```
### Resolution
Modifications to system power plans, device interrupt configurations (MSI), and `HKLM` registry paths require an elevated security token. Right-click your PowerShell 7 shortcut or terminal and choose **Run as Administrator**.

---

## 2. NVIDIA Driver Updates Reset MSI Mode

### Symptom
After installing a new Game Ready or Studio driver from NVIDIA or GeForce Experience, the GPU reverts to legacy Pin-IRQ mode instead of Message Signaled Interrupts (MSI).
### Explanation
NVIDIA's driver installer rebuilds the device parameter registry node during clean or standard driver installations, clearing `MSISupported`.
### Resolution
Re-run `Invoke-PCOptimization` or `Optimize-Gpu` after each GPU driver update. The command is fully idempotent and will re-enable MSI mode within seconds.

---

## 3. PowerCfg ASPM Warning

### Symptom
```
[WARN] PCIe ASPM setting is locked or unavailable on this motherboard firmware.
```
### Explanation
Certain OEM motherboard UEFI/BIOS configurations lock PCI Express Active State Power Management (ASPM) at the ACPI table level, preventing Windows from altering link power states.
### Resolution
This warning is non-fatal. `PCOptimizer` safely catches this condition and continues with power plan and processor throttling configuration. If desired, check your BIOS settings under `PCIe Subsystem Settings -> ASPM Support` and set it to `Disabled`.

---

## 4. GPU Power Limit Verification Rollback

### Symptom
```
[WARN] GPU power limit verification failed; driver rejected or reverted value. Rolling back to default (220 W).
```
### Explanation
NVIDIA drivers or certain VBIOS limits (such as laptops or locked OEM desktop cards) reject power limit adjustments outside their supported range. When `PCOptimizer` detects that the power limit did not stick, it immediately triggers an automatic rollback to the factory default limit to protect hardware stability.
### Resolution
1. Verify whether your GPU VBIOS permits software power limit modifications by running:
   ```powershell
   nvidia-smi -q -d POWER
   ```
2. If your card has a locked VBIOS, use MSI Afterburner undervolting via the Voltage/Frequency curve instead (see [Hardware Tuning Guide](HARDWARE_TUNING_GUIDE.md)).

---

## 5. Reverting System Settings

### Symptom
You wish to undo all optimizations applied by `PCOptimizer`.
### Resolution
Execute the revert command:
```powershell
Invoke-PCOptimization -Revert
```
Or use the dedicated rollback cmdlet:
```powershell
Restore-PCOptimization
```
This restores all captured registry keys, reinstates your previous active Windows power scheme, resets GPU power limits to factory defaults, and removes forced P0 tweaks.
