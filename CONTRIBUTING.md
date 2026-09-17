# Contributing to PCOptimizer

Thank you for your interest in contributing to `PCOptimizer`. We welcome bug reports, feature enhancements, documentation improvements, and pull requests that adhere to our development standards.

## Code of Conduct

All contributors and participants must adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

## Development Environment Requirements

- **PowerShell Version:** PowerShell 7.4 or later (`pwsh`).
- **Operating System:** Windows 10 (Build 19044/21H2+) or Windows 11.
- **PowerShell Modules:**
  - `Pester` (v5.0 or later, installed via `Install-Module -Name Pester -Scope CurrentUser`)
  - `PSScriptAnalyzer` (v1.22+ or later, installed via `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser`)

## Coding Standards & Guidelines

1. **Cmdlet Design:**
   - Every public cmdlet must adhere to standard PowerShell approved verbs (`Get-Verb`).
   - Every state-mutating function must declare `[CmdletBinding(SupportsShouldProcess)]` and respect `-WhatIf` / `-Confirm`.
   - Functions must be idempotent; running an optimization multiple times must not fail or produce erratic state.
2. **System Calls & Isolation:**
   - Never call destructive or modifying cmdlets without prior state recording.
   - All external system calls (`powercfg`, `nvidia-smi`, `Get-PnpDevice`, registry access) must be abstracted or isolated so that unit tests can mock them without requiring elevation or real hardware.
3. **Error Handling:**
   - Do not swallow fatal exceptions with `SilentlyContinue` unless explicitly checking non-essential optional keys (which must be documented).
   - Use structured `try` / `catch` blocks with descriptive error logs and actionable guidance.
4. **Strings & Localization:**
   - Centralize user-facing text strings in `Private/Get-PCOString.ps1`. English is the default project language.

## Running Tests Locally

Before submitting a Pull Request, verify that static analysis and unit tests pass cleanly:

```powershell
# 1. Static Analysis
Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse

# 2. Test Manifest
Test-ModuleManifest -Path ./PCOptimizer.psd1

# 3. Strict Mode Import
pwsh -NoProfile -Command "Set-StrictMode -Version Latest; `$ErrorActionPreference = 'Stop'; Import-Module ./PCOptimizer.psd1 -Force"

# 4. Unit Tests
Invoke-Pester -Configuration @{
    Run = @{ Path = './Tests/Unit' }
    Output = @{ Verbosity = 'Detailed' }
}
```

## Pull Request Process

1. Fork the repository and create a feature branch (`git checkout -b feature/my-feature`).
2. Implement your changes following module patterns (`Public/`, `Private/`, unit tests in `Tests/Unit/`).
3. Ensure all tests and static analysis checks pass with zero warnings or errors.
4. Update `CHANGELOG.md` under `[Unreleased]` with a summary of your changes.
5. Open a Pull Request against the `main` branch with a clear description of the motivation and behavior changes.
