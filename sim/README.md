# Simulation Directory

This directory contains simulation scripts for the eMMC Controller IP.

## Contents

| File | Description |
|------|-------------|
| `flist.f` | File list for RTL compilation |
| `qsim.do` | QuestaSim/ModelSim simulation script |
| `wave.do` | Waveform configuration script |
| `clean.do` | Clean up simulation artifacts |

## Prerequisites

- **Lattice Radiant** installed (for device simulation libraries)
- **QuestaSim/ModelSim** simulation tool

## Running Simulation

### Standalone Simulation (without Radiant IP generation)

1. Navigate to this directory:
   ```bash
   cd sim/
   ```

2. Set the FOUNDRY path (update to your Radiant installation):
   ```tcl
   set FOUNDRY "C:/lscc/radiant/2025.1"
   ```

3. Launch QuestaSim/ModelSim and run the script:
   ```tcl
   do qsim.do
   ```

4. View waveforms in the GUI

### Required Libraries

The simulation uses pre-compiled Lattice device libraries from:
```
$FOUNDRY/cae_library/simulation/libs/
```

| Library | Description |
|---------|-------------|
| `pmi_work` | PMI (Parameterized Module Instantiation) library |
| `ovi_ap6a00b` | LAV-AT (Avant) device library (default) |

For other device families, update `DEVICE_LIB` in `qsim.do`:

| Device Family | Library Name |
|---------------|--------------|
| LAV-AT (Avant) | `ovi_ap6a00b`, `ovi_ap6a00c` |
| CrossLink-NX | `lifcl` |
| MachXO5 | `lfmxo5`, `lfmxo5t` |
| CertusPro-NX | `lfcpnx` |

### With Generated IP

If you have generated the IP through Radiant:

1. The generated IP will include `dut_params.v` and `dut_inst.v` in the testbench directory
2. Define `DUT_INST_NAME` macro during compilation to use the generated instance
3. The testbench will automatically use the generated IP configuration

## Configuration

### Changing Data Interface

The default configuration uses AXI4. To simulate with AHB-Lite:

1. Edit the standalone defaults in `tb_top.v`:
   ```verilog
   localparam DATA_INTERFACE = "AHBL";  // Change from "AXI4"
   ```

2. Re-run simulation

### Simulation Parameters

Key parameters (defined in `tb_top.v` standalone mode):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DEVICE_FAMILY` | "LAV-AT" | Target FPGA family |
| `DATA_INTERFACE` | "AXI4" | Data interface type (AXI4 or AHBL) |
| `CLKI_FREQ` | 100.0 | System clock frequency (MHz) |
| `SPI_SCKDIV` | 125 | eMMC clock divider |
| `MAX_NUMLANE` | 8 | Maximum data lanes (1, 4, or 8) |

## Troubleshooting

### "eMMC Device Model Not Provided"

The `mdl_emmc.v` is a stub placeholder. For full simulation, you need to provide your own eMMC device model compatible with JEDEC eMMC specification.

### Compilation Errors

- Ensure all RTL files are present in `../rtl/`
- Check that testbench files exist in `../testbench/`
- Verify file paths in `flist.f`

### Waveform Issues

- Modify `wave.do` to add/remove signals as needed
- Signal paths may differ if using generated IP instance


