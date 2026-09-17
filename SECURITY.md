# Security Policy

## Security Overview

`PCOptimizer` is a Windows systems optimization toolkit intended for gaming and high-performance computing configurations. Because this toolkit interacts directly with low-level Windows subsystem settings, hardware power targets, and system registry configurations, it requires elevated Windows Administrator privileges.

### Scope of System Interactions

The module performs operations strictly limited to the following areas:
1. **Registry (`HKLM` and `HKCU`):**
   - Hardware-Accelerated GPU Scheduling (`HwSchMode`).
   - Message Signaled Interrupts (`MSISupported` under device parameter trees).
   - Windows Game Bar / Game DVR telemetry and recording captures.
   - Processor Performance Boost Mode visibility (`Attributes`).
   - Dynamic P-State control (`DisableDynamicPstate`, opt-in only via `-ForceP0`).
2. **Power Schemes (`powercfg.exe`):**
   - High Performance AC power scheme activation.
   - Processor throttle bounds (`PROCTHROTTLEMIN`, `PROCTHROTTLEMAX`).
   - Core parking percentage bounds (`CPMINCORES`, `CPMAXCORES`).
   - PCIe Active State Power Management (`ASPM`).
3. **GPU Management (`nvidia-smi.exe`):**
   - NVIDIA GPU power limit clamp queries and adjustments (`-pl`).

### Safety and Non-Destructive Principles

- **Prior State Capture:** Every system setting modified by `PCOptimizer` is snapshotted to a local, schema-versioned state file (`state.json`) prior to mutation.
- **Rollback Engine:** Every modification is fully reversible via `Restore-PCOptimization` or `Invoke-PCOptimization -Revert`.
- **Automatic Fallback:** GPU power limit adjustments perform a post-application verification step. If the GPU driver rejects or fails to retain the target limit within a verification window, the toolkit automatically rolls back to the GPU's default factory limit.
- **Auditing:** All operations are logged to both the console and a local timestamped log file (`log_yyyyMMdd_HHmmss.txt`) stored under `$env:ProgramData\PCOptimizer`.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0.0 | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, privilege escalation risk, or potential for unrecoverable system corruption within `PCOptimizer`:

1. **Do not open a public GitHub issue.**
2. Report the vulnerability privately via GitHub Security Advisories or by emailing the project maintainer at `security@cylae.dev`.
3. Provide detailed reproduction steps, the specific Windows OS build, PowerShell version, and hardware configuration.
4. The maintainers will acknowledge receipt within 48 hours and provide an assessment and timeline for a patch.
