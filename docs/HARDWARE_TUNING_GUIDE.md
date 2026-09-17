# Hardware Tuning Guide: RTX 3070 + Ryzen 9 5950X

This guide provides technical explanations of the optimizations applied by `PCOptimizer` and instructions for complementary hardware tuning.

---

## 1. NVIDIA GPU Optimization (RTX 3070 / Ampere)

### Hardware-Accelerated GPU Scheduling (HAGS)
- **Registry Key:** `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\HwSchMode`
- **Value:** `2` (Enabled)
- **Mechanism:** Passes frame scheduling directly to a dedicated GPU scheduling processor instead of depending on high-frequency CPU thread context switches. This reduces CPU-GPU synchronization latency and improves frame time 1% lows in modern DirectX 12 and Vulkan titles.
- **Requirement:** A Windows system reboot is mandatory for the display driver to load the scheduling kernel.

### Message Signaled Interrupts (MSI Mode)
- **Registry Key:** `...\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties\MSISupported`
- **Value:** `1` (Enabled)
- **Mechanism:** Converts the GPU from legacy line-based Pin-IRQs to PCI Express Message Signaled Interrupts (MSI). MSI uses in-band memory writes over PCIe rather than dedicated interrupt lines, preventing IRQ conflicts with storage controllers or USB hubs and cutting interrupt latency from microseconds to nanoseconds.

### GPU Power Limit & Acoustic Silence Target
- **`-SilentFactor` (Default: `0.92`):** Capping the power limit to 92% (~202W) of the maximum VBIOS limit drops fan noise noticeably while frame rate remains virtually indistinguishable from stock.
- **`-MaxSilence`:** Sets the power limit to 70% of the maximum VBIOS limit, prioritizing acoustic silence at the expense of performance. Ideal for quiet environments.
- **`-BalancedSilence`:** Sets the power limit to 85% of the maximum VBIOS limit, offering an optimal balance between low fan noise and high frame rates.
- **Mechanism:** NVIDIA Ampere GPUs exhibit steep voltage-frequency scaling curves near their TDP ceiling. Running an RTX 3070 at 100% TDP (~220W-240W) forces the cooling fans to operate at high RPMs to dissipate the last 20-30 watts, for an FPS gain of often less than 1.5%. Lowering the power limit reduces heat and fan speed.
- **Rollback Safety:** If `nvidia-smi` fails to verify that the power limit persisted, the module automatically reverts to factory default limits.

### Forced P0 State (`-ForceP0`)
- **Registry Key:** `DisableDynamicPstate` under the display driver class key.
- **Default:** Disabled (opt-in only via `-ForceP0`).
- **Explanation:** By default, NVIDIA drivers drop memory clocks from P0 (highest performance) to P2 during CUDA or compute tasks to ensure stability. Forcing P0 locks maximum memory bandwidth. However, **this prevents the card from entering lower power P8/P12 states at idle**, keeping memory clocks pinned at full speed, increasing idle power draw by 15-30W, and causing fans to spin up intermittently while browsing the desktop.

---

## 2. AMD Ryzen 9 5950X / Zen 3 Tuning

### Core Parking (`CPMINCORES` / `CPMAXCORES`)
- **Settings:** Minimum cores set to `10%` (or `5%` with `-AggressiveSilence`), maximum set to `100%`.
- **Mechanism:** Zen 3 multi-CCD processors (such as the 16-core 5950X) benefit from parking idle cores across CCD1 while light tasks or single-threaded workloads are concentrated on the highest-boost cores of CCD0. This permits idle cores to enter deep C6 sleep states, reducing idle package power and acoustic cooler noise.

### Processor Performance Boost Mode (`PERFBOOSTMODE`)
- **Settings:** Mode set to `4` (Efficient Aggressive).
- **Mechanism:** Unhides the hidden Windows power setting `54533251-82be-4824-96c1-47b60b740d00\be337238-0d82-4146-a960-4f3749d470c7` and selects Efficient Aggressive. This instructs the Windows kernel scheduler to demand sustained high workload before triggering aggressive CPU core frequency multipliers, eliminating fan revving on short background tasks.

### PCIe Active State Power Management (ASPM)
- **Setting:** `SUB_PCIEXPRESS ASPM 0` (Disabled).
- **Mechanism:** Disables PCIe link-state power savings on the primary graphics bus, preventing PCIe link retraining latency when transitioning from idle to 3D rendering.

---

## 3. Complementary Manual Tuning (Post-Reboot)

### A. MSI Afterburner Undervolting
`PCOptimizer` generates a customized guidance file at `$BackupPath\MSIAfterburner_Profile.txt`.
1. Open MSI Afterburner and press `Ctrl + F` to open the Curve Editor.
2. Select the curve point at **900 mV** or **925 mV**.
3. Raise that point to **1900 MHz - 1950 MHz**.
4. Flatten all points to the right by dragging them level with the target point or pressing `Shift + Enter`.
5. Apply and save the profile. Run Unigine Superposition or 3DMark Time Spy for 30 minutes to verify stability.

### B. AMD Ryzen BIOS: Precision Boost Overdrive & Curve Optimizer
1. Reboot into motherboard UEFI/BIOS.
2. Navigate to `Advanced -> AMD Overclocking -> Precision Boost Overdrive`.
3. Set `Precision Boost Overdrive` to **Enabled** or **Advanced**.
4. Set `Curve Optimizer` to **All Cores** or **Per Core**.
5. Set `Sign` to **Negative** and start with a magnitude of **-15** (stable on almost all Zen 3 silicon).
6. Validate stability using CoreCycler or Cinebench R23. A negative curve lowers vCore voltage at any given frequency, reducing CPU heat output by 5°C - 10°C and allowing longer sustained boost clocks.
