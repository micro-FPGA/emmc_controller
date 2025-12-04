if { $radiant(stage) == "presyn" } {
} elseif { $radiant(stage) == "premap" } {

  set CLKI_PERIOD [expr (1000/$CLKI_FREQ)]

  if { $SPI_SCKDIV == 0 } {
      set SCK_DIV 1
      set SCK_PERIOD $CLKI_PERIOD
      set SCK_PERIOD_D2 [expr ($CLKI_PERIOD/2)]
  } else {
      set SCK_DIV [expr ($SPI_SCKDIV*2)]
      set SCK_PERIOD [expr ($CLKI_PERIOD*$SCK_DIV)]
      set SCK_PERIOD_D2 [expr ($CLKI_PERIOD/2)]
  }

  set_false_path -to [get_pins -hierarchical {lscc_emmc_controller_inst/u_emmc_top/rst_n_sync_reg[*].ff_inst/LSR}]

  if { $MEM_IMPL == "HARD_IP" } {
    set_false_path -to [get_pins -hierarchical {lscc_emmc_controller_inst/u_emmc_top/gen_axi4_interface.u_axi4_m/u_dat_fifo/gen_pmi.gen_sync.u_fifo/u_mem0/fifo0/_HARD_IP.u_fifo/_SAME_WIDTH._FIFO_ADDR[*]._FIFO_DATA[*].u_fifo/_LIFCL.fifo16K.FIFO16K_MODE_inst/RPRST}]
    set_false_path -to [get_pins -hierarchical {lscc_emmc_controller_inst/u_emmc_top/gen_axi4_interface.u_axi4_m/u_dat_fifo/gen_pmi.gen_sync.u_fifo/u_mem0/fifo0/_HARD_IP.u_fifo/_SAME_WIDTH._FIFO_ADDR[*]._FIFO_DATA[*].u_fifo/_LIFCL.fifo16K.FIFO16K_MODE_inst/RSTW}]
  }

  ### These constraints must be added in the pdc (top level) constraint file
  ### Copy or rename this file as constraint.pdc and un-comment the constraints below

  #create_clock -name {clk_i} -period $CLKI_PERIOD [get_ports clk_i]
  #create_generated_clock -name {emmc_clk_o} -source [get_ports clk_i] -divide_by $SCK_DIV [get_ports emmc_clk_o]
  #if { $SPI_SCKDIV > 0 } {
  #  set_multicycle_path -setup -start -from [get_clocks clk_i] -to [get_clocks emmc_clk_o] $SCK_DIV
  #  set_multicycle_path -hold  -start -from [get_clocks clk_i] -to [get_clocks emmc_clk_o] $SCK_DIV-1
  #  set_multicycle_path -setup -end   -from [get_clocks emmc_clk_o] -to [get_clocks clk_i] $SCK_DIV
  #  set_multicycle_path -hold  -end   -from [get_clocks emmc_clk_o] -to [get_clocks clk_i] $SCK_DIV-1
  #}
  #set_false_path -from [get_ports  {rst_n_i}]


}
