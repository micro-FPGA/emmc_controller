// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__AXI_MEM_MODEL__
`define __RTL_MODULE__AXI_MEM_MODEL__
//==========================================================================
// Module : axi_mem_model
//==========================================================================
module axi_mem_model #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          SIMULATION     = 0
,parameter                          MEM_DEPTH      = 16384
,parameter                          AXI4_TID_WIDTH = 1
,parameter                          AXI4_LEN_WIDTH = 8
,parameter                          AXI4_ADR_WIDTH = 32
,parameter                          AXI4_DAT_WIDTH = 32
,parameter                          AXI4_STB_WIDTH = ((AXI4_DAT_WIDTH + 7) / 8)

) //--end_param--

( //--begin_ports--
// System clock and reset
 input                              clk_i
,input                              rst_n_i

// ---------------------------------------------------------------------------------------
// AXI4 Subordinate interface
,output wire                        s_axi4_awready_o
,input                              s_axi4_awvalid_i
,input        [AXI4_TID_WIDTH-1:0]  s_axi4_awid_i
,input        [AXI4_ADR_WIDTH-1:0]  s_axi4_awaddr_i
,input        [AXI4_LEN_WIDTH-1:0]  s_axi4_awlen_i
,input        [2:0]                 s_axi4_awsize_i
,input        [1:0]                 s_axi4_awburst_i

,output wire                        s_axi4_wready_o
,input                              s_axi4_wvalid_i
,input        [31:0]                s_axi4_wdata_i
,input        [3:0]                 s_axi4_wstrb_i
,input                              s_axi4_wlast_i

,input                              s_axi4_bready_i
,output wire                        s_axi4_bvalid_o
,output wire  [AXI4_TID_WIDTH-1:0]  s_axi4_bid_o
,output wire  [1:0]                 s_axi4_bresp_o

,output wire                        s_axi4_arready_o
,input                              s_axi4_arvalid_i
,input        [AXI4_TID_WIDTH-1:0]  s_axi4_arid_i
,input        [AXI4_ADR_WIDTH-1:0]  s_axi4_araddr_i
,input        [AXI4_LEN_WIDTH-1:0]  s_axi4_arlen_i
,input        [2:0]                 s_axi4_arsize_i
,input        [1:0]                 s_axi4_arburst_i

,input                              s_axi4_rready_i
,output wire                        s_axi4_rvalid_o
,output wire  [AXI4_TID_WIDTH-1:0]  s_axi4_rid_o
,output wire  [31:0]                s_axi4_rdata_o
,output wire  [1:0]                 s_axi4_rresp_o
,output wire                        s_axi4_rlast_o

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                          MEM_AWID = $clog2(MEM_DEPTH);

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

wire                                awready   ;
wire                                awvalid   ;
wire          [AXI4_TID_WIDTH-1:0]  awid      ;
wire          [AXI4_ADR_WIDTH-1:0]  awaddr    ;
wire          [AXI4_LEN_WIDTH-1:0]  awlen     ;
wire          [2:0]                 awsize    ;
wire          [1:0]                 awburst   ;

wire                                wready    ;
wire                                wvalid    ;
wire          [31:0]                wdata     ;
wire          [3:0]                 wstrb     ;
wire                                wlast     ;

wire                                bready    ;
wire                                bvalid    ;
wire          [AXI4_TID_WIDTH-1:0]  bid       ;
wire          [1:0]                 bresp     ;

wire                                arready   ;
wire                                arvalid   ;
wire          [AXI4_TID_WIDTH-1:0]  arid      ;
wire          [AXI4_ADR_WIDTH-1:0]  araddr    ;
wire          [AXI4_LEN_WIDTH-1:0]  arlen     ;
wire          [2:0]                 arsize    ;
wire          [1:0]                 arburst   ;

wire                                rready    ;
wire                                rvalid    ;
wire          [AXI4_TID_WIDTH-1:0]  rid       ;
wire          [31:0]                rdata     ;
wire          [1:0]                 rresp     ;
wire                                rlast     ;
wire                                rlast_d   ;


wire                                mem_int_wren;
wire                                mem_int_rden;
wire          [31:0]                mem_int_wdat;
wire          [31:0]                mem_int_rdat;
wire          [MEM_AWID-1:0]        mem_int_wadr;
wire          [MEM_AWID-1:0]        mem_int_radr;
//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [8:0]                 wrcntr;
reg           [8:0]                 rdcntr;
reg                                 rvalid_r;
reg           [AXI4_TID_WIDTH-1:0]  rid_r;
reg                                 rlast_r;

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
assign mem_int_wren = wvalid & wready & awvalid;
assign mem_int_wadr = awaddr[2+:MEM_AWID] + wrcntr;
assign mem_int_wdat = wdata;
assign mem_int_rden = rready & arvalid;
assign mem_int_radr = araddr[2+:MEM_AWID] + rdcntr;
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

assign awready = awvalid & mem_int_wren & wlast;
model_fifo_reg #
(
 .DATA_WIDTH                            (AXI4_TID_WIDTH +
                                         AXI4_ADR_WIDTH +
                                         AXI4_LEN_WIDTH +
                                         3 + 2),
 .ADDR_WIDTH                            (4)
)
aw_fifo
(
  // Inputs
 .clk                                   (clk_i),
 .rst_n                                 (rst_n_i),
 .wr_valid                              (s_axi4_awvalid_i),
 .wr_data                               ({s_axi4_awid_i,
                                          s_axi4_awaddr_i,
                                          s_axi4_awlen_i,
                                          s_axi4_awsize_i,
                                          s_axi4_awburst_i}),
 .rd_ready                              (awready),
  // Outputs
 .wr_ready                              (s_axi4_awready_o),
 .wr_aready                             (), // unused
 .rd_valid                              (awvalid),
 .rd_data                               ({awid, awaddr, awlen, awsize, awburst})
);

assign wready = wvalid & bready;
model_fifo_reg #
(
 .DATA_WIDTH                            (AXI4_STB_WIDTH +
                                         AXI4_DAT_WIDTH +
                                         1),
 .ADDR_WIDTH                            (4)
)
wd_fifo
(
  // Inputs
 .clk                                   (clk_i),
 .rst_n                                 (rst_n_i),
 .wr_valid                              (s_axi4_wvalid_i),
 .wr_data                               ({s_axi4_wstrb_i,
                                          s_axi4_wdata_i,
                                          s_axi4_wlast_i}),
 .rd_ready                              (wready),
  // Outputs
 .wr_ready                              (s_axi4_wready_o),
 .wr_aready                             (), // unused
 .rd_valid                              (wvalid),
 .rd_data                               ({wstrb, wdata, wlast})
);

assign bvalid = awvalid & mem_int_wren & wlast;
assign bid    = {AXI4_TID_WIDTH{1'b0}};
assign bresp  = 2'd0;
model_fifo_reg #
(
 .DATA_WIDTH                            (AXI4_TID_WIDTH+2),
 .ADDR_WIDTH                            (4)
)
br_fifo
(
  // Inputs
 .clk                                   (clk_i),
 .rst_n                                 (rst_n_i),
 .wr_valid                              (bvalid),
 .wr_data                               ({bid,bresp}),
 .rd_ready                              (s_axi4_bready_i),
  // Outputs
 .wr_ready                              (bready),
 .wr_aready                             (), // unused
 .rd_valid                              (s_axi4_bvalid_o),
 .rd_data                               ({s_axi4_bid_o, s_axi4_bresp_o})
);

assign arready = arvalid & mem_int_rden & rlast_d;
model_fifo_reg #
(
 .DATA_WIDTH                            (AXI4_TID_WIDTH +
                                         AXI4_ADR_WIDTH +
                                         AXI4_LEN_WIDTH +
                                         3 + 2),
 .ADDR_WIDTH                            (4)
)
ar_fifo
(
  // Inputs
 .clk                                   (clk_i),
 .rst_n                                 (rst_n_i),
 .wr_valid                              (s_axi4_arvalid_i),
 .wr_data                               ({s_axi4_arid_i,
                                          s_axi4_araddr_i,
                                          s_axi4_arlen_i,
                                          s_axi4_arsize_i,
                                          s_axi4_arburst_i}),
 .rd_ready                              (arready),
  // Outputs
 .wr_ready                              (s_axi4_arready_o),
 .wr_aready                             (), // unused
 .rd_valid                              (arvalid),
 .rd_data                               ({arid, araddr, arlen, arsize, arburst})
);

assign rid      = rid_r;
assign rresp    = 2'd0;
assign rdata    = mem_int_rdat;
assign rlast    = rlast_r;
assign rlast_d  = (rdcntr[7:0] == arlen);
assign rvalid   = rvalid_r;
//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    wrcntr <= 9'h0;
    rdcntr <= 9'h0;
    rid_r <= {AXI4_TID_WIDTH{1'b0}};
    rlast_r <= 1'h0;
    rvalid_r <= 1'h0;
    // End of automatics
  end
  else begin
    wrcntr    <= (mem_int_wren & wlast  )? 9'd0 : wrcntr + {8'd0,mem_int_wren};
    rdcntr    <= (mem_int_rden & rlast_d)? 9'd0 : rdcntr + {8'd0,mem_int_rden};
    rvalid_r  <= mem_int_rden;
    rid_r     <= arid;
    rlast_r   <= rlast_d;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

model_fifo_reg #
(
 .DATA_WIDTH                            (AXI4_TID_WIDTH +
                                         AXI4_DAT_WIDTH +
                                         2 + 1),
 .ADDR_WIDTH                            (4)
)
rd_fifo
(
  // Inputs
 .clk                                   (clk_i),
 .rst_n                                 (rst_n_i),
 .wr_valid                              (rvalid),
 .wr_data                               ({rid,
                                          rdata,
                                          rresp,
                                          rlast}),
 .rd_ready                              (s_axi4_rready_i),
  // Outputs
 .wr_ready                              (rready),
 .wr_aready                             (), // unused
 .rd_valid                              (s_axi4_rvalid_o),
 .rd_data                               ({s_axi4_rid_o, s_axi4_rdata_o, s_axi4_rresp_o, s_axi4_rlast_o})
);




endmodule //--axi_mem_model--
`endif // __RTL_MODULE__AXI_MEM_MODEL__

`ifndef __RTL_MODULE__MODEL_FIFO_REG__
`define __RTL_MODULE__MODEL_FIFO_REG__
//==========================================================================
// Module : model_fifo_reg
//==========================================================================
module model_fifo_reg #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          DATA_WIDTH       = 32
,parameter                          ADDR_WIDTH       = 2
,parameter                          NUM_WORDS        = (1 << ADDR_WIDTH)
,parameter                          AREADY_LEVEL     = NUM_WORDS/2       // Level which, when exceeded, de-asserts wr_aready port
,parameter                          COMB_WR_READY    = 0                 // Combinatorial wr_ready OR'd with rd_en
,parameter                          REGISTER_OUTPUT  = 0                 // Adds output register, read latency 0 to 1
,parameter                          RESET_FIFO_REGS  = 1                 // Reset FIFO registers on rst_n

) //--end_param--

( //--begin_ports--
 input                              rst_n
,input                              clk

,input                              wr_valid
,output                             wr_ready
,output reg                         wr_aready
,input        [DATA_WIDTH-1:0]      wr_data

,output reg                         rd_valid
,input                              rd_ready
,output reg   [DATA_WIDTH-1:0]      rd_data

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--

localparam  NUM_WORDS_MINUS_ONE = NUM_WORDS-1;

// ---------------------
// -- Local Variables --
// ---------------------

wire                            wr_en;
wire                            rd_en;

reg     [ADDR_WIDTH:0]          c_level;

reg     [ADDR_WIDTH-1:0]        wr_addr;
reg     [ADDR_WIDTH-1:0]        rd_addr;
reg     [ADDR_WIDTH:0]          level;

reg     [DATA_WIDTH-1:0]        fifo    [NUM_WORDS-1:0];
reg                             fifo_rd_valid;
wire                            fifo_rd_ready;
wire    [DATA_WIDTH-1:0]        fifo_rd_data;

reg                             wr_ready_i;


// ---------------
// -- Equations --
// ---------------

assign wr_en = wr_valid & wr_ready;
assign rd_en = fifo_rd_valid & fifo_rd_ready;

always @*
begin
    case ({wr_en, rd_en})
        2'b10   : c_level = level + {{ADDR_WIDTH{1'b0}}, 1'b1};
        2'b01   : c_level = level - {{ADDR_WIDTH{1'b0}}, 1'b1};
        default : c_level = level;
    endcase
end

always @(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0)
    begin
        wr_addr       <= {ADDR_WIDTH{1'b0}};
        rd_addr       <= {ADDR_WIDTH{1'b0}};

        level         <= {(ADDR_WIDTH+1){1'b0}};
        fifo_rd_valid <= 1'b0;
        wr_ready_i    <= 1'b0;
        wr_aready     <= 1'b0;
    end
    else
    begin
        if (wr_en)
        begin
            if (wr_addr == NUM_WORDS_MINUS_ONE)
                wr_addr <= {ADDR_WIDTH{1'b0}};
            else
                wr_addr <= wr_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
        end

        if (rd_en)
        begin
            if (rd_addr == NUM_WORDS_MINUS_ONE)
                rd_addr <= {ADDR_WIDTH{1'b0}};
            else
                rd_addr <= rd_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
        end

        level         <= c_level;
        fifo_rd_valid <= (c_level != {(ADDR_WIDTH+1){1'b0}});
        wr_ready_i    <= (c_level < NUM_WORDS);
        wr_aready     <= (c_level <= AREADY_LEVEL);
    end
end

generate
    if (COMB_WR_READY == 1)
    begin:  gen_comb_wr_ready
        // A read frees up a spot resulting in fifo not full.
        // This allows for simutaneous write and read when the fifo is
        // full.
        assign wr_ready = wr_ready_i | rd_en;
    end
    else
    begin: gen_reg_wr_ready
        assign wr_ready = wr_ready_i;
    end
endgenerate


genvar i;
generate
    for (i=0; i<NUM_WORDS; i=i+1)
    begin : gen_fifo_regs
        if (RESET_FIFO_REGS == 1)
        begin: resettable
            always @(posedge clk or negedge rst_n)
            begin
                if (rst_n == 1'b0)
                begin
                    fifo[i] <= {DATA_WIDTH{1'b0}};
                end
                else
                begin
                    if (wr_en & (wr_addr == i))
                        fifo[i] <= wr_data;
                end
            end
        end
        else
        begin: nonresettable
            always @(posedge clk)
            begin
                if (wr_en & (wr_addr == i))
                    fifo[i] <= wr_data;
            end
        end
    end
endgenerate

assign fifo_rd_data = fifo[rd_addr];

generate if (REGISTER_OUTPUT == 1)
    begin : gen_reg
        always @(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0)
            begin
                rd_valid <= 1'b0;
                rd_data  <= {DATA_WIDTH{1'b0}};
            end
            else
            begin
                if (fifo_rd_valid & fifo_rd_ready)
                    rd_valid <= 1'b1;
                else if (rd_valid & rd_ready)
                    rd_valid <= 1'b0;

                if (fifo_rd_valid & fifo_rd_ready)
                    rd_data <= fifo_rd_data;
            end
        end

        assign fifo_rd_ready = ~rd_valid | (rd_valid & rd_ready); // Empty or becoming empty
    end
    else
    begin : gen_comb
        always @*
        begin
            rd_valid = fifo_rd_valid;
            rd_data  = fifo_rd_data;
        end

        assign fifo_rd_ready = rd_ready;
    end
endgenerate

endmodule
`endif // __RTL_MODULE__MODEL_FIFO_REG__

`ifndef __RTL_MODULE__MODEL_MEM_DP__
`define __RTL_MODULE__MODEL_MEM_DP__
//==========================================================================
// Module : model_mem_dp
//==========================================================================
module model_mem_dp #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          MEM_TYPE = "LUT"    // "EBR" or "LUT"
,parameter                          MSIZ     = 32
,parameter                          AWID     = $clog2(MSIZ)
,parameter                          DWID     = 16

) //--end_param--

( //--begin_ports--
//----------------------------
// Inputs
//----------------------------
 input                              WClk
,input                              RClk

,input                              WrEn
,input        [AWID-1:0]            WAdr
,input        [DWID-1:0]            DtIn
,input                              RdEn
,input        [AWID-1:0]            RAdr

//----------------------------
// Outputs
//----------------------------
,output reg   [DWID-1:0]            DtOut

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--

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

      integer idx;
      initial begin
        DtOut = {DWID{1'b0}};
        for(idx=0; idx<MSIZ; idx=idx+1) begin
          memArray[idx] = $random;
        end
      end
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

      integer idx;
      initial begin
        DtOut = {DWID{1'b0}};
        for(idx=0; idx<MSIZ; idx=idx+1) begin
          memArray[idx] = $random;
        end
      end
    end // gen_lut

    default : begin : invalid_mem_impl
      initial begin
        $display("[%t][ERROR] Specified an invalid memory implementation type! (%m)",$time);
        $finish;
      end
    end // invalid_mem_impl
  endcase
endgenerate

// ------------------------------------------------------------------------------------------------------------
//task compare_mem_data;
//  input [AWID-1:0]    exp_ptr;
//  input [AWID-1:0]    obs_ptr;
//  input [AWID  :0]    num_dat;
//
//  integer             idx;
//  reg   [DWID-1:0]    exp_dat;
//  reg   [DWID-1:0]    obs_dat;
//  begin
//  case(MEM_TYPE)
//    "EBR" : begin
//      `E_MSG(("Invalid implementation"))
//    end // EBR
//
//    "LUT" : begin
//      for(idx=0; idx<num_dat; idx=idx+1) begin
//        exp_dat = gen_lut.memArray[exp_ptr+idx];
//        obs_dat = gen_lut.memArray[obs_ptr+idx];
//        if(obs_dat !== exp_dat) begin
//          `E_MSG(("[MISCOMPARE] Exp_Addr:0x%8h Exp_Data:0x%8h, Obs_Addr:0x%8h Obs_Data:0x%8h",
//                  exp_ptr+idx,exp_dat,obs_ptr+idx,obs_dat))
//        end
//        else begin
//          `N_MSG(("[DATA_MATCH] Exp_Addr:0x%8h Exp_Data:0x%8h, Obs_Addr:0x%8h Obs_Data:0x%8h",
//                  exp_ptr+idx,exp_dat,obs_ptr+idx,obs_dat))
//        end
//      end // for
//    end // LUT
//  endcase
//  end
//endtask // compare_mem_data

endmodule //--model_mem_dp--
`endif // __RTL_MODULE__MODEL_MEM_DP__
