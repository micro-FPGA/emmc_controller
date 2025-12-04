// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__AHBL_MEM_MODEL__
`define __RTL_MODULE__AHBL_MEM_MODEL__
//==========================================================================
// Module : ahbl_mem_model
//==========================================================================
module ahbl_mem_model #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          SIMULATION     = 0
,parameter                          MEM_DEPTH      = 16384
,parameter                          AHBL_ADR_WIDTH = 32
,parameter                          AHBL_DAT_WIDTH = 32

) //--end_param--

( //--begin_ports--
// System clock and reset
 input                              clk_i
,input                              rst_n_i

// ---------------------------------------------------------------------------------------
// AHB-Lite Subordinate interface
,input        [AHBL_ADR_WIDTH-1:0]  s_ahbl_haddr_i
,input        [2:0]                 s_ahbl_hburst_i
,input                              s_ahbl_hmastlock_i
,input        [3:0]                 s_ahbl_hprot_i
,input        [2:0]                 s_ahbl_hsize_i
,input        [1:0]                 s_ahbl_htrans_i
,input        [AHBL_DAT_WIDTH-1:0]  s_ahbl_hwdata_i
,input                              s_ahbl_hwrite_i
,input                              s_ahbl_hsel_i

,output wire  [AHBL_DAT_WIDTH-1:0]  s_ahbl_hrdata_o
,output wire                        s_ahbl_hreadyout_o
,output wire                        s_ahbl_hresp_o
,input                              s_ahbl_hready_i

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                          MEM_AWID = $clog2(MEM_DEPTH);

// HTRANS encoding
localparam [1:0]                    HTRANS_IDLE   = 2'b00;
localparam [1:0]                    HTRANS_BUSY   = 2'b01;
localparam [1:0]                    HTRANS_NONSEQ = 2'b10;
localparam [1:0]                    HTRANS_SEQ    = 2'b11;

// HRESP encoding
localparam                          HRESP_OKAY    = 1'b0;
localparam                          HRESP_ERROR   = 1'b1;

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

wire                                trans_valid;
wire                                trans_write;
wire                                trans_read;
wire          [AHBL_ADR_WIDTH-1:0]  trans_addr;
wire          [2:0]                 trans_size;

wire                                mem_int_wren;
wire                                mem_int_rden;
wire          [31:0]                mem_int_wdat;
wire          [31:0]                mem_int_rdat;
wire          [MEM_AWID-1:0]        mem_int_wadr;
wire          [MEM_AWID-1:0]        mem_int_radr;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [AHBL_ADR_WIDTH-1:0]  addr_phase_addr;
reg                                 addr_phase_write;
reg           [2:0]                 addr_phase_size;

//--------------------------------------------------------------------------
//--- Address Phase Logic ---
//--------------------------------------------------------------------------
assign trans_valid = s_ahbl_hsel_i & s_ahbl_hready_i & s_ahbl_hreadyout_o &
                     ((s_ahbl_htrans_i == HTRANS_NONSEQ) || 
                      (s_ahbl_htrans_i == HTRANS_SEQ));

assign trans_write = trans_valid & s_ahbl_hwrite_i;
assign trans_read  = trans_valid & ~s_ahbl_hwrite_i;
assign trans_addr  = s_ahbl_haddr_i;
assign trans_size  = s_ahbl_hsize_i;

//--------------------------------------------
//-- Sequential block - Address Phase Pipeline --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    addr_phase_addr  <= {AHBL_ADR_WIDTH{1'b0}};
    addr_phase_write <= 1'h0;
    addr_phase_size  <= 3'h0;
    // End of automatics
  end
  else begin
    // Capture address phase info for write data phase (HWDATA arrives 1 cycle later)
    addr_phase_addr  <= trans_addr;
    addr_phase_write <= trans_write;
    addr_phase_size  <= trans_size;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------------------------------------
//--- Memory Interface Logic ---
//--------------------------------------------------------------------------
// Read: Use current cycle address to start read immediately (data returns next cycle)
// Write: Use pipelined address to match delayed HWDATA
assign mem_int_rden = trans_read;
assign mem_int_radr = trans_addr[2+:MEM_AWID];

assign mem_int_wren = addr_phase_write;
assign mem_int_wadr = addr_phase_addr[2+:MEM_AWID];
assign mem_int_wdat = s_ahbl_hwdata_i;

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
model_mem_dp #
(
 .DWID                                (32),
 .MSIZ                                (MEM_DEPTH),
 .AWID                                (MEM_AWID))
u_mem_dp
(
 // Inputs
 .WClk                                (clk_i),
 .RClk                                (clk_i),
 .WrEn                                (mem_int_wren),
 .WAdr                                (mem_int_wadr[MEM_AWID-1:0]),
 .DtIn                                (mem_int_wdat[31:0]),
 .RdEn                                (mem_int_rden),
 .RAdr                                (mem_int_radr[MEM_AWID-1:0]),
 // Outputs
 .DtOut                               (mem_int_rdat[31:0]));

//--------------------------------------------------------------------------
//--- Output Response Logic ---
//--------------------------------------------------------------------------
// HRDATA: Direct from memory (already has 1-cycle delay from model_mem_dp)
//         This provides correct AHB-Lite timing: Address in cycle N, Data in cycle N+1
assign s_ahbl_hrdata_o    = mem_int_rdat;

// HREADYOUT: Always ready (no wait states in this simple model)
assign s_ahbl_hreadyout_o = 1'b1;

// HRESP: Always OKAY response (no error conditions)
assign s_ahbl_hresp_o     = HRESP_OKAY;



endmodule //--ahbl_mem_model--
`endif // __RTL_MODULE__AHBL_MEM_MODEL__

