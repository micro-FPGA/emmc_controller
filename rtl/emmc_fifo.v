// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_FIFO__
`define __RTL_MODULE__EMMC_FIFO__
//==========================================================================
// Module : emmc_fifo
//==========================================================================
module emmc_fifo #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                        SIMULATION    = 0
,parameter                        DEVICE_FAMILY = "LAV-AT"
,parameter                        FIFO_IMPL     = "PMI"              // "PMI"/"pmi" or "RTL"/"rtl" or "REG"/"reg"
,parameter                        MEM_IMPL      = "EBR"              // "EBR" or "LUT" or "HARD_IP"
,parameter                        PIPE_IMPL     = "FIFOREG"          // "SHREG" or "FIFOREG"
,parameter                        CLKDOMAIN     = "SYNC"             // "SYNC" or "ASYNC"
,parameter                        DWID          = 8                  // input width
,parameter                        SIZE          = 256                // fifo depth
,parameter                        AFUL_LVL      = SIZE-1             // almost full
,parameter                        AEMT_LVL      = 1                  // almost empty
,parameter                        INV_PMI_WCLK  = 0
,parameter                        INV_PMI_RCLK  = 0

) //--end_param--

( //--begin_ports--
 input                            wclk
,input                            rclk

,input                            wrst_n
,input                            rrst_n

,input        [DWID-1:0]          wdat
,input                            wren

,input                            rden

,output wire  [DWID-1:0]          rdat
,output wire                      emty
,output wire                      full
,output wire                      aful
,output wire                      aemt

); //--end_ports--
/*
function integer clog2;
  input [31:0] value;
  reg   [31:0] num;
  integer      idx;
begin
  num = value - 1;
  for (idx=0; num>0; idx=idx+1) num = num>>1;
  clog2 = idx;
end
endfunction
*/


//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
generate
  case(FIFO_IMPL)
    "RTL","rtl" : begin : gen_rtl
      localparam                    PTR_IMPL = (CLKDOMAIN == "ASYNC")? "GRAY" : "BINARY"; // {"BINARY","GRAY"}
      fifo #
      (///*AUTOINSTPARAM*/
       // Parameters
       .DWID                              (DWID)
      ,.SIZE                              (SIZE)
      ,.RLATENCY                          (1)
      ,.AFUL_LVL                          (AFUL_LVL)
      ,.AEMT_LVL                          (AEMT_LVL)
      ,.CLKDOMAIN                         (CLKDOMAIN)
      ,.PTR_IMPL                          (PTR_IMPL)
      ,.PIPE_IMPL                         (PIPE_IMPL)
      ,.MEM_TYPE                          (MEM_IMPL))
      u_fifo
      (
       // Inputs
       .wclk                              (wclk)
      ,.rclk                              (rclk)
      ,.wrst_n                            (wrst_n)
      ,.rrst_n                            (rrst_n)
      ,.wclr                              (1'b0)
      ,.rclr                              (1'b0)
      ,.wdat                              (wdat[DWID-1:0])
      ,.wren                              (wren)
      ,.rden                              (rden)
      ,.mem_rdat                          ()
       // Outputs
      ,.rdat                              (rdat[DWID-1:0])
      ,.emty                              (emty)
      ,.full                              (full)
      ,.aful                              (aful)
      ,.aemt                              (aemt)
      ,.mem_wdat                          ()
      ,.mem_wren                          ()
      ,.mem_wadr                          ()
      ,.mem_rden                          ()
      ,.mem_radr                          ()
      /*AUTOINST*/);
    end // gen_rtl

    "REG","reg" : begin : gen_reg
      shreg_fifo #
      (
       .IMPL_TYPE                         (PIPE_IMPL)
      ,.DWID                              (DWID)
      ,.RNUM                              (SIZE)
      ,.ENAFULL                           (1)
      ,.ENAEMTY                           (1)
      ,.AFULLVL                           (AFUL_LVL)
      ,.AEMTLVL                           (AEMT_LVL)
      ,.USEDTIN                           (0))
      u_fifo
      (
       // Inputs
       .clk                               (wclk)
      ,.rst_n                             (wrst_n)
      ,.clr                               (1'b0)
      ,.wren                              (wren)
      ,.dtin                              (wdat[DWID-1:0])
      ,.rden                              (rden)
       // Outputs
      ,.dtout                             (rdat[DWID-1:0])
      ,.emty                              ({aemt,emty})
      ,.full                              ({full,aful})
       );
    end // gen_reg

    "PMI", "pmi" : begin : gen_pmi
      localparam                    REG_OUT  = "noreg"; // "reg" or "noreg"
      localparam                    RLATENCY = (REG_OUT == "reg")? 2 : 1;

      wire                          wclk_w;
      wire                          rclk_w;
      wire    [DWID-1:0]            rdat_w;
      wire                          emty_w;
      wire                          aemt_w;
      wire    [DWID-1:0]            rdat_w_tmp;
      wire                          emty_w_tmp;
      wire                          aemt_w_tmp;
      wire                          rden_w;
      wire                          full_w_tmp;
      wire                          aful_w_tmp;

      if(INV_PMI_RCLK) begin : gen_inv_rclk
        reg                       emty_r;
        reg                       aemt_r;
        reg     [DWID-1:0]        rdat_r;

        assign rclk_w = ~rclk;
        assign emty_w = emty_r;
        assign aemt_w = aemt_r;
        assign rdat_w = rdat_r;
        //--------------------------------------------
        //-- Sequential block --
        //--------------------------------------------
        always @(posedge rclk or negedge rrst_n) begin
          if(~rrst_n) begin
            emty_r <= 1'b1;
            aemt_r <= 1'b1;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            rdat_r <= {DWID{1'b0}};
            // End of automatics
          end
          else begin
            emty_r <= emty_w_tmp;
            aemt_r <= aemt_w_tmp;
            rdat_r <= rdat_w_tmp;
          end
        end //--always @(posedge rclk or negedge rrst_n)--
      end // gen_inv_rclk
      else begin : gen_same_rclk
        assign rclk_w = rclk;
        assign emty_w = emty_w_tmp;
        assign aemt_w = aemt_w_tmp;
        assign rdat_w = rdat_w_tmp;
      end // gen_same_rclk

      if(INV_PMI_WCLK) begin : gen_inv_wclk
        reg                       full_r;
        reg                       aful_r;

        assign wclk_w = ~wclk;
        assign full   = full_r;
        assign aful   = aful_r;
        //--------------------------------------------
        //-- Sequential block --
        //--------------------------------------------
        always @(posedge wclk or negedge wrst_n) begin
          if(~wrst_n) begin
            full_r <= 1'b0;
            aful_r <= 1'b0;
            /*AUTORESET*/
          end
          else begin
            full_r <= full_w_tmp;
            aful_r <= aful_w_tmp;
          end
        end //--always @(posedge wclk or negedge wrst_n)--
      end // gen_inv_wclk
      else begin : gen_same_wclk
        assign wclk_w = wclk;
        assign full   = full_w_tmp;
        assign aful   = aful_w_tmp;
      end // gen_same_wclk

      if(CLKDOMAIN == "SYNC") begin : gen_sync
        wire                          rst;
        assign rst  = ~wrst_n;

        pmi_fifo #
        (
         // Parameters
         .pmi_data_width                    (DWID)
        ,.pmi_data_depth                    (SIZE)
        ,.pmi_full_flag                     (SIZE)
        ,.pmi_empty_flag                    (0)
        ,.pmi_almost_full_flag              (AFUL_LVL)
        ,.pmi_almost_empty_flag             (AEMT_LVL)
        ,.pmi_regmode                       (REG_OUT)
        ,.pmi_family                        (DEVICE_FAMILY)
        ,.pmi_implementation                (MEM_IMPL))
        u_fifo
        (
         // Inputs
         .Clock                             (wclk_w)
        ,.Reset                             (rst)
        ,.Data                              (wdat[DWID-1:0])
        ,.WrEn                              (wren)
        ,.RdEn                              (rden_w)
         // Outputs
        ,.Q                                 (rdat_w_tmp[DWID-1:0])
        ,.Empty                             (emty_w_tmp)
        ,.Full                              (full_w_tmp)
        ,.AlmostEmpty                       (aemt_w_tmp)
        ,.AlmostFull                        (aful_w_tmp)
         );
      end // gen_sync
      else begin : gen_async
        wire                          wrst;
        wire                          rrst;

        assign wrst  = ~wrst_n;
        assign rrst  = ~rrst_n;

        pmi_fifo_dc #
        (
         // Parameters
         .pmi_data_width_w                (DWID),
         .pmi_data_width_r                (DWID),
         .pmi_data_depth_w                (SIZE),
         .pmi_data_depth_r                (SIZE),
         .pmi_full_flag                   (SIZE),
         .pmi_empty_flag                  (0),
         .pmi_almost_full_flag            (AFUL_LVL),
         .pmi_almost_empty_flag           (AEMT_LVL),
         .pmi_regmode                     (REG_OUT),
         .pmi_resetmode                   ("async"),
         .pmi_family                      (DEVICE_FAMILY),
         .pmi_implementation              (MEM_IMPL))
        u_fifo
        (
         // Inputs
         .WrClock                         (wclk_w),
         .RdClock                         (rclk_w),
         .Reset                           (wrst),
         .RPReset                         (rrst),
         .Data                            (wdat[DWID-1:0]),
         .WrEn                            (wren),
         .RdEn                            (rden_w),
         // Outputs
         .Q                               (rdat_w_tmp[DWID-1:0]),
         .Empty                           (emty_w_tmp),
         .Full                            (full_w_tmp),
         .AlmostEmpty                     (aemt_w_tmp),
         .AlmostFull                      (aful_w_tmp));
      end // gen_async

      // pmi_fifo is not working as expected. When Empty=0, data is not yet on the output port
      // Need to add logic to do read ahead
      if(RLATENCY > 0) begin : gen_pipeline
        wire                          pipe_wren;
        wire    [DWID-1:0]            pipe_rdat;
        wire                          pipe_emty;
        wire                          pipe_aemt;
        wire    [RLATENCY  :0]        rdtlatency_nxt;

        reg     [RLATENCY-1:0]        rdtlatency;
        reg     [RLATENCY  :0]        adv_pipe_stt;
        reg     [RLATENCY  :0]        adv_pipe_stt_nxt;

        assign rdat      = pipe_rdat;
        assign emty      = pipe_emty;
        assign aemt      = pipe_aemt;

        assign rden_w    = (rden | ~adv_pipe_stt[RLATENCY]) & ~emty_w;
        assign pipe_wren = rdtlatency[RLATENCY-1];

        assign rdtlatency_nxt = {rdtlatency[RLATENCY-1:0],rden_w};

        always @* begin
          case({rden_w,rden})
            2'b10   : adv_pipe_stt_nxt = {adv_pipe_stt[RLATENCY-1:0],1'b1};
            2'b01   : adv_pipe_stt_nxt = {1'b0,adv_pipe_stt[RLATENCY:1]};
            default : adv_pipe_stt_nxt = adv_pipe_stt;
          endcase
        end //--always @*--

        //--------------------------------------------
        //-- Sequential block --
        //--------------------------------------------
        always @(posedge rclk or negedge rrst_n) begin
          if(~rrst_n) begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            adv_pipe_stt <= {(1+(RLATENCY)){1'b0}};
            rdtlatency <= {RLATENCY{1'b0}};
            // End of automatics
          end
          else begin
            rdtlatency <= rdtlatency_nxt[RLATENCY-1:0];
            adv_pipe_stt <= adv_pipe_stt_nxt;
          end
        end //--always @(posedge rclk or negedge rrst_n)--

        shreg_fifo #
        (
         .IMPL_TYPE                             (PIPE_IMPL)
        ,.DWID                                  (DWID)
        ,.RNUM                                  (RLATENCY+1)
        ,.ENAEMTY                               (1)
        ,.AEMTLVL                               (AEMT_LVL)
        ,.USEDTIN                               (0))
        u_rdat_pipeline
        (
         // Inputs
         .clk                                   (rclk)
        ,.rst_n                                 (rrst_n)
        ,.clr                                   (1'b0)
        ,.wren                                  (pipe_wren)
        ,.dtin                                  (rdat_w[DWID-1:0])
        ,.rden                                  (rden)
         // Outputs
        ,.dtout                                 (pipe_rdat[DWID-1:0])
        ,.emty                                  ({pipe_aemt,pipe_emty})
        ,.full                                  ()
         /*AUTOINST*/);
      end // gen_pipeline

      else begin : gen_no_pipe
        assign rden_w = rden;

        assign rdat   = rdat_w;
        assign emty   = emty_w;
        assign aemt   = aemt_w;
      end // gen_no_pipe
    end // gen_pmi

    default : begin : invalid_fifo_impl
      initial begin
        $display("[%t][ERROR] Specified an invalid FIFO implementation type! (%m)",$time);
        $finish;
      end
    end // invalid_fifo_impl
  endcase
endgenerate



endmodule //--emmc_fifo--
`endif // __RTL_MODULE__EMMC_FIFO__

`ifndef __RTL_MODULE__FIFO__
`define __RTL_MODULE__FIFO__
//==========================================================================
// Module : fifo
//==========================================================================
module fifo #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
parameter                     DWID     = 16,                // input width
parameter                     SIZE     = 8,                 // fifo depth
parameter                     AWID     = $clog2(SIZE),      // address/pointer width
parameter                     DTDEFVAL = {DWID{1'b0}},      // default write pointer value
parameter                     WPTR_DEF = {(AWID+1){1'b0}},  // default write pointer value
parameter                     RPTR_DEF = {(AWID+1){1'b0}},  // default write pointer value
parameter                     RLATENCY = 1,                 // number of cycles before rd data is available at mem port
parameter                     AFUL_LVL = SIZE-1,            // almost full
parameter                     AEMT_LVL = 1,                 // almost empty
parameter                     EN_REGIN = 0,                 // register inputs

parameter                     MEM_IMPL  = 1,                // 0 - memory from external, 1 - use internal memory
parameter                     MEM_TYPE  = "LUT",            // "EBR" or "LUT"
parameter                     PTR_IMPL  = "BINARY",         // {"BINARY","GRAY"}
parameter                     PIPE_IMPL = "FIFOREG",        // "SHREG" or "FIFOREG"
parameter                     CLKDOMAIN = "ASYNC",          // {"ASYNC", "SYNC"}
parameter                     ALWAYSON  = 0,                // 1 - write is always enabled after reset
parameter                     RWAITTIME = 2,                // number of cycles to wait before read
parameter                     FULL_COND = 1                 // {1 - fifo will not allow write when full ,
                                                            //  0 - no fifo full condition}

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
input                         wclk,
input                         rclk,

input                         wrst_n,
input                         rrst_n,

input                         wclr,
input                         rclr,

input       [DWID-1:0]        wdat,
input                         wren,

input                         rden,

input       [DWID-1:0]        mem_rdat,
//----------------------------
// Outputs
//----------------------------
output wire [DWID-1:0]        rdat,
output wire                   emty,
output reg                    full,
output reg                    aful,
output wire                   aemt,

output reg  [DWID-1:0]        mem_wdat,
output reg                    mem_wren,
output reg  [AWID-1:0]        mem_wadr,

output reg                    mem_rden,
output reg  [AWID-1:0]        mem_radr


); //--end_ports--
/*
function integer clog2;
  input [31:0] value;
  reg   [31:0] num;
  integer      idx;
begin
  num = value - 1;
  for (idx=0; num>0; idx=idx+1) num = num>>1;
  clog2 = idx;
end
endfunction
*/

//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                    RWAITWID = $clog2(RWAITTIME+1);

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
reg                           full_nxt;
reg                           aful_nxt;
reg         [DWID-1:0]        mem_wdat_nxt;
reg         [AWID-1:0]        mem_wadr_nxt;

reg                           fifo_notemty_nxt;
reg         [AWID-1:0]        mem_radr_nxt;
reg         [DWID-1:0]        pipe_mem_rdat;
reg         [RLATENCY+2-1:0]  adv_pipe_stt_nxt;

reg         [RWAITWID-1:0]    rwait_cnt_nxt;
reg                           read_mask;
/*AUTOREGINPUT*/
// Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
reg         [AWID-1:0]        mem_int_radr;     // To mem_fifo of mem_dp.v
reg                           mem_int_rden;     // To mem_fifo of mem_dp.v
reg         [AWID-1:0]        mem_int_wadr;     // To mem_fifo of mem_dp.v
reg         [DWID-1:0]        mem_int_wdat;     // To mem_fifo of mem_dp.v
reg                           mem_int_wren;     // To mem_fifo of mem_dp.v
reg                           mem_rden_nxt;     // To fifo_rptr of async_binptr.v, ...
reg                           mem_wren_nxt;     // To fifo_wptr of async_binptr.v, ...
// End of automatics

wire                          read_mask_ss;
wire        [AWID:0]          rptr_wsync;       // From fifo_rptr of async_binptr.v
wire        [AWID:0]          wptr_rsync;       // From fifo_wptr of async_binptr.v
wire        [DWID-1:0]        mem_int_rdat;
wire        [AWID:0]          diff_wptr_rptr;
/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire        [AWID:0]          rptr;             // From fifo_rptr of async_binptr.v, ...
wire        [AWID:0]          rptr_gray_wsync;  // From fifo_rptr of async_grayptr.v
wire        [AWID:0]          rptr_nxt;         // From fifo_rptr of async_binptr.v, ...
wire        [AWID:0]          wptr;             // From fifo_wptr of async_binptr.v, ...
wire        [AWID:0]          wptr_gray_rsync;  // From fifo_wptr of async_grayptr.v
wire        [AWID:0]          wptr_nxt;         // From fifo_wptr of async_binptr.v, ...
// End of automatics
wire                          pipe_wren;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg                           fifo_notemty;
reg         [RLATENCY:0]      rdtlatency;
reg         [RWAITWID-1:0]    rwait_cnt;
reg         [RLATENCY+2-1:0]  adv_pipe_stt;


//--------------------------------------------
//-- Combinatorial block --
// converts gray code to binary
//--------------------------------------------
function [AWID:0] GRAY_TO_BIN(input [AWID:0] gray);
  integer      idx;
  reg [AWID:0] bin;
begin
  for(idx=0; idx<(AWID+1); idx=idx+1) begin
    if(idx == 0) bin[idx] = ^gray;
    else         bin[idx] = ^(gray >> idx);
  end
  GRAY_TO_BIN = bin;
end
endfunction // GRAY_TO_BIN

//--------------------------------------------------------------------------
//--- wclk domain logic ---
//--------------------------------------------------------------------------

assign diff_wptr_rptr = wptr_nxt[AWID:0] - rptr_wsync[AWID:0];
//--------------------------------------------
//-- Combinatorial block --
// wclk
//--------------------------------------------
generate
if(ALWAYSON == 1) begin
  always @* begin
    full_nxt = 1'b0;
    aful_nxt = 1'b0;
  end //--always @*--
end // (ALWAYSON == 1)

else begin // (ALWAYSON == 0)
  always @* begin
    full_nxt = (wptr_nxt[AWID-1:0] == rptr_wsync[AWID-1:0]) &
               (wptr_nxt[AWID] ^ rptr_wsync[AWID]);
    aful_nxt = (diff_wptr_rptr >= AFUL_LVL); // almost full
  end //--always @*--
end // (ALWAYSON == 0)
endgenerate

//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
generate
if(FULL_COND == 1) begin
  always @* begin
    mem_wren_nxt = wren & ~full;
  end //--always @*--
end // (FULL_COND == 1)

else begin // (FULL_COND == 0)
  always @* begin
    mem_wren_nxt = wren;
  end //--always @*--
end // (FULL_COND == 0)
endgenerate

//--------------------------------------------
//-- Combinatorial block --
// wclk
//--------------------------------------------
always @* begin
  mem_wdat_nxt = wdat;

  mem_wadr_nxt = wptr[AWID-1:0];
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge wclk or negedge wrst_n) begin
  if(~wrst_n) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    aful <= 1'h0;
    full <= 1'h0;
    mem_wadr <= {AWID{1'b0}};
    mem_wdat <= {DWID{1'b0}};
    mem_wren <= 1'h0;
    // End of automatics
  end
  else begin
    full <= full_nxt;
    aful <= aful_nxt;
    mem_wdat <= mem_wdat_nxt;
    mem_wadr <= mem_wadr_nxt;
    mem_wren <= mem_wren_nxt;
  end
end //--always @(posedge wclk or negedge wrst_n)--

//--------------------------------------------------------------------------
//--- rclk domain logic ---
//--------------------------------------------------------------------------

//--------------------------------------------
//-- Combinatorial block --
// rclk
//--------------------------------------------
generate
if(ALWAYSON == 1) begin
  always @* begin
    fifo_notemty_nxt = ~read_mask_ss;
  end //--always @*--
end // (ALWAYSON == 1)

else begin // (ALWAYSON == 0)
  always @* begin
    fifo_notemty_nxt = ~(rptr_nxt == wptr_rsync);
  end //--always @*--
end // (ALWAYSON == 0)
endgenerate

//--------------------------------------------
//-- Combinatorial block --
// rclk
//--------------------------------------------
always @* begin
  mem_rden_nxt = (rden | ~adv_pipe_stt[RLATENCY+1]) & fifo_notemty;
end //--always @*--

//--------------------------------------------
//-- Combinatorial block --
// rclk
//--------------------------------------------
always @* begin
  mem_radr_nxt = rptr[AWID-1:0];
end //--always @*--

//--------------------------------------------
//-- advance pipe status --
// rclk
//--------------------------------------------
always @* begin
  case({mem_rden_nxt,rden})
    2'b10   : adv_pipe_stt_nxt = {adv_pipe_stt[RLATENCY:0],1'b1};
    2'b01   : adv_pipe_stt_nxt = {1'b0,adv_pipe_stt[RLATENCY+2-1:1]};
    default : adv_pipe_stt_nxt = adv_pipe_stt;
  endcase
end //--always @*--


//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge rclk or negedge rrst_n) begin
  if(~rrst_n) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    adv_pipe_stt <= {(1+(RLATENCY+2-1)){1'b0}};
    fifo_notemty <= 1'h0;
    mem_radr <= {AWID{1'b0}};
    mem_rden <= 1'h0;
    rdtlatency <= {(1+(RLATENCY)){1'b0}};
    // End of automatics
  end
  else begin
    fifo_notemty <= fifo_notemty_nxt;
    mem_rden <= mem_rden_nxt;
    mem_radr <= mem_radr_nxt;
    rdtlatency <= {rdtlatency[RLATENCY-1:0],mem_rden_nxt};
    adv_pipe_stt <= adv_pipe_stt_nxt;
  end
end //--always @(posedge rclk or negedge rrst_n)--

generate
if(ALWAYSON == 1) begin
  always @* begin
    if(rwait_cnt == RWAITTIME) begin
      rwait_cnt_nxt = rwait_cnt;
    end
    else begin
      rwait_cnt_nxt = (rwait_cnt + {{(RWAITWID-1){1'b0}},1'b1});
    end
  end //--always @*--

  //--------------------------------------------
  //-- Sequential block --
  //--------------------------------------------
  always @(posedge wclk or negedge wrst_n) begin
    if(~wrst_n) begin
      read_mask <= 1'b1;
      /*AUTORESET*/
      // Beginning of autoreset for uninitialized flops
      rwait_cnt <= {RWAITWID{1'b0}};
      // End of automatics
    end
    else begin
      rwait_cnt <= rwait_cnt_nxt & {RWAITTIME{~wclr}};
      read_mask <= ~(rwait_cnt == RWAITTIME);
    end
  end //--always @(posedge wclk or negedge wrst_n)--
end // (ALWAYSON == 1)
endgenerate


//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
generate
if(MEM_IMPL == 1) begin : gen_int_mem
  always @* begin
    mem_int_wren = (EN_REGIN)? mem_wren : mem_wren_nxt;
    mem_int_rden = (EN_REGIN)? mem_rden : mem_rden_nxt;
    mem_int_wadr = (EN_REGIN)? mem_wadr : mem_wadr_nxt;
    mem_int_wdat = (EN_REGIN)? mem_wdat : mem_wdat_nxt;
    mem_int_radr = (EN_REGIN)? mem_radr : mem_radr_nxt;
    pipe_mem_rdat = mem_int_rdat;
  end //--always @*--

  /*mem_dp AUTO_TEMPLATE
  (
   .WClk                                  (wclk),
   .RClk                                  (rclk),
   .WrEn                                  (mem_int_wren[]),
   .WAdr                                  (mem_int_wadr[]),
   .DtIn                                  (mem_int_wdat[]),
   .RdEn                                  (mem_int_rden[]),
   .RAdr                                  (mem_int_radr[]),
   // Outputs
   .DtOut                                 (mem_int_rdat[]),
   );*/

  mem_dp #(.MEM_TYPE(MEM_TYPE),
           .DWID(DWID),
           .MSIZ(SIZE),
           .AWID(AWID)) mem_fifo
  (/*AUTOINST*/
   // Inputs
   .WClk                                (wclk),                  // Templated
   .RClk                                (rclk),                  // Templated
   .WrEn                                (mem_int_wren),          // Templated
   .WAdr                                (mem_int_wadr[AWID-1:0]), // Templated
   .DtIn                                (mem_int_wdat[DWID-1:0]), // Templated
   .RdEn                                (mem_int_rden),          // Templated
   .RAdr                                (mem_int_radr[AWID-1:0]), // Templated
   // Outputs
   .DtOut                               (mem_int_rdat[DWID-1:0])); // Templated

end // gen_int_mem
else begin : gen_ext_mem
  assign mem_int_rdat = {DWID{1'b0}};
  always @* begin
    mem_int_wren = 1'b0;
    mem_int_rden = 1'b0;
    mem_int_wadr = {AWID{1'b0}};
    mem_int_wdat = {DWID{1'b0}};
    mem_int_radr = {AWID{1'b0}};
    pipe_mem_rdat = mem_rdat;
  end //--always @*--
end // gen_ext_mem
endgenerate

assign pipe_wren = (EN_REGIN)? rdtlatency[RLATENCY] : rdtlatency[RLATENCY-1];
shreg_fifo #(.IMPL_TYPE(PIPE_IMPL),
             .DWID(DWID),
             .RNUM(RLATENCY+2),
             .ENAEMTY(1),
             .DEFAULT(DTDEFVAL)) pipe_rdat
(
 // Inputs
 .clk                                   (rclk),
 .rst_n                                 (rrst_n),
 .clr                                   (rclr),
 .wren                                  (pipe_wren),
 .dtin                                  (pipe_mem_rdat[DWID-1:0]),
 .rden                                  (rden),
 // Outputs
 .dtout                                 (rdat[DWID-1:0]),
 .emty                                  ({aemt,emty}),
 .full                                  ()
 /*AUTOINST*/);

generate
if(ALWAYSON == 1) begin : gen_always_on
  async_binptr #(.FPTRWID(AWID+1),
                 .PTRDEFVAL(WPTR_DEF),
                 .CLKDOMAIN(CLKDOMAIN)) fifo_wptr
  (
   // Inputs
   .wclk                                  (wclk),
   .rclk                                  (rclk),
   .wrst_n                                (wrst_n),
   .rrst_n                                (rrst_n),
   .wclr                                  (wclr),
   .rclr                                  (rclr),
   .mov_cnt                               ({{AWID{1'b0}},1'b1}),
   .mov_en                                (mem_wren_nxt),
   // Outputs
   .ptr_w                                 (wptr[AWID:0]),
   .ptr_w_nxt                             (),
   .ptr_r                                 ()
   /*AUTOINST*/);

  async_binptr #(.FPTRWID(AWID+1),
                 .PTRDEFVAL(RPTR_DEF),
                 .CLKDOMAIN(CLKDOMAIN)) fifo_rptr
  (
   // Inputs
   .wclk                                  (rclk),
   .rclk                                  (wclk),
   .wrst_n                                (rrst_n),
   .rrst_n                                (wrst_n),
   .wclr                                  (rclr),
   .rclr                                  (wclr),
   .mov_cnt                               ({{AWID{1'b0}},1'b1}),
   .mov_en                                (mem_rden_nxt),
   // Outputs
   .ptr_w                                 (rptr[AWID:0]),
   .ptr_w_nxt                             (),
   .ptr_r                                 ()
   /*AUTOINST*/);

  synchro #(.DWID(1),
            .REGNUM(2),
            .DEFAULT(1'b1)) sync_read_mask
  (
   // Inputs
   .clk_s                                 (rclk),
   .rst_n                                 (rrst_n),
   .data_a                                (read_mask),
   // Outputs
   .data_s                                (read_mask_ss)
   /*AUTOINST*/);
end // gen_always_on

else begin // gen_def
  case({PTR_IMPL,CLKDOMAIN})
    {"BINARY","ASYNC"},
    {"BINARY","SYNC" } : begin : gen_bin_ptr
      async_binptr #(.FPTRWID(AWID+1),
                     .PTRDEFVAL(WPTR_DEF),
                     .CLKDOMAIN(CLKDOMAIN)) fifo_wptr
      (
       // Inputs
       .wclk                                  (wclk),
       .rclk                                  (rclk),
       .wrst_n                                (wrst_n),
       .rrst_n                                (rrst_n),
       .wclr                                  (wclr),
       .rclr                                  (rclr),
       .mov_cnt                               ({{AWID{1'b0}},1'b1}),
       .mov_en                                (mem_wren_nxt),
       // Outputs
       .ptr_w                                 (wptr[AWID:0]),
       .ptr_w_nxt                             (wptr_nxt[AWID:0]),
       .ptr_r                                 (wptr_rsync[AWID:0])
       /*AUTOINST*/);

      async_binptr #(.FPTRWID(AWID+1),
                     .PTRDEFVAL(RPTR_DEF),
                     .CLKDOMAIN(CLKDOMAIN)) fifo_rptr
      (
       // Inputs
       .wclk                                  (rclk),
       .rclk                                  (wclk),
       .wrst_n                                (rrst_n),
       .rrst_n                                (wrst_n),
       .wclr                                  (rclr),
       .rclr                                  (wclr),
       .mov_cnt                               ({{AWID{1'b0}},1'b1}),
       .mov_en                                (mem_rden_nxt),
       // Outputs
       .ptr_w                                 (rptr[AWID:0]),
       .ptr_w_nxt                             (rptr_nxt[AWID:0]),
       .ptr_r                                 (rptr_wsync[AWID:0])
       /*AUTOINST*/);
    end // gen_bin_ptr

    {"GRAY"  ,"ASYNC"} : begin : gen_gray_ptr
      async_grayptr #(.FPTRWID(AWID+1),
                      .PTRDEFVAL(WPTR_DEF)) fifo_wptr
      (
       // Inputs
       .wclk                                  (wclk),
       .rclk                                  (rclk),
       .wrst_n                                (wrst_n),
       .rrst_n                                (rrst_n),
       .wclr                                  (wclr),
       .mov_en                                (mem_wren_nxt),
       // Outputs
       .ptr_w                                 (wptr[AWID:0]),
       .ptr_w_nxt                             (wptr_nxt[AWID:0]),
       .ptr_gray_r                            (wptr_gray_rsync[AWID:0])
       /*AUTOINST*/);
      assign wptr_rsync = GRAY_TO_BIN(wptr_gray_rsync);

      async_grayptr #(.FPTRWID(AWID+1),
                      .PTRDEFVAL(RPTR_DEF)) fifo_rptr
      (
       // Inputs
       .wclk                                  (rclk),
       .rclk                                  (wclk),
       .wrst_n                                (rrst_n),
       .rrst_n                                (wrst_n),
       .wclr                                  (rclr),
       .mov_en                                (mem_rden_nxt),
       // Outputs
       .ptr_w                                 (rptr[AWID:0]),
       .ptr_w_nxt                             (rptr_nxt[AWID:0]),
       .ptr_gray_r                            (rptr_gray_wsync[AWID:0])
       /*AUTOINST*/);
      assign rptr_wsync = GRAY_TO_BIN(rptr_gray_wsync);
    end // gen_gray_ptr

  endcase // ({PTR_IMPL,CLKDOMAIN})
end // gen_def
endgenerate


endmodule //--fifo--
`endif // __RTL_MODULE__FIFO__

`ifndef __RTL_MODULE__MEM_DP__
`define __RTL_MODULE__MEM_DP__
//==========================================================================
// Module : mem_dp
//==========================================================================
module mem_dp #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
parameter               MEM_TYPE = "LUT", // "EBR" or "LUT"
parameter               MSIZ = 32,
parameter               AWID = $clog2(MSIZ),
parameter               DWID = 16

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
input                   WClk,
input                   RClk,

input                   WrEn,
input [AWID-1:0]        WAdr,
input [DWID-1:0]        DtIn,
input                   RdEn,
input [AWID-1:0]        RAdr,

//----------------------------
// Outputs
//----------------------------
output reg [DWID-1:0]   DtOut

); //--end_ports--
/*
function integer clog2;
  input [31:0] value;
  reg   [31:0] num;
  integer      idx;
begin
  num = value - 1;
  for (idx=0; num>0; idx=idx+1) num = num>>1;
  clog2 = idx;
end
endfunction
*/
generate
  case(MEM_TYPE)
    "EBR" : begin : gen_ebr
      //--------------------------------------------------------------------------
      //--- Registers/Memory ---
      //--------------------------------------------------------------------------
      reg [DWID-1:0]          memArray[MSIZ-1:0]  /* synthesis syn_ramstyle="block_ram" */;


      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge WClk) begin
        if(WrEn) begin
          memArray[WAdr] <= DtIn;
        end
      end //--always @(posedge WClk)--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge RClk) begin
        if(RdEn) begin
          DtOut <= memArray[RAdr];
        end
      end //--always @(posedge WClk)--
    end // gen_ebr

    "LUT" : begin : gen_lut
      //--------------------------------------------------------------------------
      //--- Registers/Memory ---
      //--------------------------------------------------------------------------
      reg [DWID-1:0]          memArray[MSIZ-1:0]  /* synthesis syn_ramstyle="distributed" */;


      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge WClk) begin
        if(WrEn) begin
          memArray[WAdr] <= DtIn;
        end
      end //--always @(posedge WClk)--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge RClk) begin
        if(RdEn) begin
          DtOut <= memArray[RAdr];
        end
      end //--always @(posedge WClk)--
    end // gen_lut

    default : begin : invalid_mem_impl
      initial begin
        $display("[%t][ERROR] Specified an invalid memory implementation type! (%m)",$time);
        $finish;
      end
    end // invalid_mem_impl
  endcase
endgenerate


endmodule //--mem_dp--
`endif // __RTL_MODULE__MEM_DP__

`ifndef __RTL_MODULE__SHREG_FIFO__
`define __RTL_MODULE__SHREG_FIFO__
//==========================================================================
// Module : shreg_fifo
//==========================================================================
module shreg_fifo #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                    IMPL_TYPE   = "FIFOREG"     // "SHREG" or "FIFOREG"
,parameter                    DWID        = 8             // input width
,parameter                    RNUM        = 8             // number of registers
,parameter                    DWID_O      = DWID          // output width
,parameter                    DEFAULT     = {DWID{1'b0}}  // default register value
,parameter                    ENAFULL     = 0             // enable almost full signal
,parameter                    ENAEMTY     = 0             // enable almost empty signal
,parameter                    REGFULL     = 1             // register full signal
,parameter                    REGEMTY     = 1             // register empty signal
,parameter                    AFULLVL     = RNUM-1        // almost full level
,parameter                    AEMTLVL     = 1             // almost empty level
,parameter                    SHFTDT0     = (RNUM > 1)? 1 : 0 // SHREG only - shift last data
,parameter                    USEDTIN     = 0             // SHREG only - optimize pipe by reusing the dtin as last stage
                                                          // - assumes that dtin is registered and retains value unless rden==1
,parameter                    KEEPLDT     = 1             // Keep last data in FIFOREG

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
 input                        clk
,input                        rst_n
,input                        clr

,input                        wren
,input        [DWID-1:0]      dtin

,input                        rden

//----------------------------
// Outputs
//----------------------------
,output reg   [DWID_O-1:0]    dtout
,output reg   [ENAEMTY:0]     emty     // aemty,emty
,output reg   [ENAFULL:0]     full     // full,afull

); //--end_ports--
/*
function integer clog2;
  input [31:0] value;
  reg   [31:0] num;
  integer      idx;
begin
  num = value - 1;
  for (idx=0; num>0; idx=idx+1) num = num>>1;
  clog2 = idx;
end
endfunction
*/

//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------


genvar i;
generate
  if(RNUM == 1) begin : gen_1reg
    reg                           stt_reg;
    wire                          clr_data;

    assign clr_data = (SHFTDT0)? rden : 1'b0;

    //--------------------------------------------
    //-- Combinatorial block --
    //--------------------------------------------
    always @* begin
      full =  stt_reg;
      emty = ~stt_reg;
    end //--always @*--

    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
        dtout <= DEFAULT;
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        stt_reg <= 1'h0;
        // End of automatics
      end
      else begin
        if((wren ^ rden) | clr) begin
          stt_reg <= wren & ~clr;
        end

        if(wren | clr_data) begin
          dtout <= dtin & {DWID{wren}};
        end
      end
    end //--always @(posedge clk or negedge rst_n)--

  end // gen_1reg

  else begin : gen_multistage
    integer                       idx1;

    if(IMPL_TYPE == "SHREG") begin : gen_shreg
      localparam                    PWID = RNUM*DWID;

      reg         [PWID-1:0]        pipe_nxt;
      reg         [RNUM+1:0]        stt_nxt;
      reg         [PWID+DWID-1:0]   shftdat;
      reg         [RNUM-1:0]        pipewr;
      reg         [RNUM-1:0]        piperd;
      reg         [RNUM-1:0]        piperw;
      wire        [RNUM:0]          stt_shr;
      wire        [RNUM:0]          stt_shl;

      wire                          shift_lastdt;
      wire        [RNUM+1:0]        stt_wire;


      reg         [PWID-1:0]        pipe;
      wire        [RNUM+1:0]        stt;
      reg         [RNUM-1:0]        stt_reg;

      assign stt_wire = (REGFULL)? stt : stt_nxt;
      assign stt      = {stt_reg[RNUM-1],stt_reg,stt_reg[0]};
      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        dtout = pipe[DWID_O-1:0];
        full  = (ENAFULL)? {stt_wire[RNUM],stt_wire[AFULLVL]} : stt_wire[RNUM];
        emty  = (REGEMTY)? ((ENAEMTY)? ~{stt[AEMTLVL+1]    ,stt[1]    } : ~stt[1]    ) :
                           ((ENAEMTY)? ~{stt_nxt[AEMTLVL+1],stt_nxt[1]} : ~stt_nxt[1]);
      end //--always @*--

      assign stt_shr = {1'b0,stt_reg};
      assign stt_shl = {stt_reg,1'b1};
      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        stt_nxt = {stt_reg[RNUM-1],stt_reg,stt_reg[0]};
        if(clr)
          stt_nxt[RNUM:1] = {(RNUM){1'b0}};
        else begin
          case({wren,rden})
            2'b10   : stt_nxt[RNUM:1] = stt_shl[RNUM-1:0];
            2'b01   : stt_nxt[RNUM:1] = stt_shr[RNUM:1];
            default : stt_nxt[RNUM:1] = stt_reg;
          endcase
        end
      end //--always @*--

      assign                        shift_lastdt = SHFTDT0;
      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        if(shift_lastdt)
          shftdat = {{DWID{1'b0}},pipe};
        else
          shftdat = {pipe[PWID-1:PWID-DWID],pipe};
      end //--always @*--

      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        pipewr = ~stt_reg & ((stt_reg << 1) | {{(RNUM-1){1'b0}},1'b1 });
        piperd =  ({RNUM{ shift_lastdt}} & stt_reg       ) |
                  ({RNUM{~shift_lastdt}} & (stt_reg >> 1));
        piperw =  stt_reg & ~(stt_reg >> 1);
      end //--always @*--

      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        for(idx1=0; idx1<RNUM; idx1=idx1+1) begin
          case({wren,rden})
            2'b10   : begin
              pipe_nxt[(idx1*DWID)+:(DWID)] = ({DWID{ pipewr[idx1]}} & dtin                        ) |
                                              ({DWID{~pipewr[idx1]}} & shftdat[(idx1*DWID)+:(DWID)]);
            end
            2'b01   : begin
              pipe_nxt[(idx1*DWID)+:(DWID)] = ({DWID{ piperd[idx1]}} & shftdat[((idx1+1)*DWID)+:(DWID)]) |
                                              ({DWID{~piperd[idx1]}} & shftdat[(idx1*DWID)+:(DWID)]    );
            end
            2'b11   : begin
              pipe_nxt[(idx1*DWID)+:(DWID)] = ({DWID{~piperd[idx1] & ~piperw[idx1]}} & shftdat[(idx1*DWID)+:(DWID)]    ) |
                                              ({DWID{ piperd[idx1] & ~piperw[idx1]}} & shftdat[((idx1+1)*DWID)+:(DWID)]) |
                                              ({DWID{                 piperw[idx1]}} & dtin                            );
            end
            default : pipe_nxt = pipe;
          endcase
        end
      end //--always @*--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
          stt_reg <= {RNUM{1'b0}};
          /*AUTORESET*/
        end
        else begin
          stt_reg <= stt_nxt[RNUM:1];
        end
      end //--always @(posedge clk or negedge rst_n)--

      if(USEDTIN && RNUM > 1) begin : gen_usedtin
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            pipe[PWID-DWID-1:0] <= {(RNUM-1){DEFAULT}};
            /*AUTORESET*/
          end
          else begin
            pipe[PWID-DWID-1:0] <= pipe_nxt[PWID-DWID-1:0];
          end
        end //--always @(posedge clk or negedge rst_n)--

        always @* begin
          pipe[PWID-1:PWID-DWID] = dtin;
        end //--always @*--
      end // gen_usedtin
      else begin : gen_no_usedtin
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            pipe <= {RNUM{DEFAULT}};
            /*AUTORESET*/
          end
          else begin
            pipe <= pipe_nxt;
          end
        end //--always @(posedge clk or negedge rst_n)--
      end // gen_no_usedtin
    end // gen_shreg

    else begin : gen_fiforeg
      localparam                    PTRWID = $clog2(RNUM);
      localparam                    CNTWID = $clog2(RNUM+1);

      reg         [DWID-1:0]        memArray[RNUM-1:0]  /* synthesis syn_ramstyle="distributed" */;
      reg         [CNTWID-1:0]      size_cntr;
      reg         [PTRWID-1:0]      wptr;
      reg         [PTRWID-1:0]      rptr;

      reg         [DWID-1:0]        memArray_nxt[RNUM-1:0];
      reg         [CNTWID-1:0]      size_cntr_nxt;
      wire        [PTRWID-1:0]      wptr_nxt;
      wire        [PTRWID-1:0]      wptr_incr;
      wire        [PTRWID-1:0]      rptr_nxt;
      wire        [PTRWID-1:0]      rptr_incr;
      wire        [PTRWID-1:0]      max_cnt;
      wire        [CNTWID-1:0]      full_cnt;
      wire                          gnd_wire;

      assign gnd_wire = 1'b0;

      assign max_cnt  = (RNUM-1) & {PTRWID{1'b1}};
      assign full_cnt = RNUM & {CNTWID{1'b1}};
      assign wptr_incr= (wptr + (wren & {PTRWID{1'b1}}));
      assign wptr_nxt = (wptr == max_cnt)? ({PTRWID{~wren}} & wptr) :
                                           wptr_incr;
      assign rptr_incr= (rptr + (rden & {PTRWID{1'b1}}));
      assign rptr_nxt = (rptr == max_cnt)? ({PTRWID{~rden}} & rptr) :
                                           rptr_incr;

      always @* begin
        case({wren,rden})
          2'b01   : size_cntr_nxt = size_cntr - (1'b1 & {CNTWID{1'b1}});
          2'b10   : size_cntr_nxt = size_cntr + (1'b1 & {CNTWID{1'b1}});
          default : size_cntr_nxt = size_cntr;
        endcase
      end //--always @*--

      always @* begin
        for(idx1=0; idx1<RNUM; idx1=idx1+1) begin
          memArray_nxt[idx1] = memArray[idx1];
        end
        if(wren) begin
          memArray_nxt[wptr] = dtin;
        end
      end //--always @*--

      for(i=0; i<RNUM; i=i+1) begin : gen_memreg
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            memArray[i] <= DEFAULT;
            /*AUTORESET*/
          end
          else begin
            memArray[i] <= memArray_nxt[i];
          end
        end //--always @(posedge clk or negedge rst_n)--
      end // gen_memreg

      always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          dtout <= {DWID{1'b0}};
          rptr <= {PTRWID{1'b0}};
          size_cntr <= {CNTWID{1'b0}};
          wptr <= {PTRWID{1'b0}};
          // End of automatics
        end
        else begin
          wptr             <= wptr_nxt & {PTRWID{~clr}};
          rptr             <= rptr_nxt & {PTRWID{~clr}};
          size_cntr        <= size_cntr_nxt & {CNTWID{~clr}};

          if(|size_cntr_nxt | (KEEPLDT == 0)) begin
            dtout            <= memArray_nxt[rptr_nxt];
          end
        end
      end //--always @(posedge clk or negedge rst_n)--

      if(ENAFULL) begin : gen_aful
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            full <= {(1+(ENAFULL)){1'b0}};
            // End of automatics
          end
          else begin
            full[0] <= ~clr & (size_cntr_nxt >= (AFULLVL & {CNTWID{1'b1}})); // aful
            full[1] <= ~clr & (size_cntr_nxt == full_cnt); // full
          end
        end //--always @(posedge clk or negedge rst_n)--
      end // gen_aful
      else begin : gen_noaful
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            full <= {(1+(ENAFULL)){1'b0}};
            // End of automatics
          end
          else begin
            full <= ~clr & (size_cntr_nxt == full_cnt); // full
          end
        end //--always @(posedge clk or negedge rst_n)--
      end // gen_noaful

      if(ENAEMTY) begin : gen_aemty
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            emty <= 2'b11;
            /*AUTORESET*/
          end
          else begin
            emty[0] <= clr | ~|size_cntr_nxt; // emty
            emty[1] <= clr | (size_cntr_nxt <= (AEMTLVL & {CNTWID{1'b1}})); // aemty
          end
        end //--always @(posedge clk or negedge rst_n)--
      end // gen_aemty
      else begin : gen_noaemty
        always @(posedge clk or negedge rst_n) begin
          if(~rst_n) begin
            emty <= 1'b1;
            /*AUTORESET*/
          end
          else begin
            emty <= clr | ~|size_cntr_nxt; // emty
          end
        end //--always @(posedge clk or negedge rst_n)--
      end // gen_noaemty
    end // gen_fiforeg

  end // gen_multistage
endgenerate


endmodule //--shreg_fifo--
`endif // __RTL_MODULE__SHREG_FIFO__

`ifndef __RTL_MODULE__XOR_HANDSHAKE__
`define __RTL_MODULE__XOR_HANDSHAKE__
//==========================================================================
// Module : xor_handshake
//==========================================================================
module xor_handshake #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
parameter                     DWID    = 1,            // input width
parameter                     REGNUMA = 2,            // number of pipeline registers to be used - minimum of 2
parameter                     REGNUMB = 2,            // number of pipeline registers to be used - minimum of 2
parameter                     DEFAULT = {DWID{1'b0}}  // default register value

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
input                         clk_a,
input                         clk_b,
input                         rst_n_a,
input                         rst_n_b,

input       [DWID-1:0]        req_a,

//----------------------------
// Outputs
//----------------------------
output reg  [DWID-1:0]        req_b,
output reg  [DWID-1:0]        ack_b_pulse,
output reg  [DWID-1:0]        ack_b,

output reg  [DWID-1:0]        ack_a_pulse,
output reg  [DWID-1:0]        ack_a


); //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
/*AUTOREGINPUT*/

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire        [DWID-1:0]        ack_sync_a;       // From sync_ack_b_a of synchro.v
wire        [DWID-1:0]        req_sync_b;       // From sync_req_a_b of synchro.v
// End of automatics


//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg         [DWID-1:0]        ack_sync_a_q;
reg         [DWID-1:0]        req_sync_b_q;


//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  req_b       = req_sync_b;
  ack_b_pulse = (req_sync_b ^ req_sync_b_q);
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_b or negedge rst_n_b) begin
  if(~rst_n_b) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    ack_b <= {DWID{1'b0}};
    req_sync_b_q <= {DWID{1'b0}};
    // End of automatics
  end
  else begin
    req_sync_b_q <= req_sync_b;
    ack_b <= ack_b ^ ack_b_pulse;
  end
end //--always @(posedge clk_b or negedge rst_n_b)--




//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  ack_a = ack_sync_a;
  ack_a_pulse = (ack_sync_a ^ ack_sync_a_q);
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_a or negedge rst_n_a) begin
  if(~rst_n_a) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    ack_sync_a_q <= {DWID{1'b0}};
    // End of automatics
  end
  else begin
    ack_sync_a_q <= ack_sync_a;
  end
end //--always @(posedge clk_b or negedge rst_n_b)--


//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------

synchro #(.DWID(DWID),
          .REGNUM(REGNUMB),
          .DEFAULT(DEFAULT)) sync_req_a_b
(
 // Inputs
 .clk_s                                 (clk_b),
 .rst_n                                 (rst_n_b),
 .data_a                                (req_a[DWID-1:0]),
 // Outputs
 .data_s                                (req_sync_b[DWID-1:0])
 /*AUTOINST*/);

synchro #(.DWID(DWID),
          .REGNUM(REGNUMA),
          .DEFAULT(DEFAULT)) sync_ack_b_a
(
 // Inputs
 .clk_s                                 (clk_a),
 .rst_n                                 (rst_n_a),
 .data_a                                (ack_b[DWID-1:0]),
 // Outputs
 .data_s                                (ack_sync_a[DWID-1:0])
 /*AUTOINST*/);



endmodule //--xor_handshake--
`endif // __RTL_MODULE__XOR_HANDSHAKE__

`ifndef __RTL_MODULE__SYNCHRO__
`define __RTL_MODULE__SYNCHRO__
//==========================================================================
// Module : synchro
//==========================================================================
module synchro #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
parameter                     DWID    = 1,            // input width
parameter                     REGNUM  = 2,            // number of pipeline registers to be used - minimum of 2
parameter                     DEFAULT = {DWID{1'b0}}  // default register value

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
input                         clk_s,  // clock where input signal will be sync
input                         rst_n,

input       [DWID-1:0]        data_a, // input signal
//----------------------------
// Outputs
//----------------------------
output  reg [DWID-1:0]        data_s // output synchronized to clk_s

); //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg         [REGNUM*DWID-1:0] sync_reg /* synthesis CDC_Register=2 */;


//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  data_s = sync_reg[REGNUM*DWID-1:(REGNUM-1)*DWID];
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_s or negedge rst_n) begin
  if(~rst_n) begin
    sync_reg <= {REGNUM{DEFAULT}};
    /*AUTORESET*/
  end
  else begin
    sync_reg <= {sync_reg[(REGNUM-1)*DWID-1:0],data_a};
  end
end //--always @(posedge clk_s or negedge rst_n)--



endmodule //--synchro--
`endif // __RTL_MODULE__SYNCHRO__

`ifndef __RTL_MODULE__ASYNC_GRAYPTR__
`define __RTL_MODULE__ASYNC_GRAYPTR__
//==========================================================================
// Module : async_grayptr
//==========================================================================
module async_grayptr #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
parameter                     FPTRWID   = 4,
parameter                     PTRDEFVAL = {FPTRWID{1'b0}},
parameter                     PTR_IMPL  = "UP" // {"UP", "DOWN"}

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
input                         wclk,
input                         rclk,

input                         wrst_n,
input                         rrst_n,

input                         wclr,
//input                         rclr,

//input       [FPTRWID-1:0]     mov_cnt,
input                         mov_en,

//----------------------------
// Outputs
//----------------------------
output reg  [FPTRWID-1:0]     ptr_w,
output reg  [FPTRWID-1:0]     ptr_w_nxt,
output wire [FPTRWID-1:0]     ptr_gray_r

); //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
// Convert binary to gray code
//`ifndef BIN_TO_GRAY
//`define BIN_TO_GRAY(bin) (bin ^ (bin >> 1))
//`endif
function [FPTRWID-1:0] BIN_TO_GRAY;
  input [FPTRWID-1:0] bin;
  begin
    BIN_TO_GRAY = (bin ^ (bin >> 1));
  end
endfunction

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
wire        [FPTRWID-1:0]     ptr_mov_cnt;

/*AUTOREGINPUT*/
// Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
reg         [FPTRWID-1:0]     ptr_gray_w;       // To sync_ptr_gray_r of synchro.v
// End of automatics

/*AUTOWIRE*/

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------

generate
if(PTR_IMPL == "UP") begin
  assign ptr_mov_cnt = {{(FPTRWID-1){1'b0}},1'b1};//mov_cnt;
end // (PTR_IMPL == "UP")
else begin // (PTR_IMPL == "DOWN")
  assign ptr_mov_cnt = {(FPTRWID){1'b1}};//~mov_cnt + {{(FPTRWID-1){1'b0}},1'b1};
end // (PTR_IMPL == "DOWN")
endgenerate

//--------------------------------------------
//-- up/down counter --
//--------------------------------------------
always @* begin
  case({wclr,mov_en})
    2'b00   : ptr_w_nxt = ptr_w;
    2'b01   : ptr_w_nxt = ptr_w + ptr_mov_cnt;
    default : ptr_w_nxt = PTRDEFVAL;
  endcase
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge wclk or negedge wrst_n) begin
  if(~wrst_n) begin
    ptr_w <= PTRDEFVAL;
    ptr_gray_w <= BIN_TO_GRAY(PTRDEFVAL);
    /*AUTORESET*/
  end
  else begin
    ptr_w <= ptr_w_nxt;
    ptr_gray_w <= BIN_TO_GRAY(ptr_w);
  end
end //--always @(posedge wclk or negedge wrst_n)--

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------

synchro #(.DWID(FPTRWID), .DEFAULT(PTRDEFVAL)) sync_ptr_gray_r
(
 // Inputs
 .clk_s                                 (rclk),
 .rst_n                                 (rrst_n),
 .data_a                                (ptr_gray_w[FPTRWID-1:0]),
 // Outputs
 .data_s                                (ptr_gray_r[FPTRWID-1:0])
 /*AUTOINST*/);


endmodule //--async_grayptr--
`endif // __RTL_MODULE__ASYNC_GRAYPTR__

`ifndef __RTL_MODULE__ASYNC_BINPTR__
`define __RTL_MODULE__ASYNC_BINPTR__
//==========================================================================
// Module : async_binptr
//==========================================================================
module async_binptr #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
parameter                     FPTRWID   = 4,
parameter                     PTRDEFVAL = {FPTRWID{1'b0}},
parameter                     PTR_IMPL  = "UP",            // {"UP", "DOWN"}
parameter                     CLKDOMAIN = "ASYNC",         // {"ASYNC", "SYNC"}
parameter                     PTR_LATENCY = 0

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
input                         wclk,
input                         rclk,

input                         wrst_n,
input                         rrst_n,

input                         wclr,
input                         rclr,

input       [FPTRWID-1:0]     mov_cnt,
input                         mov_en,

//----------------------------
// Outputs
//----------------------------
output reg  [FPTRWID-1:0]     ptr_w,
output reg  [FPTRWID-1:0]     ptr_w_nxt,
output reg  [FPTRWID-1:0]     ptr_r

); //--end_ports--


//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                 // auto enum state_info
                              ST_IDLE_PTR  = 2'd0,
                              ST_SYNC_REQ  = 2'd1,
                              ST_PEND_PTR  = 2'd2,
                              ST_SYNC_PEND = 2'd3;

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
wire        [FPTRWID-1:0]     ptr_mov_cnt;


generate
if(CLKDOMAIN == "ASYNC") begin

reg         [1:0]          // auto enum state_info
                              ptr_sync_ns;

reg                           pend_reqsync;
reg         [FPTRWID-1:0]     save_ptr_reg_nxt;
reg         [FPTRWID-1:0]     ptr_r_nxt;

/*AUTOREGINPUT*/
// Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
reg                           ptr_reqsync_w;    // To sync_ptr_reqsync of xor_handshake.v
// End of automatics

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire                          ptr_acksync_w;    // From sync_ptr_reqsync of xor_handshake.v
wire                          ptr_sync_done_r;  // From sync_ptr_reqsync of xor_handshake.v
// End of automatics

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg         [1:0]          // auto enum state_info
                              ptr_sync_cs;

reg         [FPTRWID-1:0]     save_ptr_reg;
reg         [PTR_LATENCY-1:0] ptr_changed;



//--------------------------------------------------------------------------
//--- wclk domain logic ---
//--------------------------------------------------------------------------

  //--------------------------------------------
  //-- pointer holding register for sync --
  //--------------------------------------------
  always @* begin
    if((ptr_sync_ns[0] ^ ptr_sync_cs[0]) & (ptr_changed[0] | pend_reqsync)) begin
      case({wclr,mov_en})
        2'b01   : save_ptr_reg_nxt = ptr_w + ptr_mov_cnt;
        2'b10   : save_ptr_reg_nxt = PTRDEFVAL;
        2'b11   : save_ptr_reg_nxt = PTRDEFVAL;
        default : save_ptr_reg_nxt = ptr_w;
      endcase
    end
    else begin
      save_ptr_reg_nxt = save_ptr_reg;
    end
  end

  //--------------------------------------------
  //-- Binary pointer synchronization --
  //--------------------------------------------
  always @* begin
    ptr_sync_ns = ptr_sync_cs;
    case({ptr_reqsync_w,ptr_acksync_w})
      2'b01,
      2'b10   : begin
        if(ptr_changed[0] | pend_reqsync) begin
          ptr_sync_ns[1] = 1'b1;
        end
      end
      default : begin
        if(ptr_changed[0] | pend_reqsync) begin
          ptr_sync_ns[0]   = ~ptr_sync_cs[0];
          ptr_sync_ns[1]   = 1'b0;
        end
      end
    endcase
  end

  always @* begin
    ptr_reqsync_w    = ptr_sync_cs[0];
    pend_reqsync     = ptr_sync_cs[1];
  end //--always @*--


  //--------------------------------------------
  //-- Sequential block --
  //--------------------------------------------
  always @(posedge wclk or negedge wrst_n) begin
    if(~wrst_n) begin
      ptr_sync_cs <= ST_IDLE_PTR;
      save_ptr_reg <= PTRDEFVAL;
      /*AUTORESET*/
    end
    else begin
      ptr_sync_cs <= ptr_sync_ns;
      save_ptr_reg <= save_ptr_reg_nxt;
    end
  end //--always @(posedge wclk or negedge wrst_n)--

  //--------------------------------------------------------------------------
  //--- rclk domain logic ---
  //--------------------------------------------------------------------------

  //--------------------------------------------
  //-- get pointer value when sync is done --
  //--------------------------------------------
  always @* begin
    if(rclr) begin
      ptr_r_nxt = PTRDEFVAL;
    end
    else begin
      if(ptr_sync_done_r)
        ptr_r_nxt = save_ptr_reg;
      else
        ptr_r_nxt = ptr_r;
    end
  end //--always @*--

  //--------------------------------------------
  //-- Sequential block --
  //--------------------------------------------
  always @(posedge rclk or negedge rrst_n) begin
    if(~rrst_n) begin
      ptr_r <= PTRDEFVAL;
      /*AUTORESET*/
    end
    else begin
      ptr_r <= ptr_r_nxt;
    end
  end //--always @(posedge rclk or negedge rrst_n)--

  //--------------------------------------------------------------------------
  //--- For Statemachine Debugging ---
  //--------------------------------------------------------------------------
  /*AUTOASCIIENUM("ptr_sync_cs", "__ptr_sync_cs__", "ST_")*/
  // Beginning of automatic ASCII enum decoding
  reg         [71:0]          __ptr_sync_cs__;  // Decode of ptr_sync_cs
  always @(ptr_sync_cs) begin
     case ({ptr_sync_cs})
       ST_IDLE_PTR:  __ptr_sync_cs__ = "idle_ptr ";
       ST_SYNC_REQ:  __ptr_sync_cs__ = "sync_req ";
       ST_PEND_PTR:  __ptr_sync_cs__ = "pend_ptr ";
       ST_SYNC_PEND: __ptr_sync_cs__ = "sync_pend";
       default:      __ptr_sync_cs__ = "%Error   ";
     endcase
  end
  // End of automatics

  /*AUTOASCIIENUM("ptr_sync_ns", "__ptr_sync_ns__", "ST_")*/
  // Beginning of automatic ASCII enum decoding
  reg         [71:0]          __ptr_sync_ns__;  // Decode of ptr_sync_ns
  always @(ptr_sync_ns) begin
     case ({ptr_sync_ns})
       ST_IDLE_PTR:  __ptr_sync_ns__ = "idle_ptr ";
       ST_SYNC_REQ:  __ptr_sync_ns__ = "sync_req ";
       ST_PEND_PTR:  __ptr_sync_ns__ = "pend_ptr ";
       ST_SYNC_PEND: __ptr_sync_ns__ = "sync_pend";
       default:      __ptr_sync_ns__ = "%Error   ";
     endcase
  end
  // End of automatics

  //--------------------------------------------------------------------------
  //--- Module Instantiation ---
  //--------------------------------------------------------------------------

  xor_handshake #(.DWID(1)) sync_ptr_reqsync
  (
   // Inputs
   .clk_a                                 (wclk),
   .clk_b                                 (rclk),
   .rst_n_a                               (wrst_n),
   .rst_n_b                               (rrst_n),
   .req_a                                 (ptr_reqsync_w),
   // Outputs
   .req_b                                 (),
   .ack_b_pulse                           (ptr_sync_done_r),
   .ack_b                                 (),
   .ack_a_pulse                           (),
   .ack_a                                 (ptr_acksync_w)
   /*AUTOINST*/);

  if(PTR_LATENCY < 2) begin
    always @* begin
      ptr_changed = (wclr|mov_en);
    end //--always @*--

  end // (PTR_LATENCY < 2)
  else begin // (PTR_LATENCY > 2)
    always @(posedge wclk or negedge wrst_n) begin
      if(~wrst_n) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        ptr_changed <= {PTR_LATENCY{1'b0}};
        // End of automatics
      end
      else begin
        ptr_changed <= {(wclr|mov_en),ptr_changed[PTR_LATENCY-1:1]};
      end
    end //--always @(posedge wclk or negedge wrst_n)--
  end // (PTR_LATENCY > 2)

end // (CLKDOMAIN == "ASYNC")

else begin // (CLKDOMAIN == "SYNC")
  always @* begin
    ptr_r = ptr_w;
  end //--always @*--
end // (CLKDOMAIN == "SYNC")
endgenerate


generate
if(PTR_IMPL == "UP") begin
  assign ptr_mov_cnt = mov_cnt;
end // (PTR_IMPL == "UP")
else begin // (PTR_IMPL == "DOWN")
  assign ptr_mov_cnt = ~mov_cnt + {{(FPTRWID-1){1'b0}},1'b1};
end // (PTR_IMPL == "DOWN")
endgenerate

//--------------------------------------------
//-- up/down counter --
//--------------------------------------------
always @* begin
  case({wclr,mov_en})
    2'b00   : ptr_w_nxt = ptr_w;
    2'b01   : ptr_w_nxt = ptr_w + ptr_mov_cnt;
    default : ptr_w_nxt = PTRDEFVAL;
  endcase
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge wclk or negedge wrst_n) begin
  if(~wrst_n) begin
    ptr_w <= PTRDEFVAL;
    /*AUTORESET*/
  end
  else begin
    ptr_w <= ptr_w_nxt;
  end
end //--always @(posedge wclk or negedge wrst_n)--



endmodule //--async_binptr--
`endif // __RTL_MODULE__ASYNC_BINPTR__

