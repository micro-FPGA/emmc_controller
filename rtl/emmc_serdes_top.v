// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_SERDES_TOP__
`define __RTL_MODULE__EMMC_SERDES_TOP__
//==========================================================================
// Module : emmc_serdes_top
//==========================================================================
module emmc_serdes_top #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                      SIMULATION    = 0

,parameter                      USE_CLKDIV1   = 0
,parameter                      CLKDIV_WID    = 8            // must be able to generate 400KHz,
                                                             // (e.g 200MHz input clock divided by (2*250 pulse width) = 400 KHz)
,parameter    [CLKDIV_WID-1:0]  DEFAULT_RATE  = {{(CLKDIV_WID-1){1'b0}},1'b1}

,parameter                      EN_DDR_MODE   = 1
,parameter                      EN_DDR_WIDE   = 1

,parameter                      MAX_NUMLANE   = 8     // [1,4,8]
,parameter                      BUS_WID       = 32
,parameter                      SPI_WID       = (EN_DDR_MODE && EN_DDR_WIDE)? 2*MAX_NUMLANE : MAX_NUMLANE

,parameter                      EN_SPI_X4     = (MAX_NUMLANE >=  4)? 1 : 0
,parameter                      EN_SPI_X8     = (MAX_NUMLANE >=  8)? 1 : 0
,parameter                      EN_DDR_X4     = (MAX_NUMLANE >=  4)? EN_DDR_MODE : 0
,parameter                      EN_DDR_X8     = (MAX_NUMLANE >=  8)? EN_DDR_MODE : 0
) //--end_param--

( //--begin_ports--
 input                          clk_i
,input                          rst_n_i

,input        [CLKDIV_WID-1:0]  cur_clk_div     // 0 - div1, 1 - div2, 2 - div4, 3 - div6,...

,input                          cmd_en_restart
,input                          dat_en_restart
,input                          en_crc_rsp_type2    // CRC for response type 2 is included in the 128b data

,input                          tx_cmd_valid
,input                          tx_cmd_wr1_rd0
,input        [1:0]             tx_cmd_last_byte
,input        [BUS_WID-1:0]     tx_cmd_data
,input                          tx_cmd_dc_en
,input        [2:0]             tx_cmd_dc_num
,input                          tx_cmd_pp1_od0
,input                          tx_cmd_crc_en

,output wire                    tx_cmd_ready
,output wire                    rx_cmd_valid
,output wire  [BUS_WID-1:0]     rx_cmd_data
,output wire                    rx_cmd_crc_ok
,output wire                    rx_cmd_end

,input                          tx_pld_valid
,input                          tx_pld_wr1_rd0
,input                          tx_pld_ddr_mode
,input        [1:0]             tx_pld_io_width
,input        [1:0]             tx_pld_last_byte
,input        [BUS_WID-1:0]     tx_pld_data
,input                          tx_pld_dc_en
,input        [2:0]             tx_pld_dc_num
,input                          tx_pld_pp1_od0
,input                          tx_pld_crc_en

,output wire                    tx_pld_ready
,output wire                    rx_pld_valid
,output wire  [BUS_WID-1:0]     rx_pld_data
,output wire                    rx_pld_crc_ok
,output wire                    rx_pld_end

// eMMC interface to IO logic
,input                          emmc_rx_ckp
,input                          emmc_rx_ckn
,output wire                    emmc_tx_ckp
,output wire                    emmc_tx_ckn

,output wire                    emmc_clk_out

,input                          emmc_cmd_clk_vld_i
,input                          emmc_cmd_crc_en_i
,input                          emmc_cmd_dlast_i
,input                          emmc_cmd_stb_i
,input                          emmc_cmd_dti_i

,output wire                    emmc_cmd_clk_vld_o
,output wire                    emmc_cmd_pp1_od0_o
,output wire                    emmc_cmd_crc_en_o
,output wire                    emmc_cmd_dc_en_o
,output wire                    emmc_cmd_dlast_o
,output wire                    emmc_cmd_doe_o
,output wire                    emmc_cmd_dto_o

,input                          emmc_dat_clk_vld_i
,input                          emmc_dat_ddr_mode_i
,input                          emmc_dat_crc_en_i
,input                          emmc_dat_dlast_i
,input        [1:0]             emmc_dat_io_width_i
,input                          emmc_dat_stb_i
,input        [SPI_WID-1:0]     emmc_dat_dti_i

,output wire                    emmc_dat_clk_vld_o
,output wire                    emmc_dat_pp1_od0_o
,output wire                    emmc_dat_crc_en_o
,output wire                    emmc_dat_dc_en_o
,output wire                    emmc_dat_dlast_o
,output wire                    emmc_dat_ddr_mode_o
,output wire  [1:0]             emmc_dat_io_width_o
,output wire                    emmc_dat_doe_o
,output wire  [SPI_WID-1:0]     emmc_dat_dto_o
)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

/*AUTOREGINPUT*/
// Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
reg                           clk_out_vld;      // To u_clkgen of emmc_clkgen.v
reg                           en_clk_gen;       // To u_clkgen of emmc_clkgen.v
reg                           rx_spi_ckn;       // To u_serdes_cmd of emmc_serdes.v, ...
reg                           rx_spi_ckp;       // To u_serdes_cmd of emmc_serdes.v, ...
reg                           tx_spi_ckn;       // To u_serdes_cmd of emmc_serdes.v, ...
reg                           tx_spi_ckp;       // To u_serdes_cmd of emmc_serdes.v, ...
// End of automatics

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire                          clk_neg;          // From u_clkgen of emmc_clkgen.v
wire                          clk_pos;          // From u_clkgen of emmc_clkgen.v
wire                          cmd_en_clk_gen;   // From u_serdes_cmd of emmc_serdes.v
wire                          dat_en_clk_gen;   // From u_serdes_dat of emmc_serdes.v
wire                          unused_cmd_if_0;  // From u_serdes_cmd of emmc_serdes.v
wire        [2:0]             unused_cmd_if_1;  // From u_serdes_cmd of emmc_serdes.v
wire                          unused_dat_if_0;  // From u_serdes_dat of emmc_serdes.v
// End of automatics

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------

assign emmc_tx_ckp = tx_spi_ckp;
assign emmc_tx_ckn = tx_spi_ckn;
//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  tx_spi_ckp  = clk_pos;
  tx_spi_ckn  = clk_neg;

  rx_spi_ckp  = emmc_rx_ckp;
  rx_spi_ckn  = emmc_rx_ckn;

  en_clk_gen  = cmd_en_clk_gen | dat_en_clk_gen;
  clk_out_vld = emmc_cmd_clk_vld_o | emmc_dat_clk_vld_o;
end //--always @*--

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
/*emmc_clkgen AUTO_TEMPLATE
(
 .CAPTURE_CSR                           (0),
 .EN_REGOUT                             (1),
 .DEFAULT_CPOL                          (0),
 .DEFAULT_CPHA                          (0),
 .CNTRWID                               (CLKDIV_WID),
 .DEFAULT_RATE                          (DEFAULT_RATE),
 .clk_divider                           (cur_clk_div[]),
 .clk_updated                           (1'b0),
 .clk_polarity                          (1'b0),
 .clk_phase                             (1'b0),
 .clk_out                               (emmc_clk_out),
);*/

emmc_clkgen #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .CNTRWID                               (CLKDIV_WID),            // Templated
 .DEFAULT_RATE                          (DEFAULT_RATE),          // Templated
 .DEFAULT_CPOL                          (0),                     // Templated
 .DEFAULT_CPHA                          (0),                     // Templated
 .USE_CLKDIV1                           (USE_CLKDIV1),
 .CAPTURE_CSR                           (0),                     // Templated
 .EN_REGOUT                             (1))                     // Templated
u_clkgen
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (rst_n_i),
 .en_clk_gen                            (en_clk_gen),
 .clk_out_vld                           (clk_out_vld),
 .clk_updated                           (1'b0),                  // Templated
 .clk_divider                           (cur_clk_div[CLKDIV_WID-1:0]), // Templated
 .clk_polarity                          (1'b0),                  // Templated
 .clk_phase                             (1'b0),                  // Templated
 // Outputs
 .clk_pos                               (clk_pos),
 .clk_neg                               (clk_neg),
 .clk_out                               (emmc_clk_out));                 // Templated

// --------------------------------------------------------------
// SERDES for Command Line
// --------------------------------------------------------------
/*emmc_serdes AUTO_TEMPLATE
(
 .ROT1_SHIFT0                           (0),
 .SHIFT_VALUE                           (1'b1),
 .EN_DDR_MODE                           (0),
 .EN_DDR_WIDE                           (0),
 .MAX_NUMLANE                           (1),
 .BUS_WID                               (BUS_WID),
 .SPI_WID                               (1),
 .EN_SPI_X1                             (1),
 .EN_SPI_X2                             (0),
 .EN_SPI_X4                             (0),
 .EN_SPI_X8                             (0),
 .EN_SPI_X16                            (0),
 .EN_SPI_X32                            (0),
 .EN_DDR_X1                             (0),
 .EN_DDR_X2                             (0),
 .EN_DDR_X4                             (0),
 .EN_DDR_X8                             (0),
 .EN_DDR_X16                            (0),
 .EN_CRC_GEN                            (1),
 .EN_CRC_CHK                            (1),
 .CRC_TYPE                              (0),

 .csr_spi_lsbf                          (1'b0),
 .tx_io_width                           (3'd0),
 .tx_ddr_mode                           (1'b0),
 .spi_ddr_mode_i                        (1'b0),
 .spi_io_width_i                        (3'd0),
 .spi_ddr_mode_o                        (unused_cmd_if_0),
 .spi_io_width_o                        (unused_cmd_if_1[]),
 .tx_valid                              (tx_cmd_valid),
 .tx_data                               (tx_cmd_data[]),
 .tx_last_byte                          (tx_cmd_last_byte[]),
 .tx_pp1_od0                            (tx_cmd_pp1_od0),
 .tx_crc_en                             (tx_cmd_crc_en),
 .tx_wr1_rd0                            (tx_cmd_wr1_rd0),
 .tx_dc_en                              (tx_cmd_dc_en),
 .tx_dc_num                             (tx_cmd_dc_num[]),
 .tx_ready                              (tx_cmd_ready),
 .rx_data                               (rx_cmd_data[]),
 .rx_valid                              (rx_cmd_valid),
 .rx_crc_ok                             (rx_cmd_crc_ok),
 .rx_end                                (rx_cmd_end),

 .en_restart                            (cmd_en_restart),
 .en_clk_gen                            (cmd_en_clk_gen),
 .spi_clk_vld_o                         (emmc_cmd_clk_vld_o),
 .spi_doe                               (emmc_cmd_doe_o),
 .spi_dto                               (emmc_cmd_dto_o),
 .spi_pp1_od0                           (emmc_cmd_pp1_od0_o),
 .spi_dc_en                             (emmc_cmd_dc_en_o),
 .spi_dlast_o                           (emmc_cmd_dlast_o),
 .spi_clk_vld_i                         (emmc_cmd_clk_vld_i),
 .spi_stb                               (emmc_cmd_stb_i),
 .spi_dti                               (emmc_cmd_dti_i),
 .spi_dlast_i                           (emmc_cmd_dlast_i),
 .spi_crc_en                            (emmc_cmd_crc_en_o),
 .spi_crc_en_i                          (emmc_cmd_crc_en_i),
);*/

emmc_serdes #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .EN_DDR_MODE                           (0),                     // Templated
 .EN_DDR_WIDE                           (0),                     // Templated
 .MAX_NUMLANE                           (1),                     // Templated
 .BUS_WID                               (BUS_WID),               // Templated
 .SPI_WID                               (1),                     // Templated
 .EN_SPI_X1                             (1),                     // Templated
 .EN_SPI_X2                             (0),                     // Templated
 .EN_SPI_X4                             (0),                     // Templated
 .EN_SPI_X8                             (0),                     // Templated
 .EN_SPI_X16                            (0),                     // Templated
 .EN_SPI_X32                            (0),                     // Templated
 .EN_DDR_X1                             (0),                     // Templated
 .EN_DDR_X2                             (0),                     // Templated
 .EN_DDR_X4                             (0),                     // Templated
 .EN_DDR_X8                             (0),                     // Templated
 .EN_DDR_X16                            (0),                     // Templated
 .EN_CRC_GEN                            (1),                     // Templated
 .EN_CRC_CHK                            (1),                     // Templated
 .CRC_TYPE                              (0),                     // Templated
 .ROT1_SHIFT0                           (0),                     // Templated
 .SHIFT_VALUE                           (1'b1))                  // Templated
u_serdes_cmd
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (rst_n_i),
 .csr_spi_lsbf                          (1'b0),                  // Templated
 .en_restart                            (cmd_en_restart),        // Templated
 .en_crc_rsp_type2                      (en_crc_rsp_type2),
 .tx_spi_ckp                            (tx_spi_ckp),
 .tx_spi_ckn                            (tx_spi_ckn),
 .rx_spi_ckp                            (rx_spi_ckp),
 .rx_spi_ckn                            (rx_spi_ckn),
 .tx_valid                              (tx_cmd_valid),          // Templated
 .tx_data                               (tx_cmd_data[BUS_WID-1:0]), // Templated
 .tx_last_byte                          (tx_cmd_last_byte[1:0]), // Templated
 .tx_io_width                           (3'd0),                  // Templated
 .tx_ddr_mode                           (1'b0),                  // Templated
 .tx_crc_en                             (tx_cmd_crc_en),         // Templated
 .tx_pp1_od0                            (tx_cmd_pp1_od0),        // Templated
 .tx_wr1_rd0                            (tx_cmd_wr1_rd0),        // Templated
 .tx_dc_en                              (tx_cmd_dc_en),          // Templated
 .tx_dc_num                             (tx_cmd_dc_num[2:0]),    // Templated
 .spi_crc_en_i                          (emmc_cmd_crc_en_i),     // Templated
 .spi_dlast_i                           (emmc_cmd_dlast_i),      // Templated
 .spi_ddr_mode_i                        (1'b0),                  // Templated
 .spi_io_width_i                        (3'd0),                  // Templated
 .spi_clk_vld_i                         (emmc_cmd_clk_vld_i),    // Templated
 .spi_stb                               (emmc_cmd_stb_i),        // Templated
 .spi_dti                               (emmc_cmd_dti_i),        // Templated
 // Outputs
 .en_clk_gen                            (cmd_en_clk_gen),        // Templated
 .tx_ready                              (tx_cmd_ready),          // Templated
 .rx_data                               (rx_cmd_data[BUS_WID-1:0]), // Templated
 .rx_valid                              (rx_cmd_valid),          // Templated
 .rx_crc_ok                             (rx_cmd_crc_ok),         // Templated
 .rx_end                                (rx_cmd_end),            // Templated
 .spi_doe                               (emmc_cmd_doe_o),        // Templated
 .spi_dto                               (emmc_cmd_dto_o),        // Templated
 .spi_clk_vld_o                         (emmc_cmd_clk_vld_o),    // Templated
 .spi_ddr_mode_o                        (unused_cmd_if_0),       // Templated
 .spi_io_width_o                        (unused_cmd_if_1[2:0]),  // Templated
 .spi_pp1_od0                           (emmc_cmd_pp1_od0_o),    // Templated
 .spi_dc_en                             (emmc_cmd_dc_en_o),      // Templated
 .spi_dlast_o                           (emmc_cmd_dlast_o),      // Templated
 .spi_crc_en                            (emmc_cmd_crc_en_o));    // Templated

// --------------------------------------------------------------
// SERDES for Data Line
// --------------------------------------------------------------
/*emmc_serdes AUTO_TEMPLATE
(
 .ROT1_SHIFT0                           (0),
 .SHIFT_VALUE                           (1'b1),
 .EN_SPI_X1                             (1),
 .EN_SPI_X2                             (0),
 .EN_SPI_X16                            (0),
 .EN_SPI_X32                            (0),
 .EN_DDR_X1                             (0),
 .EN_DDR_X2                             (0),
 .EN_DDR_X16                            (0),
 .EN_CRC_GEN                            (1),
 .EN_CRC_CHK                            (1),
 .CRC_TYPE                              (1),

 .en_crc_rsp_type2                      (1'b0),
 .csr_spi_lsbf                          (1'b0),
 .en_clk_gen                            (dat_en_clk_gen),
 .tx_valid                              (tx_pld_valid),
 .tx_data                               (tx_pld_data[]),
 .tx_last_byte                          (tx_pld_last_byte[]),
 .tx_io_width                           ({1'b0,tx_pld_io_width[1:0]}),
 .tx_ddr_mode                           (tx_pld_ddr_mode),
 .tx_pp1_od0                            (tx_pld_pp1_od0),
 .tx_crc_en                             (tx_pld_crc_en),
 .tx_wr1_rd0                            (tx_pld_wr1_rd0),
 .tx_dc_en                              (tx_pld_dc_en),
 .tx_dc_num                             (tx_pld_dc_num[]),
 .tx_ready                              (tx_pld_ready),
 .rx_data                               (rx_pld_data[]),
 .rx_valid                              (rx_pld_valid),
 .rx_crc_ok                             (rx_pld_crc_ok),
 .rx_end                                (rx_pld_end),
 .en_restart                            (dat_en_restart),
 .spi_clk_vld_o                         (emmc_dat_clk_vld_o),
 .spi_doe                               (emmc_dat_doe_o),
 .spi_dto                               (emmc_dat_dto_o[]),
 .spi_ddr_mode_o                        (emmc_dat_ddr_mode_o),
 .spi_io_width_o                        ({unused_dat_if_0,emmc_dat_io_width_o[1:0]}),
 .spi_pp1_od0                           (emmc_dat_pp1_od0_o),
 .spi_dc_en                             (emmc_dat_dc_en_o),
 .spi_dlast_o                           (emmc_dat_dlast_o),
 .spi_io_width_i                        ({1'b0,emmc_dat_io_width_i[1:0]}),
 .spi_clk_vld_i                         (emmc_dat_clk_vld_i),
 .spi_dlast_i                           (emmc_dat_dlast_i),
 .spi_ddr_mode_i                        (emmc_dat_ddr_mode_i),
 .spi_stb                               (emmc_dat_stb_i),
 .spi_dti                               (emmc_dat_dti_i[]),
 .spi_crc_en                            (emmc_dat_crc_en_o),
 .spi_crc_en_i                          (emmc_dat_crc_en_i),
);*/

emmc_serdes #
(/*AUTOINSTPARAM*/
 // Parameters
 .SIMULATION                            (SIMULATION),
 .EN_DDR_MODE                           (EN_DDR_MODE),
 .EN_DDR_WIDE                           (EN_DDR_WIDE),
 .MAX_NUMLANE                           (MAX_NUMLANE),
 .BUS_WID                               (BUS_WID),
 .SPI_WID                               (SPI_WID),
 .EN_SPI_X1                             (1),                     // Templated
 .EN_SPI_X2                             (0),                     // Templated
 .EN_SPI_X4                             (EN_SPI_X4),
 .EN_SPI_X8                             (EN_SPI_X8),
 .EN_SPI_X16                            (0),                     // Templated
 .EN_SPI_X32                            (0),                     // Templated
 .EN_DDR_X1                             (0),                     // Templated
 .EN_DDR_X2                             (0),                     // Templated
 .EN_DDR_X4                             (EN_DDR_X4),
 .EN_DDR_X8                             (EN_DDR_X8),
 .EN_DDR_X16                            (0),                     // Templated
 .EN_CRC_GEN                            (1),                     // Templated
 .EN_CRC_CHK                            (1),                     // Templated
 .CRC_TYPE                              (1),                     // Templated
 .ROT1_SHIFT0                           (0),                     // Templated
 .SHIFT_VALUE                           (1'b1))                  // Templated
u_serdes_dat
(/*AUTOINST*/
 // Inputs
 .clk_i                                 (clk_i),
 .rst_n_i                               (rst_n_i),
 .csr_spi_lsbf                          (1'b0),                  // Templated
 .en_restart                            (dat_en_restart),        // Templated
 .en_crc_rsp_type2                      (1'b0),                  // Templated
 .tx_spi_ckp                            (tx_spi_ckp),
 .tx_spi_ckn                            (tx_spi_ckn),
 .rx_spi_ckp                            (rx_spi_ckp),
 .rx_spi_ckn                            (rx_spi_ckn),
 .tx_valid                              (tx_pld_valid),          // Templated
 .tx_data                               (tx_pld_data[BUS_WID-1:0]), // Templated
 .tx_last_byte                          (tx_pld_last_byte[1:0]), // Templated
 .tx_io_width                           ({1'b0,tx_pld_io_width[1:0]}), // Templated
 .tx_ddr_mode                           (tx_pld_ddr_mode),       // Templated
 .tx_crc_en                             (tx_pld_crc_en),         // Templated
 .tx_pp1_od0                            (tx_pld_pp1_od0),        // Templated
 .tx_wr1_rd0                            (tx_pld_wr1_rd0),        // Templated
 .tx_dc_en                              (tx_pld_dc_en),          // Templated
 .tx_dc_num                             (tx_pld_dc_num[2:0]),    // Templated
 .spi_crc_en_i                          (emmc_dat_crc_en_i),     // Templated
 .spi_dlast_i                           (emmc_dat_dlast_i),      // Templated
 .spi_ddr_mode_i                        (emmc_dat_ddr_mode_i),   // Templated
 .spi_io_width_i                        ({1'b0,emmc_dat_io_width_i[1:0]}), // Templated
 .spi_clk_vld_i                         (emmc_dat_clk_vld_i),    // Templated
 .spi_stb                               (emmc_dat_stb_i),        // Templated
 .spi_dti                               (emmc_dat_dti_i[SPI_WID-1:0]), // Templated
 // Outputs
 .en_clk_gen                            (dat_en_clk_gen),        // Templated
 .tx_ready                              (tx_pld_ready),          // Templated
 .rx_data                               (rx_pld_data[BUS_WID-1:0]), // Templated
 .rx_valid                              (rx_pld_valid),          // Templated
 .rx_crc_ok                             (rx_pld_crc_ok),         // Templated
 .rx_end                                (rx_pld_end),            // Templated
 .spi_doe                               (emmc_dat_doe_o),        // Templated
 .spi_dto                               (emmc_dat_dto_o[SPI_WID-1:0]), // Templated
 .spi_clk_vld_o                         (emmc_dat_clk_vld_o),    // Templated
 .spi_ddr_mode_o                        (emmc_dat_ddr_mode_o),   // Templated
 .spi_io_width_o                        ({unused_dat_if_0,emmc_dat_io_width_o[1:0]}), // Templated
 .spi_pp1_od0                           (emmc_dat_pp1_od0_o),    // Templated
 .spi_dc_en                             (emmc_dat_dc_en_o),      // Templated
 .spi_dlast_o                           (emmc_dat_dlast_o),      // Templated
 .spi_crc_en                            (emmc_dat_crc_en_o));    // Templated



endmodule //--emmc_serdes_top--
`endif // __RTL_MODULE__EMMC_SERDES_TOP__
