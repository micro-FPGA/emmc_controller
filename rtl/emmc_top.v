// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_TOP__
`define __RTL_MODULE__EMMC_TOP__
//==========================================================================
// Module : emmc_top
//==========================================================================
module emmc_top #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          SIMULATION          = 0
,parameter                          DEVICE_FAMILY       = "LAV-AT"
,parameter                          FIFO_IMPL           = "PMI"             // "PMI"/"pmi" or "RTL"/"rtl" or "REG"/"reg"
,parameter                          MEM_IMPL            = "EBR"             // "EBR" or "LUT" or "HARD_IP"
,parameter                          USE_IO_PRIMITIVE    = 1

,parameter                          USE_CLKDIV1         = 0
,parameter                          CLKDIV_WID          = 8            // must be able to generate 400KHz,
                                                                       // (e.g 200MHz input clock divided by (2*250 pulse width) = 400 KHz)
,parameter    [CLKDIV_WID-1:0]      SPI_SCKDIV          = {{(CLKDIV_WID-1){1'b0}},1'b1}

,parameter                          EN_DDR_MODE         = 0
,parameter                          EN_DDR_WIDE         = 0

,parameter                          MAX_NUMLANE         = 8     // [1,4,8]
,parameter                          BUS_WID             = 32
,parameter                          SPI_WID             = (EN_DDR_MODE && EN_DDR_WIDE)? 2*MAX_NUMLANE : MAX_NUMLANE

,parameter                          EN_SPI_X4           = (MAX_NUMLANE >=  4)? 1 : 0
,parameter                          EN_SPI_X8           = (MAX_NUMLANE >=  8)? 1 : 0
,parameter                          EN_DDR_X4           = (MAX_NUMLANE >=  4)? EN_DDR_MODE : 0
,parameter                          EN_DDR_X8           = (MAX_NUMLANE >=  8)? EN_DDR_MODE : 0

,parameter                          NUM_REG_IN          = 1
,parameter                          EN_RSPTYP_DEC       = 1            // enable response type decoding
,parameter                          EN_AUTO_CMD         = 0            // enable generation of some commands via trigger

,parameter                          DEF_BLOCK_SIZE      = 512
,parameter                          MIN_BLOCK_SIZE      = 512
,parameter                          MAX_BLOCK_SIZE      = 4096
,parameter                          MAX_NUM_BLOCK       = 65536
,parameter                          FIFO_DEPTH          = ((2*MAX_BLOCK_SIZE)/4)
,parameter                          TMR_WIDTH           = 8

,parameter                          EN_FULLADDR_DECODE  = 0
,parameter                          DATA_INTERFACE      = "AXI4"            // "AXI4" or "AHBL"
,parameter                          REG_BASE_ADDR       = 32'h0000_0000       // Register block base address
,parameter                          AXI4_TID_WIDTH      = 1
,parameter                          AXI4_LEN_WIDTH      = 8
,parameter                          AXI4_ADR_WIDTH      = 32
,parameter                          AXI4_DAT_WIDTH      = 32
,parameter                          AXI4_STB_WIDTH      = ((AXI4_DAT_WIDTH + 7) / 8)

) //--end_param--

( //--begin_ports--

 input                              clk_i
,input                              rst_n_i

// eMMC IO interface
,output wire                        emmc_clk_o

,inout                              emmc_cmd_io         // command signal bidirectional

,input                              emmc_cmd_i          // command input
,output wire                        emmc_cmd_o          // command output
,output wire                        emmc_cmd_oe_o       // command output enable
,output wire                        io_cmd_in           // command input - for debug

,inout        [MAX_NUMLANE-1:0]     emmc_dat_io         // data signal bidirectional

,input        [MAX_NUMLANE-1:0]     emmc_dat_i          // data input
,output wire  [MAX_NUMLANE-1:0]     emmc_dat_o          // data output
,output wire  [MAX_NUMLANE-1:0]     emmc_dat_oe_o       // data output enable
,output wire  [MAX_NUMLANE-1:0]     io_dat_in           // data input - for debug

,output wire                        emmc_rst_n_o        // reset output - optional
// eMMC data strobe signal - optional (for HS200 and HS400)
,input                              emmc_dat_ds_i       // data strobe input

// interrupt signal
,output wire                        int_o               // interrupt signal


// ---------------------------------------------------------------------------------------
// APB interface
,input                              s_apb_psel_i
,input                              s_apb_penable_i
,input                              s_apb_pwrite_i
,input        [AXI4_ADR_WIDTH-1:0]  s_apb_paddr_i
,input        [AXI4_DAT_WIDTH-1:0]  s_apb_pwdata_i

,output wire                        s_apb_pready_o
,output wire                        s_apb_pslverr_o
,output wire  [AXI4_DAT_WIDTH-1:0]  s_apb_prdata_o

// ----------------------------------------------------
// AXI4 Manager interface
,input                              m_axi4_awready_i
,output wire                        m_axi4_awvalid_o
,output wire  [AXI4_ADR_WIDTH-1:0]  m_axi4_awaddr_o
,output wire  [AXI4_LEN_WIDTH-1:0]  m_axi4_awlen_o
,output wire  [AXI4_TID_WIDTH-1:0]  m_axi4_awid_o
,output wire  [2:0]                 m_axi4_awsize_o
,output wire  [1:0]                 m_axi4_awburst_o

,input                              m_axi4_wready_i
,output wire                        m_axi4_wvalid_o
,output wire  [31:0]                m_axi4_wdata_o
,output wire  [3:0]                 m_axi4_wstrb_o
,output wire                        m_axi4_wlast_o

,output wire                        m_axi4_bready_o
,input                              m_axi4_bvalid_i
,input        [AXI4_TID_WIDTH-1:0]  m_axi4_bid_i
,input        [1:0]                 m_axi4_bresp_i

,input                              m_axi4_arready_i
,output wire                        m_axi4_arvalid_o
,output wire  [AXI4_ADR_WIDTH-1:0]  m_axi4_araddr_o
,output wire  [AXI4_LEN_WIDTH-1:0]  m_axi4_arlen_o
,output wire  [AXI4_TID_WIDTH-1:0]  m_axi4_arid_o
,output wire  [2:0]                 m_axi4_arsize_o
,output wire  [1:0]                 m_axi4_arburst_o

,output wire                        m_axi4_rready_o
,input                              m_axi4_rvalid_i
,input        [AXI4_TID_WIDTH-1:0]  m_axi4_rid_i
,input        [31:0]                m_axi4_rdata_i
,input        [1:0]                 m_axi4_rresp_i
,input                              m_axi4_rlast_i
// ----------------------------------------------------

// ----------------------------------------------------
// AHB-Lite Manager interface
,output wire                        m_ahbl_hsel_o
,output wire  [AXI4_ADR_WIDTH-1:0]  m_ahbl_haddr_o
,output wire  [1:0]                 m_ahbl_htrans_o
,output wire                        m_ahbl_hwrite_o
,output wire  [2:0]                 m_ahbl_hsize_o
,output wire  [2:0]                 m_ahbl_hburst_o
,output wire  [3:0]                 m_ahbl_hprot_o
,output wire                        m_ahbl_hmastlock_o
,output wire  [AXI4_DAT_WIDTH-1:0]  m_ahbl_hwdata_o

,input                              m_ahbl_hready_i
,input                              m_ahbl_hresp_i
,input        [AXI4_DAT_WIDTH-1:0]  m_ahbl_hrdata_i
// ----------------------------------------------------

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam    [CLKDIV_WID-1:0]      DEFAULT_RATE  = SPI_SCKDIV;
localparam                          EN_NEG_SAMPLE = 0;
localparam                          PIPE_IMPL     = "FIFOREG";        // "SHREG" or "FIFOREG"
localparam                          CLKDOMAIN     = "SYNC";           // "SYNC" - sck_src_i clock is the same as clk_i

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

/*AUTOREGINPUT*/

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire                          bus_access_error; // From u_apb_s of emmc_apb_s.v
wire                          cmd_en_restart;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          cmd_proc_mem_avail;// From u_axi4_m of emmc_axi4_m.v
wire                          cmd_proc_mem_free;// From u_axi4_m of emmc_axi4_m.v
wire        [31:0]            cmd_proc_mem_rdat;// From u_axi4_m of emmc_axi4_m.v
wire                          cmd_proc_mem_rden;// From u_cmd_proc of emmc_cmd_proc.v
wire        [BUS_WID-1:0]     cmd_proc_mem_wdat;// From u_cmd_proc of emmc_cmd_proc.v
wire                          cmd_proc_mem_wren;// From u_cmd_proc of emmc_cmd_proc.v
wire        [CLKDIV_WID-1:0]  csr_clk_div;      // From u_csr of emmc_csr.v
wire        [15:0]            csr_cmd_timeout;  // From u_csr of emmc_csr.v
wire        [15:0]            csr_dat_timeout;  // From u_csr of emmc_csr.v
wire        [3:0]             csr_emmc_block_len;// From u_csr of emmc_csr.v
wire        [31:0]            csr_emmc_cmd_arg; // From u_csr of emmc_csr.v
wire                          csr_emmc_cmd_boot;// From u_csr of emmc_csr.v
wire        [5:0]             csr_emmc_cmd_idx; // From u_csr of emmc_csr.v
wire                          csr_emmc_cmd_start;// From u_csr of emmc_csr.v
wire                          csr_emmc_ddr_mode;// From u_csr of emmc_csr.v
wire        [1:0]             csr_emmc_io_width;// From u_csr of emmc_csr.v
wire        [15:0]            csr_emmc_num_blocks;// From u_csr of emmc_csr.v
wire                          csr_emmc_pp1_od0; // From u_csr of emmc_csr.v
wire        [2:0]             csr_emmc_rsp_typ; // From u_csr of emmc_csr.v
wire                          csr_emmc_rst;     // From u_csr of emmc_csr.v
wire                          csr_emmc_send_deselect;// From u_csr of emmc_csr.v
wire                          csr_emmc_send_select;// From u_csr of emmc_csr.v
wire                          csr_emmc_send_stop;// From u_csr of emmc_csr.v
wire                          csr_ip_core_rst;  // From u_csr of emmc_csr.v
wire        [7:0]             csr_radr;         // From u_apb_s of emmc_apb_s.v
wire        [31:0]            csr_rdat;         // From u_csr of emmc_csr.v
wire                          csr_rden;         // From u_apb_s of emmc_apb_s.v
wire                          csr_rvld;         // From u_csr of emmc_csr.v
wire        [31:0]            csr_src_dst_addr; // From u_csr of emmc_csr.v
wire        [7:0]             csr_wadr;         // From u_apb_s of emmc_apb_s.v
wire        [AXI4_DAT_WIDTH-1:0] csr_wdat;      // From u_apb_s of emmc_apb_s.v
wire        [3:0]             csr_wren;         // From u_apb_s of emmc_apb_s.v
wire        [CLKDIV_WID-1:0]  cur_clk_div;      // From u_cmd_proc of emmc_cmd_proc.v
wire                          dat_en_restart;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          det_bus_rd_error; // From u_axi4_m of emmc_axi4_m.v
wire                          det_bus_wr_error; // From u_axi4_m of emmc_axi4_m.v
wire                          det_cmd_crc_err;  // From u_cmd_proc of emmc_cmd_proc.v
wire                          det_dat_timeout;  // From u_cmd_proc of emmc_cmd_proc.v
wire                          det_emmc_done;    // From u_cmd_proc of emmc_cmd_proc.v
wire                          det_emmc_start;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          det_pld_crc_err;  // From u_cmd_proc of emmc_cmd_proc.v
wire                          det_rsp_timeout;  // From u_cmd_proc of emmc_cmd_proc.v
wire                          emmc_clk_out;     // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_clk_vld_i;// From u_iologic of emmc_iologic.v
wire                          emmc_cmd_clk_vld_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_crc_en_i;// From u_iologic of emmc_iologic.v
wire                          emmc_cmd_crc_en_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_dc_en_o; // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_dlast_i; // From u_iologic of emmc_iologic.v
wire                          emmc_cmd_dlast_o; // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_doe_o;   // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_dti_i;   // From u_iologic of emmc_iologic.v
wire                          emmc_cmd_dto_o;   // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_pp1_od0_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_cmd_stb_i;   // From u_iologic of emmc_iologic.v
wire                          emmc_dat_clk_vld_i;// From u_iologic of emmc_iologic.v
wire                          emmc_dat_clk_vld_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_crc_en_i;// From u_iologic of emmc_iologic.v
wire                          emmc_dat_crc_en_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_dc_en_o; // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_ddr_mode_i;// From u_iologic of emmc_iologic.v
wire                          emmc_dat_ddr_mode_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_dlast_i; // From u_iologic of emmc_iologic.v
wire                          emmc_dat_dlast_o; // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_doe_o;   // From u_serdes_top of emmc_serdes_top.v
wire        [SPI_WID-1:0]     emmc_dat_dti_i;   // From u_iologic of emmc_iologic.v
wire        [SPI_WID-1:0]     emmc_dat_dto_o;   // From u_serdes_top of emmc_serdes_top.v
wire        [1:0]             emmc_dat_io_width_i;// From u_iologic of emmc_iologic.v
wire        [1:0]             emmc_dat_io_width_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_pp1_od0_o;// From u_serdes_top of emmc_serdes_top.v
wire                          emmc_dat_stb_i;   // From u_iologic of emmc_iologic.v
wire                          emmc_memrd_req;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          emmc_memwr_req;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          emmc_req_done;    // From u_axi4_m of emmc_axi4_m.v
wire                          emmc_rx_ckn;      // From u_iologic of emmc_iologic.v
wire                          emmc_rx_ckp;      // From u_iologic of emmc_iologic.v
wire                          emmc_tx_ckn;      // From u_serdes_top of emmc_serdes_top.v
wire                          emmc_tx_ckp;      // From u_serdes_top of emmc_serdes_top.v
wire                          en_crc_rsp_type2; // From u_cmd_proc of emmc_cmd_proc.v
wire        [5:0]             info_rsp_b0;      // From u_cmd_proc of emmc_cmd_proc.v
wire        [31:0]            info_rsp_dat0;    // From u_cmd_proc of emmc_cmd_proc.v
wire        [31:0]            info_rsp_dat1;    // From u_cmd_proc of emmc_cmd_proc.v
wire        [31:0]            info_rsp_dat2;    // From u_cmd_proc of emmc_cmd_proc.v
wire        [31:0]            info_rsp_dat3;    // From u_cmd_proc of emmc_cmd_proc.v
wire                          int_csr;          // From u_csr of emmc_csr.v
wire                          rd_on_emty_error; // From u_apb_s of emmc_apb_s.v
wire                          rx_cmd_crc_ok;    // From u_serdes_top of emmc_serdes_top.v
wire        [BUS_WID-1:0]     rx_cmd_data;      // From u_serdes_top of emmc_serdes_top.v
wire                          rx_cmd_end;       // From u_serdes_top of emmc_serdes_top.v
wire                          rx_cmd_valid;     // From u_serdes_top of emmc_serdes_top.v
wire                          rx_pld_crc_ok;    // From u_serdes_top of emmc_serdes_top.v
wire        [BUS_WID-1:0]     rx_pld_data;      // From u_serdes_top of emmc_serdes_top.v
wire                          rx_pld_end;       // From u_serdes_top of emmc_serdes_top.v
wire                          rx_pld_valid;     // From u_serdes_top of emmc_serdes_top.v
wire                          rxfifo_rden;      // From u_apb_s of emmc_apb_s.v
wire                          tx_cmd_crc_en;    // From u_cmd_proc of emmc_cmd_proc.v
wire        [BUS_WID-1:0]     tx_cmd_data;      // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_cmd_dc_en;     // From u_cmd_proc of emmc_cmd_proc.v
wire        [2:0]             tx_cmd_dc_num;    // From u_cmd_proc of emmc_cmd_proc.v
wire        [1:0]             tx_cmd_last_byte; // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_cmd_pp1_od0;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_cmd_ready;     // From u_serdes_top of emmc_serdes_top.v
wire                          tx_cmd_valid;     // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_cmd_wr1_rd0;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_pld_crc_en;    // From u_cmd_proc of emmc_cmd_proc.v
wire        [BUS_WID-1:0]     tx_pld_data;      // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_pld_dc_en;     // From u_cmd_proc of emmc_cmd_proc.v
wire        [2:0]             tx_pld_dc_num;    // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_pld_ddr_mode;  // From u_cmd_proc of emmc_cmd_proc.v
wire        [1:0]             tx_pld_io_width;  // From u_cmd_proc of emmc_cmd_proc.v
wire        [1:0]             tx_pld_last_byte; // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_pld_pp1_od0;   // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_pld_ready;     // From u_serdes_top of emmc_serdes_top.v
wire                          tx_pld_valid;     // From u_cmd_proc of emmc_cmd_proc.v
wire                          tx_pld_wr1_rd0;   // From u_cmd_proc of emmc_cmd_proc.v
wire        [AXI4_DAT_WIDTH-1:0] txfifo_wdata;  // From u_apb_s of emmc_apb_s.v
wire                          txfifo_wren;      // From u_apb_s of emmc_apb_s.v
wire                          wr_on_full_error; // From u_apb_s of emmc_apb_s.v
// End of automatics


wire          [3*8-1:0]       debug_dat_line;
wire          [3*1-1:0]       debug_cmd_line;

wire                          main_rst_n /* synthesis syn_keep=1 */;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [1:0]           rst_n_sync    /* synthesis syn_preserve=1 */;
reg                           ip_core_rst_n /* synthesis syn_preserve=1 */;

assign emmc_rst_n_o = ~csr_emmc_rst;
assign int_o        = int_csr;

assign debug_dat_line[ 0+:8] = 8'hFF & io_dat_in;
assign debug_dat_line[ 8+:8] = 8'hFF & emmc_dat_o;
assign debug_dat_line[16+:8] = 8'hFF & emmc_dat_oe_o;

assign debug_cmd_line[ 0+:1] = io_cmd_in;
assign debug_cmd_line[ 1+:1] = emmc_cmd_o;
assign debug_cmd_line[ 2+:1] = emmc_cmd_oe_o;

assign main_rst_n = rst_n_sync[1];

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    rst_n_sync <= 2'h0;
    // End of automatics
  end
  else begin
    rst_n_sync <= {rst_n_sync[0],1'b1};
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge main_rst_n) begin
  if(~main_rst_n) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    ip_core_rst_n <= 1'h0;
    // End of automatics
  end
  else begin
    ip_core_rst_n <= ~csr_ip_core_rst;
  end
end //--always @(posedge clk_i or negedge main_rst_n)--

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
/*emmc_apb_s AUTO_TEMPLATE
(
 .EN_FIFO                               (0),
 .sck_src_i                             (clk_i),
 .sck_rst_n_i                           (main_rst_n),
 .rst_n_i                               (main_rst_n),
 .rxfifo_emty                           (1'b0),
 .txfifo_aful                           (1'b0),
 .apb_\(.*\)                            (s_apb_\1[]),
);*/

emmc_apb_s #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .DEVICE_FAMILY                         (DEVICE_FAMILY),
 .CLKDOMAIN                             (CLKDOMAIN),
 .EN_FULLADDR_DECODE                    (EN_FULLADDR_DECODE),
 .EN_FIFO                               (0),                     // Templated
 .REG_BASE_ADDR                         (REG_BASE_ADDR),
 .AXI4_LEN_WIDTH                        (AXI4_LEN_WIDTH),
 .AXI4_ADR_WIDTH                        (AXI4_ADR_WIDTH),
 .AXI4_DAT_WIDTH                        (AXI4_DAT_WIDTH),
 .AXI4_STB_WIDTH                        (AXI4_STB_WIDTH))
u_apb_s
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (main_rst_n),            // Templated
 .sck_src_i                             (clk_i),                 // Templated
 .sck_rst_n_i                           (main_rst_n),            // Templated
 .apb_psel_i                            (s_apb_psel_i),          // Templated
 .apb_penable_i                         (s_apb_penable_i),       // Templated
 .apb_pwrite_i                          (s_apb_pwrite_i),        // Templated
 .apb_paddr_i                           (s_apb_paddr_i[AXI4_ADR_WIDTH-1:0]), // Templated
 .apb_pwdata_i                          (s_apb_pwdata_i[AXI4_DAT_WIDTH-1:0]), // Templated
 .csr_rdat                              (csr_rdat[AXI4_DAT_WIDTH-1:0]),
 .rxfifo_emty                           (1'b0),                  // Templated
 .txfifo_aful                           (1'b0),                  // Templated
 // Outputs
 .apb_pready_o                          (s_apb_pready_o),        // Templated
 .apb_pslverr_o                         (s_apb_pslverr_o),       // Templated
 .apb_prdata_o                          (s_apb_prdata_o[AXI4_DAT_WIDTH-1:0]), // Templated
 .csr_wren                              (csr_wren[3:0]),
 .csr_wadr                              (csr_wadr[7:0]),
 .csr_wdat                              (csr_wdat[AXI4_DAT_WIDTH-1:0]),
 .csr_rden                              (csr_rden),
 .csr_radr                              (csr_radr[7:0]),
 .rxfifo_rden                           (rxfifo_rden),
 .txfifo_wdata                          (txfifo_wdata[AXI4_DAT_WIDTH-1:0]),
 .txfifo_wren                           (txfifo_wren),
 .bus_access_error                      (bus_access_error),
 .wr_on_full_error                      (wr_on_full_error),
 .rd_on_emty_error                      (rd_on_emty_error));

//--------------------------------------------------------------------------
//--- Data Interface Selection (AXI4 or AHB-Lite) ---
//--------------------------------------------------------------------------
generate
  if(DATA_INTERFACE == "AXI4") begin : gen_axi4_interface

    // Tie off unused AHB-Lite outputs
    assign m_ahbl_hsel_o      = 1'b0;
    assign m_ahbl_haddr_o     = {AXI4_ADR_WIDTH{1'b0}};
    assign m_ahbl_htrans_o    = 2'b00;  // HTRANS_IDLE
    assign m_ahbl_hwrite_o    = 1'b0;
    assign m_ahbl_hsize_o     = 3'b000;
    assign m_ahbl_hburst_o    = 3'b000;
    assign m_ahbl_hprot_o     = 4'b0000;
    assign m_ahbl_hmastlock_o = 1'b0;
    assign m_ahbl_hwdata_o    = {AXI4_DAT_WIDTH{1'b0}};

    /*emmc_axi4_m AUTO_TEMPLATE
    (
     .rst_n_i                               (ip_core_rst_n),
    );*/

    emmc_axi4_m #
    (/*AUTOINSTPARAM*/
     // Parameters
     .SIMULATION                            (SIMULATION),
     .DEVICE_FAMILY                         (DEVICE_FAMILY),
     .FIFO_IMPL                             (FIFO_IMPL),
     .MEM_IMPL                              (MEM_IMPL),
     .PIPE_IMPL                             (PIPE_IMPL),
     .CLKDOMAIN                             (CLKDOMAIN),
     .MIN_BLOCK_SIZE                        (MIN_BLOCK_SIZE),
     .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
     .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK),
     .FIFO_DEPTH                            (FIFO_DEPTH),
     .AXI4_TID_WIDTH                        (AXI4_TID_WIDTH),
     .AXI4_LEN_WIDTH                        (AXI4_LEN_WIDTH),
     .AXI4_ADR_WIDTH                        (AXI4_ADR_WIDTH),
     .AXI4_DAT_WIDTH                        (AXI4_DAT_WIDTH),
     .AXI4_STB_WIDTH                        (AXI4_STB_WIDTH))
    u_axi4_m
    (/*AUTOINST*/
     // Inputs
     .clk_i                                 (clk_i),
     .rst_n_i                               (ip_core_rst_n),         // Templated
     .m_axi4_awready_i                      (m_axi4_awready_i),
     .m_axi4_wready_i                       (m_axi4_wready_i),
     .m_axi4_bvalid_i                       (m_axi4_bvalid_i),
     .m_axi4_bid_i                          (m_axi4_bid_i[AXI4_TID_WIDTH-1:0]),
     .m_axi4_bresp_i                        (m_axi4_bresp_i[1:0]),
     .m_axi4_arready_i                      (m_axi4_arready_i),
     .m_axi4_rvalid_i                       (m_axi4_rvalid_i),
     .m_axi4_rid_i                          (m_axi4_rid_i[AXI4_TID_WIDTH-1:0]),
     .m_axi4_rdata_i                        (m_axi4_rdata_i[31:0]),
     .m_axi4_rresp_i                        (m_axi4_rresp_i[1:0]),
     .m_axi4_rlast_i                        (m_axi4_rlast_i),
     .csr_emmc_block_len                    (csr_emmc_block_len[3:0]),
     .csr_emmc_num_blocks                   (csr_emmc_num_blocks[15:0]),
     .csr_src_dst_addr                      (csr_src_dst_addr[31:0]),
     .emmc_memrd_req                        (emmc_memrd_req),
     .emmc_memwr_req                        (emmc_memwr_req),
     .cmd_proc_mem_rden                     (cmd_proc_mem_rden),
     .cmd_proc_mem_wdat                     (cmd_proc_mem_wdat[31:0]),
     .cmd_proc_mem_wren                     (cmd_proc_mem_wren),
     // Outputs
     .m_axi4_awvalid_o                      (m_axi4_awvalid_o),
     .m_axi4_awaddr_o                       (m_axi4_awaddr_o[AXI4_ADR_WIDTH-1:0]),
     .m_axi4_awlen_o                        (m_axi4_awlen_o[AXI4_LEN_WIDTH-1:0]),
     .m_axi4_awid_o                         (m_axi4_awid_o[AXI4_TID_WIDTH-1:0]),
     .m_axi4_awsize_o                       (m_axi4_awsize_o[2:0]),
     .m_axi4_awburst_o                      (m_axi4_awburst_o[1:0]),
     .m_axi4_wvalid_o                       (m_axi4_wvalid_o),
     .m_axi4_wdata_o                        (m_axi4_wdata_o[31:0]),
     .m_axi4_wstrb_o                        (m_axi4_wstrb_o[3:0]),
     .m_axi4_wlast_o                        (m_axi4_wlast_o),
     .m_axi4_bready_o                       (m_axi4_bready_o),
     .m_axi4_arvalid_o                      (m_axi4_arvalid_o),
     .m_axi4_araddr_o                       (m_axi4_araddr_o[AXI4_ADR_WIDTH-1:0]),
     .m_axi4_arlen_o                        (m_axi4_arlen_o[AXI4_LEN_WIDTH-1:0]),
     .m_axi4_arid_o                         (m_axi4_arid_o[AXI4_TID_WIDTH-1:0]),
     .m_axi4_arsize_o                       (m_axi4_arsize_o[2:0]),
     .m_axi4_arburst_o                      (m_axi4_arburst_o[1:0]),
     .m_axi4_rready_o                       (m_axi4_rready_o),
     .det_bus_wr_error                      (det_bus_wr_error),
     .det_bus_rd_error                      (det_bus_rd_error),
     .emmc_req_done                         (emmc_req_done),
     .cmd_proc_mem_avail                    (cmd_proc_mem_avail),
     .cmd_proc_mem_rdat                     (cmd_proc_mem_rdat[31:0]),
     .cmd_proc_mem_free                     (cmd_proc_mem_free));

  end // gen_axi4_interface

  else if(DATA_INTERFACE == "AHBL") begin : gen_ahbl_interface

    // Tie off unused AXI4 outputs
    assign m_axi4_awvalid_o = 1'b0;
    assign m_axi4_awaddr_o  = {AXI4_ADR_WIDTH{1'b0}};
    assign m_axi4_awlen_o   = {AXI4_LEN_WIDTH{1'b0}};
    assign m_axi4_awid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_awsize_o  = 3'b000;
    assign m_axi4_awburst_o = 2'b00;

    assign m_axi4_wvalid_o  = 1'b0;
    assign m_axi4_wdata_o   = 32'h0;
    assign m_axi4_wstrb_o   = 4'h0;
    assign m_axi4_wlast_o   = 1'b0;

    assign m_axi4_bready_o  = 1'b0;

    assign m_axi4_arvalid_o = 1'b0;
    assign m_axi4_araddr_o  = {AXI4_ADR_WIDTH{1'b0}};
    assign m_axi4_arlen_o   = {AXI4_LEN_WIDTH{1'b0}};
    assign m_axi4_arid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_arsize_o  = 3'b000;
    assign m_axi4_arburst_o = 2'b00;

    assign m_axi4_rready_o  = 1'b0;

    /*emmc_ahbl_m AUTO_TEMPLATE
    (
     .rst_n_i                               (ip_core_rst_n),
     .ahbl_\(.*\)                           (m_ahbl_\1[]),
    );*/

    emmc_ahbl_m #
    (/*AUTOINSTPARAM*/
     // Parameters
     .SIMULATION                            (SIMULATION),
     .DEVICE_FAMILY                         (DEVICE_FAMILY),
     .FIFO_IMPL                             (FIFO_IMPL),
     .MEM_IMPL                              (MEM_IMPL),
     .PIPE_IMPL                             (PIPE_IMPL),
     .CLKDOMAIN                             (CLKDOMAIN),
     .MIN_BLOCK_SIZE                        (MIN_BLOCK_SIZE),
     .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
     .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK),
     .FIFO_DEPTH                            (FIFO_DEPTH),
     .AXI4_TID_WIDTH                        (AXI4_TID_WIDTH),
     .AXI4_LEN_WIDTH                        (AXI4_LEN_WIDTH),
     .AXI4_ADR_WIDTH                        (AXI4_ADR_WIDTH),
     .AXI4_DAT_WIDTH                        (AXI4_DAT_WIDTH),
     .AXI4_STB_WIDTH                        (AXI4_STB_WIDTH))
    u_ahbl_m
    (/*AUTOINST*/
     // Inputs
     .clk_i                                 (clk_i),
     .rst_n_i                               (ip_core_rst_n),         // Templated
     .ahbl_hready_i                         (m_ahbl_hready_i),       // Templated
     .ahbl_hresp_i                          (m_ahbl_hresp_i),        // Templated
     .ahbl_hrdata_i                         (m_ahbl_hrdata_i[AXI4_DAT_WIDTH-1:0]), // Templated
     .csr_emmc_block_len                    (csr_emmc_block_len[3:0]),
     .csr_emmc_num_blocks                   (csr_emmc_num_blocks[15:0]),
     .csr_src_dst_addr                      (csr_src_dst_addr[31:0]),
     .emmc_memrd_req                        (emmc_memrd_req),
     .emmc_memwr_req                        (emmc_memwr_req),
     .cmd_proc_mem_rden                     (cmd_proc_mem_rden),
     .cmd_proc_mem_wdat                     (cmd_proc_mem_wdat[31:0]),
     .cmd_proc_mem_wren                     (cmd_proc_mem_wren),
     // Outputs
     .ahbl_hsel_o                           (m_ahbl_hsel_o),         // Templated
     .ahbl_haddr_o                          (m_ahbl_haddr_o[AXI4_ADR_WIDTH-1:0]), // Templated
     .ahbl_htrans_o                         (m_ahbl_htrans_o[1:0]),  // Templated
     .ahbl_hwrite_o                         (m_ahbl_hwrite_o),       // Templated
     .ahbl_hsize_o                          (m_ahbl_hsize_o[2:0]),   // Templated
     .ahbl_hburst_o                         (m_ahbl_hburst_o[2:0]),  // Templated
     .ahbl_hprot_o                          (m_ahbl_hprot_o[3:0]),   // Templated
     .ahbl_hmastlock_o                      (m_ahbl_hmastlock_o),    // Templated
     .ahbl_hwdata_o                         (m_ahbl_hwdata_o[AXI4_DAT_WIDTH-1:0]), // Templated
     .det_bus_wr_error                      (det_bus_wr_error),
     .det_bus_rd_error                      (det_bus_rd_error),
     .emmc_req_done                         (emmc_req_done),
     .cmd_proc_mem_avail                    (cmd_proc_mem_avail),
     .cmd_proc_mem_rdat                     (cmd_proc_mem_rdat[31:0]),
     .cmd_proc_mem_free                     (cmd_proc_mem_free));

  end // gen_ahbl_interface

  else begin : gen_invalid_interface
    // Tie off all bus interface outputs to prevent floating signals
    assign m_axi4_awvalid_o = 1'b0;
    assign m_axi4_awaddr_o  = {AXI4_ADR_WIDTH{1'b0}};
    assign m_axi4_awlen_o   = {AXI4_LEN_WIDTH{1'b0}};
    assign m_axi4_awid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_awsize_o  = 3'b000;
    assign m_axi4_awburst_o = 2'b00;
    assign m_axi4_wvalid_o  = 1'b0;
    assign m_axi4_wdata_o   = 32'h0;
    assign m_axi4_wstrb_o   = 4'h0;
    assign m_axi4_wlast_o   = 1'b0;
    assign m_axi4_bready_o  = 1'b0;
    assign m_axi4_arvalid_o = 1'b0;
    assign m_axi4_araddr_o  = {AXI4_ADR_WIDTH{1'b0}};
    assign m_axi4_arlen_o   = {AXI4_LEN_WIDTH{1'b0}};
    assign m_axi4_arid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_arsize_o  = 3'b000;
    assign m_axi4_arburst_o = 2'b00;
    assign m_axi4_rready_o  = 1'b0;

    assign m_ahbl_hsel_o      = 1'b0;
    assign m_ahbl_haddr_o     = {AXI4_ADR_WIDTH{1'b0}};
    assign m_ahbl_htrans_o    = 2'b00;
    assign m_ahbl_hwrite_o    = 1'b0;
    assign m_ahbl_hsize_o     = 3'b000;
    assign m_ahbl_hburst_o    = 3'b000;
    assign m_ahbl_hprot_o     = 4'b0000;
    assign m_ahbl_hmastlock_o = 1'b0;
    assign m_ahbl_hwdata_o    = {AXI4_DAT_WIDTH{1'b0}};

    // Tie off shared outputs to prevent floating
    assign det_bus_wr_error   = 1'b0;
    assign det_bus_rd_error   = 1'b0;
    assign emmc_req_done      = 1'b0;
    assign cmd_proc_mem_avail = 1'b0;
    assign cmd_proc_mem_rdat  = 32'h0;
    assign cmd_proc_mem_free  = 1'b0;

    // Generate compile-time error if invalid DATA_INTERFACE specified
    initial begin
      $error("Invalid DATA_INTERFACE parameter: %s. Must be \"AXI4\" or \"AHBL\"", DATA_INTERFACE);
    end
  end // gen_invalid_interface

  if(SIMULATION) begin : gen_sim
    initial begin
      if (MIN_BLOCK_SIZE > MAX_BLOCK_SIZE)
        $error("MIN_BLOCK_SIZE cannot exceed MAX_BLOCK_SIZE");
      if (MAX_BLOCK_SIZE > 16384)
        $error("MAX_BLOCK_SIZE cannot exceed 16KB");
      if (FIFO_DEPTH < (2*MAX_BLOCK_SIZE)/4)
        $error("FIFO_DEPTH too small for MAX_BLOCK_SIZE");
    end
  end // gen_sim

endgenerate

/*emmc_csr AUTO_TEMPLATE
(
 .rst_n_i                               (main_rst_n),
);*/

emmc_csr #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .USE_CLKDIV1                           (USE_CLKDIV1),
 .CLKDIV_WID                            (CLKDIV_WID),
 .DEFAULT_RATE                          (DEFAULT_RATE[CLKDIV_WID-1:0]),
 .EN_RSPTYP_DEC                         (EN_RSPTYP_DEC),
 .EN_AUTO_CMD                           (EN_AUTO_CMD),
 .EN_DDR_MODE                           (EN_DDR_MODE),
 .DEF_BLOCK_SIZE                        (DEF_BLOCK_SIZE),
 .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
 .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK),
 .TMR_WIDTH                             (TMR_WIDTH))
u_csr
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (main_rst_n),            // Templated
 .det_emmc_start                        (det_emmc_start),
 .det_emmc_done                         (det_emmc_done),
 .det_cmd_crc_err                       (det_cmd_crc_err),
 .det_pld_crc_err                       (det_pld_crc_err),
 .det_bus_wr_error                      (det_bus_wr_error),
 .det_bus_rd_error                      (det_bus_rd_error),
 .det_rsp_timeout                       (det_rsp_timeout),
 .det_dat_timeout                       (det_dat_timeout),
 .debug_dat_line                        (debug_dat_line[23:0]),
 .debug_cmd_line                        (debug_cmd_line[2:0]),
 .info_rsp_b0                           (info_rsp_b0[5:0]),
 .info_rsp_dat0                         (info_rsp_dat0[31:0]),
 .info_rsp_dat1                         (info_rsp_dat1[31:0]),
 .info_rsp_dat2                         (info_rsp_dat2[31:0]),
 .info_rsp_dat3                         (info_rsp_dat3[31:0]),
 .csr_wren                              (csr_wren[3:0]),
 .csr_wadr                              (csr_wadr[7:0]),
 .csr_wdat                              (csr_wdat[31:0]),
 .csr_rden                              (csr_rden),
 .csr_radr                              (csr_radr[7:0]),
 // Outputs
 .csr_clk_div                           (csr_clk_div[CLKDIV_WID-1:0]),
 .csr_emmc_pp1_od0                      (csr_emmc_pp1_od0),
 .csr_emmc_ddr_mode                     (csr_emmc_ddr_mode),
 .csr_emmc_io_width                     (csr_emmc_io_width[1:0]),
 .csr_emmc_send_select                  (csr_emmc_send_select),
 .csr_emmc_send_deselect                (csr_emmc_send_deselect),
 .csr_emmc_send_stop                    (csr_emmc_send_stop),
 .csr_emmc_block_len                    (csr_emmc_block_len[3:0]),
 .csr_emmc_num_blocks                   (csr_emmc_num_blocks[15:0]),
 .csr_emmc_cmd_idx                      (csr_emmc_cmd_idx[5:0]),
 .csr_emmc_rsp_typ                      (csr_emmc_rsp_typ[2:0]),
 .csr_emmc_cmd_arg                      (csr_emmc_cmd_arg[31:0]),
 .csr_emmc_cmd_boot                     (csr_emmc_cmd_boot),
 .csr_emmc_cmd_start                    (csr_emmc_cmd_start),
 .csr_src_dst_addr                      (csr_src_dst_addr[31:0]),
 .csr_cmd_timeout                       (csr_cmd_timeout[15:0]),
 .csr_dat_timeout                       (csr_dat_timeout[15:0]),
 .csr_emmc_rst                          (csr_emmc_rst),
 .csr_ip_core_rst                       (csr_ip_core_rst),
 .csr_rdat                              (csr_rdat[31:0]),
 .csr_rvld                              (csr_rvld),
 .int_csr                               (int_csr));

/*emmc_cmd_proc AUTO_TEMPLATE
(
 .rst_n_i                               (ip_core_rst_n),
);*/

emmc_cmd_proc #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .CLKDIV_WID                            (CLKDIV_WID),
 .BUS_WID                               (BUS_WID),
 .TMR_WIDTH                             (TMR_WIDTH),
 .EN_SPI_X4                             (EN_SPI_X4),
 .EN_SPI_X8                             (EN_SPI_X8),
 .MIN_BLOCK_SIZE                        (MIN_BLOCK_SIZE),
 .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
 .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK))
u_cmd_proc
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (ip_core_rst_n),         // Templated
 .csr_clk_div                           (csr_clk_div[CLKDIV_WID-1:0]),
 .csr_emmc_pp1_od0                      (csr_emmc_pp1_od0),
 .csr_emmc_ddr_mode                     (csr_emmc_ddr_mode),
 .csr_emmc_io_width                     (csr_emmc_io_width[1:0]),
 .csr_emmc_send_select                  (csr_emmc_send_select),
 .csr_emmc_send_deselect                (csr_emmc_send_deselect),
 .csr_emmc_send_stop                    (csr_emmc_send_stop),
 .csr_emmc_block_len                    (csr_emmc_block_len[3:0]),
 .csr_emmc_num_blocks                   (csr_emmc_num_blocks[15:0]),
 .csr_emmc_cmd_idx                      (csr_emmc_cmd_idx[5:0]),
 .csr_emmc_rsp_typ                      (csr_emmc_rsp_typ[2:0]),
 .csr_emmc_cmd_arg                      (csr_emmc_cmd_arg[31:0]),
 .csr_emmc_cmd_boot                     (csr_emmc_cmd_boot),
 .csr_emmc_cmd_start                    (csr_emmc_cmd_start),
 .csr_cmd_timeout                       (csr_cmd_timeout[15:0]),
 .csr_dat_timeout                       (csr_dat_timeout[15:0]),
 .emmc_req_done                         (emmc_req_done),
 .cmd_proc_mem_avail                    (cmd_proc_mem_avail),
 .cmd_proc_mem_rdat                     (cmd_proc_mem_rdat[BUS_WID-1:0]),
 .cmd_proc_mem_free                     (cmd_proc_mem_free),
 .tx_cmd_ready                          (tx_cmd_ready),
 .rx_cmd_valid                          (rx_cmd_valid),
 .rx_cmd_data                           (rx_cmd_data[BUS_WID-1:0]),
 .rx_cmd_crc_ok                         (rx_cmd_crc_ok),
 .rx_cmd_end                            (rx_cmd_end),
 .tx_pld_ready                          (tx_pld_ready),
 .rx_pld_valid                          (rx_pld_valid),
 .rx_pld_data                           (rx_pld_data[BUS_WID-1:0]),
 .rx_pld_crc_ok                         (rx_pld_crc_ok),
 .rx_pld_end                            (rx_pld_end),
 .emmc_tx_ckp                           (emmc_tx_ckp),
 .emmc_cmd_clk_vld_i                    (emmc_cmd_clk_vld_i),
 .emmc_cmd_clk_vld_o                    (emmc_cmd_clk_vld_o),
 .emmc_cmd_dc_en_o                      (emmc_cmd_dc_en_o),
 .emmc_dat_dti_i                        (emmc_dat_dti_i[0:0]),
 .emmc_dat_clk_vld_i                    (emmc_dat_clk_vld_i),
 .emmc_dat_dc_en_o                      (emmc_dat_dc_en_o),
 // Outputs
 .det_emmc_start                        (det_emmc_start),
 .det_emmc_done                         (det_emmc_done),
 .det_cmd_crc_err                       (det_cmd_crc_err),
 .det_pld_crc_err                       (det_pld_crc_err),
 .det_rsp_timeout                       (det_rsp_timeout),
 .det_dat_timeout                       (det_dat_timeout),
 .info_rsp_b0                           (info_rsp_b0[5:0]),
 .info_rsp_dat0                         (info_rsp_dat0[31:0]),
 .info_rsp_dat1                         (info_rsp_dat1[31:0]),
 .info_rsp_dat2                         (info_rsp_dat2[31:0]),
 .info_rsp_dat3                         (info_rsp_dat3[31:0]),
 .emmc_memrd_req                        (emmc_memrd_req),
 .emmc_memwr_req                        (emmc_memwr_req),
 .cmd_proc_mem_rden                     (cmd_proc_mem_rden),
 .cmd_proc_mem_wdat                     (cmd_proc_mem_wdat[BUS_WID-1:0]),
 .cmd_proc_mem_wren                     (cmd_proc_mem_wren),
 .tx_cmd_valid                          (tx_cmd_valid),
 .tx_cmd_wr1_rd0                        (tx_cmd_wr1_rd0),
 .tx_cmd_last_byte                      (tx_cmd_last_byte[1:0]),
 .tx_cmd_data                           (tx_cmd_data[BUS_WID-1:0]),
 .tx_cmd_dc_en                          (tx_cmd_dc_en),
 .tx_cmd_dc_num                         (tx_cmd_dc_num[2:0]),
 .tx_cmd_pp1_od0                        (tx_cmd_pp1_od0),
 .tx_cmd_crc_en                         (tx_cmd_crc_en),
 .tx_pld_valid                          (tx_pld_valid),
 .tx_pld_wr1_rd0                        (tx_pld_wr1_rd0),
 .tx_pld_ddr_mode                       (tx_pld_ddr_mode),
 .tx_pld_io_width                       (tx_pld_io_width[1:0]),
 .tx_pld_last_byte                      (tx_pld_last_byte[1:0]),
 .tx_pld_data                           (tx_pld_data[BUS_WID-1:0]),
 .tx_pld_dc_en                          (tx_pld_dc_en),
 .tx_pld_dc_num                         (tx_pld_dc_num[2:0]),
 .tx_pld_pp1_od0                        (tx_pld_pp1_od0),
 .tx_pld_crc_en                         (tx_pld_crc_en),
 .cmd_en_restart                        (cmd_en_restart),
 .dat_en_restart                        (dat_en_restart),
 .en_crc_rsp_type2                      (en_crc_rsp_type2),
 .cur_clk_div                           (cur_clk_div[CLKDIV_WID-1:0]));

/*emmc_iologic AUTO_TEMPLATE
(
 .rst_n_i                               (ip_core_rst_n),
);*/

emmc_iologic #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .USE_IO_PRIMITIVE                      (USE_IO_PRIMITIVE),
 .EN_DDR_MODE                           (EN_DDR_MODE),
 .EN_DDR_WIDE                           (EN_DDR_WIDE),
 .MAX_NUMLANE                           (MAX_NUMLANE),
 .SPI_WID                               (SPI_WID),
 .NUM_REG_IN                            (NUM_REG_IN),
 .EN_NEG_SAMPLE                         (EN_NEG_SAMPLE))
u_iologic
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (ip_core_rst_n),         // Templated
 .emmc_tx_ckp                           (emmc_tx_ckp),
 .emmc_tx_ckn                           (emmc_tx_ckn),
 .emmc_clk_out                          (emmc_clk_out),
 .emmc_cmd_clk_vld_o                    (emmc_cmd_clk_vld_o),
 .emmc_cmd_pp1_od0_o                    (emmc_cmd_pp1_od0_o),
 .emmc_cmd_crc_en_o                     (emmc_cmd_crc_en_o),
 .emmc_cmd_dc_en_o                      (emmc_cmd_dc_en_o),
 .emmc_cmd_dlast_o                      (emmc_cmd_dlast_o),
 .emmc_cmd_doe_o                        (emmc_cmd_doe_o),
 .emmc_cmd_dto_o                        (emmc_cmd_dto_o),
 .emmc_dat_clk_vld_o                    (emmc_dat_clk_vld_o),
 .emmc_dat_pp1_od0_o                    (emmc_dat_pp1_od0_o),
 .emmc_dat_crc_en_o                     (emmc_dat_crc_en_o),
 .emmc_dat_dc_en_o                      (emmc_dat_dc_en_o),
 .emmc_dat_dlast_o                      (emmc_dat_dlast_o),
 .emmc_dat_ddr_mode_o                   (emmc_dat_ddr_mode_o),
 .emmc_dat_io_width_o                   (emmc_dat_io_width_o[1:0]),
 .emmc_dat_doe_o                        (emmc_dat_doe_o),
 .emmc_dat_dto_o                        (emmc_dat_dto_o[SPI_WID-1:0]),
 .emmc_cmd_i                            (emmc_cmd_i),
 .emmc_dat_i                            (emmc_dat_i[MAX_NUMLANE-1:0]),
 .emmc_dat_ds_i                         (emmc_dat_ds_i),
 // Inouts
 .emmc_cmd_io                           (emmc_cmd_io),
 .emmc_dat_io                           (emmc_dat_io[MAX_NUMLANE-1:0]),
 // Outputs
 .emmc_rx_ckp                           (emmc_rx_ckp),
 .emmc_rx_ckn                           (emmc_rx_ckn),
 .emmc_cmd_clk_vld_i                    (emmc_cmd_clk_vld_i),
 .emmc_cmd_crc_en_i                     (emmc_cmd_crc_en_i),
 .emmc_cmd_dlast_i                      (emmc_cmd_dlast_i),
 .emmc_cmd_stb_i                        (emmc_cmd_stb_i),
 .emmc_cmd_dti_i                        (emmc_cmd_dti_i),
 .emmc_dat_clk_vld_i                    (emmc_dat_clk_vld_i),
 .emmc_dat_ddr_mode_i                   (emmc_dat_ddr_mode_i),
 .emmc_dat_crc_en_i                     (emmc_dat_crc_en_i),
 .emmc_dat_dlast_i                      (emmc_dat_dlast_i),
 .emmc_dat_io_width_i                   (emmc_dat_io_width_i[1:0]),
 .emmc_dat_stb_i                        (emmc_dat_stb_i),
 .emmc_dat_dti_i                        (emmc_dat_dti_i[SPI_WID-1:0]),
 .emmc_clk_o                            (emmc_clk_o),
 .emmc_cmd_o                            (emmc_cmd_o),
 .emmc_cmd_oe_o                         (emmc_cmd_oe_o),
 .io_cmd_in                             (io_cmd_in),
 .emmc_dat_o                            (emmc_dat_o[MAX_NUMLANE-1:0]),
 .emmc_dat_oe_o                         (emmc_dat_oe_o[MAX_NUMLANE-1:0]),
 .io_dat_in                             (io_dat_in[MAX_NUMLANE-1:0]));

/*emmc_serdes_top AUTO_TEMPLATE
(
 .rst_n_i                               (ip_core_rst_n),
);*/

emmc_serdes_top #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .USE_CLKDIV1                           (USE_CLKDIV1),
 .CLKDIV_WID                            (CLKDIV_WID),
 .DEFAULT_RATE                          (DEFAULT_RATE[CLKDIV_WID-1:0]),
 .EN_DDR_MODE                           (EN_DDR_MODE),
 .EN_DDR_WIDE                           (EN_DDR_WIDE),
 .MAX_NUMLANE                           (MAX_NUMLANE),
 .BUS_WID                               (BUS_WID),
 .SPI_WID                               (SPI_WID),
 .EN_SPI_X4                             (EN_SPI_X4),
 .EN_SPI_X8                             (EN_SPI_X8),
 .EN_DDR_X4                             (EN_DDR_X4),
 .EN_DDR_X8                             (EN_DDR_X8))
u_serdes_top
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (ip_core_rst_n),         // Templated
 .cur_clk_div                           (cur_clk_div[CLKDIV_WID-1:0]),
 .cmd_en_restart                        (cmd_en_restart),
 .dat_en_restart                        (dat_en_restart),
 .en_crc_rsp_type2                      (en_crc_rsp_type2),
 .tx_cmd_valid                          (tx_cmd_valid),
 .tx_cmd_wr1_rd0                        (tx_cmd_wr1_rd0),
 .tx_cmd_last_byte                      (tx_cmd_last_byte[1:0]),
 .tx_cmd_data                           (tx_cmd_data[BUS_WID-1:0]),
 .tx_cmd_dc_en                          (tx_cmd_dc_en),
 .tx_cmd_dc_num                         (tx_cmd_dc_num[2:0]),
 .tx_cmd_pp1_od0                        (tx_cmd_pp1_od0),
 .tx_cmd_crc_en                         (tx_cmd_crc_en),
 .tx_pld_valid                          (tx_pld_valid),
 .tx_pld_wr1_rd0                        (tx_pld_wr1_rd0),
 .tx_pld_ddr_mode                       (tx_pld_ddr_mode),
 .tx_pld_io_width                       (tx_pld_io_width[1:0]),
 .tx_pld_last_byte                      (tx_pld_last_byte[1:0]),
 .tx_pld_data                           (tx_pld_data[BUS_WID-1:0]),
 .tx_pld_dc_en                          (tx_pld_dc_en),
 .tx_pld_dc_num                         (tx_pld_dc_num[2:0]),
 .tx_pld_pp1_od0                        (tx_pld_pp1_od0),
 .tx_pld_crc_en                         (tx_pld_crc_en),
 .emmc_rx_ckp                           (emmc_rx_ckp),
 .emmc_rx_ckn                           (emmc_rx_ckn),
 .emmc_cmd_clk_vld_i                    (emmc_cmd_clk_vld_i),
 .emmc_cmd_crc_en_i                     (emmc_cmd_crc_en_i),
 .emmc_cmd_dlast_i                      (emmc_cmd_dlast_i),
 .emmc_cmd_stb_i                        (emmc_cmd_stb_i),
 .emmc_cmd_dti_i                        (emmc_cmd_dti_i),
 .emmc_dat_clk_vld_i                    (emmc_dat_clk_vld_i),
 .emmc_dat_ddr_mode_i                   (emmc_dat_ddr_mode_i),
 .emmc_dat_crc_en_i                     (emmc_dat_crc_en_i),
 .emmc_dat_dlast_i                      (emmc_dat_dlast_i),
 .emmc_dat_io_width_i                   (emmc_dat_io_width_i[1:0]),
 .emmc_dat_stb_i                        (emmc_dat_stb_i),
 .emmc_dat_dti_i                        (emmc_dat_dti_i[SPI_WID-1:0]),
 // Outputs
 .tx_cmd_ready                          (tx_cmd_ready),
 .rx_cmd_valid                          (rx_cmd_valid),
 .rx_cmd_data                           (rx_cmd_data[BUS_WID-1:0]),
 .rx_cmd_crc_ok                         (rx_cmd_crc_ok),
 .rx_cmd_end                            (rx_cmd_end),
 .tx_pld_ready                          (tx_pld_ready),
 .rx_pld_valid                          (rx_pld_valid),
 .rx_pld_data                           (rx_pld_data[BUS_WID-1:0]),
 .rx_pld_crc_ok                         (rx_pld_crc_ok),
 .rx_pld_end                            (rx_pld_end),
 .emmc_tx_ckp                           (emmc_tx_ckp),
 .emmc_tx_ckn                           (emmc_tx_ckn),
 .emmc_clk_out                          (emmc_clk_out),
 .emmc_cmd_clk_vld_o                    (emmc_cmd_clk_vld_o),
 .emmc_cmd_pp1_od0_o                    (emmc_cmd_pp1_od0_o),
 .emmc_cmd_crc_en_o                     (emmc_cmd_crc_en_o),
 .emmc_cmd_dc_en_o                      (emmc_cmd_dc_en_o),
 .emmc_cmd_dlast_o                      (emmc_cmd_dlast_o),
 .emmc_cmd_doe_o                        (emmc_cmd_doe_o),
 .emmc_cmd_dto_o                        (emmc_cmd_dto_o),
 .emmc_dat_clk_vld_o                    (emmc_dat_clk_vld_o),
 .emmc_dat_pp1_od0_o                    (emmc_dat_pp1_od0_o),
 .emmc_dat_crc_en_o                     (emmc_dat_crc_en_o),
 .emmc_dat_dc_en_o                      (emmc_dat_dc_en_o),
 .emmc_dat_dlast_o                      (emmc_dat_dlast_o),
 .emmc_dat_ddr_mode_o                   (emmc_dat_ddr_mode_o),
 .emmc_dat_io_width_o                   (emmc_dat_io_width_o[1:0]),
 .emmc_dat_doe_o                        (emmc_dat_doe_o),
 .emmc_dat_dto_o                        (emmc_dat_dto_o[SPI_WID-1:0]));


endmodule //--emmc_top--
`endif // __RTL_MODULE__EMMC_TOP__
