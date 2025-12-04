# eMMC Controller - Quick Start Guide

This guide provides step-by-step instructions to quickly run simulations and generate bitstreams for the eMMC Controller IP.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Running Simulation](#running-simulation)
- [Generating Bitstream for Hardware](#generating-bitstream-for-hardware)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have the following tools installed:

- **QuestaSim/ModelSim** - For RTL simulation
- **Lattice Propel** - For SoC integration and IP configuration
- **Lattice Radiant** - For FPGA synthesis and bitstream generation
- **Git** - For cloning the repository

---

## Running Simulation

Follow these steps to run RTL simulation for the IP.

### Standalone Simulation (without IP generation)

1. **Navigate to the simulation directory:**
   ```bash
   cd sim/
   ```

2. **Launch QuestaSim/ModelSim and run the simulation script:**
   ```tcl
   do qsim.do
   ```

3. **View the waveforms** in your simulation tool's GUI to analyze the simulation results.

**Notes:**
- Standalone simulation uses default parameters defined in `tb_top.v`
- The eMMC device model (`mdl_emmc.v`) is a stub - you must provide your own eMMC device model for full functional simulation
- Current implementation supports SDR mode only (up to 52 MB/s). DDR, HS200, HS400, and Boot modes are not yet implemented

### Simulation with Generated IP

1. **Generate the IP in Radiant** using the IP Catalog
2. **Navigate to the generated IP's testbench directory**
3. **Run simulation** - the generated `dut_params.v` and `dut_inst.v` will be used automatically

---

## Generating Bitstream for Hardware

Follow these steps to synthesize the design and generate a bitstream for FPGA programming.

### Using Example Design (Propel SoC)

1. **Open the Propel project:**
   - Navigate to `example_design/soc_emmc/`
   - Open `soc_emmc.sbx` with Lattice Propel

2. **Generate the Radiant project:**
   - In Propel, click on the **Radiant icon** in the toolbar
   - Propel will automatically generate the Radiant project files
   - Radiant will open automatically with the generated project

3. **Add timing constraints:**
   - In Radiant, go to **File List** view
   - Right-click on **Constraint Files** → **Add** → **Existing File**
   - Navigate to: `example_design/soc_emmc/constraint/soc_emmc_constraint.pdc`
   - Select and add the constraint file

4. **Begin the bitstream generation flow:**
   - In Radiant, click **Tools** → **Run All** (or press `Ctrl+R`)
   - Alternatively, run the individual steps:
     1. **Synthesis** - Synthesize the RTL design
     2. **Map** - Map the design to FPGA resources
     3. **Place & Route** - Place and route the design
     4. **Generate Bitstream** - Generate the programming file

5. **Locate the generated bitstream:**
   - After successful completion, the bitstream will be located at:
     ```
     example_design/soc_emmc/impl_1/soc_emmc_impl_1.bit
     ```

6. **Program the FPGA:**
   - Use Lattice Programmer or Radiant's programming tool to download the bitstream to your target FPGA board

---

## Troubleshooting

### Simulation Issues

**Problem:** "eMMC Device Model Not Provided" message and simulation stops

**Solution:**
- The `mdl_emmc.v` is a stub placeholder
- You must provide your own eMMC device model compatible with JEDEC eMMC specification
- Options:
  - Obtain an eMMC device model from a third-party vendor
  - Use a behavioral model from your eMMC silicon vendor
  - Implement a custom eMMC device model

**Problem:** Simulation fails with undefined macro errors

**Solution:**
- Ensure you're running simulation from the `sim/` directory
- Check that `+incdir+../testbench/` is in the file list
- Verify all testbench files exist in `testbench/`

**Problem:** Library not found errors

**Solution:**
- Update the `FOUNDRY` path in `qsim.do` to match your Radiant installation
- Verify the device library exists (e.g., `ovi_ap6a00b` for LAV-AT)

---

### IP Integration Issues

**Problem:** IP doesn't appear in Radiant/Propel IP catalog

**Solution:**
- Ensure the IP repository path is correctly configured in Radiant/Propel
- Verify that `metadata.xml` and `plugin/` directory are present
- Check Radiant/Propel version compatibility (minimum 2025.1)

**Problem:** Synthesis fails with compilation errors

**Solution:**
- Verify all RTL files are included in the project
- Check that the target FPGA family matches the IP configuration
- Ensure all required Lattice primitives are available for your device

---

### Radiant Synthesis Issues

**Problem:** Constraint file not found

**Solution:**
- Ensure the path is correct: `example_design/soc_emmc/constraint/soc_emmc_constraint.pdc`
- If the file is missing, check if it exists in the repository

**Problem:** Synthesis fails with timing violations

**Solution:**
- Review the timing reports in Radiant (`impl_1/*.rpt` files)
- Adjust the clock frequency or constraints as needed
- Consider using a lower eMMC clock frequency

---

### Hardware Issues

**Problem:** eMMC device not responding

**Solution:**
- Verify eMMC physical connections (clock, command, data signals)
- Check that device power-up sequence is correct (wait for power stable)
- Verify reset timing - assert `emmc_rst_n_o` for at least 1ms after power-up
- Review register configuration via APB interface

**Problem:** Data transfer errors or CRC failures

**Solution:**
- Reduce eMMC clock frequency via `CFG0.CLK_DIV` register
- Check signal integrity on the eMMC bus (reflections, crosstalk)
- Verify IO voltage levels match eMMC device requirements
- Ensure proper termination on data lines

---

## Additional Resources

- **Full Documentation:** See [README.md](README.md) for detailed IP documentation
- **IP Metadata:** Review [metadata.xml](metadata.xml) for IP configuration details
- **Register Map:** See [memory_map.xml](memory_map.xml) for register definitions
- **Simulation Guide:** See [sim/README.md](sim/README.md) for simulation details

---

## Support

For issues, questions, or feature requests, please:
- Check the [README.md](README.md) for detailed documentation
- Review the [doc/introduction.html](doc/introduction.html) for IP-specific details
- Contact Lattice Semiconductor support

---

**Quick Reference:**

| Task | Command/Location |
|------|------------------|
| Run Simulation | `cd sim/` → `do qsim.do` |
| Clean Simulation | `cd sim/` → `do clean.do` |
| Open Propel Project | `example_design/soc_emmc/soc_emmc.sbx` |
| Constraint File | `example_design/soc_emmc/constraint/soc_emmc_constraint.pdc` |
| Generated Bitstream | `example_design/soc_emmc/impl_1/soc_emmc_impl_1.bit` |

