# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-17

### Added
- **Full PowerShell Module Architecture**: Restructured into a standard PowerShell module with manifest `PCOptimizer.psd1`, loader `PCOptimizer.psm1`, and separated `Public/` and `Private/` functions.
- **English Default Localization**: Converted all French console outputs, log entries, and comments into English, backed by a unified string repository (`Private/Get-PCOString.ps1`).
- **Structured Logging System**: Implemented `Write-PCOLog` with support for levels (`Debug`, `Info`, `Warn`, `Error`, `Success`, `Step`), dual console color output, persistent timestamped log files, and `-Quiet` / `-Verbose` handling.
- **Robust `nvidia-smi` CSV Parser**: Introduced `ConvertFrom-PCONvidiaSmiOutput` validating column structure, type-casting numeric power/clock values, and safely degrading when NVIDIA hardware or drivers are absent.
- **Idempotency & WhatIf Support**: All mutating cmdlets implement `[CmdletBinding(SupportsShouldProcess)]` with `-WhatIf` / `-Confirm` support and idempotent re-execution safety.
- **Parameter Sets & Validation**: Added strict `[ValidateRange(0.01, 1.0)]` on `SilentFactor`, parameter set isolation preventing illegal combinations (e.g. `-MaxPerf` with `-Revert`), and path validation.
- **Schema-Versioned State Persistence**: State file `state.json` now includes `SchemaVersion`, system environment metadata, and full state validation with recovery from corrupt or missing files.
- **Standalone Public Cmdlets**:
  - `Invoke-PCOptimization` (alias `Optimize-PC`)
  - `Restore-PCOptimization`
  - `Get-PCOptimizationState`
  - `Get-NvidiaGpuStatus`
  - `Export-MSIAfterburnerProfile`
  - `Optimize-Gpu`
  - `Optimize-Cpu`
  - `Optimize-GamingFeatures`
- **Comprehensive Pester Unit Test Suite**: Over 40 unit tests covering success, hardware absence, bad parameters, state corruption, idempotency, and side-effect-free `-WhatIf` operation using mocks.
- **CI/CD Automation**: GitHub Actions workflow running static analysis (`PSScriptAnalyzer`) and Pester unit test suites on Windows runners.
- **Documentation & Guides**: Added architecture diagram, hardware tuning guide for RTX 3070 undervolting and Ryzen 9 5950X PBO/Curve Optimizer, troubleshooting guide, and reproducible example scripts.

### Changed
- **Default State Directory**: Changed default backup directory from `$env:ProgramData\RTX3070-5950X-Optimizer` to `$env:ProgramData\PCOptimizer` (with automated fallback checks for existing legacy backups).
- **Error Handling**: Replaced silent error swallowing (`-ErrorAction SilentlyContinue`) with structured `try`/`catch` blocks, exit codes, and actionable feedback.

### Removed
- **Legacy Monolithic Script**: Completely removed the original single-file French prototype script.
