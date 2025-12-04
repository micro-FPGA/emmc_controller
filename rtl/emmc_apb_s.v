// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_APB_S__
`define __RTL_MODULE__EMMC_APB_S__
//==========================================================================
// Module : emmc_apb_s
//==========================================================================
module emmc_apb_s #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          SIMULATION        = 0
,parameter                          DEVICE_FAMILY     = "LAV-AT"
,parameter                          CLKDOMAIN         = "SYNC"              // "SYNC" - sck_src_i clock is the same as clk_i

,parameter                          EN_FULLADDR_DECODE= 0
,parameter                          EN_FIFO           = 0                   // enable FIFO

,parameter                          REG_BASE_ADDR     = 32'h0000_0000       // Register block base address

,parameter                          AXI4_LEN_WIDTH    = 8
,parameter                          AXI4_ADR_WIDTH    = 32
,parameter                          AXI4_DAT_WIDTH    = 32
,parameter                          AXI4_STB_WIDTH    = ((AXI4_DAT_WIDTH + 7) / 8)


) //--end_param--

( //--begin_ports--
 input                              clk_i               // system clock
,input                              rst_n_i

,input                              sck_src_i           // internal core clock
,input                              sck_rst_n_i

 // APB interface - clk_i domain
,input                              apb_psel_i          // apb slave select
,input                              apb_penable_i       // apb enable
,input                              apb_pwrite_i        // apb write 1, read 0
,input        [AXI4_ADR_WIDTH-1:0]  apb_paddr_i         // apb address
,input        [AXI4_DAT_WIDTH-1:0]  apb_pwdata_i        // apb write data

,output wire                        apb_pready_o        // apb ready
,output wire                        apb_pslverr_o       // apb slave error
,output wire  [AXI4_DAT_WIDTH-1:0]  apb_prdata_o        // apb read data

// CSR interface - sck_src_i domain
,output wire  [3:0]                 csr_wren            // write enable per byte
,output wire  [7:0]                 csr_wadr            // write dword address
,output wire  [AXI4_DAT_WIDTH-1:0]  csr_wdat            // write data
,output wire                        csr_rden            // read enable
,output wire  [7:0]                 csr_radr            // read dword address

,input        [AXI4_DAT_WIDTH-1:0]  csr_rdat            // read data - 1 cycle latency

// Rx FIFO interface - clk_i domain
,input                              rxfifo_emty

,output reg                         rxfifo_rden

// Tx FIFO interface - clk_i domain
,input                              txfifo_aful

,output reg   [AXI4_DAT_WIDTH-1:0]  txfifo_wdata
,output reg                         txfifo_wren

,output wire                        bus_access_error
,output reg                         wr_on_full_error
,output reg                         rd_on_emty_error


)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam    [63:0]                VALID_AXI_ADDR_MAP  = 64'hFFFF_FFFF_FFFF_FC00;    // 1 KB aligned

localparam                          DWORD_ADR_MAP       = 1;                  // 1 - registers are mapped with DWORD offset (increment by 4)
                                                                              // 0 - address map based on register data width
                                                                              //     (e.g. 8 - byte address, 16 word address, etc)
localparam                          DECODE_BADDR        = EN_FULLADDR_DECODE;

localparam                          REG_INPUT           = 1 ;                 // register the bus inputs
localparam                          REG_DATA_OUT        = 1 ;                 // register the bus data output

localparam                          REG_ADR_WIDTH       = 8 ;                 // local register address width
localparam                          REG_WDT_WIDTH       = 32;                 // local register write data width
localparam                          REG_RDT_WIDTH       = 32;                 // local register read data width
localparam                          REG_RD_LATENCY      = 1 ;                 // number of cycles before CSR read data is available,
                                                                              // E.g. 0 means read data is already available while csr_rden=1
                                                                              // E.g. 1 means 1 clock cycle after csr_rden=1

localparam                          ADR_TX_FIFO_DATA    = {2'd2,6'h06} // addr[9:2]
                                   ,ADR_RX_FIFO_DATA    = {2'd2,6'h07} // addr[9:2]
                                   ;
//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
wire                                gnd_wire;

wire                                csr_big_endian;
wire                                csr_rdat_valid;
wire                                csr_wr_done;
wire                                rsvd_done;

wire          [AXI4_ADR_WIDTH-1:0]  apb_pwdata_w;
wire          [AXI4_ADR_WIDTH-1:0]  bus_addr;
wire          [AXI4_DAT_WIDTH-1:0]  bus_data;
wire                                pready_nxt;

wire          [31:0]                reg_base_addr;

wire                                wadrdec_ip_addr;
wire                                wadrdec_csr_block;
wire                                wadrdec_tx_fifo;
wire                                wadrdec_rx_fifo;
wire                                wadrdec_reserved;

wire                                radrdec_ip_addr;
wire                                radrdec_csr_block;
wire                                radrdec_tx_fifo;
wire                                radrdec_rx_fifo;
wire                                radrdec_reserved;


//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg                                 pready;

assign gnd_wire           = 1'b0;
assign csr_big_endian     = 1'b0;
assign reg_base_addr      = REG_BASE_ADDR;

assign wadrdec_ip_addr    = (EN_FULLADDR_DECODE)? (apb_paddr_i[31:10] == reg_base_addr[31:10]) : 1'b1;
assign radrdec_ip_addr    = (EN_FULLADDR_DECODE)? (apb_paddr_i[31:10] == reg_base_addr[31:10]) : 1'b1;

assign wadrdec_csr_block  = wadrdec_ip_addr;
assign wadrdec_tx_fifo    = (EN_FIFO)? wadrdec_ip_addr & (bus_addr[9:2] == ADR_TX_FIFO_DATA) : 1'b0;
assign wadrdec_rx_fifo    = (EN_FIFO)? wadrdec_ip_addr & (bus_addr[9:2] == ADR_RX_FIFO_DATA) : 1'b0;
assign wadrdec_reserved   = ~wadrdec_ip_addr;

assign radrdec_csr_block  = radrdec_ip_addr;
assign radrdec_tx_fifo    = (EN_FIFO)? radrdec_ip_addr & (bus_addr[9:2] == ADR_TX_FIFO_DATA) : 1'b0;
assign radrdec_rx_fifo    = (EN_FIFO)? radrdec_ip_addr & (bus_addr[9:2] == ADR_RX_FIFO_DATA) : 1'b0;
assign radrdec_reserved   = ~radrdec_ip_addr;

assign apb_pready_o       = pready;
assign pready_nxt         = ~pready & apb_psel_i & (csr_wr_done | csr_rdat_valid | rsvd_done);
assign apb_pwdata_w       = (csr_big_endian)? {apb_pwdata_i[8*0+:8]
                                              ,apb_pwdata_i[8*1+:8]
                                              ,apb_pwdata_i[8*2+:8]
                                              ,apb_pwdata_i[8*3+:8]
                                              } : apb_pwdata_i;
//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    pready <= 1'h0;
    // End of automatics
  end
  else begin
    pready <= pready_nxt;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

generate
  if(DWORD_ADR_MAP) begin : gen_dword_map
    assign bus_addr       = {apb_paddr_i[AXI4_ADR_WIDTH-1:2],2'd0};
  end // gen_dword_map
  else begin : gen_default_map
    assign bus_addr       = apb_paddr_i;
  end // gen_default_map

  if(DECODE_BADDR) begin : gen_decode_base
    reg                                 pslverr;

    assign apb_pslverr_o    = pslverr;
    assign bus_access_error = pslverr;

    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        pslverr <= 1'h0;
        // End of automatics
      end
      else begin
        pslverr <= pready_nxt & (wadrdec_reserved | radrdec_reserved);
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--

  end // gen_decode_base
  else begin : gen_nodec_base
    assign apb_pslverr_o    = 1'b0;
    assign bus_access_error = 1'b0;
  end // gen_nodec_base

  if(REG_INPUT || (CLKDOMAIN != "SYNC")) begin : gen_regin
    reg           [REG_ADR_WIDTH-1:0]   bus_addr_r;
    reg           [REG_WDT_WIDTH-1:0]   bus_data_r;
    reg                                 wren_r;
    reg                                 rden_r;
    reg                                 rsvd_done_r;

    assign bus_data = bus_data_r;
    assign csr_wren = {4{wren_r}};
    assign csr_wadr = bus_addr_r;
    assign csr_wdat = bus_data_r;

    assign csr_rden = rden_r;
    assign csr_radr = bus_addr_r;

    if(CLKDOMAIN == "SYNC") begin : gen_sync_in
      assign csr_wr_done = wren_r;
      assign rsvd_done   = rsvd_done_r;

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          bus_addr_r <= {REG_ADR_WIDTH{1'b0}};
          bus_data_r <= {REG_WDT_WIDTH{1'b0}};
          rden_r <= 1'h0;
          rsvd_done_r <= 1'h0;
          wren_r <= 1'h0;
          // End of automatics
        end
        else begin
          bus_addr_r  <= bus_addr[REG_ADR_WIDTH+2-1:2];
          bus_data_r  <= apb_pwdata_w[REG_WDT_WIDTH-1:0];
          wren_r      <= apb_psel_i & ~apb_penable_i &  apb_pwrite_i & wadrdec_csr_block;
          rden_r      <= apb_psel_i & ~apb_penable_i & ~apb_pwrite_i & radrdec_csr_block;
          rsvd_done_r <= apb_psel_i & ~apb_penable_i & (wadrdec_reserved | radrdec_reserved);
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_sync_in
    else begin : gen_async_in
      reg           [2:0]   psel_ss /* synthesis CDC_Register=3 */;
      reg           [1:0]   psel_reg_ss /* synthesis CDC_Register=2 */;
      reg                   bus_wr1_rd0;

      //--------------------------------------------
      //-- synchronize bus signal to reg clock --
      //--------------------------------------------
      always @(posedge sck_src_i or negedge sck_rst_n_i) begin
        if(~sck_rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          bus_addr_r <= {REG_ADR_WIDTH{1'b0}};
          bus_data_r <= {REG_WDT_WIDTH{1'b0}};
          bus_wr1_rd0 <= 1'h0;
          psel_ss <= 3'h0;
          rden_r <= 1'h0;
          wren_r <= 1'h0;
          // End of automatics
        end
        else begin
          psel_ss <= {psel_ss[1:0],apb_psel_i};

          wren_r  <= psel_ss[2:1] &  bus_wr1_rd0; // did not include base address decoding
          rden_r  <= psel_ss[2:1] & ~bus_wr1_rd0; // did not include base address decoding

          // capture bus signals - these are multicycle path
          bus_addr_r  <= bus_addr[REG_ADR_WIDTH+2-1:2];
          bus_data_r  <= apb_pwdata_w[REG_WDT_WIDTH-1:0];
          bus_wr1_rd0 <= apb_pwrite_i;
        end
      end //--always @(posedge sck_src_i or negedge sck_rst_n_i)--

      assign csr_wr_done = psel_reg_ss[1];
      assign rsvd_done   = psel_reg_ss[1] & (wadrdec_reserved | radrdec_reserved);
      //--------------------------------------------
      //-- synchronize psel_ss back to system clock--
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          psel_reg_ss <= 2'h0;
          // End of automatics
        end
        else begin
          psel_reg_ss <= {psel_reg_ss[0],psel_ss[2]};
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--

    end // gen_async_in

  end // gen_regin
  else begin : gen_noregin
    assign bus_data = apb_pwdata_w;

    assign rsvd_done   = apb_psel_i & (wadrdec_reserved | radrdec_reserved);
    assign csr_wr_done = apb_pwrite_i;

    assign csr_wren = {4{apb_psel_i & ~apb_penable_i &  apb_pwrite_i & wadrdec_csr_block}};
    assign csr_wadr = bus_addr[REG_ADR_WIDTH+2-1:2];
    assign csr_wdat = bus_data[REG_WDT_WIDTH-1:0];

    assign csr_rden = apb_psel_i & ~apb_penable_i & ~apb_pwrite_i & radrdec_csr_block;
    assign csr_radr = bus_addr[REG_ADR_WIDTH+2-1:2];
  end // gen_noregin

  if(REG_DATA_OUT || (CLKDOMAIN != "SYNC")) begin : gen_regout
    reg           [REG_RDT_WIDTH-1:0]   prdat;
    wire          [REG_RDT_WIDTH-1:0]   prdat_nxt;

    assign apb_prdata_o = prdat & {AXI4_DAT_WIDTH{1'b1}};
    assign prdat_nxt    = csr_rdat;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        prdat <= {REG_RDT_WIDTH{1'b0}};
        // End of automatics
      end
      else begin
        if(csr_rdat_valid) begin
          prdat <= (csr_big_endian)? {prdat_nxt[8*0+:8]
                                     ,prdat_nxt[8*1+:8]
                                     ,prdat_nxt[8*2+:8]
                                     ,prdat_nxt[8*3+:8]
                                     } : prdat_nxt;
        end
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_regout
  else begin : gen_noregout
    assign apb_prdata_o = {AXI4_DAT_WIDTH{1'b1}} & ((csr_big_endian)? {csr_rdat[8*0+:8]
                                                                      ,csr_rdat[8*1+:8]
                                                                      ,csr_rdat[8*2+:8]
                                                                      ,csr_rdat[8*3+:8]
                                                                      } : csr_rdat);
  end // gen_noregout

  if(REG_RD_LATENCY) begin : gen_rdlat_gt0
    reg           [REG_RD_LATENCY-1:0]  rd_delay;

    if(CLKDOMAIN == "SYNC") begin : gen_sync_dout

      assign csr_rdat_valid = rd_delay[REG_RD_LATENCY-1];

      //--------------------------------------------
      //-- CSR read data valid --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rd_delay <= {REG_RD_LATENCY{1'b0}};
          // End of automatics
        end
        else begin
          rd_delay <= {rd_delay,csr_rden} & {REG_RD_LATENCY{1'b1}};
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_sync_dout
    else begin : gen_async_dout
      reg                                 rdat_avail;
      reg           [2:0]                 rdat_avail_ss /* synthesis CDC_Register=3 */;
      reg           [1:0]                 rdat_avail_reg_ss /* synthesis CDC_Register=2 */;

      assign csr_rdat_valid = (rdat_avail_ss[2:1] == 2'b01);

      //--------------------------------------------
      //-- CSR read data valid handshake --
      //--------------------------------------------
      always @(posedge sck_src_i or negedge sck_rst_n_i) begin
        if(~sck_rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rd_delay <= {REG_RD_LATENCY{1'b0}};
          rdat_avail <= 1'h0;
          rdat_avail_reg_ss <= 2'h0;
          // End of automatics
        end
        else begin
          rd_delay          <= {rd_delay,csr_rden} & {REG_RD_LATENCY{1'b1}};
          rdat_avail_reg_ss <= {rdat_avail_reg_ss[0],rdat_avail_ss[1]};

          if(rdat_avail) begin
            rdat_avail <= ~rdat_avail_reg_ss[1];
          end
          else begin
            rdat_avail <= rd_delay[REG_RD_LATENCY-1];
          end
        end
      end //--always @(posedge sck_src_i or negedge sck_rst_n_i)--

      //--------------------------------------------
      //-- CSR read data valid --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rdat_avail_ss <= 3'h0;
          // End of automatics
        end
        else begin
          rdat_avail_ss <= {rdat_avail_ss[1:0],rdat_avail};
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_async_dout
  end // gen_rdlat_gt0
  else begin : gen_rdlat_eq0
    assign csr_rdat_valid = csr_rden;
  end // gen_rdlat_eq0

  if(EN_FIFO) begin : gen_map_fifo
    //--------------------------------------------
    //-- Tx FIFO write --
    //--------------------------------------------
    always @(posedge sck_src_i or negedge sck_rst_n_i) begin
      if(~sck_rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        txfifo_wdata <= {AXI4_DAT_WIDTH{1'b0}};
        txfifo_wren <= 1'h0;
        wr_on_full_error <= 1'h0;
        // End of automatics
      end
      else begin
        txfifo_wren  <= apb_psel_i & ~apb_penable_i &  apb_pwrite_i &
                        wadrdec_tx_fifo & ~txfifo_aful;
        txfifo_wdata <= apb_pwdata_w;
        wr_on_full_error <= txfifo_wren & txfifo_aful;
      end
    end //--always @(posedge sck_src_i or negedge sck_rst_n_i)--

    //--------------------------------------------
    //-- Rx FIFO read --
    //--------------------------------------------
    always @(posedge sck_src_i or negedge sck_rst_n_i) begin
      if(~sck_rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        rd_on_emty_error <= 1'h0;
        rxfifo_rden <= 1'h0;
        // End of automatics
      end
      else begin
        rxfifo_rden  <= apb_psel_i & apb_penable_i & pready_nxt &
                        ~apb_pwrite_i & radrdec_rx_fifo & ~rxfifo_emty;
        rd_on_emty_error <= rxfifo_rden & rxfifo_emty;
      end
    end //--always @(posedge sck_src_i or negedge sck_rst_n_i)--
  end // gen_map_fifo

  else begin : gen_no_map_fifo
    //--------------------------------------------
    //-- Combinatorial block --
    //--------------------------------------------
    always @* begin
      rxfifo_rden       = gnd_wire;
      txfifo_wren       = gnd_wire;
      txfifo_wdata      = {AXI4_DAT_WIDTH{gnd_wire}};
      rd_on_emty_error  = gnd_wire;
      wr_on_full_error  = gnd_wire;
    end //--always @*--
  end // gen_no_map_fifo

endgenerate

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------



endmodule //--emmc_apb_s--
`endif // __RTL_MODULE__EMMC_APB_S__
