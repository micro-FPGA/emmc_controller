# IP Release Notes

## 1. Introduction

This document contains the Release Notes for the eMMC Controller IP. For specific details about the IP, refer to the following:
- README.md
- QUICKSTART.md
- doc/introduction.html

---

## eMMC Controller IP v1.0.0

| Software | Software Version | Summary of Changes |
|----------|------------------|-------------------|
| Lattice Radiant | 2025.1+ | • Initial release |
| Lattice Propel | 2025.1+ | • Initial release |

### Features

- JEDEC JESD84-B51A standard support
- Data IO width: x1, x4, x8
- AXI4 Manager interface for data transfer
- AHB-Lite Manager interface (alternative)
- APB Subordinate interface for CSR access
- eMMC clock frequencies up to 52 MHz (SDR)
- Programmable clock divider
- Configurable FIFO depth (512 to 8192 bytes)
- Interrupt support
- Optional IO primitive integration

### Supported Devices

- LAV-AT (Lattice Avant)
- LFCPNX (CertusPro-NX)
- LFD2NX (Certus-NX)
- LIFCL (CrossLink-NX)
- LFMXO5 (MachXO5-NX)

### Known Limitations

- DDR mode not implemented
- HS200/HS400 modes not implemented
- Boot mode not implemented
- Maximum speed: 52 MB/s (High Speed SDR)

### Validation

| Test | Status | Details |
|------|--------|---------|
| RTL Simulation | ✅ Passed | QuestaSim/ModelSim |
| Hardware Testing | ✅ Passed | Basic commands validated on Sentry DC-SCM Board with MachXO5D (XO5D) |
| Static Timing Analysis | ✅ Met | 100 MHz system clock |

---
