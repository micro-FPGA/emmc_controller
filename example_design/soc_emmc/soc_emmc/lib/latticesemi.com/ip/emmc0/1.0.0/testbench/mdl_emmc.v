// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
//
// Module      : mdl_emmc
// Description : eMMC Device Model Stub
//               The actual eMMC device model must be provided by the user.
//               This stub preserves the interface for testbench compilation.
//
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__MDL_EMMC__
`define __RTL_MODULE__MDL_EMMC__

`timescale 1ns/1ps

module mdl_emmc #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter    [0:0]                 OPT_DUAL_VOLTAGE  = 1'b0
,parameter    [0:0]                 OPT_HIGH_CAPACITY = 1'b0
,parameter                          LGMEMSZ           = 20    // Log_2(Mem size in bytes)
,parameter                          LGBOOTSZ          = 17    // Minimum of 17, for 128kB
,parameter                          MAX_BLKLEN        = 512   // Max Blk Size in bytes
,parameter                          MEM_HEX           = 0
,parameter                          BOOT_HEX          = 0

) //--end_param--

( //--begin_ports--
 input  wire                        rst_n
,input  wire                        sd_clk
,inout  wire                        sd_cmd
,inout  wire  [7:0]                 sd_dat
,output wire                        sd_ds

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--

  //-----
  //--- Stub Implementation ---
  //-----

  // Drive outputs to safe state
  assign sd_ds = 1'b0;

  initial begin
    $display("");
    $display("================================================================================");
    $display("  ERROR: eMMC Device Model Not Provided");
    $display("================================================================================");
    $display("");
    $display("  The eMMC device model (mdl_emmc) is a stub placeholder.");
    $display("  You must provide your own eMMC device model for simulation.");
    $display("");
    $display("  Options:");
    $display("    1. Obtain an eMMC device model from a third-party vendor");
    $display("    2. Use a behavioral model from your eMMC silicon vendor");
    $display("    3. Implement a custom eMMC device model");
    $display("");
    $display("  The model must be compatible with JEDEC eMMC specification.");
    $display("");
    $display("================================================================================");
    $display("");
    $stop;
  end

endmodule

`endif // __RTL_MODULE__MDL_EMMC__
