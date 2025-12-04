// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__TB_TOP__
`define __RTL_MODULE__TB_TOP__
`timescale 1ns / 1ps

`ifndef MODELSIM
  `define MODELSIM
`endif
`include "tb_common.v"
// TB models
`include "apb_mst_model.v"
`include "axi_mem_model.v"
`include "ahbl_mem_model.v"
`include "mdl_emmc.v"
//==========================================================================
// Module : tb_top
//==========================================================================
module tb_top #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          SIMULATION = 1

) //--end_param--

( //--begin_ports--

); //--end_ports--

// -----------------------------------------
// initialize TB reset and message counters
`TB_MAIN_RESET(tb_clk,tb_rst_n)
// Default TB clock - 50 MHz
`CLOCK_GENERATOR(tb_clk,20)
// message counter reporting task
`TB_REPORT_TASK
// -----------------------------------------

//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
// When DUT_INST_NAME is defined, IP was generated via Radiant - use generated params
// When DUT_INST_NAME is NOT defined, use standalone defaults for direct RTL simulation
`ifdef DUT_INST_NAME
  `include "dut_params.v"
`else
  // Standalone simulation defaults
  localparam                          DEVICE_FAMILY       = "LAV-AT";
  localparam                          AXI4_TID_WIDTH      = 1;
  localparam                          EN_DDR_MODE         = 0;
  localparam                          MAX_NUMLANE         = 8;
  localparam                          DEF_BLOCK_SIZE      = 512;
  localparam                          MIN_BLOCK_SIZE      = 512;
  localparam                          MAX_BLOCK_SIZE      = 1024;
  localparam                          MAX_NUM_BLOCK       = 32;
  localparam                          CSR_INTERFACE       = "APB";
  localparam                          DATA_INTERFACE      = "AXI4";
  localparam                          EN_FULLADDR_DECODE  = 0;
  localparam                          REG_BASE_ADDR       = 32'h00000000;
  localparam                          FIFO_DEPTH          = 512;
  localparam                          MEM_IMPL            = "HARD_IP";
  localparam                          CLKI_FREQ           = 100.0;
  localparam                          CLKDIV_WID          = 7;
  localparam                          SPI_SCKDIV          = 125;
  localparam                          USE_CLKDIV1         = 1;
  localparam                          USE_IO_PRIMITIVE    = 1;
`endif

`ifndef DEVICE_ADDR
  `define DEVICE_ADDR                         16'hBCDA
`endif

`define EMMC_ID_ADDR                          10'h000
`define EMMC_INT_ENA_ADDR                     10'h004
`define EMMC_CFG0_ADDR                        10'h008
`define EMMC_CFG1_ADDR                        10'h00C

`define EMMC_INFO_STS_ADDR                    10'h100
`define EMMC_INT_STS_ADDR                     10'h104
`define EMMC_RESP_D0_ADDR                     10'h108
`define EMMC_RESP_D1_ADDR                     10'h10C
`define EMMC_RESP_D2_ADDR                     10'h110
`define EMMC_RESP_D3_ADDR                     10'h114
`define EMMC_RESP_D4_ADDR                     10'h118

`define EMMC_SOFTRST_ADDR                     10'h200
`define EMMC_INT_SET_ADDR                     10'h204
`define EMMC_SRC_DST_ADDR                     10'h208
`define EMMC_CTRL0_ADDR                       10'h20C
`define EMMC_CTRL1_ADDR                       10'h210
`define EMMC_CTRL2_ADDR                       10'h214
`define EMMC_TXFIFO_ADDR                      10'h218
`define EMMC_RXFIFO_ADDR                      10'h21C

`define AXI4_INCR                             1'b1
`define AXI4_FIXED                            1'b0

`define EMMC_CSR_ADDR(REG_OFFSET)             (REG_BASE_ADDR+({10{1'b1}} & REG_OFFSET))

`define APB_RD32(ADDR,DATA)                   tb_top.u_apb_m.apb_rd(`EMMC_CSR_ADDR(ADDR),0,0,DATA)
`define APB_WR32(ADDR,DATA)                   tb_top.u_apb_m.apb_wr(`EMMC_CSR_ADDR(ADDR),DATA)
`define APB_RD32_MULT(ADDR,DATA,BCNT)         tb_top.u_apb_m.apb_rd_multiple(`EMMC_CSR_ADDR(ADDR),DATA,BCNT)
`define APB_WR32_MULT(ADDR,DATA,BCNT)         tb_top.u_apb_m.apb_wr_multiple(`EMMC_CSR_ADDR(ADDR),DATA,BCNT)


`ifdef ENABLE_BUS_DEBUG
localparam                        APB_BFM_MSGS_ON = 1;
`else
localparam                        APB_BFM_MSGS_ON = 0;
`endif

localparam                        CLKI_PERIOD = (1000.0/CLKI_FREQ);


//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
/*AUTOREGINPUT*/
/*AUTOWIRE*/
reg                                 clk_i;
reg                                 rst_n_i;
reg                                 emmc_clk_dly  ;

tri1                                emmc_cmd_io   ;     // command signal bidirectional
tri1          [7:0]                 emmc_dat_io   ;     // data signal bidirectional

wire                                emmc_clk_o    ;
wire                                emmc_rst_n_o  ;     // reset output - optional
wire                                emmc_dat_ds_i ;     // data strobe input
wire                                emmc_cmd_i    ;     // command input
wire                                emmc_cmd_o    ;     // command output
wire                                emmc_cmd_oe_o ;     // command output enable
wire          [MAX_NUMLANE-1:0]     emmc_dat_i    ;     // data input
wire          [MAX_NUMLANE-1:0]     emmc_dat_o    ;     // data output
wire          [MAX_NUMLANE-1:0]     emmc_dat_oe_o ;     // data output enable

wire                                int_o;

wire                                m_axi4_awvalid_o;
wire                                m_axi4_awready_i;
wire        [AXI4_TID_WIDTH-1:0]    m_axi4_awid_o;
wire        [31:0]                  m_axi4_awaddr_o;
wire        [1:0]                   m_axi4_awburst_o;
wire        [7:0]                   m_axi4_awlen_o;
wire        [2:0]                   m_axi4_awsize_o;
wire        [2:0]                   m_axi4_awprot_o;

wire                                m_axi4_wvalid_o;
wire                                m_axi4_wready_i;
wire        [31:0]                  m_axi4_wdata_o;
wire        [3:0]                   m_axi4_wstrb_o;
wire                                m_axi4_wlast_o;

wire                                m_axi4_bvalid_i;
wire                                m_axi4_bready_o;
wire        [AXI4_TID_WIDTH-1:0]    m_axi4_bid_i;
wire        [1:0]                   m_axi4_bresp_i;

wire                                m_axi4_arvalid_o;
wire                                m_axi4_arready_i;
wire        [AXI4_TID_WIDTH-1:0]    m_axi4_arid_o;
wire        [31:0]                  m_axi4_araddr_o;
wire        [1:0]                   m_axi4_arburst_o;
wire        [7:0]                   m_axi4_arlen_o;
wire        [2:0]                   m_axi4_arsize_o;
wire        [2:0]                   m_axi4_arprot_o;

wire                                m_axi4_rvalid_i;
wire                                m_axi4_rready_o;
wire        [AXI4_TID_WIDTH-1:0]    m_axi4_rid_i;
wire        [31:0]                  m_axi4_rdata_i;
wire                                m_axi4_rlast_i;
wire        [1:0]                   m_axi4_rresp_i;

wire                                m_ahbl_hsel_o;
wire        [31:0]                  m_ahbl_haddr_o;
wire        [1:0]                   m_ahbl_htrans_o;
wire                                m_ahbl_hwrite_o;
wire        [2:0]                   m_ahbl_hsize_o;
wire        [2:0]                   m_ahbl_hburst_o;
wire        [3:0]                   m_ahbl_hprot_o;
wire                                m_ahbl_hmastlock_o;
wire        [31:0]                  m_ahbl_hwdata_o;

wire                                m_ahbl_hready_i;
wire                                m_ahbl_hresp_i;
wire        [31:0]                  m_ahbl_hrdata_i;

wire                                s_apb_psel_i;
wire                                s_apb_penable_i;
wire                                s_apb_pwrite_i;
wire        [31:0]                  s_apb_paddr_i;
wire        [31:0]                  s_apb_pwdata_i;

wire                                s_apb_pready_o;
wire                                s_apb_pslverr_o;
wire        [31:0]                  s_apb_prdata_o;


//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg         [31:0]                  bus_addr;
reg         [31:0]                  bus_wdat;
reg         [31:0]                  bus_rdat;
reg         [15:0]                  sck_pulse_width;
reg         [5*32-1:0]              rsp_dat;


genvar i;
generate
  if(USE_IO_PRIMITIVE) begin : gen_io
    assign emmc_cmd_i    = emmc_cmd_io;
    assign emmc_cmd_o    = 1'b0;
    assign emmc_cmd_oe_o = 1'b0;

    assign emmc_dat_i    = emmc_dat_io;
    assign emmc_dat_o    = {MAX_NUMLANE{1'b0}};
    assign emmc_dat_oe_o = {MAX_NUMLANE{1'b0}};
    assign emmc_dat_ds_i = 1'b0; // TODO: used in DDR mode
  end // gen_io
  else begin : gen_no_io
    assign emmc_cmd_i  = emmc_cmd_io;
    assign emmc_cmd_io = (emmc_cmd_oe_o)? emmc_cmd_o : 1'bz;

    assign emmc_dat_i     = emmc_dat_io;
    assign emmc_dat_ds_i  = 1'b0; // TODO: used in DDR mode
    for(i=0; i<MAX_NUMLANE; i=i+1) begin : gen_dt
      assign emmc_dat_io[i+0] = (emmc_dat_oe_o[i])? emmc_dat_o[i+0] : 1'bz;
    end // gen_dt
  end // gen_no_io
endgenerate


// ----------------------------------------
// System Clock and Reset
`CLOCK_GENERATOR(clk_i,CLKI_PERIOD)
always @* begin
  rst_n_i = tb_rst_n;
end //--always @*--
// ----------------------------------------

// Simulation timeout
initial begin
  wait(test_en);
  case(SPI_SCKDIV)
    0       : begin
      `TIMED_STOP(300000,clk_i)
    end
    default : begin
      `TIMED_STOP(((SPI_SCKDIV*100000)+300000),clk_i)
    end
  endcase
end

`include "tb_util_task.v"

//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  emmc_clk_dly = #2 emmc_clk_o;
end //--always @*--

// ------------------------------------------------------------------------------------------------------------
// Main Test Sequence
// ------------------------------------------------------------------------------------------------------------
initial begin
  bus_addr = 32'd0;
  bus_wdat = 32'd0;
  bus_rdat = 32'd0;
  sck_pulse_width = 16'd1;

  wait(test_en);
  wait(rst_n_i == 1'b1);

  // Target Reset
  tgt_reset;

  set_emmc_clk_io_config(0.4,EMMC_SDR_MODE,EMMC_IO_WIDTH_X1,EMMC_IO_DRIVE_OD0); // SCK Freq, DDR_MOD, IO_WIDTH, IO_DRIVE

  emmc_cmd_go_idle;

  emmc_cmd_send_op_cond;

  emmc_cmd_all_send_cid;

  emmc_cmd_set_relative_addr(`DEVICE_ADDR);

  set_emmc_clk_io_config(5,EMMC_SDR_MODE,EMMC_IO_WIDTH_X1,EMMC_IO_DRIVE_PP1); // SCK Freq, DDR_MOD, IO_WIDTH, IO_DRIVE

  emmc_cmd_send_status(`DEVICE_ADDR);

  emmc_cmd_send_csd(`DEVICE_ADDR);

  emmc_cmd_send_cid(`DEVICE_ADDR);

  set_emmc_clk_io_config(25,EMMC_SDR_MODE,EMMC_IO_WIDTH_X1,EMMC_IO_DRIVE_PP1); // SCK Freq, DDR_MOD, IO_WIDTH, IO_DRIVE

  emmc_cmd_send_csd(`DEVICE_ADDR);

  emmc_cmd_send_cid(`DEVICE_ADDR);

  set_emmc_clk_io_config(50,EMMC_SDR_MODE,EMMC_IO_WIDTH_X1,EMMC_IO_DRIVE_PP1); // SCK Freq, DDR_MOD, IO_WIDTH, IO_DRIVE

  emmc_cmd_send_csd(`DEVICE_ADDR);

  emmc_cmd_send_cid(`DEVICE_ADDR);

  emmc_cmd_select_deselect_card(`DEVICE_ADDR);

  bus_addr = 32'hA000_0000;
  emmc_cmd_send_ext_csd(bus_addr);

  emmc_cmd_set_block_length((1 << BLKLEN_512B));
  emmc_cmd_set_block_count(1);

  // Write-Read in x1
  bus_addr = 32'hA000_1000; // get data from this location
  emmc_cmd_write_block(`DEVICE_ADDR,bus_addr,BLKLEN_512B, 16'd1);

  bus_addr = 32'hA000_2000; // send data to this location
  emmc_cmd_read_block(`DEVICE_ADDR,bus_addr,BLKLEN_512B, 16'd1);

  `TB_MEM_COMPARE((16'h1000 >> 2),(16'h2000 >> 2),128);

  // Write-Read in x4
  emmc_cmd_switch(SWITCH_CMD_WR_BYTE, EXT_CSD_BUS_WIDTH_IDX, BUS_WIDTH_4BIT, CMD_SET_STANDARD);   // index=183 (BUS_WIDTH), value=0x02 (4-bit SDR)

  set_emmc_clk_io_config(50,EMMC_SDR_MODE,EMMC_IO_WIDTH_X4,EMMC_IO_DRIVE_PP1); // SCK Freq, DDR_MOD, IO_WIDTH, IO_DRIVE

  bus_addr = 32'hA000_3000; // get data from this location
  emmc_cmd_write_block(`DEVICE_ADDR,bus_addr,BLKLEN_512B, 16'd1);

  bus_addr = 32'hA000_4000; // send data to this location
  emmc_cmd_read_block(`DEVICE_ADDR,bus_addr,BLKLEN_512B, 16'd1);

  `TB_MEM_COMPARE((16'h1000 >> 2),(16'h2000 >> 2),128);

  // Write-Read in x8
  emmc_cmd_switch(SWITCH_CMD_WR_BYTE, EXT_CSD_BUS_WIDTH_IDX, BUS_WIDTH_8BIT, CMD_SET_STANDARD);   // index=183 (BUS_WIDTH), value=0x02 (8-bit SDR)

  set_emmc_clk_io_config(50,EMMC_SDR_MODE,EMMC_IO_WIDTH_X8,EMMC_IO_DRIVE_PP1); // SCK Freq, DDR_MOD, IO_WIDTH, IO_DRIVE

  bus_addr = 32'hA000_5000; // get data from this location
  emmc_cmd_write_block(`DEVICE_ADDR,bus_addr,BLKLEN_512B, 16'd1);

  bus_addr = 32'hA000_6000; // send data to this location
  emmc_cmd_read_block(`DEVICE_ADDR,bus_addr,BLKLEN_512B, 16'd1);

  `TB_MEM_COMPARE((16'h1000 >> 2),(16'h2000 >> 2),128);

  `ENDSIM(2000,clk_i)
end

// ------------------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
`ifdef ap6a00a
  GSRA GSR_INST (.GSR_N  (tb_rst_n));
`elsif ap6a00b
  GSRA GSR_INST (.GSR_N  (tb_rst_n));
`else
  GSR GSR_INST (.CLK(tb_clk), .GSR_N  (tb_rst_n));
`endif



// ------------------------------
// DUT Instance
// ------------------------------
`ifdef DUT_INST_NAME
  // Generated IP mode - use generated instance file
  `include "dut_inst.v"
  defparam `DUT_INST_NAME.SIMULATION = 1;
`else
  // Standalone simulation mode - directly instantiate lscc_emmc_controller
  // Note: DATA_INTERFACE selects either AXI4 or AHBL (not both)
  // Unused interface outputs are left unconnected, unused inputs are tied to constants
  generate
    if (DATA_INTERFACE == "AXI4") begin : gen_dut_axi4
      lscc_emmc_controller #
      (/*AUTOINSTPARAM*/
       // Parameters
       .SIMULATION                            (SIMULATION),
       .DEVICE_FAMILY                         (DEVICE_FAMILY),
       .AXI4_TID_WIDTH                        (AXI4_TID_WIDTH),
       .EN_DDR_MODE                           (EN_DDR_MODE),
       .MAX_NUMLANE                           (MAX_NUMLANE),
       .DEF_BLOCK_SIZE                        (DEF_BLOCK_SIZE),
       .MIN_BLOCK_SIZE                        (MIN_BLOCK_SIZE),
       .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
       .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK),
       .CSR_INTERFACE                         (CSR_INTERFACE),
       .DATA_INTERFACE                        (DATA_INTERFACE),
       .EN_FULLADDR_DECODE                    (EN_FULLADDR_DECODE),
       .REG_BASE_ADDR                         (REG_BASE_ADDR),
       .FIFO_DEPTH                            (FIFO_DEPTH),
       .MEM_IMPL                              (MEM_IMPL),
       .CLKI_FREQ                             (CLKI_FREQ),
       .CLKDIV_WID                            (CLKDIV_WID),
       .SPI_SCKDIV                            (SPI_SCKDIV),
       .USE_CLKDIV1                           (USE_CLKDIV1),
       .USE_IO_PRIMITIVE                      (USE_IO_PRIMITIVE))
      u_dut
      (/*AUTOINST*/
       // Inputs
       .clk_i                                 (clk_i),
       .rst_n_i                               (rst_n_i),
       // eMMC Interface
       .emmc_dat_ds_i                         (emmc_dat_ds_i),
       // Outputs
       .emmc_clk_o                            (emmc_clk_o),
       .emmc_rst_n_o                          (emmc_rst_n_o),
       .int_o                                 (int_o),
       // eMMC Inouts
       .emmc_cmd_io                           (emmc_cmd_io),
       .emmc_dat_io                           (emmc_dat_io),
       // AXI4 Master Interface (active)
       .m_axi4_awready_i                      (m_axi4_awready_i),
       .m_axi4_awvalid_o                      (m_axi4_awvalid_o),
       .m_axi4_awid_o                         (m_axi4_awid_o),
       .m_axi4_awaddr_o                       (m_axi4_awaddr_o),
       .m_axi4_awlen_o                        (m_axi4_awlen_o),
       .m_axi4_awsize_o                       (m_axi4_awsize_o),
       .m_axi4_awburst_o                      (m_axi4_awburst_o),
       .m_axi4_awprot_o                       (m_axi4_awprot_o),
       .m_axi4_wready_i                       (m_axi4_wready_i),
       .m_axi4_wvalid_o                       (m_axi4_wvalid_o),
       .m_axi4_wdata_o                        (m_axi4_wdata_o),
       .m_axi4_wstrb_o                        (m_axi4_wstrb_o),
       .m_axi4_wlast_o                        (m_axi4_wlast_o),
       .m_axi4_bready_o                       (m_axi4_bready_o),
       .m_axi4_bvalid_i                       (m_axi4_bvalid_i),
       .m_axi4_bid_i                          (m_axi4_bid_i),
       .m_axi4_bresp_i                        (m_axi4_bresp_i),
       .m_axi4_arready_i                      (m_axi4_arready_i),
       .m_axi4_arvalid_o                      (m_axi4_arvalid_o),
       .m_axi4_arid_o                         (m_axi4_arid_o),
       .m_axi4_araddr_o                       (m_axi4_araddr_o),
       .m_axi4_arlen_o                        (m_axi4_arlen_o),
       .m_axi4_arsize_o                       (m_axi4_arsize_o),
       .m_axi4_arburst_o                      (m_axi4_arburst_o),
       .m_axi4_arprot_o                       (m_axi4_arprot_o),
       .m_axi4_rvalid_i                       (m_axi4_rvalid_i),
       .m_axi4_rready_o                       (m_axi4_rready_o),
       .m_axi4_rid_i                          (m_axi4_rid_i),
       .m_axi4_rdata_i                        (m_axi4_rdata_i),
       .m_axi4_rresp_i                        (m_axi4_rresp_i),
       .m_axi4_rlast_i                        (m_axi4_rlast_i),
       // AHB-Lite Master Interface (unused - outputs dangling, inputs tied)
       .m_ahbl_hsel_o                         (),
       .m_ahbl_haddr_o                        (),
       .m_ahbl_htrans_o                       (),
       .m_ahbl_hwrite_o                       (),
       .m_ahbl_hsize_o                        (),
       .m_ahbl_hburst_o                       (),
       .m_ahbl_hprot_o                        (),
       .m_ahbl_hmastlock_o                    (),
       .m_ahbl_hwdata_o                       (),
       .m_ahbl_hready_i                       (1'b1),
       .m_ahbl_hresp_i                        (1'b0),
       .m_ahbl_hrdata_i                       (32'h0),
       // APB Slave Interface
       .s_apb_penable_i                       (s_apb_penable_i),
       .s_apb_psel_i                          (s_apb_psel_i),
       .s_apb_pwrite_i                        (s_apb_pwrite_i),
       .s_apb_paddr_i                         (s_apb_paddr_i),
       .s_apb_pwdata_i                        (s_apb_pwdata_i),
       .s_apb_pready_o                        (s_apb_pready_o),
       .s_apb_pslverr_o                       (s_apb_pslverr_o),
       .s_apb_prdata_o                        (s_apb_prdata_o));
    end // gen_dut_axi4
    else if (DATA_INTERFACE == "AHBL") begin : gen_dut_ahbl
      lscc_emmc_controller #
      (/*AUTOINSTPARAM*/
       // Parameters
       .SIMULATION                            (SIMULATION),
       .DEVICE_FAMILY                         (DEVICE_FAMILY),
       .AXI4_TID_WIDTH                        (AXI4_TID_WIDTH),
       .EN_DDR_MODE                           (EN_DDR_MODE),
       .MAX_NUMLANE                           (MAX_NUMLANE),
       .DEF_BLOCK_SIZE                        (DEF_BLOCK_SIZE),
       .MIN_BLOCK_SIZE                        (MIN_BLOCK_SIZE),
       .MAX_BLOCK_SIZE                        (MAX_BLOCK_SIZE),
       .MAX_NUM_BLOCK                         (MAX_NUM_BLOCK),
       .CSR_INTERFACE                         (CSR_INTERFACE),
       .DATA_INTERFACE                        (DATA_INTERFACE),
       .EN_FULLADDR_DECODE                    (EN_FULLADDR_DECODE),
       .REG_BASE_ADDR                         (REG_BASE_ADDR),
       .FIFO_DEPTH                            (FIFO_DEPTH),
       .MEM_IMPL                              (MEM_IMPL),
       .CLKI_FREQ                             (CLKI_FREQ),
       .CLKDIV_WID                            (CLKDIV_WID),
       .SPI_SCKDIV                            (SPI_SCKDIV),
       .USE_CLKDIV1                           (USE_CLKDIV1),
       .USE_IO_PRIMITIVE                      (USE_IO_PRIMITIVE))
      u_dut
      (/*AUTOINST*/
       // Inputs
       .clk_i                                 (clk_i),
       .rst_n_i                               (rst_n_i),
       // eMMC Interface
       .emmc_dat_ds_i                         (emmc_dat_ds_i),
       // Outputs
       .emmc_clk_o                            (emmc_clk_o),
       .emmc_rst_n_o                          (emmc_rst_n_o),
       .int_o                                 (int_o),
       // eMMC Inouts
       .emmc_cmd_io                           (emmc_cmd_io),
       .emmc_dat_io                           (emmc_dat_io),
       // AXI4 Master Interface (unused - outputs dangling, inputs tied)
       .m_axi4_awready_i                      (1'b0),
       .m_axi4_awvalid_o                      (),
       .m_axi4_awid_o                         (),
       .m_axi4_awaddr_o                       (),
       .m_axi4_awlen_o                        (),
       .m_axi4_awsize_o                       (),
       .m_axi4_awburst_o                      (),
       .m_axi4_awprot_o                       (),
       .m_axi4_wready_i                       (1'b0),
       .m_axi4_wvalid_o                       (),
       .m_axi4_wdata_o                        (),
       .m_axi4_wstrb_o                        (),
       .m_axi4_wlast_o                        (),
       .m_axi4_bready_o                       (),
       .m_axi4_bvalid_i                       (1'b0),
       .m_axi4_bid_i                          ({AXI4_TID_WIDTH{1'b0}}),
       .m_axi4_bresp_i                        (2'b00),
       .m_axi4_arready_i                      (1'b0),
       .m_axi4_arvalid_o                      (),
       .m_axi4_arid_o                         (),
       .m_axi4_araddr_o                       (),
       .m_axi4_arlen_o                        (),
       .m_axi4_arsize_o                       (),
       .m_axi4_arburst_o                      (),
       .m_axi4_arprot_o                       (),
       .m_axi4_rvalid_i                       (1'b0),
       .m_axi4_rready_o                       (),
       .m_axi4_rid_i                          ({AXI4_TID_WIDTH{1'b0}}),
       .m_axi4_rdata_i                        (32'h0),
       .m_axi4_rresp_i                        (2'b00),
       .m_axi4_rlast_i                        (1'b0),
       // AHB-Lite Master Interface (active)
       .m_ahbl_hsel_o                         (m_ahbl_hsel_o),
       .m_ahbl_haddr_o                        (m_ahbl_haddr_o),
       .m_ahbl_htrans_o                       (m_ahbl_htrans_o),
       .m_ahbl_hwrite_o                       (m_ahbl_hwrite_o),
       .m_ahbl_hsize_o                        (m_ahbl_hsize_o),
       .m_ahbl_hburst_o                       (m_ahbl_hburst_o),
       .m_ahbl_hprot_o                        (m_ahbl_hprot_o),
       .m_ahbl_hmastlock_o                    (m_ahbl_hmastlock_o),
       .m_ahbl_hwdata_o                       (m_ahbl_hwdata_o),
       .m_ahbl_hready_i                       (m_ahbl_hready_i),
       .m_ahbl_hresp_i                        (m_ahbl_hresp_i),
       .m_ahbl_hrdata_i                       (m_ahbl_hrdata_i),
       // APB Slave Interface
       .s_apb_penable_i                       (s_apb_penable_i),
       .s_apb_psel_i                          (s_apb_psel_i),
       .s_apb_pwrite_i                        (s_apb_pwrite_i),
       .s_apb_paddr_i                         (s_apb_paddr_i),
       .s_apb_pwdata_i                        (s_apb_pwdata_i),
       .s_apb_pready_o                        (s_apb_pready_o),
       .s_apb_pslverr_o                       (s_apb_pslverr_o),
       .s_apb_prdata_o                        (s_apb_prdata_o));
    end // gen_dut_ahbl
  endgenerate
`endif


mdl_emmc u_mdl_emmc
(
 // Inputs
 .rst_n                                 (emmc_rst_n_o),
 .sd_clk                                (emmc_clk_dly),
 // Inouts
 .sd_cmd                                (emmc_cmd_io),
 .sd_dat                                (emmc_dat_io[7:0]),
 // Outputs
 .sd_ds                                 (emmc_dat_ds_i)
 /*AUTOINST*/);

apb_mst_model #
(
 // Parameters
 .ADDR_WIDTH                            (32),
 .DATA_WIDTH                            (32),
 .APB_BFM_MSGS_ON                       (APB_BFM_MSGS_ON))
u_apb_m
(
 // Inputs
 .apb_pclk_i                            (clk_i),
 .apb_preset_n_i                        (rst_n_i),
 .apb_pready_o                          (s_apb_pready_o),
 .apb_pslverr_o                         (s_apb_pslverr_o),
 .apb_prdata_o                          (s_apb_prdata_o[31:0]),
 .int_o                                 (int_o),
 // Outputs
 .apb_psel_i                            (s_apb_psel_i),
 .apb_penable_i                         (s_apb_penable_i),
 .apb_pwrite_i                          (s_apb_pwrite_i),
 .apb_paddr_i                           (s_apb_paddr_i[31:0]),
 .apb_pwdata_i                          (s_apb_pwdata_i[31:0])
 /*AUTOINST*/);

// ------------------------------------------------------------------------------------------------------------
// Memory Model Selection and Interface Tie-offs
// When IP is generated with specific interface, unused interface wires must be driven to safe values
// ------------------------------------------------------------------------------------------------------------
generate
  if(DATA_INTERFACE == "AXI4") begin : gen_axi_mem_model

    // Tie off unused AHB-Lite DUT output wires (DUT has no AHB-Lite master ports)
    assign m_ahbl_hsel_o      = 1'b0;
    assign m_ahbl_haddr_o     = 32'h0;
    assign m_ahbl_htrans_o    = 2'b00;  // HTRANS_IDLE
    assign m_ahbl_hwrite_o    = 1'b0;
    assign m_ahbl_hsize_o     = 3'b000;
    assign m_ahbl_hburst_o    = 3'b000;
    assign m_ahbl_hprot_o     = 4'h0;
    assign m_ahbl_hmastlock_o = 1'b0;
    assign m_ahbl_hwdata_o    = 32'h0;

    // Tie off unused AHB-Lite memory response input wires
    assign m_ahbl_hready_i = 1'b1;
    assign m_ahbl_hresp_i  = 1'b0;
    assign m_ahbl_hrdata_i = 32'h0;

    /*axi_mem_model AUTO_TEMPLATE
    (
     .s_axi4_\(.*\)_i                       (m_axi4_\1_o[]),
     .s_axi4_\(.*\)_o                       (m_axi4_\1_i[]),
    );*/

    axi_mem_model #
    (
     // Parameters
     .SIMULATION                            (SIMULATION),
     .MEM_DEPTH                             (16384),
     .AXI4_TID_WIDTH                        (1),
     .AXI4_LEN_WIDTH                        (8),
     .AXI4_ADR_WIDTH                        (32),
     .AXI4_DAT_WIDTH                        (32),
     .AXI4_STB_WIDTH                        (4)
     /*AUTOINSTPARAM*/)
    u_axi_mem_model
    (/*AUTOINST*/
     // Inputs
     .clk_i                                 (clk_i),
     .rst_n_i                               (rst_n_i),
     .s_axi4_awvalid_i                      (m_axi4_awvalid_o),      // Templated
     .s_axi4_awid_i                         (m_axi4_awid_o[0:0]),    // Templated
     .s_axi4_awaddr_i                       (m_axi4_awaddr_o[31:0]), // Templated
     .s_axi4_awlen_i                        (m_axi4_awlen_o[7:0]),   // Templated
     .s_axi4_awsize_i                       (m_axi4_awsize_o[2:0]),  // Templated
     .s_axi4_awburst_i                      (m_axi4_awburst_o[1:0]), // Templated
     .s_axi4_wvalid_i                       (m_axi4_wvalid_o),       // Templated
     .s_axi4_wdata_i                        (m_axi4_wdata_o[31:0]),  // Templated
     .s_axi4_wstrb_i                        (m_axi4_wstrb_o[3:0]),   // Templated
     .s_axi4_wlast_i                        (m_axi4_wlast_o),        // Templated
     .s_axi4_bready_i                       (m_axi4_bready_o),       // Templated
     .s_axi4_arvalid_i                      (m_axi4_arvalid_o),      // Templated
     .s_axi4_arid_i                         (m_axi4_arid_o[0:0]),    // Templated
     .s_axi4_araddr_i                       (m_axi4_araddr_o[31:0]), // Templated
     .s_axi4_arlen_i                        (m_axi4_arlen_o[7:0]),   // Templated
     .s_axi4_arsize_i                       (m_axi4_arsize_o[2:0]),  // Templated
     .s_axi4_arburst_i                      (m_axi4_arburst_o[1:0]), // Templated
     .s_axi4_rready_i                       (m_axi4_rready_o),       // Templated
     // Outputs
     .s_axi4_awready_o                      (m_axi4_awready_i),      // Templated
     .s_axi4_wready_o                       (m_axi4_wready_i),       // Templated
     .s_axi4_bvalid_o                       (m_axi4_bvalid_i),       // Templated
     .s_axi4_bid_o                          (m_axi4_bid_i[0:0]),     // Templated
     .s_axi4_bresp_o                        (m_axi4_bresp_i[1:0]),   // Templated
     .s_axi4_arready_o                      (m_axi4_arready_i),      // Templated
     .s_axi4_rvalid_o                       (m_axi4_rvalid_i),       // Templated
     .s_axi4_rid_o                          (m_axi4_rid_i[0:0]),     // Templated
     .s_axi4_rdata_o                        (m_axi4_rdata_i[31:0]),  // Templated
     .s_axi4_rresp_o                        (m_axi4_rresp_i[1:0]),   // Templated
     .s_axi4_rlast_o                        (m_axi4_rlast_i));       // Templated

  end // gen_axi_mem_model
  else if(DATA_INTERFACE == "AHBL") begin : gen_ahbl_mem_model

    // Tie off unused AXI4 DUT output wires (DUT has no AXI4 master ports)
    assign m_axi4_awvalid_o = 1'b0;
    assign m_axi4_awid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_awaddr_o  = 32'h0;
    assign m_axi4_awlen_o   = 8'h0;
    assign m_axi4_awsize_o  = 3'b000;
    assign m_axi4_awburst_o = 2'b00;
    assign m_axi4_awprot_o  = 3'b000;

    assign m_axi4_wvalid_o  = 1'b0;
    assign m_axi4_wdata_o   = 32'h0;
    assign m_axi4_wstrb_o   = 4'h0;
    assign m_axi4_wlast_o   = 1'b0;

    assign m_axi4_bready_o  = 1'b0;

    assign m_axi4_arvalid_o = 1'b0;
    assign m_axi4_arid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_araddr_o  = 32'h0;
    assign m_axi4_arlen_o   = 8'h0;
    assign m_axi4_arsize_o  = 3'b000;
    assign m_axi4_arburst_o = 2'b00;
    assign m_axi4_arprot_o  = 3'b000;

    assign m_axi4_rready_o  = 1'b0;

    // Tie off unused AXI4 memory response input wires
    assign m_axi4_awready_i = 1'b0;
    assign m_axi4_wready_i  = 1'b0;
    assign m_axi4_bvalid_i  = 1'b0;
    assign m_axi4_bid_i     = 1'b0;
    assign m_axi4_bresp_i   = 2'b00;
    assign m_axi4_arready_i = 1'b0;
    assign m_axi4_rvalid_i  = 1'b0;
    assign m_axi4_rid_i     = 1'b0;
    assign m_axi4_rdata_i   = 32'h0;
    assign m_axi4_rresp_i   = 2'b00;
    assign m_axi4_rlast_i   = 1'b0;

    /*ahbl_mem_model AUTO_TEMPLATE
    (
     .s_ahbl_\(.*\)_i                       (m_ahbl_\1_o[]),
     .s_ahbl_hready_i                       (m_ahbl_hreadyout),
     .s_ahbl_hreadyout_o                    (m_ahbl_hreadyout),
     .s_ahbl_hrdata_o                       (m_ahbl_hrdata_i[]),
     .s_ahbl_hresp_o                        (m_ahbl_hresp_i),
    );*/

    // Internal signal for hreadyout/hready connection
    wire m_ahbl_hreadyout;
    assign m_ahbl_hready_i = m_ahbl_hreadyout;

    ahbl_mem_model #
    (
     // Parameters
     .SIMULATION                            (SIMULATION),
     .MEM_DEPTH                             (16384),
     .AHBL_ADR_WIDTH                        (32),
     .AHBL_DAT_WIDTH                        (32)
     /*AUTOINSTPARAM*/)
    u_ahbl_mem_model
    (/*AUTOINST*/
     // Inputs
     .clk_i                                 (clk_i),
     .rst_n_i                               (rst_n_i),
     .s_ahbl_haddr_i                        (m_ahbl_haddr_o[31:0]),  // Templated
     .s_ahbl_hburst_i                       (m_ahbl_hburst_o[2:0]),  // Templated
     .s_ahbl_hmastlock_i                    (m_ahbl_hmastlock_o),    // Templated
     .s_ahbl_hprot_i                        (m_ahbl_hprot_o[3:0]),   // Templated
     .s_ahbl_hsize_i                        (m_ahbl_hsize_o[2:0]),   // Templated
     .s_ahbl_htrans_i                       (m_ahbl_htrans_o[1:0]),  // Templated
     .s_ahbl_hwdata_i                       (m_ahbl_hwdata_o[31:0]), // Templated
     .s_ahbl_hwrite_i                       (m_ahbl_hwrite_o),       // Templated
     .s_ahbl_hsel_i                         (m_ahbl_hsel_o),         // Templated
     .s_ahbl_hready_i                       (m_ahbl_hreadyout),      // Templated
     // Outputs
     .s_ahbl_hrdata_o                       (m_ahbl_hrdata_i[31:0]), // Templated
     .s_ahbl_hreadyout_o                    (m_ahbl_hreadyout),      // Templated
     .s_ahbl_hresp_o                        (m_ahbl_hresp_i));       // Templated

  end // gen_ahbl_mem_model
  else begin : gen_invalid_mem_model
    // Invalid DATA_INTERFACE parameter
    initial begin
      $display("ERROR: Invalid DATA_INTERFACE parameter: %s. Must be \"AXI4\" or \"AHBL\"", DATA_INTERFACE);
      $finish;
    end

    // Tie off all DUT output wires (both interfaces)
    assign m_axi4_awvalid_o = 1'b0;
    assign m_axi4_awid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_awaddr_o  = 32'h0;
    assign m_axi4_awlen_o   = 8'h0;
    assign m_axi4_awsize_o  = 3'b000;
    assign m_axi4_awburst_o = 2'b00;
    assign m_axi4_awprot_o  = 3'b000;
    assign m_axi4_wvalid_o  = 1'b0;
    assign m_axi4_wdata_o   = 32'h0;
    assign m_axi4_wstrb_o   = 4'h0;
    assign m_axi4_wlast_o   = 1'b0;
    assign m_axi4_bready_o  = 1'b0;
    assign m_axi4_arvalid_o = 1'b0;
    assign m_axi4_arid_o    = {AXI4_TID_WIDTH{1'b0}};
    assign m_axi4_araddr_o  = 32'h0;
    assign m_axi4_arlen_o   = 8'h0;
    assign m_axi4_arsize_o  = 3'b000;
    assign m_axi4_arburst_o = 2'b00;
    assign m_axi4_arprot_o  = 3'b000;
    assign m_axi4_rready_o  = 1'b0;

    assign m_ahbl_hsel_o      = 1'b0;
    assign m_ahbl_haddr_o     = 32'h0;
    assign m_ahbl_htrans_o    = 2'b00;
    assign m_ahbl_hwrite_o    = 1'b0;
    assign m_ahbl_hsize_o     = 3'b000;
    assign m_ahbl_hburst_o    = 3'b000;
    assign m_ahbl_hprot_o     = 4'h0;
    assign m_ahbl_hmastlock_o = 1'b0;
    assign m_ahbl_hwdata_o    = 32'h0;

    // Tie off all memory response input wires (both interfaces)
    assign m_axi4_awready_i = 1'b0;
    assign m_axi4_wready_i  = 1'b0;
    assign m_axi4_bvalid_i  = 1'b0;
    assign m_axi4_bid_i     = 1'b0;
    assign m_axi4_bresp_i   = 2'b00;
    assign m_axi4_arready_i = 1'b0;
    assign m_axi4_rvalid_i  = 1'b0;
    assign m_axi4_rid_i     = 1'b0;
    assign m_axi4_rdata_i   = 32'h0;
    assign m_axi4_rresp_i   = 2'b00;
    assign m_axi4_rlast_i   = 1'b0;

    assign m_ahbl_hready_i = 1'b0;
    assign m_ahbl_hresp_i  = 1'b0;
    assign m_ahbl_hrdata_i = 32'h0;
  end // gen_invalid_mem_model
endgenerate


endmodule //--tb_top--
`endif // __RTL_MODULE__TB_TOP__
//--------------------------------------------------------------------------
// Local Variables:
// verilog-library-directories: ("./" "../rtl")
// verilog-library-files: ()
// End:
//--------------------------------------------------------------------------
