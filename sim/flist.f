# File List for QuestaSim/ModelSim Compilation
# eMMC Controller IP
#
# Usage: vlog -f flist.f
# Format: One file path per line, comments start with #

# -----------------------------------------------------------------------------
# Include Directories
# -----------------------------------------------------------------------------
+incdir+../testbench/
+incdir+../rtl/

# -----------------------------------------------------------------------------
# RTL Source Files
# -----------------------------------------------------------------------------
../rtl/emmc_fifo.v
../rtl/emmc_clkgen.v
../rtl/emmc_csr.v
../rtl/emmc_cmd_proc.v
../rtl/emmc_serdes.v
../rtl/emmc_serdes_top.v
../rtl/emmc_iologic.v
../rtl/emmc_apb_s.v
../rtl/emmc_axi4_m.v
../rtl/emmc_ahbl_m.v
../rtl/emmc_top.v
../rtl/lscc_emmc_controller.v

# -----------------------------------------------------------------------------
# Testbench Top (includes other TB files via `include)
# Note: tb_common.v, tb_util_task.v, apb_mst_model.v, axi_mem_model.v,
#       ahbl_mem_model.v, mdl_emmc.v are included by tb_top.v
# -----------------------------------------------------------------------------
../testbench/tb_top.v
