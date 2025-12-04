// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_SERDES__
`define __RTL_MODULE__EMMC_SERDES__
//==========================================================================
// Module : emmc_serdes
//==========================================================================
module emmc_serdes #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                      SIMULATION  = 0

,parameter                      EN_DDR_MODE = 1
,parameter                      EN_DDR_WIDE = 1

,parameter                      MAX_NUMLANE = 8     // [1,2,4,8,16]
,parameter                      BUS_WID     = 32
,parameter                      SPI_WID     = (EN_DDR_MODE && EN_DDR_WIDE)? 2*MAX_NUMLANE : MAX_NUMLANE

,parameter                      EN_SPI_X1   = 1
,parameter                      EN_SPI_X2   = (MAX_NUMLANE >=  2)? 1 : 0
,parameter                      EN_SPI_X4   = (MAX_NUMLANE >=  4)? 1 : 0
,parameter                      EN_SPI_X8   = (MAX_NUMLANE >=  8)? 1 : 0
,parameter                      EN_SPI_X16  = (MAX_NUMLANE >= 16)? 1 : 0
,parameter                      EN_SPI_X32  = (MAX_NUMLANE >= 32)? 1 : 0

,parameter                      EN_DDR_X1   = EN_DDR_MODE
,parameter                      EN_DDR_X2   = (MAX_NUMLANE >=  2)? EN_DDR_MODE : 0
,parameter                      EN_DDR_X4   = (MAX_NUMLANE >=  4)? EN_DDR_MODE : 0
,parameter                      EN_DDR_X8   = (MAX_NUMLANE >=  8)? EN_DDR_MODE : 0
,parameter                      EN_DDR_X16  = (MAX_NUMLANE >= 16)? EN_DDR_MODE : 0

,parameter                      EN_CRC_GEN  = 1
,parameter                      EN_CRC_CHK  = 1
,parameter                      CRC_TYPE    = 0      // 0 - CRC7, 1 - CRC16

,parameter                      ROT1_SHIFT0 = 0
,parameter                      SHIFT_VALUE = 1'b0

) //--end_param--

( //--begin_ports--

 input                          clk_i
,input                          rst_n_i

,input                          csr_spi_lsbf    // lsb first transmit enable

,input                          en_restart
,input                          en_crc_rsp_type2    // CRC for response type 2 is included in the 128b data

,input                          tx_spi_ckp
,input                          tx_spi_ckn
,input                          rx_spi_ckp
,input                          rx_spi_ckn
,output wire                    en_clk_gen

,input                          tx_valid
,input        [BUS_WID-1:0]     tx_data
,input        [1:0]             tx_last_byte  // last byte index for BUS_WID > 8
,input        [2:0]             tx_io_width   // 0 - x1, 1 - x2, 2 - x4,..., 6 - x32
,input                          tx_ddr_mode   // 0 - SDR, 1 - DDR
,output wire                    tx_ready

,input                          tx_crc_en     // enable CRC calculation
,input                          tx_pp1_od0    // drive mode: 0 - open-drain, 1 - push-pull
,input                          tx_wr1_rd0    // 0 - SPI read, 1 - SPI write
,input                          tx_dc_en      // dummy cycle enable
,input        [2:0]             tx_dc_num     // number of dummy cycle

,output wire  [BUS_WID-1:0]     rx_data
,output wire                    rx_valid
,output wire                    rx_crc_ok
,output wire                    rx_end

,input                          spi_crc_en_i    // crc indicator
,input                          spi_dlast_i     // last data indicator
,input                          spi_ddr_mode_i  // 0 - SDR, 1 - DDR
,input        [2:0]             spi_io_width_i  // 0 - x1, 1 - x2, 2 - x4,..., 6 - x32
,input                          spi_clk_vld_i   // clock enable for input, must be pipeline of (spi_clk_vld_o & ~spi_dc_en)
,input                          spi_stb         // data input strobe
,input        [SPI_WID-1:0]     spi_dti         // data input

,output wire                    spi_doe         // data output enable
,output wire  [SPI_WID-1:0]     spi_dto         // data output
,output wire                    spi_clk_vld_o   // clock enable for output
,output wire                    spi_ddr_mode_o  // 0 - SDR, 1 - DDR
,output wire  [2:0]             spi_io_width_o  // 0 - x1, 1 - x2, 2 - x4,..., 6 - x32
,output wire                    spi_pp1_od0     // drive mode: 0 - open-drain, 1 - push-pull
,output wire                    spi_dc_en       // dummy cycle
,output wire                    spi_dlast_o     // last data indicator
,output wire                    spi_crc_en      // crc enable


)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--

//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                        SWID     = MAX_NUMLANE;
localparam                        CRCWID   = (CRC_TYPE)? 16 : 7;

localparam                        SPI_X1   = 3'd0
                                 ,SPI_X2   = 3'd1
                                 ,SPI_X4   = 3'd2
                                 ,SPI_X8   = 3'd3
                                 ,SPI_X16  = 3'd4
                                 ,SPI_X32  = 3'd5
                                 ;

`define DOUT_SHIFT_ROTATE(DATA,S_IDX,BITLEN,EN_ROT,SHIFT_VAL)   {(({(BITLEN){ (EN_ROT)}} & DATA[(S_IDX)+:(BITLEN)]) | \
                                                                  ({(BITLEN){~(EN_ROT)}} & {(BITLEN){(SHIFT_VAL)}})), \
                                                                  DATA[(BITLEN)+:BUS_WID-(BITLEN)]}

`define DIN8_SHIFT(DAT_I,DAT_O,IWID)                            ({DAT_O[0+:8-IWID],DAT_I[0+:IWID]})

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
reg           [2:0]               bit_cntr_nxt;
reg           [1:0]               byt_cntr_nxt;

reg           [3:0]               bit_cntr_rx_nxt;
reg                               dlast_nxt;

wire                              gnd_wire;
wire                              en_rotate;
wire                              shift_value;

wire                              tx_ddr_mode_w;
wire          [2:0]               tx_io_width_w;

wire                              en_shift_wdat;
wire                              en_load_wdat;
wire                              en_ddr;
wire          [5:0]               tx_width_1hot;
wire          [5:0]               io_width_1hot;
wire          [5:0]               rx_width_1hot;
wire                              byte_done;
wire          [1:0]               byt_cntr_w;

wire          [BUS_WID-1:0]       tx_data_w;
wire          [BUS_WID-1:0]       wdata_bus_nxt;
wire          [BUS_WID-1:0]       wdata_crc_all;
wire          [BUS_WID-1:0]       wdata_x01_nxt;
wire          [BUS_WID-1:0]       wdata_x02_nxt;
wire          [BUS_WID-1:0]       wdata_x04_nxt;
wire          [BUS_WID-1:0]       wdata_x08_nxt;
wire          [BUS_WID-1:0]       wdata_x16_nxt;
wire          [BUS_WID-1:0]       wdata_x32_nxt;

wire          [SWID-1:0]          spi_dti_pos;
wire          [SWID-1:0]          spi_dti_neg;

wire          [ 0:0]              spidat_sdr_01_in;
wire          [ 1:0]              spidat_sdr_02_in;
wire          [ 3:0]              spidat_sdr_04_in;
wire          [ 7:0]              spidat_sdr_08_in;
wire          [15:0]              spidat_sdr_16_in;
wire          [31:0]              spidat_sdr_32_in;

wire          [ 1:0]              spidat_ddr_01_in;
wire          [ 3:0]              spidat_ddr_02_in;
wire          [ 7:0]              spidat_ddr_04_in;
wire          [15:0]              spidat_ddr_08_in;
wire          [31:0]              spidat_ddr_16_in;
wire          [31:0]              spidat_ddr_32_in;

wire          [7:0]               rdata_8b_nxt;
wire          [7:0]               rdata_8b_x01_nxt;
wire          [7:0]               rdata_8b_x02_nxt;
wire          [7:0]               rdata_8b_x04_nxt;
wire          [7:0]               rdata_8b_x08_nxt;

wire          [7:0]               rdata_16_nxt;
wire          [7:0]               rdata_16_x16_nxt;

wire          [15:0]              rdata_32_nxt;

wire                              spi_sample_valid;
wire                              rx_pos_sample;
wire                              rx_neg_sample;
wire                              rx_ddr_mode;
wire          [2:0]               rx_io_width;
wire                              rx_crc_en;
wire                              rx_dlast;
wire          [7:0]               rdata_16_hi;
wire          [15:0]              rdata_32_hi;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [BUS_WID-1:0]       wdata_r;
reg           [7:0]               rdata_8b_r;
reg                               wait_stb;

reg           [2:0]               bit_cntr;
reg           [3:0]               bit_cntr_rx;
reg           [2:0]               max_bit_cnt;
reg           [1:0]               byt_cntr;
reg                               tx_ready_r;

reg                               clk_valid_r;
reg                               pp1_od0_r;
reg                               crc_en_r;
reg                               dc_en_r;
reg                               dlast_r;
reg                               dout_en_r;
reg                               ddr_mode_r;
reg           [2:0]               io_width_r;

reg                               rx_byte_done;
reg                               rx_word_done;
reg                               rx_dt32_done;
reg                               rx_data_last;
reg                               rx_stb;
reg                               rx_crc_en_dly;



//--------------------------------------------
//-- set_8bit_swap --
//--------------------------------------------
function [7:0] set_8bit_swap;
  input       [7:0]       data_in;
  input       [2:0]       io_width;
  input                   lsbf;
  reg         [7:0]       result_lsbf;
  reg         [7:0]       result_x1;
  reg         [7:0]       result_x2;
  reg         [7:0]       result_x4;
  reg         [7:0]       result_x8;
  integer                 idx;
  begin

    result_x1   = 8'd0;
    result_x2   = 8'd0;
    result_x4   = 8'd0;
    result_x8   = 8'd0;
    result_lsbf = 8'd0;
    if(lsbf) begin
      result_lsbf = data_in;
    end // lsbf
    else begin // msbf
      case(io_width)
        3'd0    : begin  // x1
          for(idx = 0; idx<8; idx=idx+1) begin
            result_x1[idx*1+0] = data_in[7-idx*1];
          end
        end // x1
        3'd1    : begin // x2
          for(idx = 0; idx<4; idx=idx+1) begin
            result_x2[idx*2+0] = data_in[6-idx*2];
            result_x2[idx*2+1] = data_in[7-idx*2];
          end
        end // x2
        3'd2    : begin // x4
          for(idx = 0; idx<2; idx=idx+1) begin
            result_x4[idx*4+0] = data_in[4-idx*4];
            result_x4[idx*4+1] = data_in[5-idx*4];
            result_x4[idx*4+2] = data_in[6-idx*4];
            result_x4[idx*4+3] = data_in[7-idx*4];
          end
        end // x4
        default : begin // x8
          result_x8 = data_in;
        end // x8
      endcase
    end // msbf
    set_8bit_swap  = ((EN_SPI_X1)? result_x1 : 8'd0) |
                     ((EN_SPI_X2)? result_x2 : 8'd0) |
                     ((EN_SPI_X4)? result_x4 : 8'd0) |
                     ((EN_SPI_X8)? result_x8 : 8'd0) |
                     result_lsbf;
  end
endfunction // set_8bit_swap

//--------------------------------------------
//-- set_databit_swap --
//--------------------------------------------
function [BUS_WID-1:0] set_databit_swap;
  input       [BUS_WID-1:0] data_in;
  input       [2:0]         io_width;
  input                     lsbf;
  reg         [BUS_WID-1:0] result;
  integer                   idx;
  begin

    result = {BUS_WID{1'b0}};
    case(BUS_WID)
      16      : begin
        result[8*0+:8] = set_8bit_swap(data_in[8*0+:8],io_width,lsbf);
        result[8*1+:8] = set_8bit_swap(data_in[8*1+:8],io_width,lsbf);
      end
      32      : begin
        result[8*0+:8] = set_8bit_swap(data_in[8*0+:8],io_width,lsbf);
        result[8*1+:8] = set_8bit_swap(data_in[8*1+:8],io_width,lsbf);
        result[8*2+:8] = set_8bit_swap(data_in[8*2+:8],io_width,lsbf);
        result[8*3+:8] = set_8bit_swap(data_in[8*3+:8],io_width,lsbf);
      end
      default : begin
        result[8*0+:8] = set_8bit_swap(data_in[8*0+:8],io_width,lsbf);
      end
    endcase
    set_databit_swap = result;
  end
endfunction // set_databit_swap

//--------------------------------------------
//-- get_io_width_onehot --
//--------------------------------------------
function [5:0] get_io_width_onehot;
  input       [2:0]         io_width;
  reg         [5:0]         io_width_onehot;
  begin
    io_width_onehot[0]  = (EN_SPI_X1 )? (io_width == SPI_X1 ) : 1'b0;
    io_width_onehot[1]  = (EN_SPI_X2 )? (io_width == SPI_X2 ) : 1'b0;
    io_width_onehot[2]  = (EN_SPI_X4 )? (io_width == SPI_X4 ) : 1'b0;
    io_width_onehot[3]  = (EN_SPI_X8 )? (io_width == SPI_X8 ) : 1'b0;
    io_width_onehot[4]  = (EN_SPI_X16)? (io_width == SPI_X16) : 1'b0;
    io_width_onehot[5]  = (EN_SPI_X32)? (io_width == SPI_X32) : 1'b0;

    get_io_width_onehot = io_width_onehot;
  end
endfunction // get_io_width_onehot


//--------------------------------------------
//-- calc_crc7_1b --
//--------------------------------------------
function [6:0] calc_crc7_1b;
  input                         data_in;
  input       [6:0]             crc_q;

  reg                           crc_b0;
  reg         [6:0]             crc_d;
  reg         [6:0]             polynomial_map;
  begin
    // polynomial: x^7 + x^3 + 1
    polynomial_map  = 7'h09;
    crc_b0          = data_in  ^ crc_q[6];
    crc_d           = ({7{crc_b0}} & polynomial_map) ^ {crc_q[5:0],1'b0};
    calc_crc7_1b    = crc_d;
  end
endfunction // calc_crc7_1b

//--------------------------------------------
//-- calc_crc16_1b --
//--------------------------------------------
function [15:0] calc_crc16_1b;
  input                         data_in;
  input       [15:0]            crc_q;

  reg                           crc_b0;
  reg         [15:0]            crc_d;
  reg         [15:0]            polynomial_map;
  begin
    // polynomial: x^16 + x^12 + x^5 + 1
    polynomial_map  = 16'h1021;
    crc_b0          = data_in  ^ crc_q[15];
    crc_d           = ({16{crc_b0}} & polynomial_map) ^ {crc_q[14:0],1'b0};
    calc_crc16_1b   = crc_d;
  end
endfunction // calc_crc16_1b

//------------------------------------------------------------------------------

assign gnd_wire           = 1'b0;
assign en_rotate          = ROT1_SHIFT0;
assign shift_value        = SHIFT_VALUE;

assign tx_ddr_mode_w      = (EN_DDR_MODE)? tx_ddr_mode : 1'b0;
assign tx_io_width_w      = (SWID == 1)? 3'd0 :
                            (SWID == 2)? {2'd0,tx_io_width[0]} :
                            (SWID == 4)? {1'd0,tx_io_width[1:0]} :
                            (SWID == 8)? {1'd0,tx_io_width[1:0]} :
                                                tx_io_width;

assign en_load_wdat       = tx_valid & tx_ready;
assign en_shift_wdat      = (wait_stb)? tx_spi_ckp & spi_stb : tx_spi_ckp;

assign tx_width_1hot      = get_io_width_onehot(tx_io_width_w);
assign io_width_1hot      = get_io_width_onehot(io_width_r);
assign rx_width_1hot      = get_io_width_onehot(rx_io_width);

assign byte_done          = en_shift_wdat & (bit_cntr == 3'd0);

assign tx_ready           = tx_ready_r & ((wait_stb)? tx_spi_ckp & spi_stb : tx_spi_ckp);

assign rdata_8b_x01_nxt   = ((EN_DDR_X1 && rx_ddr_mode)? `DIN8_SHIFT(spidat_ddr_01_in,rdata_8b_r,2) : `DIN8_SHIFT(spidat_sdr_01_in,rdata_8b_r,1));
assign rdata_8b_x02_nxt   = ((EN_DDR_X2 && rx_ddr_mode)? `DIN8_SHIFT(spidat_ddr_02_in,rdata_8b_r,4) : `DIN8_SHIFT(spidat_sdr_02_in,rdata_8b_r,2));
assign rdata_8b_x04_nxt   = ((EN_DDR_X4 && rx_ddr_mode)? spidat_ddr_04_in                           : `DIN8_SHIFT(spidat_sdr_04_in,rdata_8b_r,4));
assign rdata_8b_x08_nxt   = ((EN_DDR_X8 && rx_ddr_mode)? ((rx_neg_sample)? spidat_ddr_08_in[8+:8] :
                                                                           spidat_ddr_08_in[0+:8])  : spidat_sdr_08_in                          );

assign rdata_8b_nxt       = ({8{rx_width_1hot[0]}} & rdata_8b_x01_nxt[0+:8]) |
                            ({8{rx_width_1hot[1]}} & rdata_8b_x02_nxt[0+:8]) |
                            ({8{rx_width_1hot[2]}} & rdata_8b_x04_nxt[0+:8]) |
                            ({8{rx_width_1hot[3]}} & rdata_8b_x08_nxt[0+:8]) |
                            ({8{rx_width_1hot[4]}} & spidat_sdr_16_in[0+:8]) |
                            ({8{rx_width_1hot[5]}} & spidat_sdr_32_in[0+:8]);

assign rdata_16_x16_nxt   = ((EN_DDR_X16 && rx_ddr_mode)? spidat_ddr_16_in[8+:8] : spidat_sdr_16_in[8+:8]);

assign rdata_16_nxt       = ({8{rx_width_1hot[3]}} & spidat_ddr_08_in[8+:8]) |
                            ({8{rx_width_1hot[4]}} & rdata_16_x16_nxt[0+:8]) |
                            ({8{rx_width_1hot[5]}} & spidat_sdr_32_in[8+:8]);

assign rdata_32_nxt       = ({8{rx_width_1hot[4]}} & spidat_ddr_16_in[16+:16]) |
                            ({8{rx_width_1hot[5]}} & spidat_sdr_32_in[16+:16]);

// shift out wdata
assign wdata_bus_nxt      = (({BUS_WID{io_width_1hot[0]}} & wdata_x01_nxt) |
                             ({BUS_WID{io_width_1hot[1]}} & wdata_x02_nxt) |
                             ({BUS_WID{io_width_1hot[2]}} & wdata_x04_nxt) |
                             ({BUS_WID{io_width_1hot[3]}} & wdata_x08_nxt) |
                             ({BUS_WID{io_width_1hot[4]}} & wdata_x16_nxt) |
                             ({BUS_WID{io_width_1hot[5]}} & wdata_x32_nxt));
//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  bit_cntr_nxt = bit_cntr;
  if(en_load_wdat) begin
    bit_cntr_nxt = (tx_dc_en)? tx_dc_num :
                   (tx_crc_en)? 3'd7 :
                   ({3{tx_width_1hot[0]}} & ((EN_DDR_X1 && tx_ddr_mode_w)? 3'd3 : 3'd7)) |
                   ({3{tx_width_1hot[1]}} & ((EN_DDR_X2 && tx_ddr_mode_w)? 3'd1 : 3'd3)) |
                   ({3{tx_width_1hot[2]}} & ((EN_DDR_X4 && tx_ddr_mode_w)? 3'd0 : 3'd1));  // other IO width: 0 max
  end
  else if(en_shift_wdat) begin
    bit_cntr_nxt = (|bit_cntr  )? (bit_cntr - 3'd1) :
                   (|byt_cntr_w)? max_bit_cnt : 3'd0;
  end
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    wdata_r <= {BUS_WID{SHIFT_VALUE}};
    dlast_r <= 1'h1;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    bit_cntr <= 3'h0;
    byt_cntr <= 2'h0;
    clk_valid_r <= 1'h0;
    crc_en_r <= 1'h0;
    dc_en_r <= 1'h0;
    ddr_mode_r <= 1'h0;
    dout_en_r <= 1'h0;
    io_width_r <= 3'h0;
    max_bit_cnt <= 3'h0;
    pp1_od0_r <= 1'h0;
    tx_ready_r <= 1'h0;
    wait_stb <= 1'h0;
    // End of automatics
  end
  else begin
    tx_ready_r      <= ~|{bit_cntr_nxt,byt_cntr_nxt};
    bit_cntr        <= bit_cntr_nxt;
    byt_cntr        <= byt_cntr_nxt;
    dlast_r         <= dlast_nxt;
    if(en_restart) begin
      bit_cntr      <= 3'd0;
      byt_cntr      <= 2'd0;
      clk_valid_r   <= 1'b0;
      wait_stb      <= 1'b0;
      pp1_od0_r     <= 1'b0;
      dc_en_r       <= 1'b0;
      dout_en_r     <= 1'b0;
    end
    else if(en_load_wdat) begin
      clk_valid_r   <= 1'b1;
      wait_stb      <= ~(tx_wr1_rd0 | tx_dc_en);
      pp1_od0_r     <= tx_pp1_od0;
      dc_en_r       <= tx_dc_en;
      crc_en_r      <= tx_crc_en;
      dout_en_r     <= tx_wr1_rd0 | tx_dc_en;
      ddr_mode_r    <= (tx_dc_en)? 1'b0 : tx_ddr_mode_w;
      io_width_r    <= tx_io_width_w;
      wdata_r       <= (tx_dc_en | tx_wr1_rd0)? tx_data_w : {BUS_WID{shift_value}};
      max_bit_cnt   <= (tx_crc_en)? 3'd7 :
                       (({3{tx_width_1hot[0]}} & ((EN_DDR_X1 && tx_ddr_mode_w)? 3'd3 : 3'd7)) |
                        ({3{tx_width_1hot[1]}} & ((EN_DDR_X2 && tx_ddr_mode_w)? 3'd1 : 3'd3)) |
                        ({3{tx_width_1hot[2]}} & ((EN_DDR_X4 && tx_ddr_mode_w)? 3'd0 : 3'd1))); // other IO width: 0 max
    end // en_load_wdat
    else if(en_shift_wdat) begin
      clk_valid_r   <= (|{byt_cntr_w,bit_cntr}) & clk_valid_r;
      wait_stb      <= (|{byt_cntr_w,bit_cntr}) & wait_stb   ;
      pp1_od0_r     <= (|{byt_cntr_w,bit_cntr}) & pp1_od0_r  ;
      crc_en_r      <= (|{byt_cntr_w,bit_cntr}) & crc_en_r   ;
      dc_en_r       <= (|{byt_cntr_w,bit_cntr}) & dc_en_r    ;
      dout_en_r     <= (|{byt_cntr_w,bit_cntr}) & dout_en_r  ;
      wdata_r       <= (dout_en_r)? ((crc_en_r)? wdata_crc_all : wdata_bus_nxt) :
                                    {BUS_WID{shift_value}};
    end
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  bit_cntr_rx_nxt = bit_cntr_rx;
  if(spi_sample_valid & rx_stb) begin
    bit_cntr_rx_nxt = bit_cntr_rx + {3'd0,rx_pos_sample};
  end
  else begin
    bit_cntr_rx_nxt = 4'd0;
  end
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    rdata_8b_r <= {8{1'b1}};
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    bit_cntr_rx <= 4'h0;
    rx_crc_en_dly <= 1'h0;
    // End of automatics
  end
  else begin
    bit_cntr_rx <= bit_cntr_rx_nxt;
    if((rx_pos_sample | rx_neg_sample) & spi_sample_valid & rx_stb) begin
      rdata_8b_r  <= rdata_8b_nxt;
      rx_crc_en_dly <= rx_crc_en;
    end
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    rx_byte_done <= 1'h0;
    rx_data_last <= 1'h0;
    rx_dt32_done <= 1'h0;
    rx_word_done <= 1'h0;
    // End of automatics
  end
  else begin
    rx_data_last <= (rx_pos_sample | rx_neg_sample) & spi_sample_valid & rx_stb & rx_dlast;
    rx_byte_done <= (rx_pos_sample & spi_sample_valid & rx_stb &
                      ((rx_crc_en)? (bit_cntr_rx[2:0] == 3'd7) :
                                    (((EN_SPI_X1  && (rx_io_width == SPI_X1 ))? ((EN_DDR_X1 && rx_ddr_mode)? (bit_cntr_rx[1:0] == 2'd3)         : (bit_cntr_rx[2:0] == 3'd7)) : 1'b0) |
                                     ((EN_SPI_X2  && (rx_io_width == SPI_X2 ))? ((EN_DDR_X2 && rx_ddr_mode)? (bit_cntr_rx[0:0] == 1'd1)         : (bit_cntr_rx[1:0] == 2'd3)) : 1'b0) |
                                     ((EN_SPI_X4  && (rx_io_width == SPI_X4 ))? ((EN_DDR_X4 && rx_ddr_mode)? 1'b1                               : (bit_cntr_rx[0:0] == 1'd1)) : 1'b0) |
                                     ((EN_SPI_X8  && (rx_io_width == SPI_X8 ))? ((EN_DDR_X8 && rx_ddr_mode)? (BUS_WID == 8 && EN_DDR_WIDE == 0) : 1'b1                      ) : 1'b0)
                                    )
                      )) | (rx_neg_sample & spi_sample_valid & rx_stb);

    rx_word_done <= rx_pos_sample & spi_sample_valid & rx_stb &
                    (((EN_SPI_X8  && (rx_io_width == SPI_X8 ))? ((EN_DDR_X8  && rx_ddr_mode)? 1'b1 : 1'b0) : 1'b0) |
                     ((EN_SPI_X16 && (rx_io_width == SPI_X16))? ((EN_DDR_X16 && rx_ddr_mode)? 1'b0 : 1'b1) : 1'b0)
                    );

    rx_dt32_done <= rx_pos_sample & spi_sample_valid & rx_stb &
                    (((EN_SPI_X16 && (rx_io_width == SPI_X16))? ((EN_DDR_X16 && rx_ddr_mode)? 1'b1 : 1'b0) : 1'b0) |
                     ((EN_SPI_X32 && (rx_io_width == SPI_X32))?                                       1'b1 : 1'b0)
                    );
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

genvar i;
generate
  if(EN_CRC_GEN) begin : gen_crc_gen
    if(CRC_TYPE == 1) begin : gen_crc16
      wire          [SWID-1:0]          wcrc_per_line;
      wire          [SWID-1:0]          crc_ok_w;
      wire          [15:0]              wdata_w;

      reg                               wcrc_en;
      reg                               rcrc_en;
      reg                               rcrc_hold_cap;
      reg                               crc_ok_r;
      reg                               xfer_end;
      reg                               det_crc_b1;

      assign rx_crc_ok = crc_ok_r;
      assign rx_end    = xfer_end;

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          crc_ok_r <= 1'h0;
          det_crc_b1 <= 1'h0;
          rcrc_en <= 1'h0;
          rcrc_hold_cap <= 1'h0;
          rx_stb <= 1'h0;
          wcrc_en <= 1'h0;
          xfer_end <= 1'h0;
          // End of automatics
        end
        else begin
          rx_stb    <= (rx_pos_sample)? spi_stb : rx_stb;
          xfer_end  <= rcrc_hold_cap & rx_byte_done;
          if(wcrc_en) begin
            wcrc_en     <= ((BUS_WID > 8)? ~(en_load_wdat & crc_en_r  ) & wcrc_en :
                                           ~(en_load_wdat & det_crc_b1) & wcrc_en) & ~en_restart;
            det_crc_b1  <= det_crc_b1 | (en_load_wdat & crc_en_r);
          end
          else begin
            // CRC calculation in data line starts after Start (1 clock cycle)
            wcrc_en     <= en_load_wdat & tx_dc_en & ~tx_data_w[0] & ~en_restart;
            det_crc_b1  <= 1'b0;
          end

          crc_ok_r    <= (EN_SPI_X8 && (rx_io_width == SPI_X8))? &crc_ok_w[7:0] :
                         (EN_SPI_X4 && (rx_io_width == SPI_X4))? &crc_ok_w[3:0] :
                                                                  crc_ok_w[0];

          if(rcrc_en) begin
            rcrc_en       <= ((rx_pos_sample)? spi_clk_vld_i : rcrc_en) & ~en_restart;
            rcrc_hold_cap <= (rx_byte_done & rx_crc_en_dly) ^ rcrc_hold_cap;
          end
          else begin
            // CRC calculation in command line starts after Start
            rcrc_en       <= ~spi_dti_pos[0] & rx_pos_sample & ~en_restart;
            rcrc_hold_cap <= 1'b0;
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--

      assign wdata_w        = ((BUS_WID > 8)? wdata_r : {8'hFF,wdata_r}) & 16'hFFFF;
      assign tx_data_w      = (tx_crc_en)? ({{24{1'b1}},wcrc_per_line} & {BUS_WID{1'b1}}) :
                                           set_databit_swap(tx_data,tx_io_width_w,csr_spi_lsbf);
      assign wdata_crc_all  = ({{24{1'b1}},wcrc_per_line} & {BUS_WID{1'b1}});

      for(i=0; i<SWID; i=i+1) begin : gen_lane
        // -----------------------------------------------------------------------------
        // Write Data CRC
        // -----------------------------------------------------------------------------
        wire                              wdat16_in;
        wire          [15:0]              wcrc16_nxt;

        reg           [15:0]              wcrc16_r;

        // CRC in data line is separate per line - msbyte first
        assign wcrc_per_line[i] = wcrc16_r[15];

        assign wdat16_in  = (en_load_wdat)? tx_data_w[i] :
                            (EN_SPI_X8 && (io_width_r == SPI_X8))? wdata_w[i+8] : // BUS_WID must be > 8
                            (EN_SPI_X4 && (io_width_r == SPI_X4))? wdata_w[i+4] :  wdata_w[i+1];
        assign wcrc16_nxt = ((en_load_wdat & tx_crc_en) | crc_en_r)? {wcrc16_r[14:0],wcrc16_r[15]} :
                                                                     calc_crc16_1b(wdat16_in,wcrc16_r);
        //--------------------------------------------
        //-- Sequential block --
        //--------------------------------------------
        always @(posedge clk_i or negedge rst_n_i) begin
          if(~rst_n_i) begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            wcrc16_r <= 16'h0;
            // End of automatics
          end
          else begin
            if(wcrc_en) begin
              wcrc16_r <= (en_shift_wdat)? wcrc16_nxt : wcrc16_r;
            end
            else begin
              wcrc16_r  <= 16'd0;
            end
          end
        end //--always @(posedge clk_i or negedge rst_n_i)--


        // -----------------------------------------------------------------------------
        // Read Data CRC
        // -----------------------------------------------------------------------------
        wire          [15:0]              rcrc16_nxt;

        reg           [15:0]              rcrc16_r;
        reg           [15:0]              rcrc16_actual;

        assign rcrc16_nxt  = calc_crc16_1b(spi_dti_pos[i],rcrc16_r);
        assign crc_ok_w[i] = rcrc_en & rx_byte_done & (rcrc16_actual == rcrc16_r);
        //--------------------------------------------
        //-- Sequential block --
        //--------------------------------------------
        always @(posedge clk_i or negedge rst_n_i) begin
          if(~rst_n_i) begin
            rcrc16_actual <= {16{1'b1}};
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            rcrc16_r <= 16'h0;
            // End of automatics
          end
          else begin
            // CRC is msbyte first
            rcrc16_actual   <= (rx_pos_sample & spi_sample_valid & rx_stb)? {rcrc16_actual[14:0],spi_dti_pos[i]} : rcrc16_actual;
            if(rcrc_en) begin
              rcrc16_r      <= (rx_pos_sample & ~rx_crc_en)? rcrc16_nxt : rcrc16_r;
            end
            else begin
              // CRC calculation in command line starts after Start
              rcrc16_r      <= 16'd0;
            end
          end
        end //--always @(posedge clk_i or negedge rst_n_i)--

      end // gen_lane

    end // gen_crc16

    else begin : gen_crc7
      wire                              wdat7_in;
      wire          [6:0]               wcrc7_nxt;
      wire          [6:0]               rcrc7_nxt;
      wire          [7:0]               rcrc7_dat;
      wire          [BUS_WID-1:0]       wdata_wcrc;

      reg                               wcrc_en;
      reg           [6:0]               wcrc7_r;

      reg                               rcrc_en;
      reg           [6:0]               rcrc7_r;
      reg           [6:0]               rcrc7_prev;
      reg                               det_rx_start;
      reg                               crc_ok;
      reg                               xfer_end;

      assign tx_data_w      = set_databit_swap(wdata_wcrc,tx_io_width_w,csr_spi_lsbf);
      assign wdata_wcrc     = (tx_crc_en)? ({wcrc7_r,1'b1} & {BUS_WID{1'b1}}) : tx_data;
      assign wdata_crc_all  = wdata_bus_nxt;

      assign wdat7_in   = (en_load_wdat)? tx_data_w[0] : wdata_r[1];
      assign wcrc7_nxt  = calc_crc7_1b(wdat7_in,wcrc7_r);

      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        rx_stb = spi_stb;
      end //--always @*--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          wcrc7_r <= 7'h0;
          wcrc_en <= 1'h0;
          // End of automatics
        end
        else begin
          if(wcrc_en) begin
            wcrc7_r <= (en_shift_wdat)? wcrc7_nxt : wcrc7_r;
            wcrc_en <= ~(en_load_wdat & (tx_crc_en | tx_dc_en)) & wcrc_en & ~en_restart;
          end
          else begin
            // CRC calculation in command line starts after Start and T-bit (2 clock cycles)
            wcrc_en <= en_shift_wdat & clk_valid_r & ~dc_en_r & ~wdata_r[0] & ~en_restart;
            wcrc7_r <= 7'd9; // CRC value after input bits 2'b01 (Start and T-bit)
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--

      assign rcrc7_nxt  = calc_crc7_1b(spi_dti_pos[0],rcrc7_r);
      assign rcrc7_dat  = {rcrc7_prev,1'b1};
      assign rx_crc_ok  = crc_ok;
      assign rx_end     = xfer_end;
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          crc_ok <= 1'h0;
          det_rx_start <= 1'h0;
          rcrc7_prev <= 7'h0;
          rcrc7_r <= 7'h0;
          rcrc_en <= 1'h0;
          xfer_end <= 1'h0;
          // End of automatics
        end
        else begin
          rcrc7_prev  <= (rx_byte_done)? rcrc7_r : rcrc7_prev;
          xfer_end    <= rcrc_en & rx_crc_en_dly & rx_byte_done;
          if(rcrc_en) begin
            det_rx_start  <= 1'b0;
            rcrc_en       <= spi_clk_vld_i & rcrc_en & ~en_restart;
            rcrc7_r       <= (rx_pos_sample)? rcrc7_nxt : rcrc7_r;
            crc_ok        <= rx_byte_done & (rdata_8b_r == rcrc7_dat);
          end
          else begin
            // CRC calculation in command line starts after Start and T-bit (2 clock cycles)
            det_rx_start  <= det_rx_start | (rx_pos_sample & spi_sample_valid & rx_stb & ~spi_dti_pos[0]);
            rcrc_en       <= det_rx_start & rx_pos_sample & (~en_crc_rsp_type2 | (bit_cntr_rx[2:0] == 3'd7)) & ~en_restart; // in R2 response, the first byte is excluded in CRC
            rcrc7_r       <= (~en_crc_rsp_type2 & spi_dti_pos[0])? 7'd9 : 7'd0;  // CRC value after input bits 2'b01 or 2'b00 (Start and T-bit)
            crc_ok        <= 1'b0;
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--

    end // gen_crc7
  end // gen_crc_gen

  else begin : gen_nocrc_gen
    assign tx_data_w      = set_databit_swap(tx_data,tx_io_width_w,csr_spi_lsbf);
    assign wdata_crc_all  = wdata_bus_nxt;
    assign rx_crc_ok      = 1'b0;
  end // gen_nocrc_gen

  if(EN_DDR_MODE) begin : gen_ddr
    reg           [SPI_WID-1:0]       spi_dout_r;
    reg           [2:0]               io_width_q;
    reg                               ddr_mode_q;
    reg                               clk_valid_q;
    reg                               pp1_od0_q;
    reg                               dout_en_q;
    reg                               crc_en_q;
    reg                               dc_en_q;
    reg                               dlast_q;

    wire          [SPI_WID-1:0]       spi_dout_x32;

    assign en_clk_gen     = (tx_spi_ckp)? clk_valid_r : clk_valid_q;

    assign spi_dto        = spi_dout_r;
    assign spi_doe        = dout_en_q;
    assign spi_clk_vld_o  = clk_valid_q;
    assign spi_pp1_od0    = pp1_od0_q;
    assign spi_crc_en     = crc_en_q;
    assign spi_dc_en      = dc_en_q;
    assign spi_dlast_o    = dlast_q;
    assign spi_io_width_o = io_width_q;
    assign spi_ddr_mode_o = ddr_mode_q;

    assign en_ddr        = ddr_mode_r;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        dlast_q <= 1'd1;
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        clk_valid_q <= 1'h0;
        crc_en_q <= 1'h0;
        dc_en_q <= 1'h0;
        ddr_mode_q <= 1'h0;
        dout_en_q <= 1'h0;
        io_width_q <= 3'h0;
        pp1_od0_q <= 1'h0;
        // End of automatics
      end
      else begin
        if(tx_spi_ckp) begin
          clk_valid_q   <= clk_valid_r;
          pp1_od0_q     <= pp1_od0_r;
          crc_en_q      <= crc_en_r;
          dc_en_q       <= dc_en_r;
          dlast_q       <= dlast_r;
          dout_en_q     <= dout_en_r;
          io_width_q    <= io_width_r;
          ddr_mode_q    <= ddr_mode_r;
        end
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--

    assign spi_dout_x32 = (EN_SPI_X32 && (io_width_r == 3'd5))? ({SPI_WID{1'b1}} & wdata_r[0+:SPI_WID]) : {SPI_WID{1'b0}};

    if(EN_DDR_WIDE) begin : gen_wide
      wire          [SPI_WID-1:0]       spi_dout_x01;
      wire          [SPI_WID-1:0]       spi_dout_x02;
      wire          [SPI_WID-1:0]       spi_dout_x04;
      wire          [SPI_WID-1:0]       spi_dout_x08;
      wire          [SPI_WID-1:0]       spi_dout_x16;

      wire          [SPI_WID-1:0]       spi_dout_nxt;

      assign spi_sample_valid = spi_clk_vld_i;
      assign rx_ddr_mode      = spi_ddr_mode_i;
      assign rx_crc_en        = spi_crc_en_i;
      assign rx_dlast         = spi_dlast_i;
      assign rx_io_width      = spi_io_width_i;

      assign spi_dti_pos = spi_dti[   0+:SWID];
      assign spi_dti_neg = spi_dti[SWID+:SWID];

      assign rx_pos_sample    = rx_spi_ckp;
      assign rx_neg_sample    = 1'b0;       // no negedge sampling in DDR Wide since both are available

      // ddr data low
      assign spi_dout_x01[   0+:SWID] = (EN_SPI_X1  && (io_width_r == SPI_X1 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 0+: 1]} : {SWID{1'b0}};
      assign spi_dout_x02[   0+:SWID] = (EN_SPI_X2  && (io_width_r == SPI_X2 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 0+: 2]} : {SWID{1'b0}};
      assign spi_dout_x04[   0+:SWID] = (EN_SPI_X4  && (io_width_r == SPI_X4 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 0+: 4]} : {SWID{1'b0}};
      assign spi_dout_x08[   0+:SWID] = (EN_SPI_X8  && (io_width_r == SPI_X8 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 0+: 8]} : {SWID{1'b0}};
      assign spi_dout_x16[   0+:SWID] = (EN_SPI_X16 && (io_width_r == SPI_X16))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 0+:16]} : {SWID{1'b0}};
      // ddr data high
      assign spi_dout_x01[SWID+:SWID] = (EN_SPI_X1  && (io_width_r == SPI_X1 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 1+: 1]} : {SWID{1'b0}};
      assign spi_dout_x02[SWID+:SWID] = (EN_SPI_X2  && (io_width_r == SPI_X2 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 2+: 2]} : {SWID{1'b0}};
      assign spi_dout_x04[SWID+:SWID] = (EN_SPI_X4  && (io_width_r == SPI_X4 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 4+: 4]} : {SWID{1'b0}};
      assign spi_dout_x08[SWID+:SWID] = (EN_SPI_X8  && (io_width_r == SPI_X8 ))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[ 8+: 8]} : {SWID{1'b0}};
      assign spi_dout_x16[SWID+:SWID] = (EN_SPI_X16 && (io_width_r == SPI_X16))? {SWID{1'b1}} & {{(SWID){SHIFT_VALUE}},wdata_r[16+:16]} : {SWID{1'b0}};

      assign spi_dout_nxt = spi_dout_x01 |
                            spi_dout_x02 |
                            spi_dout_x04 |
                            spi_dout_x08 |
                            spi_dout_x16;
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          spi_dout_r <= {SPI_WID{SHIFT_VALUE}};
          /*AUTORESET*/
        end
        else begin
          if(tx_spi_ckp) begin
            spi_dout_r <= ((ddr_mode_r)? spi_dout_nxt : {2{spi_dout_nxt[0+:SWID]}}) |
                          spi_dout_x32;
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_wide
    else begin : gen_nowide
      reg           [SWID-1:0]          spi_dti_pos_r;
      reg           [SWID-1:0]          spi_dti_neg_r;
      reg           [SWID-1:0]          spi_dout_h_r;
      reg                               spi_clk_valid_r;
      reg                               spi_ddr_mode_r;
      reg           [2:0]               spi_io_width_r;
      reg                               spi_crc_en_r;
      reg                               spi_dlast_r;
      reg                               rx_spi_ckp_r;
      reg                               rx_spi_ckn_r;

      wire          [SPI_WID-1:0]       spi_dout_l_x01;
      wire          [SPI_WID-1:0]       spi_dout_l_x02;
      wire          [SPI_WID-1:0]       spi_dout_l_x04;
      wire          [SPI_WID-1:0]       spi_dout_l_x08;
      wire          [SPI_WID-1:0]       spi_dout_l_x16;

      wire          [SPI_WID-1:0]       spi_dout_h_x01;
      wire          [SPI_WID-1:0]       spi_dout_h_x02;
      wire          [SPI_WID-1:0]       spi_dout_h_x04;
      wire          [SPI_WID-1:0]       spi_dout_h_x08;
      wire          [SPI_WID-1:0]       spi_dout_h_x16;

      assign spi_sample_valid = spi_clk_valid_r;
      assign rx_ddr_mode      = spi_ddr_mode_r;
      assign rx_crc_en        = spi_crc_en_r;
      assign rx_dlast         = spi_dlast_r;
      assign rx_io_width      = spi_io_width_r;

      assign spi_dti_pos = spi_dti_pos_r;
      assign spi_dti_neg = spi_dti_neg_r;

      assign rx_pos_sample      = (BUS_WID == 8 && EN_SPI_X8 && EN_DDR_X8 && rx_ddr_mode && (rx_io_width == SPI_X8))? rx_spi_ckp_r : rx_spi_ckp;
      assign rx_neg_sample      = (BUS_WID == 8 && EN_SPI_X8 && EN_DDR_X8 && rx_ddr_mode && (rx_io_width == SPI_X8))? rx_spi_ckn_r : 1'b0;

      // ddr data low
      assign spi_dout_l_x01 = (EN_SPI_X1  && (io_width_r == SPI_X1 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 0+: 1]} : {SPI_WID{1'b0}};
      assign spi_dout_l_x02 = (EN_SPI_X2  && (io_width_r == SPI_X2 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 0+: 2]} : {SPI_WID{1'b0}};
      assign spi_dout_l_x04 = (EN_SPI_X4  && (io_width_r == SPI_X4 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 0+: 4]} : {SPI_WID{1'b0}};
      assign spi_dout_l_x08 = (EN_SPI_X8  && (io_width_r == SPI_X8 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 0+: 8]} : {SPI_WID{1'b0}};
      assign spi_dout_l_x16 = (EN_SPI_X16 && (io_width_r == SPI_X16))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 0+:16]} : {SPI_WID{1'b0}};
      // ddr data high
      assign spi_dout_h_x01 = (EN_SPI_X1  && (io_width_r == SPI_X1 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 1+: 1]} : {SPI_WID{1'b0}};
      assign spi_dout_h_x02 = (EN_SPI_X2  && (io_width_r == SPI_X2 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 2+: 2]} : {SPI_WID{1'b0}};
      assign spi_dout_h_x04 = (EN_SPI_X4  && (io_width_r == SPI_X4 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 4+: 4]} : {SPI_WID{1'b0}};
      assign spi_dout_h_x08 = (EN_SPI_X8  && (io_width_r == SPI_X8 ))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[ 8+: 8]} : {SPI_WID{1'b0}};
      assign spi_dout_h_x16 = (EN_SPI_X16 && (io_width_r == SPI_X16))? {SPI_WID{1'b1}} & {{(SPI_WID){SHIFT_VALUE}},wdata_r[16+:16]} : {SPI_WID{1'b0}};
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          spi_dout_h_r  <= {SWID{SHIFT_VALUE}};
          spi_dout_r    <= {SPI_WID{SHIFT_VALUE}};
          /*AUTORESET*/
        end
        else begin
          if(tx_spi_ckp) begin
            spi_dout_r    <= spi_dout_l_x01 |
                             spi_dout_l_x02 |
                             spi_dout_l_x04 |
                             spi_dout_l_x08 |
                             spi_dout_l_x16 |
                             spi_dout_x32;

            spi_dout_h_r  <= spi_dout_h_x01 |
                             spi_dout_h_x02 |
                             spi_dout_h_x04 |
                             spi_dout_h_x08 |
                             spi_dout_h_x16 |
                             spi_dout_x32;
          end
          else if(ddr_mode_q & tx_spi_ckn) begin
            spi_dout_r <= spi_dout_h_r;
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          spi_dti_neg_r <= {SWID{SHIFT_VALUE}};
          spi_dti_pos_r <= {SWID{SHIFT_VALUE}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rx_spi_ckn_r <= 1'h0;
          rx_spi_ckp_r <= 1'h0;
          spi_clk_valid_r <= 1'h0;
          spi_crc_en_r <= 1'h0;
          spi_ddr_mode_r <= 1'h0;
          spi_dlast_r <= 1'h0;
          spi_io_width_r <= 3'h0;
          // End of automatics
        end
        else begin
          rx_spi_ckp_r <= rx_spi_ckp;
          rx_spi_ckn_r <= rx_spi_ckn;
          if(rx_spi_ckp) begin
            spi_dti_pos_r   <= spi_dti;
            spi_clk_valid_r <= spi_clk_vld_i;
            spi_ddr_mode_r  <= spi_ddr_mode_i;
            spi_crc_en_r    <= spi_crc_en_i;
            spi_dlast_r     <= spi_dlast_i;
            spi_io_width_r  <= spi_io_width_i;
          end
          else if(spi_ddr_mode_i & rx_spi_ckn) begin
            spi_dti_neg_r <= spi_dti;
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_nowide
  end // gen_ddr
  else begin : gen_sdr
    assign en_clk_gen       = (en_load_wdat )? 1'b1 :
                              (en_shift_wdat)? ((|bit_cntr)? clk_valid_r : |byt_cntr_w) :
                                               clk_valid_r;

    assign spi_dto          = wdata_r[0+:SPI_WID];
    assign spi_doe          = dout_en_r;
    assign spi_clk_vld_o    = clk_valid_r;
    assign spi_crc_en       = crc_en_r;
    assign spi_dc_en        = dc_en_r;
    assign spi_pp1_od0      = pp1_od0_r;
    assign spi_dlast_o      = dlast_r;
    assign spi_io_width_o   = io_width_r;
    assign spi_ddr_mode_o   = ddr_mode_r;
    assign spi_dti_pos      = spi_dti;
    assign spi_dti_neg      = spi_dti;
    assign spi_sample_valid = spi_clk_vld_i;
    assign en_ddr           = 1'b0;
    assign rx_ddr_mode      = 1'b0;
    assign rx_crc_en        = spi_crc_en_i;
    assign rx_dlast         = spi_dlast_i;
    assign rx_io_width      = spi_io_width_i;
    assign rx_pos_sample    = rx_spi_ckp;
    assign rx_neg_sample    = 1'b0;       // no negedge sampling in SDR
  end // gen_sdr

  case(BUS_WID)
    8       : begin : gen_08b
      // x1,x2,x4: SDR,DDR
      // x8: SDR
      reg           [7:0]               rx_data_r;
      reg                               rx_valid_r;

      assign rx_valid      = rx_valid_r;
      assign rx_data       = rx_data_r;

      assign rdata_16_hi   = {8{1'b1}};
      assign rdata_32_hi   = {16{1'b1}};

      assign wdata_x01_nxt = (EN_DDR_X1  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r,2,2,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r,1,1,en_rotate,shift_value);
      assign wdata_x02_nxt = (EN_DDR_X2  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r,4,4,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r,2,2,en_rotate,shift_value);
      assign wdata_x04_nxt = (EN_DDR_X4  && en_ddr)? tx_data_w                                             : `DOUT_SHIFT_ROTATE(wdata_r,4,4,en_rotate,shift_value);
      assign wdata_x08_nxt = tx_data_w;
      assign wdata_x16_nxt = {BUS_WID{1'b0}};
      assign wdata_x32_nxt = {BUS_WID{1'b0}};

      assign byt_cntr_w = {2{gnd_wire}};
      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        dlast_nxt    = ~gnd_wire;
        byt_cntr_nxt = {2{gnd_wire}};
      end //--always @*--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          rx_data_r <= {8{1'b1}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rx_valid_r <= 1'h0;
          // End of automatics
        end
        else begin
          rx_valid_r <= rx_byte_done;
          rx_data_r <= rdata_8b_r;
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_08b

    16      : begin : gen_16b
      // x1,x2,x4,x8: SDR,DDR
      // x16: SDR
      reg           [7:0]               rdata_16_hi_r;
      reg                               rx_byt_ptr;
      reg           [15:0]              rx_data_pipe;
      reg                               rx_valid_r;

      assign rx_data  = rx_data_pipe;
      assign rx_valid = rx_valid_r;

      assign rdata_16_hi   = rdata_16_hi_r;
      assign rdata_32_hi   = {16{1'b1}};

      assign wdata_x01_nxt = (EN_DDR_X1  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r,2,2,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r,1,1,en_rotate,shift_value);
      assign wdata_x02_nxt = (EN_DDR_X2  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r,4,4,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r,2,2,en_rotate,shift_value);
      assign wdata_x04_nxt = (EN_DDR_X4  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r,8,8,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r,4,4,en_rotate,shift_value);
      assign wdata_x08_nxt = (EN_DDR_X8  && en_ddr)? tx_data_w                                             : `DOUT_SHIFT_ROTATE(wdata_r,8,8,en_rotate,shift_value);
      assign wdata_x16_nxt = tx_data_w;
      assign wdata_x32_nxt = {BUS_WID{1'b0}};

      assign byt_cntr_w = {1'b0,byt_cntr[0]};
      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        dlast_nxt    = dlast_r;
        byt_cntr_nxt = {1'b0,byt_cntr[0]};
        if(en_load_wdat) begin
          // x8 SDR: 1 cycle/byte
          // x8 DDR: 1 cycle/2 bytes
          dlast_nxt    = (tx_last_byte == 2'd0);
          byt_cntr_nxt = (tx_dc_en)? 2'd0 :
                         ({2{tx_width_1hot[0]}} & {1'b0,((EN_DDR_X1 && tx_ddr_mode_w)? 1'b0 : tx_last_byte[0])}) |
                         ({2{tx_width_1hot[1]}} & {1'b0,((EN_DDR_X2 && tx_ddr_mode_w)? 1'b0 : tx_last_byte[0])}) |
                         ({2{tx_width_1hot[2]}} & {1'b0,((EN_DDR_X4 && tx_ddr_mode_w)? 1'b0 : tx_last_byte[0])}) |
                         ({2{tx_width_1hot[3]}} & {1'b0,((EN_DDR_X8 && tx_ddr_mode_w)? 1'b0 : tx_last_byte[0])});
        end
        else if(en_shift_wdat & (~|bit_cntr)) begin
          dlast_nxt    = ~byt_cntr[1];
          byt_cntr_nxt = byt_cntr - {1'd0,|byt_cntr};
        end
      end //--always @*--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          rx_data_pipe <= {16{1'b1}};
          rdata_16_hi_r <= {8{1'b1}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rx_byt_ptr <= 1'h0;
          rx_valid_r <= 1'h0;
          // End of automatics
        end
        else begin
          rdata_16_hi_r <= rdata_16_nxt;
          if(rx_byte_done) begin
            rx_byt_ptr <= (rx_data_last)? 1'b0 : ~rx_byt_ptr;
          end
          else if(rx_word_done) begin
            rx_byt_ptr <= 1'b0;
          end

          rx_valid_r <= (rx_byte_done | rx_word_done) & rx_data_last;
          case(rx_byt_ptr)
            2'd1    : rx_data_pipe <= (rx_byte_done)? {rdata_8b_r,rx_data_pipe[8*0+:8*1]} :
                                                      rx_data_pipe;
            default : rx_data_pipe <= (rx_byte_done)? {rx_data_pipe[8*1+:8*1],rdata_8b_r} :
                                      (rx_word_done)? {rdata_16_hi,rdata_8b_r} :
                                                      rx_data_pipe;
          endcase
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--

    end // gen_16b

    default : begin : gen_32b
      // x1,x2,x4,x8,x16: SDR,DDR
      // x32: SDR
      reg           [15:0]              rdata_32_hi_r;
      reg           [7:0]               rdata_16_hi_r;
      reg           [1:0]               rx_byt_ptr;
      reg           [31:0]              rx_data_pipe;
      reg                               rx_valid_r;

      assign rx_data  = rx_data_pipe;
      assign rx_valid = rx_valid_r;

      assign rdata_16_hi   = rdata_16_hi_r;
      assign rdata_32_hi   = rdata_32_hi_r;

      assign wdata_x01_nxt = (EN_DDR_X1  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r, 2, 2,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r, 1, 1,en_rotate,shift_value);
      assign wdata_x02_nxt = (EN_DDR_X2  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r, 4, 4,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r, 2, 2,en_rotate,shift_value);
      assign wdata_x04_nxt = (EN_DDR_X4  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r, 8, 8,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r, 4, 4,en_rotate,shift_value);
      assign wdata_x08_nxt = (EN_DDR_X8  && en_ddr)? `DOUT_SHIFT_ROTATE(wdata_r,16,16,en_rotate,shift_value) : `DOUT_SHIFT_ROTATE(wdata_r, 8, 8,en_rotate,shift_value);
      assign wdata_x16_nxt = (EN_DDR_X16 && en_ddr)? tx_data_w                                               : `DOUT_SHIFT_ROTATE(wdata_r,16,16,en_rotate,shift_value);
      assign wdata_x32_nxt = tx_data_w;

      assign byt_cntr_w = byt_cntr;
      //--------------------------------------------
      //-- Combinatorial block --
      //--------------------------------------------
      always @* begin
        dlast_nxt    = dlast_r;
        byt_cntr_nxt = byt_cntr;
        if(en_load_wdat) begin
          dlast_nxt    = (tx_last_byte == 2'd0) |
                         (tx_width_1hot[3] & (((EN_DDR_X8  && tx_ddr_mode_w)? {1'b0,tx_last_byte[1]} : tx_last_byte) == 2'd0)) |
                         (tx_width_1hot[4] & ~((EN_DDR_X16 && tx_ddr_mode_w)? 1'b0 : tx_last_byte[1])) |
                         (tx_width_1hot[5]);
          byt_cntr_nxt = (tx_dc_en)? 2'd0 :
                         ({2{tx_width_1hot[0]}} & tx_last_byte) |
                         ({2{tx_width_1hot[1]}} & tx_last_byte) |
                         ({2{tx_width_1hot[2]}} & tx_last_byte) |
                         ({2{tx_width_1hot[3]}} & ((EN_DDR_X8  && tx_ddr_mode_w)? {1'b0,tx_last_byte[1]} : tx_last_byte)) |
                         ({2{tx_width_1hot[4]}} & {1'b0,((EN_DDR_X16 && tx_ddr_mode_w)? 1'b0 : tx_last_byte[1])});
        end
        else if(en_shift_wdat & (~|bit_cntr)) begin
          dlast_nxt    = ~byt_cntr[1];
          byt_cntr_nxt = byt_cntr - {1'd0,|byt_cntr};
        end
      end //--always @*--

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          rdata_16_hi_r <= {8{1'b1}};
          rdata_32_hi_r <= {16{1'b1}};
          rx_data_pipe  <= {32{1'b1}};
          rx_byt_ptr    <= 2'd0;
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rx_valid_r <= 1'h0;
          // End of automatics
        end
        else begin
          rdata_16_hi_r <= rdata_16_nxt;
          rdata_32_hi_r <= rdata_32_nxt;
          if(rx_byte_done) begin
            rx_byt_ptr <= (rx_data_last)? 2'd0 : (rx_byt_ptr + 2'd1);
          end
          else if(rx_word_done) begin
            rx_byt_ptr <= (rx_data_last)? 2'd0 : (rx_byt_ptr + 2'd2);
          end
          else if(rx_dt32_done) begin
            rx_byt_ptr <= 2'd0;
          end

          rx_valid_r <= (rx_byte_done | rx_word_done | rx_dt32_done) & rx_data_last;
          case(rx_byt_ptr)
            2'd1    : rx_data_pipe <= (rx_byte_done)? {rx_data_pipe[8*2+:8*2],rdata_8b_r,rx_data_pipe[8*0+:8*1]} :
                                                      rx_data_pipe;
            2'd2    : rx_data_pipe <= (rx_byte_done)? {rx_data_pipe[8*3+:8*1],rdata_8b_r,rx_data_pipe[8*0+:8*2]} :
                                      (rx_word_done)? {rdata_16_hi,rdata_8b_r,rx_data_pipe[8*0+:8*2]} :
                                                      rx_data_pipe;
            2'd3    : rx_data_pipe <= (rx_byte_done)? {rdata_8b_r,rx_data_pipe[8*0+:8*3]} :
                                                      rx_data_pipe;
            default : rx_data_pipe <= (rx_byte_done)? {rx_data_pipe[8*1+:8*3],rdata_8b_r} :
                                      (rx_word_done)? {rx_data_pipe[8*2+:8*2],rdata_16_hi,rdata_8b_r} :
                                      (rx_dt32_done)? {rdata_32_hi,rdata_16_hi,rdata_8b_r} :
                                                      rx_data_pipe;
          endcase
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_32b
  endcase

  case(SWID)
    2       : begin : gen_io_x02
      assign spidat_sdr_01_in = spi_dti_pos[0+: 1];
      assign spidat_sdr_02_in = spi_dti_pos[0+: 2];
      assign spidat_sdr_04_in = 4'd0;
      assign spidat_sdr_08_in = 8'd0;
      assign spidat_sdr_16_in = 16'd0;
      assign spidat_sdr_32_in = 32'd0;

      assign spidat_ddr_01_in = {spi_dti_pos[0+: 1],spi_dti_neg[0+: 1]}; // pos data is first bit
      assign spidat_ddr_02_in = {spi_dti_pos[0+: 2],spi_dti_neg[0+: 2]}; // pos data is first bit
      assign spidat_ddr_04_in = 8'd0;
      assign spidat_ddr_08_in = 16'd0;
      assign spidat_ddr_16_in = 32'd0;
      assign spidat_ddr_32_in = 32'd0;
    end // gen_io_x02

    4       : begin : gen_io_x04
      assign spidat_sdr_01_in = spi_dti_pos[0+: 1];
      assign spidat_sdr_02_in = spi_dti_pos[0+: 2];
      assign spidat_sdr_04_in = spi_dti_pos[0+: 4];
      assign spidat_sdr_08_in = 8'd0;
      assign spidat_sdr_16_in = 16'd0;
      assign spidat_sdr_32_in = 32'd0;

      assign spidat_ddr_01_in = {spi_dti_pos[0+: 1],spi_dti_neg[0+: 1]}; // pos data is first bit
      assign spidat_ddr_02_in = {spi_dti_pos[0+: 2],spi_dti_neg[0+: 2]}; // pos data is first bit
      assign spidat_ddr_04_in = {spi_dti_pos[0+: 4],spi_dti_neg[0+: 4]}; // pos data is first bit
      assign spidat_ddr_08_in = 16'd0;
      assign spidat_ddr_16_in = 32'd0;
      assign spidat_ddr_32_in = 32'd0;
    end // gen_io_x04

    8       : begin : gen_io_x08
      assign spidat_sdr_01_in = spi_dti_pos[0+: 1];
      assign spidat_sdr_02_in = spi_dti_pos[0+: 2];
      assign spidat_sdr_04_in = spi_dti_pos[0+: 4];
      assign spidat_sdr_08_in = spi_dti_pos[0+: 8];
      assign spidat_sdr_16_in = 16'd0;
      assign spidat_sdr_32_in = 32'd0;

      assign spidat_ddr_01_in = {spi_dti_pos[0+: 1],spi_dti_neg[0+: 1]}; // pos data is first bit
      assign spidat_ddr_02_in = {spi_dti_pos[0+: 2],spi_dti_neg[0+: 2]}; // pos data is first bit
      assign spidat_ddr_04_in = {spi_dti_pos[0+: 4],spi_dti_neg[0+: 4]}; // pos data is first bit
      assign spidat_ddr_08_in = {spi_dti_neg[0+: 8],spi_dti_pos[0+: 8]}; // pos data is first byte
      assign spidat_ddr_16_in = 32'd0;
      assign spidat_ddr_32_in = 32'd0;
    end // gen_io_x08

    16      : begin : gen_io_x16
      assign spidat_sdr_01_in = spi_dti_pos[0+: 1];
      assign spidat_sdr_02_in = spi_dti_pos[0+: 2];
      assign spidat_sdr_04_in = spi_dti_pos[0+: 4];
      assign spidat_sdr_08_in = spi_dti_pos[0+: 8];
      assign spidat_sdr_16_in = spi_dti_pos[0+:16];
      assign spidat_sdr_32_in = 32'd0;

      assign spidat_ddr_01_in = {spi_dti_pos[0+: 1],spi_dti_neg[0+: 1]}; // pos data is first bit
      assign spidat_ddr_02_in = {spi_dti_pos[0+: 2],spi_dti_neg[0+: 2]}; // pos data is first bit
      assign spidat_ddr_04_in = {spi_dti_pos[0+: 4],spi_dti_neg[0+: 4]}; // pos data is first bit
      assign spidat_ddr_08_in = {spi_dti_neg[0+: 8],spi_dti_pos[0+: 8]}; // pos data is first byte
      assign spidat_ddr_16_in = {spi_dti_neg[0+:16],spi_dti_pos[0+:16]};
      assign spidat_ddr_32_in = 32'd0;
    end // gen_io_x16

    32      : begin : gen_io_x32
      assign spidat_sdr_01_in = spi_dti_pos[0+: 1];
      assign spidat_sdr_02_in = spi_dti_pos[0+: 2];
      assign spidat_sdr_04_in = spi_dti_pos[0+: 4];
      assign spidat_sdr_08_in = spi_dti_pos[0+: 8];
      assign spidat_sdr_16_in = spi_dti_pos[0+:16];
      assign spidat_sdr_32_in = spi_dti_pos[0+:32];

      assign spidat_ddr_01_in = {spi_dti_pos[0+: 1],spi_dti_neg[0+: 1]}; // pos data is first bit
      assign spidat_ddr_02_in = {spi_dti_pos[0+: 2],spi_dti_neg[0+: 2]}; // pos data is first bit
      assign spidat_ddr_04_in = {spi_dti_pos[0+: 4],spi_dti_neg[0+: 4]}; // pos data is first bit
      assign spidat_ddr_08_in = {spi_dti_neg[0+: 8],spi_dti_pos[0+: 8]}; // pos data is first byte
      assign spidat_ddr_16_in = {spi_dti_neg[0+:16],spi_dti_pos[0+:16]};
      assign spidat_ddr_32_in = spi_dti_pos[0+:32];
    end // gen_io_x32

    default : begin : gen_io_x01
      assign spidat_sdr_01_in = spi_dti_pos[0+: 1];
      assign spidat_sdr_02_in = 2'd0;
      assign spidat_sdr_04_in = 4'd0;
      assign spidat_sdr_08_in = 8'd0;
      assign spidat_sdr_16_in = 16'd0;
      assign spidat_sdr_32_in = 32'd0;

      assign spidat_ddr_01_in = {spi_dti_pos[0+: 1],spi_dti_neg[0+: 1]}; // pos data is first bit
      assign spidat_ddr_02_in = 4'd0;
      assign spidat_ddr_04_in = 8'd0;
      assign spidat_ddr_08_in = 16'd0;
      assign spidat_ddr_16_in = 32'd0;
      assign spidat_ddr_32_in = 32'd0;
    end // gen_io_x01
  endcase
endgenerate

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------



endmodule //--emmc_serdes--
`endif // __RTL_MODULE__EMMC_SERDES__
