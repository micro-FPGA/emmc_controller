// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_CSR__
`define __RTL_MODULE__EMMC_CSR__
//==========================================================================
// Module : emmc_csr
//==========================================================================
module emmc_csr #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                      SIMULATION      = 0
,parameter                      USE_CLKDIV1     = 0
,parameter                      CLKDIV_WID      = 8            // must be able to generate 400KHz,
                                                               // (e.g 200MHz input clock divided by (2*250 pulse width) = 400 KHz)
,parameter    [CLKDIV_WID-1:0]  DEFAULT_RATE    = {{(CLKDIV_WID-1){1'b0}},1'b1}

,parameter                      EN_RSPTYP_DEC   = 1            // enable response type decoding
,parameter                      EN_AUTO_CMD     = 0            // enable generation of some commands via trigger
,parameter                      EN_DDR_MODE     = 0

,parameter                      DEF_BLOCK_SIZE  = 512
,parameter                      MAX_BLOCK_SIZE  = 4096
,parameter                      MAX_NUM_BLOCK   = 65536

,parameter                      TMR_WIDTH       = 8
) //--end_param--

( //--begin_ports--
 input                          clk_i
,input                          rst_n_i

,input                          det_emmc_start
,input                          det_emmc_done
,input                          det_cmd_crc_err
,input                          det_pld_crc_err
,input                          det_bus_wr_error
,input                          det_bus_rd_error
,input                          det_rsp_timeout
,input                          det_dat_timeout

,input        [3*8-1:0]         debug_dat_line
,input        [3*1-1:0]         debug_cmd_line

,input        [5:0]             info_rsp_b0
,input        [31:0]            info_rsp_dat0
,input        [31:0]            info_rsp_dat1
,input        [31:0]            info_rsp_dat2
,input        [31:0]            info_rsp_dat3

,output wire  [CLKDIV_WID-1:0]  csr_clk_div             // 0 - div1, 1 - div2, 2 - div4, 3 - div6,...

,output wire                    csr_emmc_pp1_od0        // 0 - open-drain mode, 1 - push-pull mode
,output wire                    csr_emmc_ddr_mode       // 0 - SDR mode, 1 - DDR mode
,output wire  [1:0]             csr_emmc_io_width       // 0 - x1, 1 - (x2)rsvd, 2 - x4, 3 - x8

,output wire                    csr_emmc_send_select
,output wire                    csr_emmc_send_deselect
,output wire                    csr_emmc_send_stop
,output wire  [3:0]             csr_emmc_block_len      // 0 - 1 byte, 1 - 2 bytes,...,8- 256 bytes, 9 - 512 bytes,..., 14 - 16KB
,output wire  [15:0]            csr_emmc_num_blocks     // 0 - no data, 1 - 1 data block, 2 - 2 data blocks,...,
,output wire  [5:0]             csr_emmc_cmd_idx
,output wire  [2:0]             csr_emmc_rsp_typ        // 0 - no response, 1 - R1, 2 - R2,..., 5 - R5
,output wire  [31:0]            csr_emmc_cmd_arg
,output wire                    csr_emmc_cmd_boot       // boot mode
,output wire                    csr_emmc_cmd_start
,output wire  [31:0]            csr_src_dst_addr

,output wire  [15:0]            csr_cmd_timeout
,output wire  [15:0]            csr_dat_timeout

,output wire                    csr_emmc_rst
,output wire                    csr_ip_core_rst

// from bus interface
,input        [3:0]             csr_wren            // write enable per byte
,input        [7:0]             csr_wadr            // write dword address
,input        [31:0]            csr_wdat            // write data

,input                          csr_rden            // read enable
,input        [7:0]             csr_radr            // read dword address

,output wire  [31:0]            csr_rdat            // read data
,output wire                    csr_rvld            // read data valid

,output reg                     int_csr             /* synthesis syn_preserve=1 */

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                      REG_CSRDAT  = 1;
localparam                      BLKCNTWID   = $clog2(MAX_NUM_BLOCK);
localparam                      BLOCK_LEN   = $clog2(DEF_BLOCK_SIZE);

localparam                      RSP_R0 = 3'd0
                               ,RSP_R1 = 3'd1
                               ,RSP_R2 = 3'd2
                               ,RSP_R3 = 3'd3
                               ,RSP_R4 = 3'd4
                               ,RSP_R5 = 3'd5
                               ;

// ---------------------------------------------------
// Register Mapping
// addr[7:6] | Register block
// ---------------------------------------------------
// 2'd0      | Configuration Registers (0x00 - 0x3F)
// 2'd1      | Status Registers        (0x40 - 0x7F)
// 2'd2      | Control Registers       (0x80 - 0xBF)
// 2'd3      | Reserved                (0xC0 - 0xFF)
// ---------------------------------------------------

//----------------------------------------------------------------
// DWORD Offset mapping
//----------------------------------------------------------------
                               // Configuration registers
localparam                      ADR_EMMC_ID       = {2'd0,6'h00}
                               ,ADR_EMMC_INT_ENA  = {2'd0,6'h01}
                               ,ADR_EMMC_CFG0     = {2'd0,6'h02}
                               ,ADR_EMMC_CFG1     = {2'd0,6'h03}
                               // Status registers
                               ,ADR_EMMC_INFO_STS = {2'd1,6'h00}
                               ,ADR_EMMC_INT_STS  = {2'd1,6'h01}
                               ,ADR_EMMC_RESP_D0  = {2'd1,6'h02}
                               ,ADR_EMMC_RESP_D1  = {2'd1,6'h03}
                               ,ADR_EMMC_RESP_D2  = {2'd1,6'h04}
                               ,ADR_EMMC_RESP_D3  = {2'd1,6'h05}
                               ,ADR_EMMC_RESP_D4  = {2'd1,6'h06}
                               // Control registers
                               ,ADR_EMMC_SOFTRST  = {2'd2,6'h00}
                               ,ADR_EMMC_INT_SET  = {2'd2,6'h01}
                               ,ADR_EMMC_SRC_DST  = {2'd2,6'h02}
                               ,ADR_EMMC_CTRL0    = {2'd2,6'h03}
                               ,ADR_EMMC_CTRL1    = {2'd2,6'h04}
                               ,ADR_EMMC_CTRL2    = {2'd2,6'h05}
                               ;

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
wire                            gnd_wire;

wire          [31:0]            int_trigger;
wire          [31:0]            emmc_ip_id;

wire          [3:0]             wrsel_emmc_cfg0    ;
wire          [3:0]             wrsel_emmc_cfg1    ;
wire          [3:0]             wrsel_emmc_int_ena ;
wire          [3:0]             wrsel_emmc_int_sts ;
wire          [3:0]             wrsel_emmc_int_set ;
wire          [3:0]             wrsel_emmc_softrst ;
wire          [3:0]             wrsel_emmc_src_dst ;
wire          [3:0]             wrsel_emmc_ctrl0   ;
wire          [3:0]             wrsel_emmc_ctrl1   ;
wire          [3:0]             wrsel_emmc_ctrl2   ;

wire          [31:0]            emmc_cfg0_nxt      ;
wire          [31:0]            emmc_cfg1_nxt      ;
wire          [31:0]            emmc_int_ena_nxt   ;
wire          [31:0]            emmc_int_sts_nxt   ;
wire          [31:0]            emmc_softrst_nxt   ;
wire          [31:0]            emmc_src_dst_nxt   ;
wire          [31:0]            emmc_ctrl0_nxt     ;
wire          [31:0]            emmc_ctrl1_nxt     ;
wire          [31:0]            emmc_ctrl2_nxt     ;

wire          [31:0]            emmc_cfg0          ;
wire          [31:0]            emmc_cfg1          ;
wire          [31:0]            emmc_int_ena       ;
wire          [31:0]            emmc_int_sts       ;
wire          [31:0]            emmc_info_sts      ;
wire          [31:0]            emmc_softrst       ;
wire          [31:0]            emmc_src_dst       ;
wire          [31:0]            emmc_ctrl0         ;
wire          [31:0]            emmc_ctrl1         ;
wire          [31:0]            emmc_ctrl2         ;

wire          [15:0]            emmc_num_blocks_w;
wire          [15:0]            cmd_timeout_w;
wire          [15:0]            dat_timeout_w;

reg           [31:0]            csr_rdat_nxt;
//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [CLKDIV_WID-1:0]  clk_div;
reg                             pp1_od0;
reg                             ddr_mode;
reg           [1:0]             io_width;

reg           [TMR_WIDTH-1:0]   cmd_timeout;
reg           [TMR_WIDTH-1:0]   dat_timeout;

reg                             int_ena_cmd_done    ;
reg                             int_ena_cmd_crc_err ;
reg                             int_ena_dat_crc_err ;
reg                             int_ena_bus_wr_err  ;
reg                             int_ena_bus_rd_err  ;
reg                             int_ena_cmd_timeout ;
reg                             int_ena_dat_timeout ;

reg                             int_sts_cmd_done    ;
reg                             int_sts_cmd_crc_err ;
reg                             int_sts_dat_crc_err ;
reg                             int_sts_bus_wr_err  ;
reg                             int_sts_bus_rd_err  ;
reg                             int_sts_cmd_timeout ;
reg                             int_sts_dat_timeout ;

reg                             emmc_tgt_rst;
reg                             ip_core_rst;

reg           [2:0]             emmc_rsp_typ       ;
reg                             emmc_send_select   ;
reg                             emmc_send_deselect ;
reg                             emmc_send_stop     ;
reg                             emmc_cmd_boot      ;
reg           [3:0]             emmc_block_len     ;
reg           [BLKCNTWID-1:0]   emmc_num_blocks    ;
reg           [5:0]             emmc_cmd_idx       ;
reg           [31:0]            emmc_cmd_arg       ;
reg                             emmc_cmd_start     ;

reg           [31:0]            src_dst_baddr      ;

assign gnd_wire = 1'b0;
assign emmc_num_blocks_w      = emmc_num_blocks & 16'hFFFF;
assign cmd_timeout_w          = cmd_timeout & 16'hFFFF;
assign dat_timeout_w          = dat_timeout & 16'hFFFF;

// -----------------------------------------------
// Output to submodules
// -----------------------------------------------
assign csr_clk_div            = clk_div;
assign csr_emmc_pp1_od0       = pp1_od0;
assign csr_emmc_ddr_mode      = ddr_mode;
assign csr_emmc_io_width      = io_width;

assign csr_emmc_block_len     = emmc_block_len;
assign csr_emmc_num_blocks    = emmc_num_blocks_w;
assign csr_emmc_cmd_idx       = emmc_cmd_idx;
assign csr_emmc_cmd_arg       = emmc_cmd_arg;
assign csr_emmc_send_select   = emmc_send_select  ;
assign csr_emmc_send_deselect = emmc_send_deselect;
assign csr_emmc_send_stop     = emmc_send_stop    ;
assign csr_emmc_cmd_boot      = emmc_cmd_boot;
assign csr_emmc_cmd_start     = emmc_cmd_start;
assign csr_emmc_rst           = emmc_tgt_rst;
assign csr_ip_core_rst        = ip_core_rst;

assign csr_src_dst_addr       = src_dst_baddr;
assign csr_cmd_timeout        = cmd_timeout_w;
assign csr_dat_timeout        = dat_timeout_w;

//--------------------------------------------
//-- CSR Read Data --
//--------------------------------------------
always @* begin
  case(csr_radr[7:0])
    ADR_EMMC_ID         : csr_rdat_nxt = emmc_ip_id;
    ADR_EMMC_CFG0       : csr_rdat_nxt = emmc_cfg0;
    ADR_EMMC_CFG1       : csr_rdat_nxt = emmc_cfg1;
    ADR_EMMC_INT_ENA    : csr_rdat_nxt = emmc_int_ena;
    ADR_EMMC_INT_STS    : csr_rdat_nxt = emmc_int_sts;
    ADR_EMMC_INFO_STS   : csr_rdat_nxt = emmc_info_sts;
    ADR_EMMC_RESP_D0    : csr_rdat_nxt = {26'd0,info_rsp_b0};
    ADR_EMMC_RESP_D1    : csr_rdat_nxt = info_rsp_dat0;
    ADR_EMMC_RESP_D2    : csr_rdat_nxt = info_rsp_dat1;
    ADR_EMMC_RESP_D3    : csr_rdat_nxt = info_rsp_dat2;
    ADR_EMMC_RESP_D4    : csr_rdat_nxt = info_rsp_dat3;
    ADR_EMMC_SOFTRST    : csr_rdat_nxt = emmc_softrst;
    ADR_EMMC_SRC_DST    : csr_rdat_nxt = emmc_src_dst;
    ADR_EMMC_CTRL0      : csr_rdat_nxt = emmc_ctrl0;
    ADR_EMMC_CTRL1      : csr_rdat_nxt = emmc_ctrl1;
    ADR_EMMC_CTRL2      : csr_rdat_nxt = emmc_ctrl2;
    default             : csr_rdat_nxt = 32'd0;
  endcase
end //--always @*--

genvar i;
generate
  for(i=0; i<4; i=i+1) begin : gen_per_byte
    // -------------------
    // CSR write select
    // -------------------
    assign wrsel_emmc_cfg0        [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_CFG0    );
    assign wrsel_emmc_cfg1        [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_CFG1    );

    assign wrsel_emmc_int_ena     [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_INT_ENA );
    assign wrsel_emmc_int_sts     [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_INT_STS );
    assign wrsel_emmc_int_set     [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_INT_SET );

    assign wrsel_emmc_softrst     [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_SOFTRST );

    assign wrsel_emmc_src_dst     [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_SRC_DST );
    assign wrsel_emmc_ctrl0       [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_CTRL0   );
    assign wrsel_emmc_ctrl1       [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_CTRL1   );
    assign wrsel_emmc_ctrl2       [i] = csr_wren[i] & (csr_wadr[7:0] == ADR_EMMC_CTRL2   );

    // -------------------
    // CSR Write
    // -------------------
    assign emmc_cfg0_nxt    [8*i+:8] = (wrsel_emmc_cfg0     [i])? csr_wdat[8*i+:8] : emmc_cfg0[8*i+:8];
    assign emmc_cfg1_nxt    [8*i+:8] = (wrsel_emmc_cfg1     [i])? csr_wdat[8*i+:8] : emmc_cfg1[8*i+:8];

    assign emmc_int_ena_nxt [8*i+:8] = (wrsel_emmc_int_ena  [i])? csr_wdat[8*i+:8] : emmc_int_ena[8*i+:8];

    assign emmc_int_sts_nxt [8*i+:8] = (wrsel_emmc_int_sts  [i])? ((~csr_wdat[8*i+:8] & emmc_int_sts[8*i+:8]) | int_trigger[8*i+:8]) :
                                       (wrsel_emmc_int_set  [i])? (( csr_wdat[8*i+:8] | emmc_int_sts[8*i+:8]) | int_trigger[8*i+:8]) :
                                                                  ((                    emmc_int_sts[8*i+:8]) | int_trigger[8*i+:8]);

    assign emmc_softrst_nxt [8*i+:8] = (wrsel_emmc_softrst  [i])? csr_wdat[8*i+:8] : emmc_softrst[8*i+:8];

    assign emmc_src_dst_nxt [8*i+:8] = (wrsel_emmc_src_dst  [i])? csr_wdat[8*i+:8] : emmc_src_dst[8*i+:8];
    assign emmc_ctrl0_nxt   [8*i+:8] = (wrsel_emmc_ctrl0    [i])? csr_wdat[8*i+:8] : emmc_ctrl0[8*i+:8];
    assign emmc_ctrl1_nxt   [8*i+:8] = (wrsel_emmc_ctrl1    [i])? csr_wdat[8*i+:8] : emmc_ctrl1[8*i+:8];
    assign emmc_ctrl2_nxt   [8*i+:8] = (wrsel_emmc_ctrl2    [i])? csr_wdat[8*i+:8] : emmc_ctrl2[8*i+:8];

  end // gen_per_byte
endgenerate

// -----------------------------------------------------------
// CSR Registers
// -----------------------------------------------------------
assign emmc_ip_id    = {8'h4C,8'h53,8'h43,8'h43};

assign emmc_cfg0     = {8'd0
                       // byte 2
                       ,2'd0
                       ,io_width
                       ,2'd0
                       ,ddr_mode
                       ,pp1_od0
                       // byte 1
                       ,{(16-CLKDIV_WID){1'b0}}
                       // byte 0
                       ,clk_div
                       };

assign emmc_cfg1     = {dat_timeout_w
                       // byte 0 and 1
                       ,cmd_timeout_w
                       };

assign emmc_int_ena  = {8'd0
                       // byte 2
                       ,2'd0
                       ,int_ena_dat_timeout
                       ,int_ena_cmd_timeout
                       ,int_ena_bus_rd_err
                       ,int_ena_bus_wr_err
                       ,int_ena_dat_crc_err
                       ,int_ena_cmd_crc_err
                       // byte 1
                       ,8'd0
                       // byte 0
                       ,7'd0
                       ,int_ena_cmd_done
                       };

assign int_trigger   = {8'd0
                       // byte 2
                       ,2'd0
                       ,det_dat_timeout
                       ,det_rsp_timeout
                       ,det_bus_rd_error
                       ,det_bus_wr_error
                       ,det_pld_crc_err
                       ,det_cmd_crc_err
                       // byte 1
                       ,8'd0
                       // byte 0
                       ,7'd0
                       ,det_emmc_done
                       };

assign emmc_int_sts  = {8'd0
                       // byte 2
                       ,2'd0
                       ,int_sts_dat_timeout
                       ,int_sts_cmd_timeout
                       ,int_sts_bus_rd_err
                       ,int_sts_bus_wr_err
                       ,int_sts_dat_crc_err
                       ,int_sts_cmd_crc_err
                       // byte 1
                       ,8'd0
                       // byte 0
                       ,7'd0
                       ,int_sts_cmd_done
                       };

assign emmc_info_sts = {debug_dat_line
                       // byte 0
                       ,1'd0
                       ,debug_cmd_line
                       ,3'd0
                       ,det_emmc_start
                       };

assign emmc_softrst  = {30'd0
                       ,emmc_tgt_rst
                       ,1'b0 //ip_core_rst
                       };

assign emmc_src_dst  = {src_dst_baddr
                       };

assign emmc_ctrl0    = {emmc_num_blocks_w
                       // byte 1
                       ,8'd0
                       // byte 0
                       ,4'd0
                       ,emmc_block_len
                       };

assign emmc_ctrl1    = {emmc_cmd_arg
                       };

assign emmc_ctrl2    = {16'd0
                       // byte 1
                       ,1'd0
                       ,emmc_rsp_typ
                       ,emmc_send_stop
                       ,emmc_send_deselect
                       ,emmc_send_select
                       ,emmc_cmd_boot
                       // byte 0
                       ,1'b0 // emmc_cmd_start - Write only
                       ,1'd0
                       ,emmc_cmd_idx
                       };


//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    clk_div <= DEFAULT_RATE;
    emmc_block_len <= BLOCK_LEN;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    cmd_timeout <= {TMR_WIDTH{1'b0}};
    dat_timeout <= {TMR_WIDTH{1'b0}};
    emmc_cmd_arg <= 32'h0;
    emmc_cmd_boot <= 1'h0;
    emmc_cmd_idx <= 6'h0;
    emmc_cmd_start <= 1'h0;
    emmc_num_blocks <= {BLKCNTWID{1'b0}};
    emmc_tgt_rst <= 1'h0;
    int_csr <= 1'h0;
    int_ena_bus_rd_err <= 1'h0;
    int_ena_bus_wr_err <= 1'h0;
    int_ena_cmd_crc_err <= 1'h0;
    int_ena_cmd_done <= 1'h0;
    int_ena_cmd_timeout <= 1'h0;
    int_ena_dat_crc_err <= 1'h0;
    int_ena_dat_timeout <= 1'h0;
    int_sts_bus_rd_err <= 1'h0;
    int_sts_bus_wr_err <= 1'h0;
    int_sts_cmd_crc_err <= 1'h0;
    int_sts_cmd_done <= 1'h0;
    int_sts_cmd_timeout <= 1'h0;
    int_sts_dat_crc_err <= 1'h0;
    int_sts_dat_timeout <= 1'h0;
    io_width <= 2'h0;
    ip_core_rst <= 1'h0;
    pp1_od0 <= 1'h0;
    src_dst_baddr <= 32'h0;
    // End of automatics
  end
  else begin
    clk_div             <= emmc_cfg0_nxt[ 0+:CLKDIV_WID];
    pp1_od0             <= emmc_cfg0_nxt[16+:1];
    io_width            <= emmc_cfg0_nxt[20+:2];

    cmd_timeout         <= emmc_cfg1_nxt[ 0+:TMR_WIDTH];
    dat_timeout         <= emmc_cfg1_nxt[16+:TMR_WIDTH];

    int_ena_cmd_done    <= emmc_int_ena_nxt[ 0+:1];
    int_ena_cmd_crc_err <= emmc_int_ena_nxt[16+:1];
    int_ena_dat_crc_err <= emmc_int_ena_nxt[17+:1];
    int_ena_bus_wr_err  <= emmc_int_ena_nxt[18+:1];
    int_ena_bus_rd_err  <= emmc_int_ena_nxt[19+:1];
    int_ena_cmd_timeout <= emmc_int_ena_nxt[20+:1];
    int_ena_dat_timeout <= emmc_int_ena_nxt[21+:1];

    int_csr             <= |(emmc_int_ena & emmc_int_sts);
    int_sts_cmd_done    <= emmc_int_sts_nxt[ 0+:1];
    int_sts_cmd_crc_err <= emmc_int_sts_nxt[16+:1];
    int_sts_dat_crc_err <= emmc_int_sts_nxt[17+:1];
    int_sts_bus_wr_err  <= emmc_int_sts_nxt[18+:1];
    int_sts_bus_rd_err  <= emmc_int_sts_nxt[19+:1];
    int_sts_cmd_timeout <= emmc_int_sts_nxt[20+:1];
    int_sts_dat_timeout <= emmc_int_sts_nxt[21+:1];

    ip_core_rst         <= emmc_softrst_nxt[0] & ~(ip_core_rst);
    emmc_tgt_rst        <= emmc_softrst_nxt[1];

    emmc_block_len      <= emmc_ctrl0_nxt[ 0+:4];
    emmc_num_blocks     <= emmc_ctrl0_nxt[16+:BLKCNTWID];

    emmc_cmd_arg        <= emmc_ctrl1_nxt[ 0+:32];

    emmc_cmd_idx        <= emmc_ctrl2_nxt[ 0+:6];
    emmc_cmd_start      <= emmc_ctrl2_nxt[ 7+:1] & ~(emmc_cmd_start);
    emmc_cmd_boot       <= emmc_ctrl2_nxt[ 8+:1];

    src_dst_baddr       <= emmc_src_dst_nxt;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

generate
  if(REG_CSRDAT) begin : gen_regdata
    reg           [31:0]            csr_rdat_r;
    reg                             csr_rvld_r;

    assign csr_rdat = csr_rdat_r;
    assign csr_rvld = csr_rvld_r;

    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        csr_rdat_r <= 32'h0;
        csr_rvld_r <= 1'h0;
        // End of automatics
      end
      else begin
        csr_rdat_r <= csr_rdat_nxt;
        csr_rvld_r <= csr_rden;
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--

  end // gen_regdata
  else begin : gen_noregdata
    assign csr_rdat = csr_rdat_nxt;
    assign csr_rvld = csr_rden;
  end // gen_noregdata

  if(EN_DDR_MODE) begin : gen_ddr
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        ddr_mode <= 1'h0;
        // End of automatics
      end
      else begin
        ddr_mode <= emmc_cfg0_nxt[17+:1];
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_ddr
  else begin : gen_sdr
    //--------------------------------------------
    //-- Combinatorial block --
    //--------------------------------------------
    always @* begin
      ddr_mode = gnd_wire;
    end //--always @*--
  end // gen_sdr

  if(EN_AUTO_CMD) begin : gen_auto_cmd

    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        emmc_send_deselect <= 1'h0;
        emmc_send_select <= 1'h0;
        emmc_send_stop <= 1'h0;
        // End of automatics
      end
      else begin
        emmc_send_select   <= emmc_ctrl2_nxt[ 9+:1];
        emmc_send_deselect <= emmc_ctrl2_nxt[10+:1];
        emmc_send_stop     <= emmc_ctrl2_nxt[11+:1];
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--

  end // gen_auto_cmd
  else begin : gen_no_auto_cmd

    //--------------------------------------------
    //-- Combinatorial block --
    //--------------------------------------------
    always @* begin
      emmc_send_select   = { 1{gnd_wire}};
      emmc_send_deselect = { 1{gnd_wire}};
      emmc_send_stop     = { 1{gnd_wire}};
    end //--always @*--
  end // gen_no_auto_cmd

  if(EN_RSPTYP_DEC) begin : gen_rsp_dec

    assign csr_emmc_rsp_typ = emmc_rsp_typ;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        emmc_rsp_typ <= 3'h0;
        // End of automatics
      end
      else begin
        case(csr_emmc_cmd_idx)
          // Basic Commands
          6'd00   : emmc_rsp_typ <= RSP_R0;
          6'd01   : emmc_rsp_typ <= RSP_R3;
          6'd02   : emmc_rsp_typ <= RSP_R2;
          6'd03   : emmc_rsp_typ <= RSP_R1;
          6'd04   : emmc_rsp_typ <= RSP_R0;
          6'd05   : emmc_rsp_typ <= RSP_R1;  // R1b
          6'd06   : emmc_rsp_typ <= RSP_R1;  // R1b
          6'd07   : emmc_rsp_typ <= RSP_R1;  // R1/R1b
          6'd08   : emmc_rsp_typ <= RSP_R1;
          6'd09   : emmc_rsp_typ <= RSP_R2;
          6'd10   : emmc_rsp_typ <= RSP_R2;
          6'd12   : emmc_rsp_typ <= RSP_R1;  // R1/R1b
          6'd13   : emmc_rsp_typ <= RSP_R1;
          6'd14   : emmc_rsp_typ <= RSP_R1;
          6'd15   : emmc_rsp_typ <= RSP_R0;
          6'd19   : emmc_rsp_typ <= RSP_R1;
          // Block Read Commands
          6'd16   : emmc_rsp_typ <= RSP_R1;
          6'd17   : emmc_rsp_typ <= RSP_R1;
          6'd18   : emmc_rsp_typ <= RSP_R1;
          6'd21   : emmc_rsp_typ <= RSP_R1;
          // Block Write Commands
          6'd23   : emmc_rsp_typ <= RSP_R1;
          6'd24   : emmc_rsp_typ <= RSP_R1;
          6'd25   : emmc_rsp_typ <= RSP_R1;
          6'd26   : emmc_rsp_typ <= RSP_R1;
          6'd27   : emmc_rsp_typ <= RSP_R1;
          6'd49   : emmc_rsp_typ <= RSP_R1;
          // Write Protect Commands
          6'd28   : emmc_rsp_typ <= RSP_R1;  // R1b
          6'd29   : emmc_rsp_typ <= RSP_R1;  // R1b
          6'd30   : emmc_rsp_typ <= RSP_R1;
          6'd31   : emmc_rsp_typ <= RSP_R1;
          // Erase Commands
          6'd35   : emmc_rsp_typ <= RSP_R1;
          6'd36   : emmc_rsp_typ <= RSP_R1;
          6'd38   : emmc_rsp_typ <= RSP_R1;  // R1b
          // IO Commands
          6'd39   : emmc_rsp_typ <= RSP_R1;
          6'd40   : emmc_rsp_typ <= RSP_R5;
          // Lock/Unlock Commands
          6'd42   : emmc_rsp_typ <= RSP_R1;
          // Command Queue Commands
          6'd44   : emmc_rsp_typ <= RSP_R1;
          6'd45   : emmc_rsp_typ <= RSP_R1;
          6'd46   : emmc_rsp_typ <= RSP_R1;
          6'd47   : emmc_rsp_typ <= RSP_R1;
          6'd48   : emmc_rsp_typ <= RSP_R1;  // R1b
          // Security Protocols Commands
          6'd53   : emmc_rsp_typ <= RSP_R1;
          6'd54   : emmc_rsp_typ <= RSP_R1;
          // Application Specific Commands
          6'd55   : emmc_rsp_typ <= RSP_R1;
          6'd56   : emmc_rsp_typ <= RSP_R1;
          // Unknown/Obsolete/Reserved Commands
          default : emmc_rsp_typ <= RSP_R0;
        endcase
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_rsp_dec
  else begin : gen_no_rsp_dec
    assign csr_emmc_rsp_typ = emmc_rsp_typ;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        emmc_rsp_typ <= 3'h0;
        // End of automatics
      end
      else begin
        emmc_rsp_typ <= emmc_ctrl2_nxt[12+:3];
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_no_rsp_dec
endgenerate
//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------



endmodule //--emmc_csr--
`endif // __RTL_MODULE__EMMC_CSR__
