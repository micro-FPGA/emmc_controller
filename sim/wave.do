# =============================================================================
# Waveform Configuration Script
# eMMC Controller IP
# =============================================================================

# -----------------------------------------------------------------------------
# Testbench Signals
# -----------------------------------------------------------------------------
add wave -noupdate -divider "Testbench"
add wave -noupdate -radix binary /tb_top/tb_clk
add wave -noupdate -radix binary /tb_top/tb_rst_n
add wave -noupdate -radix binary /tb_top/clk_i
add wave -noupdate -radix binary /tb_top/rst_n_i

# -----------------------------------------------------------------------------
# eMMC Interface
# -----------------------------------------------------------------------------
add wave -noupdate -divider "eMMC Interface"
add wave -noupdate -radix binary /tb_top/emmc_clk_o
add wave -noupdate -radix binary /tb_top/emmc_rst_n_o
add wave -noupdate -radix binary /tb_top/emmc_cmd_io
add wave -noupdate -radix hex    /tb_top/emmc_dat_io

# -----------------------------------------------------------------------------
# Interrupt
# -----------------------------------------------------------------------------
add wave -noupdate -divider "Interrupt"
add wave -noupdate -radix binary /tb_top/int_o

# -----------------------------------------------------------------------------
# APB Slave Interface
# -----------------------------------------------------------------------------
add wave -noupdate -divider "APB Slave Interface"
add wave -noupdate -radix binary /tb_top/s_apb_psel_i
add wave -noupdate -radix binary /tb_top/s_apb_penable_i
add wave -noupdate -radix binary /tb_top/s_apb_pwrite_i
add wave -noupdate -radix hex    /tb_top/s_apb_paddr_i
add wave -noupdate -radix hex    /tb_top/s_apb_pwdata_i
add wave -noupdate -radix binary /tb_top/s_apb_pready_o
add wave -noupdate -radix binary /tb_top/s_apb_pslverr_o
add wave -noupdate -radix hex    /tb_top/s_apb_prdata_o

# -----------------------------------------------------------------------------
# AXI4 Master Interface (Write Channel)
# -----------------------------------------------------------------------------
add wave -noupdate -divider "AXI4 Write Address"
add wave -noupdate -radix binary /tb_top/m_axi4_awvalid_o
add wave -noupdate -radix binary /tb_top/m_axi4_awready_i
add wave -noupdate -radix hex    /tb_top/m_axi4_awaddr_o
add wave -noupdate -radix hex    /tb_top/m_axi4_awlen_o

add wave -noupdate -divider "AXI4 Write Data"
add wave -noupdate -radix binary /tb_top/m_axi4_wvalid_o
add wave -noupdate -radix binary /tb_top/m_axi4_wready_i
add wave -noupdate -radix hex    /tb_top/m_axi4_wdata_o
add wave -noupdate -radix binary /tb_top/m_axi4_wlast_o

add wave -noupdate -divider "AXI4 Write Response"
add wave -noupdate -radix binary /tb_top/m_axi4_bvalid_i
add wave -noupdate -radix binary /tb_top/m_axi4_bready_o
add wave -noupdate -radix hex    /tb_top/m_axi4_bresp_i

# -----------------------------------------------------------------------------
# AXI4 Master Interface (Read Channel)
# -----------------------------------------------------------------------------
add wave -noupdate -divider "AXI4 Read Address"
add wave -noupdate -radix binary /tb_top/m_axi4_arvalid_o
add wave -noupdate -radix binary /tb_top/m_axi4_arready_i
add wave -noupdate -radix hex    /tb_top/m_axi4_araddr_o
add wave -noupdate -radix hex    /tb_top/m_axi4_arlen_o

add wave -noupdate -divider "AXI4 Read Data"
add wave -noupdate -radix binary /tb_top/m_axi4_rvalid_i
add wave -noupdate -radix binary /tb_top/m_axi4_rready_o
add wave -noupdate -radix hex    /tb_top/m_axi4_rdata_i
add wave -noupdate -radix binary /tb_top/m_axi4_rlast_i

# -----------------------------------------------------------------------------
# Configure waveform viewer
# -----------------------------------------------------------------------------
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

# Update waveform window
update


