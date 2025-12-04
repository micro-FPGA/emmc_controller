// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__LSCC_EMMC_CONTROLLER__
`define __RTL_MODULE__LSCC_EMMC_CONTROLLER__
//==========================================================================
// Module : lscc_emmc_controller
//==========================================================================
module lscc_emmc_controller #

( //--begin_param--
//----------------------------
// Parameters
// User Must Configure the IP Using
// Radiant IP Generation Wizard
//----------------------------
 parameter                          SIMULATION          = 0
,parameter                          DEVICE_FAMILY       = "LAV-AT"
,parameter                          FIFO_IMPL           = "PMI"             // "PMI"/"pmi" or "RTL"/"rtl" or "REG"/"reg"
,parameter                          MEM_IMPL            = "EBR"             // "EBR" or "LUT" or "HARD_IP"
,parameter                          CLKI_FREQ           = 100.0             // system clock (clk_i) frequency - 200 MHz max

,parameter                          USE_IO_PRIMITIVE    = 1

,parameter                          USE_CLKDIV1         = 0
,parameter                          CLKDIV_WID          = 8            // must be able to generate 400KHz,
                                                                       // (e.g 200MHz input clock divided by (2*250 pulse width) = 400 KHz)
,parameter    [CLKDIV_WID-1:0]      SPI_SCKDIV          = {{(CLKDIV_WID-1){1'b0}},1'b1}   // default clock divider

,parameter                          EN_DDR_MODE         = 0
,parameter                          EN_DDR_WIDE         = 0

,parameter                          MAX_NUMLANE         = 8            // [1,4,8]
,parameter                          BUS_WID             = 32
,parameter                          SPI_WID             = (EN_DDR_MODE && EN_DDR_WIDE)? 2*MAX_NUMLANE : MAX_NUMLANE

,parameter                          EN_SPI_X4           = (MAX_NUMLANE >=  4)? 1 : 0
,parameter                          EN_SPI_X8           = (MAX_NUMLANE >=  8)? 1 : 0
,parameter                          EN_DDR_X4           = (MAX_NUMLANE >=  4)? EN_DDR_MODE : 0
,parameter                          EN_DDR_X8           = (MAX_NUMLANE >=  8)? EN_DDR_MODE : 0


,parameter                          EN_FULLADDR_DECODE  = 0
,parameter                          CSR_INTERFACE       = "APB"
,parameter                          DATA_INTERFACE      = "AXI4"
,parameter                          REG_BASE_ADDR       = 32'h0000_0000       // Register block base address
,parameter                          AXI4_TID_WIDTH      = 1
,parameter                          AXI4_LEN_WIDTH      = 8
,parameter                          AXI4_ADR_WIDTH      = 32
,parameter                          AXI4_DAT_WIDTH      = 32
,parameter                          AXI4_STB_WIDTH      = ((AXI4_DAT_WIDTH + 7) / 8)

,parameter                          DEF_BLOCK_SIZE      = 512
,parameter                          MIN_BLOCK_SIZE      = 512
,parameter                          MAX_BLOCK_SIZE      = 4096
,parameter                          MAX_NUM_BLOCK       = 65536
,parameter                          FIFO_DEPTH          = ((2*MAX_BLOCK_SIZE)/4)
,parameter                          TMR_WIDTH           = 8

) //--end_param--

( //--begin_ports--

// System clock and reset
 input                              clk_i
,input                              rst_n_i

// eMMC IO interface
,output wire                        emmc_clk_o

,inout                              emmc_cmd_io         // command signal bidirectional
,inout        [MAX_NUMLANE-1:0]     emmc_dat_io         // data signal bidirectional

,output wire                        emmc_rst_n_o        // reset output - optional
// eMMC data strobe signal - optional (for HS200 and HS400)
,input                              emmc_dat_ds_i       // data strobe input

// Optional - IO control signals
,input                              emmc_cmd_i          // command input
,output wire                        emmc_cmd_o          // command output
,output wire                        emmc_cmd_oe_o       // command output enable

,input        [MAX_NUMLANE-1:0]     emmc_dat_i          // data input
,output wire  [MAX_NUMLANE-1:0]     emmc_dat_o          // data output
,output wire  [MAX_NUMLANE-1:0]     emmc_dat_oe_o       // data output enable

// interrupt signal
,output wire                        int_o               // interrupt signal

// ----------------------------------------------------
// AXI4 Manager interface
,input                              m_axi4_awready_i
,output wire                        m_axi4_awvalid_o
,output wire  [AXI4_ADR_WIDTH-1:0]  m_axi4_awaddr_o
,output wire  [AXI4_LEN_WIDTH-1:0]  m_axi4_awlen_o
,output wire  [AXI4_TID_WIDTH-1:0]  m_axi4_awid_o
,output wire  [2:0]                 m_axi4_awsize_o
,output wire  [1:0]                 m_axi4_awburst_o
,output wire  [2:0]                 m_axi4_awprot_o

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
,output wire  [2:0]                 m_axi4_arprot_o

,output wire                        m_axi4_rready_o
,input                              m_axi4_rvalid_i
,input        [AXI4_TID_WIDTH-1:0]  m_axi4_rid_i
,input        [31:0]                m_axi4_rdata_i
,input        [1:0]                 m_axi4_rresp_i
,input                              m_axi4_rlast_i

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
// APB interface
,input                              s_apb_psel_i
,input                              s_apb_penable_i
,input                              s_apb_pwrite_i
,input        [AXI4_ADR_WIDTH-1:0]  s_apb_paddr_i
,input        [AXI4_DAT_WIDTH-1:0]  s_apb_pwdata_i

,output wire                        s_apb_pready_o
,output wire                        s_apb_pslverr_o
,output wire  [AXI4_DAT_WIDTH-1:0]  s_apb_prdata_o

); //--end_ports--


//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                          NUM_REG_IN          = 1;            // IO logic pipeline
localparam                          EN_RSPTYP_DEC       = 1;            // enable response type decoding
localparam                          EN_AUTO_CMD         = 0;            // enable generation of some commands via trigger


//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

/*AUTOREGINPUT*/

/*AUTOWIRE*/
wire                                io_cmd_in;          // data input - for debug
wire          [MAX_NUMLANE-1:0]     io_dat_in;          // data input - for debug

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------

assign m_axi4_awprot_o = 3'd0; // unused
assign m_axi4_arprot_o = 3'd0; // unused

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
emmc_top #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .DEVICE_FAMILY                         (DEVICE_FAMILY),
 .FIFO_IMPL                             (FIFO_IMPL),
 .MEM_IMPL                              (MEM_IMPL),
 .USE_IO_PRIMITIVE                      (USE_IO_PRIMITIVE),
 .USE_CLKDIV1                           (USE_CLKDIV1),
 .CLKDIV_WID                            (CLKDIV_WID),
 .SPI_SCKDIV                            (SPI_SCKDIV[CLKDIV_WID-1:0]),
 .EN_DDR_MODE                           (EN_DDR_MODE),
 .EN_DDR_WIDE                           (EN_DDR_WIDE),
 .MAX_NUMLANE                           (MAX_NUMLANE),
 .BUS_WID                               (BUS_WID),
 .SPI_WID                               (SPI_WID),
 .EN_SPI_X4                             (EN_SPI_X4),
 .EN_SPI_X8                             (EN_SPI_X8),
 .EN_DDR_X4                             (EN_DDR_X4),
 .EN_DDR_X8                             (EN_DDR_X8),
 .NUM_REG_IN                            (NUM_REG_IN),
 .EN_RSPTYP_DEC                         (EN_RSPTYP_DEC),
 .EN_AUTO_CMD                           (EN_AUTO_CMD),
 .DEF_BLOCK_SIZE                        (DEF_BLOCK_SIZE),
 .MIN_BLOCK_SIZE                        (MIN_BLOCK_SIZE),
 .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
 .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK),
 .FIFO_DEPTH                            (FIFO_DEPTH),
 .TMR_WIDTH                             (TMR_WIDTH),
 .EN_FULLADDR_DECODE                    (EN_FULLADDR_DECODE),
 .DATA_INTERFACE                        (DATA_INTERFACE),
 .REG_BASE_ADDR                         (REG_BASE_ADDR),
 .AXI4_TID_WIDTH                        (AXI4_TID_WIDTH),
 .AXI4_LEN_WIDTH                        (AXI4_LEN_WIDTH),
 .AXI4_ADR_WIDTH                        (AXI4_ADR_WIDTH),
 .AXI4_DAT_WIDTH                        (AXI4_DAT_WIDTH),
 .AXI4_STB_WIDTH                        (AXI4_STB_WIDTH))
u_emmc_top
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (rst_n_i),
 .emmc_cmd_i                            (emmc_cmd_i),
 .emmc_dat_i                            (emmc_dat_i[MAX_NUMLANE-1:0]),
 .emmc_dat_ds_i                         (emmc_dat_ds_i),
 .s_apb_psel_i                          (s_apb_psel_i),
 .s_apb_penable_i                       (s_apb_penable_i),
 .s_apb_pwrite_i                        (s_apb_pwrite_i),
 .s_apb_paddr_i                         (s_apb_paddr_i[AXI4_ADR_WIDTH-1:0]),
 .s_apb_pwdata_i                        (s_apb_pwdata_i[AXI4_DAT_WIDTH-1:0]),
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
 .m_ahbl_hready_i                       (m_ahbl_hready_i),
 .m_ahbl_hresp_i                        (m_ahbl_hresp_i),
 .m_ahbl_hrdata_i                       (m_ahbl_hrdata_i[AXI4_DAT_WIDTH-1:0]),
 // Inouts
 .emmc_cmd_io                           (emmc_cmd_io),
 .emmc_dat_io                           (emmc_dat_io[MAX_NUMLANE-1:0]),
 // Outputs
 .emmc_clk_o                            (emmc_clk_o),
 .emmc_cmd_o                            (emmc_cmd_o),
 .emmc_cmd_oe_o                         (emmc_cmd_oe_o),
 .io_cmd_in                             (io_cmd_in),
 .emmc_dat_o                            (emmc_dat_o[MAX_NUMLANE-1:0]),
 .emmc_dat_oe_o                         (emmc_dat_oe_o[MAX_NUMLANE-1:0]),
 .io_dat_in                             (io_dat_in[MAX_NUMLANE-1:0]),
 .emmc_rst_n_o                          (emmc_rst_n_o),
 .int_o                                 (int_o),
 .s_apb_pready_o                        (s_apb_pready_o),
 .s_apb_pslverr_o                       (s_apb_pslverr_o),
 .s_apb_prdata_o                        (s_apb_prdata_o[AXI4_DAT_WIDTH-1:0]),
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
 .m_ahbl_hsel_o                         (m_ahbl_hsel_o),
 .m_ahbl_haddr_o                        (m_ahbl_haddr_o[AXI4_ADR_WIDTH-1:0]),
 .m_ahbl_htrans_o                       (m_ahbl_htrans_o[1:0]),
 .m_ahbl_hwrite_o                       (m_ahbl_hwrite_o),
 .m_ahbl_hsize_o                        (m_ahbl_hsize_o[2:0]),
 .m_ahbl_hburst_o                       (m_ahbl_hburst_o[2:0]),
 .m_ahbl_hprot_o                        (m_ahbl_hprot_o[3:0]),
 .m_ahbl_hmastlock_o                    (m_ahbl_hmastlock_o),
 .m_ahbl_hwdata_o                       (m_ahbl_hwdata_o[AXI4_DAT_WIDTH-1:0]));



endmodule //--lscc_emmc_controller--
`endif // __RTL_MODULE__LSCC_EMMC_CONTROLLER__

//--------------------------------------------------------------------------
// Local Variables:
// verilog-library-directories: (".")
// verilog-library-files: ()
// End:
//--------------------------------------------------------------------------
