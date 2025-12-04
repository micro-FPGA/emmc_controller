# =============================================================================
# QuestaSim/ModelSim Simulation Script
# eMMC Controller IP - Standalone Simulation
# =============================================================================
#
# Usage:
#   cd sim/
#   do qsim.do
#
# Prerequisites:
#   - Lattice Radiant installed (for pre-compiled device libraries)
#
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration - Update these paths for your environment
# -----------------------------------------------------------------------------
# Radiant installation path (update if different)
if {![info exists FOUNDRY]} {
   set FOUNDRY "C:/lscc/radiant/2026.1"
}

# Pre-compiled library path
set LIB_PATH "$FOUNDRY/cae_library/simulation/libs"

# Device family library (change based on target device)
# Options:
#   ovi_ap6a00b, ovi_ap6a00c - LAV-AT (Avant)
#   lifcl                    - CrossLink-NX
#   lfmxo5, lfmxo5t          - MachXO5
#   lfcpnx                   - CertusPro-NX
set DEVICE_LIB "ovi_ap6a00b"

# -----------------------------------------------------------------------------
# Clean up previous simulation work directory
# -----------------------------------------------------------------------------
if {[file exists work]} {
   file delete -force work
}

# -----------------------------------------------------------------------------
# Create work library
# -----------------------------------------------------------------------------
vlib work

# -----------------------------------------------------------------------------
# Map pre-compiled Lattice libraries
# -----------------------------------------------------------------------------
vmap pmi_work $LIB_PATH/pmi_work
vmap $DEVICE_LIB $LIB_PATH/$DEVICE_LIB

# -----------------------------------------------------------------------------
# Compile RTL files using file list
# -----------------------------------------------------------------------------
# -timescale: Set simulation time precision
# -f: Use file list for compilation
# -sv: Enable SystemVerilog support
# -mfcu: Multi-file compilation unit support
# -l: Log file for compilation
# -suppress: Suppress specific warning codes
vlog -timescale 1ns/1ps -f flist.f -sv -mfcu -l compile.log -suppress 2388,2083

# -----------------------------------------------------------------------------
# Optimize design
# -----------------------------------------------------------------------------
# -L: Link with additional libraries
# -debug: Enable debugging features
# -work: Target work library
# tb_top: Testbench top module name
# -l: Log file for optimization
# -o: Output optimized design name
# +acc: Enable access to all signals
# +noacc: Disable access for library cells (faster simulation)
# -suppress: Suppress specific warning codes
vopt -L work -L pmi_work -L $DEVICE_LIB \
     -debug -work work tb_top \
     -l optimize.log -o design_opt \
     +acc +noacc+pmi_work.* +noacc+${DEVICE_LIB}.* \
     -suppress 8602,13259,2135,2912,1127,7063,2732,7033

# -----------------------------------------------------------------------------
# Run simulation
# -----------------------------------------------------------------------------
# -L: Link with additional libraries
# design_opt: Optimized design name from vopt
# -sv_seed: Random seed for SystemVerilog randomization
# -lib: Library containing the design
# -l: Log file for simulation
# -suppress: Suppress specific warning codes
vsim -L work -L pmi_work -L $DEVICE_LIB \
     design_opt -sv_seed 1 -lib work \
     -l sim.log \
     -suppress 8602,12130,10000,7033,8630,3009,3389

# -----------------------------------------------------------------------------
# Load waveform configuration (if available)
# -----------------------------------------------------------------------------
if {[file exists wave.do]} {
   do wave.do
}

# -----------------------------------------------------------------------------
# Run simulation to completion
# -----------------------------------------------------------------------------
run -all


