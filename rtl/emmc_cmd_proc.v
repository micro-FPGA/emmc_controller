// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_CMD_PROC__
`define __RTL_MODULE__EMMC_CMD_PROC__
//==========================================================================
// Module : emmc_cmd_proc
//==========================================================================
module emmc_cmd_proc #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                      SIMULATION    = 0

,parameter                      CLKDIV_WID    = 8            // must be able to generate 400KHz,
,parameter                      BUS_WID       = 32
,parameter                      TMR_WIDTH     = 8

,parameter                      EN_SPI_X4     = 1
,parameter                      EN_SPI_X8     = 1

,parameter                      MIN_BLOCK_SIZE  = 512
,parameter                      MAX_BLOCK_SIZE  = 4096
,parameter                      MAX_NUM_BLOCK   = 65536

) //--end_param--

( //--begin_ports--
 input                          clk_i
,input                          rst_n_i

,input        [CLKDIV_WID-1:0]  csr_clk_div             // 0 - div1, 1 - div2, 2 - div4, 3 - div6,...

,input                          csr_emmc_pp1_od0        // 0 - open-drain mode, 1 - push-pull mode
,input                          csr_emmc_ddr_mode       // 0 - SDR mode, 1 - DDR mode
,input        [1:0]             csr_emmc_io_width       // 0 - x1, 1 - (x2)rsvd, 2 - x4, 3 - x8

,input                          csr_emmc_send_select
,input                          csr_emmc_send_deselect
,input                          csr_emmc_send_stop

,input        [3:0]             csr_emmc_block_len      // 0 - 1 byte, 1 - 2 bytes,...,8- 256 bytes, 9 - 512 bytes,..., 14 - 16KB
,input        [15:0]            csr_emmc_num_blocks     // 0 - no data, 1 - 1 data block, 2 - 2 data blocks,...,
,input        [5:0]             csr_emmc_cmd_idx
,input        [2:0]             csr_emmc_rsp_typ        // 0 - no response, 1 - R1, 2 - R2,..., 5 - R5
,input        [31:0]            csr_emmc_cmd_arg
,input                          csr_emmc_cmd_boot       // boot mode
,input                          csr_emmc_cmd_start

,input        [15:0]            csr_cmd_timeout
,input        [15:0]            csr_dat_timeout

,output reg                     det_emmc_start
,output reg                     det_emmc_done
,output reg                     det_cmd_crc_err
,output reg                     det_pld_crc_err

,output wire                    det_rsp_timeout
,output wire                    det_dat_timeout

,output wire  [5:0]             info_rsp_b0
,output wire  [31:0]            info_rsp_dat0
,output wire  [31:0]            info_rsp_dat1
,output wire  [31:0]            info_rsp_dat2
,output wire  [31:0]            info_rsp_dat3

// to Bus controller
,output wire                    emmc_memrd_req          // for eMMC read request, write the data to AXI
,output wire                    emmc_memwr_req          // for eMMC write request, need to fetch data from AXI
,input                          emmc_req_done

,input                          cmd_proc_mem_avail
,input        [BUS_WID-1:0]     cmd_proc_mem_rdat
,output wire                    cmd_proc_mem_rden

,input                          cmd_proc_mem_free
,output wire  [BUS_WID-1:0]     cmd_proc_mem_wdat
,output wire                    cmd_proc_mem_wren

// interface to SERDES
,output wire                    tx_cmd_valid
,output wire                    tx_cmd_wr1_rd0
,output wire  [1:0]             tx_cmd_last_byte
,output wire  [BUS_WID-1:0]     tx_cmd_data
,output wire                    tx_cmd_dc_en
,output wire  [2:0]             tx_cmd_dc_num
,output wire                    tx_cmd_pp1_od0
,output wire                    tx_cmd_crc_en

,input                          tx_cmd_ready
,input                          rx_cmd_valid
,input        [BUS_WID-1:0]     rx_cmd_data
,input                          rx_cmd_crc_ok
,input                          rx_cmd_end

,output wire                    tx_pld_valid
,output wire                    tx_pld_wr1_rd0
,output wire                    tx_pld_ddr_mode
,output wire  [1:0]             tx_pld_io_width
,output wire  [1:0]             tx_pld_last_byte
,output wire  [BUS_WID-1:0]     tx_pld_data
,output wire                    tx_pld_dc_en
,output wire  [2:0]             tx_pld_dc_num
,output wire                    tx_pld_pp1_od0
,output wire                    tx_pld_crc_en

,input                          tx_pld_ready
,input                          rx_pld_valid
,input        [BUS_WID-1:0]     rx_pld_data
,input                          rx_pld_crc_ok
,input                          rx_pld_end

,output reg                     cmd_en_restart
,output reg                     dat_en_restart
,output reg                     en_crc_rsp_type2    // CRC for response type 2 is included in the 128b data
// current clock divider
,output wire  [CLKDIV_WID-1:0]  cur_clk_div     // 0 - div1, 1 - div2, 2 - div4, 3 - div6,...

,input                          emmc_tx_ckp

,input                          emmc_cmd_clk_vld_i
,input                          emmc_cmd_clk_vld_o
,input                          emmc_cmd_dc_en_o
,input        [0:0]             emmc_dat_dti_i
,input                          emmc_dat_clk_vld_i
,input                          emmc_dat_dc_en_o

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
localparam                      // auto enum state_1
                                ST_CMD_IDLE   = 3'd0
                               ,ST_CMD_BOOT   = 3'd1
                               ,ST_CMD_START  = 3'd2
                               ,ST_CMD_ARG    = 3'd3
                               ,ST_CMD_CRC    = 3'd4
                               ,ST_CMD_DUMMY  = 3'd5
                               ,ST_CMD_RSP    = 3'd6
                               ,ST_CMD_WAIT   = 3'd7
                               ;

localparam                      // auto enum state_2
                                ST_RSP_IDLE   = 3'd0
                               ,ST_RSP_START  = 3'd1
                               ,ST_RSP_ARG    = 3'd2
                               ,ST_RSP_CRC    = 3'd3
                               ,ST_RSP_WAIT   = 3'd4
                               ;

localparam                      // auto enum state_3
                                ST_WDT_IDLE     = 3'd0
                               ,ST_WDT_START    = 3'd2
                               ,ST_WDT_PAYLOAD  = 3'd3
                               ,ST_WDT_CRC      = 3'd4
                               ,ST_WDT_DUMMY    = 3'd5
                               ,ST_WDT_RSP      = 3'd6
                               ,ST_WDT_WAIT     = 3'd7
                               ;

localparam                      // auto enum state_4
                                ST_REC_IDLE   = 3'd0
                               ,ST_REC_WAIT0  = 3'd1
                               ,ST_REC_WAIT1  = 3'd2
                               ,ST_REC_WAIT2  = 3'd3
                               ,ST_REC_END    = 3'd4
                               ;

localparam                      SPI_X1   = 2'd0
                               ,SPI_X4   = 2'd2
                               ,SPI_X8   = 2'd3
                               ;

localparam                      RSP_R0 = 3'd0
                               ,RSP_R1 = 3'd1
                               ,RSP_R2 = 3'd2
                               ,RSP_R3 = 3'd3
                               ,RSP_R4 = 3'd4
                               ,RSP_R5 = 3'd5
                               ;

localparam                      DSTAT_APP_CMD           = 5
                               ,DSTAT_EXCEPTION_EVENT   = 6
                               ,DSTAT_SWITCH_ERROR      = 7
                               ,DSTAT_READY_FOR_DATA    = 8
                               ,DSTAT_CURRENT_STATE     = 9     // [12:9] - 4bits device state
                               ,DSTAT_ERASE_RESET       = 13
                               ,DSTAT_WP_ERASE_SKIP     = 15
                               ,DSTAT_CID_CSD_WRITE     = 16
                               ,DSTAT_ERROR             = 19
                               ,DSTAT_CC_ERROR          = 20
                               ,DSTAT_DEV_ECC_FAILED    = 21
                               ,DSTAT_ILLEGAL_COMMAND   = 22
                               ,DSTAT_COM_CRC_ERROR     = 23
                               ,DSTAT_LOCK_FAILED       = 24
                               ,DSTAT_DEV_IS_LOCKED     = 25
                               ,DSTAT_WP_VIOLATION      = 26
                               ,DSTAT_ERASE_PARAM       = 27
                               ,DSTAT_ERASE_SEQ_ERROR   = 28
                               ,DSTAT_BLOCK_LEN_ERROR   = 29
                               ,DSTAT_ADDRESS_MISALIGN  = 30
                               ,DSTAT_ADDRESS_OUTRANGE  = 31
                               ;

localparam                      CMDCNTWID = (BUS_WID == 32)? 3 : (BUS_WID == 16)? 4 : 5;
localparam                      RSPCNTWID = (BUS_WID == 32)? 3 : (BUS_WID == 16)? 4 : 5;
localparam                      WDTCNTWID = $clog2(MAX_BLOCK_SIZE+1);
localparam                      BLKCNTWID = $clog2(MAX_NUM_BLOCK);

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
wire          [31:0]            cmd_arg_byteswap;

wire          [15:0]            wdt_cntr_init;
wire                            cmd_bustest_wr;
wire                            cmd_bustest_rd;
//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [2:0]             // auto enum state_1
                                cmd_cs;
reg           [2:0]             // auto enum state_2
                                rsp_cs;
reg           [2:0]             // auto enum state_3
                                wdt_cs;
reg           [2:0]             // auto enum state_4
                                recovery_cs;


reg                             en_timer;
reg                             en_timer_mask;
reg           [4:0]             rsp_tmr0;
reg                             hit_rsp_tmr0_max;
reg           [TMR_WIDTH-1:0]   rsp_tmr1;
reg                             rsp_tmr1_gt_timeout;
reg                             dat_tmr1_gt_timeout;

reg           [CMDCNTWID-1:0]   cmd_cntr;       // used for tx of cmd and rsp
reg           [RSPCNTWID-1:0]   rsp_cntr;       // used for rx of rsp
reg           [RSPCNTWID-1:0]   rsp_ptr;        // used for storing rsp
reg           [WDTCNTWID-1:0]   wdt_cntr;       // used for write data
reg           [BLKCNTWID-1:0]   blk_cntr;       // used for number of blocks
reg                             all_blocks_done;
reg                             cmd_clk_vld_q;
reg                             det_cmd_done;
reg                             xfer_done;
reg                             check_busy;
reg                             rd_not_started;

reg                             dat_line_not_busy;
reg                             wait_wr_data;
reg                             wait_rd_data;
reg                             wdt_last;

reg                             cmd_valid     ;
reg                             cmd_wr1_rd0   ;
reg           [1:0]             cmd_last_byte ;   // last byte index: 0 - byte_0, 1 - byte_1,..., 3 - byte_3
reg           [BUS_WID-1:0]     cmd_data      ;
reg                             cmd_dc_en     ;
reg           [2:0]             cmd_dc_num    ;   // number of dummy: 0 - 1 clock cycle, 1 - 2 clock_cycle,..., 7 - 8 clock cycles
reg                             cmd_pp1_od0   ;
reg                             cmd_crc_en    ;

reg                             pld_valid     ;
reg                             pld_wr1_rd0   ;
reg                             pld_ddr_mode  ;
reg           [1:0]             pld_io_width  ;   // io width: 0 - x1, 1 - x2, 2 - x4, 3 - x8
reg           [1:0]             pld_last_byte ;   // last byte index: 0 - byte_0, 1 - byte_1,..., 3 - byte_3
reg           [BUS_WID-1:0]     pld_data      ;
reg                             pld_dc_en     ;
reg           [2:0]             pld_dc_num    ;   // number of dummy: 0 - 1 clock cycle, 1 - 2 clock_cycle,..., 7 - 8 clock cycles
reg                             pld_pp1_od0   ;
reg                             pld_crc_en    ;

reg           [5:0]             saved_rsp_b0  ;
reg           [31:0]            saved_rsp_dat0;
reg           [31:0]            saved_rsp_dat1;
reg           [31:0]            saved_rsp_dat2;
reg           [31:0]            saved_rsp_dat3;

assign cur_clk_div      = csr_clk_div;

assign tx_cmd_valid     = cmd_valid     ;
assign tx_cmd_wr1_rd0   = cmd_wr1_rd0   ;
assign tx_cmd_last_byte = cmd_last_byte ;
assign tx_cmd_data      = cmd_data      ;
assign tx_cmd_dc_en     = cmd_dc_en     ;
assign tx_cmd_dc_num    = cmd_dc_num    ;
assign tx_cmd_pp1_od0   = cmd_pp1_od0   ;
assign tx_cmd_crc_en    = cmd_crc_en    ;

assign tx_pld_valid     = pld_valid     ;
assign tx_pld_wr1_rd0   = pld_wr1_rd0   ;
assign tx_pld_ddr_mode  = pld_ddr_mode  ;
assign tx_pld_io_width  = pld_io_width  ;
assign tx_pld_last_byte = pld_last_byte ;
assign tx_pld_data      = pld_data      ;
assign tx_pld_dc_en     = pld_dc_en     ;
assign tx_pld_dc_num    = pld_dc_num    ;
assign tx_pld_pp1_od0   = pld_pp1_od0   ;
assign tx_pld_crc_en    = pld_crc_en    ;

assign info_rsp_b0      = saved_rsp_b0  ;
assign info_rsp_dat0    = saved_rsp_dat0;
assign info_rsp_dat1    = saved_rsp_dat1;
assign info_rsp_dat2    = saved_rsp_dat2;
assign info_rsp_dat3    = saved_rsp_dat3;

assign cmd_proc_mem_wren  = wait_rd_data & rx_pld_valid & ~rx_pld_end;
assign cmd_proc_mem_wdat  = rx_pld_data;

assign cmd_proc_mem_rden  = wait_wr_data & tx_pld_valid & tx_pld_ready & ~wdt_last &
                            ((wdt_cs == ST_WDT_START) | (wdt_cs == ST_WDT_PAYLOAD));

assign emmc_memrd_req     = wait_rd_data;  // for eMMC read request, write the data to AXI
assign emmc_memwr_req     = wait_wr_data;  // for eMMC write request, need to fetch data from AXI

// transmit MSB first
assign cmd_arg_byteswap   = {csr_emmc_cmd_arg[ 7: 0]
                            ,csr_emmc_cmd_arg[15: 8]
                            ,csr_emmc_cmd_arg[23:16]
                            ,csr_emmc_cmd_arg[31:24]
                            };

assign det_rsp_timeout  = rsp_tmr1_gt_timeout;
assign det_dat_timeout  = dat_tmr1_gt_timeout;

assign wdt_cntr_init[0 ] = (csr_emmc_block_len == 4'd0 ) & (MIN_BLOCK_SIZE ==     1);
assign wdt_cntr_init[1 ] = (csr_emmc_block_len == 4'd1 ) & (MIN_BLOCK_SIZE >=     2);
assign wdt_cntr_init[2 ] = (csr_emmc_block_len == 4'd2 ) & (MIN_BLOCK_SIZE >=     4);
assign wdt_cntr_init[3 ] = (csr_emmc_block_len == 4'd3 ) & (MIN_BLOCK_SIZE >=     8);
assign wdt_cntr_init[4 ] = (csr_emmc_block_len == 4'd4 ) & (MIN_BLOCK_SIZE >=    16);
assign wdt_cntr_init[5 ] = (csr_emmc_block_len == 4'd5 ) & (MIN_BLOCK_SIZE >=    32);
assign wdt_cntr_init[6 ] = (csr_emmc_block_len == 4'd6 ) & (MIN_BLOCK_SIZE >=    64);
assign wdt_cntr_init[7 ] = (csr_emmc_block_len == 4'd7 ) & (MIN_BLOCK_SIZE >=   128);
assign wdt_cntr_init[8 ] = (csr_emmc_block_len == 4'd8 ) & (MIN_BLOCK_SIZE >=   256);
assign wdt_cntr_init[9 ] = (csr_emmc_block_len == 4'd9 ) & (MIN_BLOCK_SIZE >=   512);
assign wdt_cntr_init[10] = (csr_emmc_block_len == 4'd10) & (MIN_BLOCK_SIZE >=  1024);
assign wdt_cntr_init[11] = (csr_emmc_block_len == 4'd11) & (MIN_BLOCK_SIZE >=  2048);
assign wdt_cntr_init[12] = (csr_emmc_block_len == 4'd12) & (MIN_BLOCK_SIZE >=  4096);
assign wdt_cntr_init[13] = (csr_emmc_block_len == 4'd13) & (MIN_BLOCK_SIZE >=  8192);
assign wdt_cntr_init[14] = (csr_emmc_block_len == 4'd14) & (MIN_BLOCK_SIZE >= 16384);
assign wdt_cntr_init[15] = (csr_emmc_block_len == 4'd15) & (MIN_BLOCK_SIZE >= 32768);

assign cmd_bustest_wr = (csr_emmc_cmd_idx == 6'd19);
assign cmd_bustest_rd = (csr_emmc_cmd_idx == 6'd14);
//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    cmd_data      <= {BUS_WID{1'd1}};
    cmd_cs        <= ST_CMD_IDLE;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    cmd_cntr <= {CMDCNTWID{1'b0}};
    cmd_crc_en <= 1'h0;
    cmd_dc_en <= 1'h0;
    cmd_dc_num <= 3'h0;
    cmd_last_byte <= 2'h0;
    cmd_pp1_od0 <= 1'h0;
    cmd_valid <= 1'h0;
    cmd_wr1_rd0 <= 1'h0;
    det_emmc_done <= 1'h0;
    det_emmc_start <= 1'h0;
    // End of automatics
  end
  else begin
    case(cmd_cs)
      ST_CMD_BOOT : begin
        cmd_cs            <= ST_CMD_BOOT;
        cmd_valid         <= 1'd1;
        cmd_wr1_rd0       <= 1'd1;
        cmd_data          <= {BUS_WID{1'd0}};
        // TODO: perform boot data fetching
      end // ST_CMD_BOOT

      ST_CMD_START : begin
        cmd_cs            <= ST_CMD_START;
        cmd_valid         <= 1'd1;
        cmd_wr1_rd0       <= 1'd1;
        cmd_pp1_od0       <= csr_emmc_pp1_od0;
        cmd_data          <= {BUS_WID{1'd1}} & {2'b01,csr_emmc_cmd_idx};
        cmd_cntr[1:0]     <= (BUS_WID == 32)? 2'd0 :
                             (BUS_WID == 16)? 2'd1 : 2'd3;

        if(tx_cmd_valid & tx_cmd_ready) begin
          cmd_cs          <= ST_CMD_ARG;
          cmd_data        <= (BUS_WID == 32)? cmd_arg_byteswap[31:0] :
                             (BUS_WID == 16)? cmd_arg_byteswap[15:0] :
                                              cmd_arg_byteswap[ 7:0];
          cmd_last_byte   <= (BUS_WID == 32)? 2'd3 :
                             (BUS_WID == 16)? 2'd1 : 2'd0;
        end
      end // ST_CMD_START

      ST_CMD_ARG : begin
        cmd_cs            <= ST_CMD_ARG;
        cmd_valid         <= 1'd1;

        if(tx_cmd_valid & tx_cmd_ready) begin
          cmd_cs          <= (|cmd_cntr[1:0])? ST_CMD_ARG : ST_CMD_CRC;
          cmd_cntr[1:0]   <= (BUS_WID == 32)? 2'd0 :
                             (BUS_WID == 16)? 2'd0 : (cmd_cntr[1:0] - {1'b0,|cmd_cntr[1:0]});
          cmd_data        <= (BUS_WID == 32)? {BUS_WID{1'd1}} :
                             (BUS_WID == 16)? ((cmd_cntr[1:0])? cmd_arg_byteswap[31:16] : {BUS_WID{1'd1}}) :
                                              ((cmd_cntr[1:0] == 2'd3)? cmd_arg_byteswap[15: 8] :
                                               (cmd_cntr[1:0] == 2'd2)? cmd_arg_byteswap[23:16] :
                                               (cmd_cntr[1:0] == 2'd1)? cmd_arg_byteswap[31:24] :
                                                                   {BUS_WID{1'd1}});
          cmd_last_byte   <= (BUS_WID == 32)? 2'd0 :
                             (BUS_WID == 16)? ((cmd_cntr[1:0])? 2'd1 : 2'd0) : 2'd0;
          cmd_crc_en      <= (BUS_WID == 32)? 1'd1 : ((cmd_cntr[1:0])? 1'd0 : 1'd1);
        end
      end // ST_CMD_ARG

      ST_CMD_CRC : begin
        cmd_cs            <= ST_CMD_CRC;
        cmd_valid         <= 1'd1;
        cmd_last_byte     <= 2'd0;
        cmd_data          <= {BUS_WID{1'd1}};
        // RSP_R2 has 128 bits which includes CRC7, count in BUS_WID=8 will not include CRC
        cmd_cntr          <= (csr_emmc_rsp_typ == RSP_R0)? {RSPCNTWID{1'b0}} :
                             (csr_emmc_rsp_typ == RSP_R2)? ((BUS_WID == 32)? 3'd5 :
                                                            (BUS_WID == 16)? 4'd9 : 5'd16) :
                             (BUS_WID == 32)? 3'd2 :
                             (BUS_WID == 16)? 4'd3 : 5'd5;

        if(tx_cmd_valid & tx_cmd_ready) begin
          cmd_cs          <= ST_CMD_DUMMY;
          cmd_crc_en      <= 1'b0;
          cmd_wr1_rd0     <= 1'd0;
          cmd_pp1_od0     <= 1'b0;
          cmd_dc_en       <= 1'h1;
          cmd_dc_num      <= 3'd1;  // minimum of 2 dummy clock cycles
        end
      end // ST_CMD_CRC

      ST_CMD_DUMMY : begin
        cmd_cs            <= ST_CMD_DUMMY;
        cmd_valid         <= 1'd1;
        cmd_last_byte     <= 2'd0;
        cmd_data          <= {BUS_WID{1'd1}};

        if(tx_cmd_valid & tx_cmd_ready) begin
          cmd_cs          <= (|cmd_cntr)? ST_CMD_RSP : ST_CMD_WAIT;
          cmd_dc_en       <= (|cmd_cntr)? 1'd0 : 1'd1;
          cmd_dc_num      <= (|cmd_cntr)? 3'd0 : 3'd7;
        end
      end // ST_CMD_DUMMY

      ST_CMD_RSP : begin
        cmd_cs            <= ST_CMD_RSP;
        cmd_valid         <= 1'd1;
        cmd_data          <= {BUS_WID{1'd1}};

        if(tx_cmd_valid & tx_cmd_ready) begin
          cmd_cntr        <= cmd_cntr - {{(RSPCNTWID-1){1'b0}},|cmd_cntr};
          cmd_last_byte   <= (~|cmd_cntr[1+:RSPCNTWID-1])? 2'd0 :
                             (BUS_WID == 32)? (((csr_emmc_rsp_typ == RSP_R2) & (cmd_cntr == 3'd2))? 2'd2 : 2'd3) :
                             (BUS_WID == 16)? (((csr_emmc_rsp_typ == RSP_R2) & (cmd_cntr == 3'd2))? 2'd0 : 2'd1) : 2'd0;
          cmd_crc_en      <= ~|cmd_cntr[1+:RSPCNTWID-1] & cmd_cntr[0]; // cmd_cntr==1
          cmd_dc_en       <= ~|cmd_cntr;
          cmd_dc_num      <= 3'd7;
          cmd_pp1_od0     <= (cmd_dc_en)? (wait_wr_data | wait_rd_data) : 1'b0;

          if(rsp_cs == ST_RSP_CRC) begin
            cmd_cs        <= ST_CMD_WAIT;
          end
        end

      end // ST_CMD_RSP

      ST_CMD_WAIT : begin
        cmd_cs            <= ST_CMD_WAIT;
        cmd_last_byte     <= 2'd0;
        cmd_data          <= {BUS_WID{1'd1}};
        det_emmc_done     <= ~(emmc_cmd_clk_vld_i | emmc_cmd_dc_en_o |
                               wait_wr_data | wait_rd_data);

        if(tx_cmd_valid & tx_cmd_ready) begin
          cmd_valid       <= wait_wr_data | wait_rd_data;
          cmd_pp1_od0     <= wait_wr_data | wait_rd_data;
        end

        if(det_emmc_done) begin
          cmd_cs          <= ST_CMD_IDLE;
          det_emmc_start  <= 1'b0;
        end
      end // ST_CMD_RSP

      default : begin // ST_CMD_IDLE
        cmd_cs            <= ST_CMD_IDLE;
        det_emmc_start    <= det_emmc_start | csr_emmc_cmd_start;
        det_emmc_done     <= 1'b0;
        cmd_cntr          <= {CMDCNTWID{1'b0}};

        cmd_valid         <= 1'b0;
        cmd_wr1_rd0       <= 1'd0;
        cmd_dc_en         <= 1'd0;
        cmd_pp1_od0       <= 1'd0;
        cmd_crc_en        <= 1'd0;
        cmd_last_byte     <= 2'd0;
        cmd_dc_num        <= 3'd0;
        cmd_data          <= {BUS_WID{1'd1}};

        if(det_emmc_start) begin
          cmd_cs          <= (csr_emmc_cmd_boot)? ST_CMD_BOOT : ST_CMD_START;
        end
      end // ST_CMD_IDLE
    endcase

    if(cmd_en_restart) begin
      cmd_cs              <= ST_CMD_IDLE;
      det_emmc_start      <= 1'b0;
      det_emmc_done       <= 1'b1;
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
    dat_tmr1_gt_timeout <= 1'h0;
    en_timer <= 1'h0;
    en_timer_mask <= 1'h0;
    hit_rsp_tmr0_max <= 1'h0;
    rsp_tmr0 <= 5'h0;
    rsp_tmr1 <= {TMR_WIDTH{1'b0}};
    rsp_tmr1_gt_timeout <= 1'h0;
    // End of automatics
  end
  else begin
    hit_rsp_tmr0_max      <= &rsp_tmr0 & emmc_tx_ckp;
    rsp_tmr1_gt_timeout   <= (rsp_tmr1 > csr_cmd_timeout[0+:TMR_WIDTH]) & (rsp_cs == ST_RSP_START);
    dat_tmr1_gt_timeout   <= (rsp_tmr1 > csr_dat_timeout[0+:TMR_WIDTH]) & (wdt_cs == ST_WDT_PAYLOAD);
    en_timer_mask         <= (rsp_cs == ST_RSP_START) | (wdt_cs == ST_WDT_RSP);
    if(en_timer) begin
      rsp_tmr0            <= rsp_tmr0 + {4'd0, emmc_tx_ckp}; // timer counter for response
      rsp_tmr1            <= rsp_tmr1 + {{(TMR_WIDTH-1){1'b0}},hit_rsp_tmr0_max}; // timer counter for response
      en_timer            <= ~(((rsp_cs == ST_RSP_START) & rx_cmd_valid) |
                               ((wdt_cs == ST_WDT_RSP) & (rx_pld_valid & ~rx_pld_end)) |
                               ((wdt_cs == ST_WDT_PAYLOAD) & wait_rd_data & (rx_pld_valid | ~dat_line_not_busy)) |
                               cmd_en_restart
                              );
    end
    else begin
      rsp_tmr0            <= 4'd0;
      rsp_tmr1            <= {TMR_WIDTH{1'b0}};
      en_timer            <= ~en_timer_mask & ((rsp_cs == ST_RSP_START) |
                                               ((wdt_cs == ST_WDT_RSP) & ~cmd_bustest_wr) |
                                               (rd_not_started & (cmd_cs == ST_CMD_WAIT)));
    end
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    rsp_cs <= ST_RSP_IDLE;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    cmd_clk_vld_q <= 1'h0;
    det_cmd_done <= 1'h0;
    en_crc_rsp_type2 <= 1'h0;
    rsp_cntr <= {RSPCNTWID{1'b0}};
    // End of automatics
  end
  else begin
    cmd_clk_vld_q         <= emmc_cmd_clk_vld_i;
    det_cmd_done          <= (cmd_cs == ST_CMD_RSP) & (det_cmd_done | (~emmc_cmd_clk_vld_i & cmd_clk_vld_q));
    en_crc_rsp_type2      <= 1'b0;

    case(rsp_cs)
      ST_RSP_START : begin
        rsp_cs            <= ST_RSP_START;
        en_crc_rsp_type2  <= (csr_emmc_rsp_typ == RSP_R2);
        rsp_cntr          <= (csr_emmc_rsp_typ == RSP_R0)? {RSPCNTWID{1'b0}} :
                             (csr_emmc_rsp_typ == RSP_R2)? ((BUS_WID == 32)? 3'd4 :
                                                            (BUS_WID == 16)? 4'd8 : 5'd15) :
                             (BUS_WID == 32)? 3'd1 :
                             (BUS_WID == 16)? 4'd2 : 5'd4;
        if(rx_cmd_valid & cmd_clk_vld_q) begin
          rsp_cs          <= ST_RSP_ARG;
        end
      end // ST_RSP_START

      ST_RSP_ARG : begin
        rsp_cs            <= ST_RSP_ARG;
        rsp_cntr          <= rsp_cntr - {{(RSPCNTWID-1){1'b0}},(|rsp_cntr & rx_cmd_valid)};
        if(rx_cmd_valid & (~|rsp_cntr[1+:RSPCNTWID-1])) begin
          rsp_cs          <= ST_RSP_CRC;
        end
      end // ST_RSP_ARG

      ST_RSP_CRC : begin
        rsp_cs            <= ST_RSP_CRC;
        if(rx_cmd_valid) begin
          rsp_cs          <= ST_RSP_WAIT;
        end
      end // ST_RSP_CRC

      ST_RSP_WAIT : begin
        rsp_cs            <= ST_RSP_WAIT;
        if(~emmc_cmd_clk_vld_i) begin
          rsp_cs          <= ST_RSP_IDLE;
        end
      end // ST_RSP_WAIT

      default : begin // ST_RSP_IDLE
        rsp_cs            <= ST_RSP_IDLE;
        if(det_cmd_done & (csr_emmc_rsp_typ != RSP_R0)) begin
          rsp_cs          <= ST_RSP_START;
        end
      end // ST_RSP_IDLE
    endcase

    if(cmd_en_restart) begin
      rsp_cs              <= ST_RSP_IDLE;
      det_cmd_done        <= 1'b0;
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
    all_blocks_done <= 1'h0;
    blk_cntr <= {BLKCNTWID{1'b0}};
    dat_line_not_busy <= 1'h0;
    det_cmd_crc_err <= 1'h0;
    det_pld_crc_err <= 1'h0;
    wait_rd_data <= 1'h0;
    wait_wr_data <= 1'h0;
    // End of automatics
  end
  else begin
    dat_line_not_busy <= emmc_dat_dti_i[0];
    det_cmd_crc_err   <= (rx_cmd_valid & rx_cmd_end & ~rx_cmd_crc_ok & (csr_emmc_rsp_typ != RSP_R3));
    det_pld_crc_err   <= (rx_pld_valid & rx_pld_end & ~rx_pld_crc_ok) |
                         (rx_pld_valid & xfer_done & wait_wr_data & (rx_pld_data[7:4] != 4'd5));

    all_blocks_done   <= (blk_cntr == csr_emmc_num_blocks);
    if(wait_wr_data | wait_rd_data) begin
      blk_cntr        <= blk_cntr + {{(BLKCNTWID-1){1'b0}},(wdt_last & tx_pld_ready)};
    end
    else begin
      blk_cntr        <= {BLKCNTWID{1'b0}};
    end

    if(wait_wr_data) begin
      wait_wr_data <= ~(all_blocks_done & (wdt_cs == ST_WDT_WAIT));
    end
    else begin
      wait_wr_data <= ((csr_emmc_cmd_idx == 6'd19) |     // BUSTEST_W
                       (csr_emmc_cmd_idx == 6'd24) |     // WRITE_BLOCK
                       (csr_emmc_cmd_idx == 6'd25) |     // WRITE_MULTIPLE_BLOCK
                       (csr_emmc_cmd_idx == 6'd26) |     // PROGRAM_CID
                       (csr_emmc_cmd_idx == 6'd27) |     // PROGRAM_CSD
                       (csr_emmc_cmd_idx == 6'd49) |     // SET_TIME
                       (csr_emmc_cmd_idx == 6'd42) |     // LOCK/UNLOCK
                       (csr_emmc_cmd_idx == 6'd47) |     // EXECUTE_WRITE_TASK
                       (csr_emmc_cmd_idx == 6'd54) |     // PROTOCOL_WR
                       ((csr_emmc_cmd_idx == 6'd56) &
                        csr_emmc_cmd_arg[0])             // GEN_CMD,WR
                      ) & (cmd_cs == ST_CMD_RSP);
    end // wait_wr_data==0

    if(wait_rd_data) begin
      wait_rd_data <= ~(emmc_req_done & (wdt_cs == ST_WDT_WAIT)); // need to wait until bus transfer is done
    end
    else begin
      wait_rd_data <= ((csr_emmc_cmd_idx == 6'd08) |     // SEND_EXT_CSD
                       (csr_emmc_cmd_idx == 6'd14) |     // BUSTEST_R
                       (csr_emmc_cmd_idx == 6'd17) |     // READ_SINGLE_BLOCK
                       (csr_emmc_cmd_idx == 6'd18) |     // READ_MULTIPLE_BLOCK
                       (csr_emmc_cmd_idx == 6'd21) |     // SEND_TUNING_BLOCK
                       (csr_emmc_cmd_idx == 6'd30) |     // SEND_WRITE_PROT
                       (csr_emmc_cmd_idx == 6'd31) |     // SEND_WRITE_PROT_TYPE
                       (csr_emmc_cmd_idx == 6'd46) |     // EXECUTE_READ_TASK
                       (csr_emmc_cmd_idx == 6'd53) |     // PROTOCOL_RD
                       ((csr_emmc_cmd_idx == 6'd56) &
                        ~csr_emmc_cmd_arg[0])            // GEN_CMD,RD
                      ) & (cmd_cs == ST_CMD_RSP);
    end // wait_rd_data==0

    if(cmd_en_restart) begin
      // TODO: error handling for bus
      wait_wr_data <= 1'b0;
      wait_rd_data <= 1'b0;
    end
  end
end //--always @(posedge clk_i or negedge rst_n_i)--


//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    pld_data      <= {BUS_WID{1'd1}};
    wdt_cs        <= ST_WDT_IDLE;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    check_busy <= 1'h0;
    pld_crc_en <= 1'h0;
    pld_dc_en <= 1'h0;
    pld_dc_num <= 3'h0;
    pld_ddr_mode <= 1'h0;
    pld_io_width <= 2'h0;
    pld_last_byte <= 2'h0;
    pld_pp1_od0 <= 1'h0;
    pld_valid <= 1'h0;
    pld_wr1_rd0 <= 1'h0;
    rd_not_started <= 1'h0;
    wdt_cntr <= {WDTCNTWID{1'b0}};
    wdt_last <= 1'h0;
    xfer_done <= 1'h0;
    // End of automatics
  end
  else begin
    xfer_done             <= xfer_done | (rx_pld_valid & rx_pld_end);
    check_busy            <= check_busy | (xfer_done & (~wait_wr_data | rx_pld_valid));
    rd_not_started        <= 1'b0;
    case(wdt_cs)
      ST_WDT_START : begin
        wdt_cs            <= ST_WDT_START;
        rd_not_started    <= wait_rd_data;

        if(tx_pld_valid & tx_pld_ready) begin
          wdt_cs          <= ST_WDT_PAYLOAD;

          pld_wr1_rd0     <= wait_wr_data;
          pld_pp1_od0     <= wait_wr_data;
          pld_dc_en       <= 1'd0;
          pld_data        <= (wait_wr_data)? cmd_proc_mem_rdat : pld_data;
          pld_last_byte   <= (BUS_WID == 32)? 2'd3 :
                             (BUS_WID == 16)? 2'd1 : 2'd0;
          wdt_cntr        <= wdt_cntr - ((BUS_WID == 32)? {{(WDTCNTWID-3){1'b0}},3'd4} :
                                         (BUS_WID == 16)? {{(WDTCNTWID-2){1'b0}},2'd2} :
                                                          {{(WDTCNTWID-1){1'b0}},1'd1});
        end
      end // ST_WDT_START

      ST_WDT_PAYLOAD : begin
        wdt_cs            <= ST_WDT_PAYLOAD;
        rd_not_started    <= rd_not_started & dat_line_not_busy & ~rx_pld_valid;

        if(tx_pld_valid & tx_pld_ready) begin
          wdt_cs          <= (wdt_last)? ST_WDT_CRC : ST_WDT_PAYLOAD;

          wdt_last        <= (BUS_WID == 32)? ~|wdt_cntr[3+:WDTCNTWID-3] & ~wdt_last :
                             (BUS_WID == 16)? ~|wdt_cntr[2+:WDTCNTWID-2] & ~wdt_last :
                                              ~|wdt_cntr[1+:WDTCNTWID-1] & ~wdt_last;
          wdt_cntr        <= wdt_cntr - ((BUS_WID == 32)? {{(WDTCNTWID-3){1'b0}},3'd4} :
                                         (BUS_WID == 16)? {{(WDTCNTWID-2){1'b0}},2'd2} :
                                                          {{(WDTCNTWID-1){1'b0}},1'd1});
          pld_data        <= (wait_wr_data)? cmd_proc_mem_rdat : pld_data;
          pld_last_byte   <= (BUS_WID == 32)? ((wdt_last)? 2'd1 : 2'd3) :
                             (BUS_WID == 16)? 2'd1 : 2'd0;
          pld_crc_en      <= wdt_last;
        end
      end // ST_WDT_PAYLOAD

      ST_WDT_CRC : begin
        wdt_cs            <= ST_WDT_CRC;
        pld_data          <= {BUS_WID{1'd1}};

        // TODO: for BUS_WID=8, need to send another byte since CRC is 16b
        if(tx_pld_valid & tx_pld_ready) begin
          wdt_cs          <= ST_WDT_DUMMY;
          pld_last_byte   <= 2'd0;
          pld_crc_en      <= 1'b0;
          pld_wr1_rd0     <= 1'd0;
          pld_dc_en       <= 1'd1;
        end
      end // ST_WDT_CRC

      ST_WDT_DUMMY : begin
        wdt_cs            <= ST_WDT_DUMMY;
        pld_last_byte     <= 2'd0;
        pld_data          <= {BUS_WID{1'd1}};

        if(tx_pld_valid & tx_pld_ready) begin
          pld_io_width    <= SPI_X1;
          pld_pp1_od0     <= 1'b0;
          pld_dc_num      <= 3'd1;

          if(pld_dc_num[0]) begin
            wdt_cs        <= (wait_rd_data)? ST_WDT_WAIT : ST_WDT_RSP;
            pld_valid     <= (wait_rd_data)? 1'b0 : pld_valid;
            pld_dc_en     <= 1'd0;
            pld_dc_num    <= 3'd0;
          end
        end
      end // ST_WDT_DUMMY

      ST_WDT_RSP : begin
        wdt_cs            <= ST_WDT_RSP;
        pld_pp1_od0       <= pld_pp1_od0 | (xfer_done & rx_pld_valid & dat_line_not_busy & wait_wr_data);

        if(tx_pld_valid & tx_pld_ready) begin
          pld_io_width    <= csr_emmc_io_width;
          pld_dc_en       <= 1'b1;
        end

        // wait until not busy
        if((check_busy & dat_line_not_busy) |
           cmd_bustest_wr) begin
          wdt_cs          <= ST_WDT_WAIT;
        end

      end // ST_WDT_RSP

      ST_WDT_WAIT : begin
        wdt_cs            <= ST_WDT_WAIT;

        if(~emmc_dat_clk_vld_i & (~all_blocks_done | emmc_req_done)) begin
          wdt_cs          <= ST_WDT_IDLE;
        end
      end // ST_WDT_RSP

      default : begin // ST_WDT_IDLE
        wdt_cs            <= ST_WDT_IDLE;
        wdt_cntr          <= wdt_cntr_init[0+:WDTCNTWID];
        wdt_last          <= 1'd0;
        xfer_done         <= 1'b0;
        check_busy        <= 1'b0;

        pld_ddr_mode      <= csr_emmc_ddr_mode;
        pld_io_width      <= csr_emmc_io_width;
        pld_wr1_rd0       <= 1'd0;
        pld_crc_en        <= 1'd0;
        pld_dc_en         <= 1'd1;
        pld_dc_num        <= 3'd0;
        pld_last_byte     <= 2'd0;
        pld_data          <= {BUS_WID{1'd1}};

        if(cmd_cs == ST_CMD_IDLE) begin
          pld_valid       <= 1'b0;
          pld_pp1_od0     <= 1'b0;
        end
        else if(wait_rd_data) begin
          pld_pp1_od0     <= 1'b0;
          if(((cmd_cs == ST_CMD_RSP) |
              (cmd_cs == ST_CMD_WAIT)) & cmd_proc_mem_free) begin
            wdt_cs        <= ST_WDT_START;
            pld_valid     <= 1'b1;
          end
        end
        else if(wait_wr_data) begin
          pld_valid       <= (((rsp_cs == ST_RSP_CRC) | (rsp_cs == ST_RSP_WAIT)) &
                               tx_cmd_valid & tx_cmd_ready & tx_cmd_dc_en) |
                             (tx_pld_valid & tx_pld_ready) | pld_valid;
          pld_pp1_od0     <= 1'b1;

          if(tx_pld_valid & tx_pld_ready & cmd_proc_mem_avail) begin
            wdt_cs        <= ST_WDT_START;

            pld_data[7:0] <= (EN_SPI_X8 && (pld_io_width == SPI_X8))? 8'd0             :
                             (EN_SPI_X4 && (pld_io_width == SPI_X4))? {4'd0,{4{1'b1}}} :
                                                                      {1'd0,{7{1'b1}}};
          end
        end // (cmd_cs != ST_CMD_IDLE)
      end // ST_WDT_IDLE
    endcase

    if(cmd_en_restart) begin
      wdt_cs              <= ST_WDT_IDLE;
    end
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    recovery_cs <= ST_REC_IDLE;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    cmd_en_restart <= 1'h0;
    dat_en_restart <= 1'h0;
    // End of automatics
  end
  else begin
    case(recovery_cs)
      ST_REC_WAIT0 : begin
        recovery_cs       <= ST_REC_WAIT1;
      end // ST_REC_WAIT0

      ST_REC_WAIT1 : begin
        recovery_cs       <= ST_REC_WAIT2;
      end // ST_REC_WAIT1

      ST_REC_WAIT2 : begin
        recovery_cs       <= ST_REC_END;
      end // ST_REC_WAIT2

      ST_REC_END : begin
        recovery_cs       <= ST_REC_IDLE;
        cmd_en_restart    <= 1'b0;
        dat_en_restart    <= 1'b0;
      end // ST_REC_END

      default : begin // ST_REC_IDLE
        recovery_cs       <= ST_REC_IDLE;
        if(rsp_tmr1_gt_timeout |
           dat_tmr1_gt_timeout) begin
          recovery_cs     <= ST_REC_WAIT0;
          cmd_en_restart  <= 1'b1;
          dat_en_restart  <= dat_tmr1_gt_timeout;
        end
      end // ST_REC_IDLE
    endcase
  end
end //--always @(posedge clk_i or negedge rst_n_i)--



generate
  case(BUS_WID)
    16      : begin : gen_16b
      wire          [15:0]            rsp_arg_byteswap;

      // received MSB first
      assign rsp_arg_byteswap   = {rx_cmd_data[ 7: 0]
                                  ,rx_cmd_data[15: 8]
                                  };
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          saved_rsp_b0   <= {6{1'b1}};
          saved_rsp_dat0 <= {32{1'b1}};
          saved_rsp_dat1 <= {32{1'b1}};
          saved_rsp_dat2 <= {32{1'b1}};
          saved_rsp_dat3 <= {32{1'b1}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rsp_ptr <= {RSPCNTWID{1'b0}};
          // End of automatics
        end
        else begin
          if(cmd_cs == ST_CMD_DUMMY) begin
            // reset before start of response
            saved_rsp_b0   <= {6{1'b1}};
            saved_rsp_dat0 <= {32{1'b1}};
            saved_rsp_dat1 <= {32{1'b1}};
            saved_rsp_dat2 <= {32{1'b1}};
            saved_rsp_dat3 <= {32{1'b1}};
          end

          if(rsp_cs == ST_RSP_IDLE) begin
            rsp_ptr <= {RSPCNTWID{1'b0}};
          end
          else if(rx_cmd_valid) begin
            rsp_ptr                 <= rsp_ptr + {{(RSPCNTWID-1){1'b0}},1'b1};
            saved_rsp_b0  [ 0+: 6]  <= (rsp_ptr == 3'd0)? rx_cmd_data[ 0+: 6] : saved_rsp_b0  [ 0+: 6];
            saved_rsp_dat0[ 0+:32]  <= (rsp_ptr == 3'd1)? rsp_arg_byteswap[ 0+:32] : saved_rsp_dat0[ 0+:32];
            saved_rsp_dat1[ 0+:32]  <= (rsp_ptr == 3'd2)? rsp_arg_byteswap[ 0+:32] : saved_rsp_dat1[ 0+:32];
            saved_rsp_dat2[ 0+:32]  <= (rsp_ptr == 3'd3)? rsp_arg_byteswap[ 0+:32] : saved_rsp_dat2[ 0+:32];
            saved_rsp_dat3[ 0+:24]  <= (rsp_ptr == 3'd4)? rsp_arg_byteswap[ 8+:24] : saved_rsp_dat3[ 0+:24];
            saved_rsp_dat3[24+: 8]  <= (rsp_ptr == 3'd5)? rx_cmd_data[ 0+: 8] : saved_rsp_dat3[24+: 8];
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_16b

    32      : begin : gen_32b
      wire          [31:0]            rsp_arg_byteswap;

      // received MSB first
      assign rsp_arg_byteswap   = {rx_cmd_data[ 7: 0]
                                  ,rx_cmd_data[15: 8]
                                  ,rx_cmd_data[23:16]
                                  ,rx_cmd_data[31:24]
                                  };
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          saved_rsp_b0   <= {6{1'b1}};
          saved_rsp_dat0 <= {32{1'b1}};
          saved_rsp_dat1 <= {32{1'b1}};
          saved_rsp_dat2 <= {32{1'b1}};
          saved_rsp_dat3 <= {32{1'b1}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          rsp_ptr <= {RSPCNTWID{1'b0}};
          // End of automatics
        end
        else begin
          if(cmd_cs == ST_CMD_DUMMY) begin
            // reset before start of response
            saved_rsp_b0   <= {6{1'b1}};
            saved_rsp_dat0 <= {32{1'b1}};
            saved_rsp_dat1 <= {32{1'b1}};
            saved_rsp_dat2 <= {32{1'b1}};
            saved_rsp_dat3 <= {32{1'b1}};
          end

          if(rsp_cs == ST_RSP_IDLE) begin
            rsp_ptr <= {RSPCNTWID{1'b0}};
          end
          else if(rx_cmd_valid) begin
            rsp_ptr                 <= rsp_ptr + {{(RSPCNTWID-1){1'b0}},1'b1};
            saved_rsp_b0  [ 0+: 6]  <= (rsp_ptr == 3'd0)? rx_cmd_data     [ 0+: 6] : saved_rsp_b0  [ 0+: 6];
            saved_rsp_dat0[ 0+:32]  <= (rsp_ptr == 3'd1)? rsp_arg_byteswap[ 0+:32] : saved_rsp_dat0[ 0+:32];
            saved_rsp_dat1[ 0+:32]  <= (rsp_ptr == 3'd2)? rsp_arg_byteswap[ 0+:32] : saved_rsp_dat1[ 0+:32];
            saved_rsp_dat2[ 0+:32]  <= (rsp_ptr == 3'd3)? rsp_arg_byteswap[ 0+:32] : saved_rsp_dat2[ 0+:32];
            saved_rsp_dat3[ 8+:24]  <= (rsp_ptr == 3'd4)? rsp_arg_byteswap[ 8+:24] : saved_rsp_dat3[ 8+:24];
            saved_rsp_dat3[ 0+: 8]  <= (rsp_ptr == 3'd5)? rx_cmd_data     [ 0+: 8] : saved_rsp_dat3[ 0+: 8];
          end
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_32b

    default : begin : gen_08b
      // TODO
    end // gen_08b
  endcase

  if(SIMULATION) begin : gen_sim
    // -----------------------------------
    // For Simulation use only
    // State in ASCII for readability
    // -----------------------------------

    /*AUTOASCIIENUM("cmd_cs", "_cmd_cs_", "ST_CMD_")*/
    // Beginning of automatic ASCII enum decoding
    reg         [39:0]        _cmd_cs_;         // Decode of cmd_cs
    always @(cmd_cs) begin
       case ({cmd_cs})
         ST_CMD_IDLE:  _cmd_cs_ = "idle ";
         ST_CMD_BOOT:  _cmd_cs_ = "boot ";
         ST_CMD_START: _cmd_cs_ = "start";
         ST_CMD_ARG:   _cmd_cs_ = "arg  ";
         ST_CMD_CRC:   _cmd_cs_ = "crc  ";
         ST_CMD_DUMMY: _cmd_cs_ = "dummy";
         ST_CMD_RSP:   _cmd_cs_ = "rsp  ";
         ST_CMD_WAIT:  _cmd_cs_ = "wait ";
         default:      _cmd_cs_ = "%Erro";
       endcase
    end
    // End of automatics

    /*AUTOASCIIENUM("rsp_cs", "_rsp_cs_", "ST_RSP_")*/
    // Beginning of automatic ASCII enum decoding
    reg         [39:0]        _rsp_cs_;         // Decode of rsp_cs
    always @(rsp_cs) begin
       case ({rsp_cs})
         ST_RSP_IDLE:  _rsp_cs_ = "idle ";
         ST_RSP_START: _rsp_cs_ = "start";
         ST_RSP_ARG:   _rsp_cs_ = "arg  ";
         ST_RSP_CRC:   _rsp_cs_ = "crc  ";
         ST_RSP_WAIT:  _rsp_cs_ = "wait ";
         default:      _rsp_cs_ = "%Erro";
       endcase
    end
    // End of automatics

    /*AUTOASCIIENUM("wdt_cs", "_wdt_cs_", "ST_WDT_")*/
    // Beginning of automatic ASCII enum decoding
    reg         [55:0]        _wdt_cs_;         // Decode of wdt_cs
    always @(wdt_cs) begin
       case ({wdt_cs})
         ST_WDT_IDLE:    _wdt_cs_ = "idle   ";
         ST_WDT_START:   _wdt_cs_ = "start  ";
         ST_WDT_PAYLOAD: _wdt_cs_ = "payload";
         ST_WDT_CRC:     _wdt_cs_ = "crc    ";
         ST_WDT_DUMMY:   _wdt_cs_ = "dummy  ";
         ST_WDT_RSP:     _wdt_cs_ = "rsp    ";
         ST_WDT_WAIT:    _wdt_cs_ = "wait   ";
         default:        _wdt_cs_ = "%Error ";
       endcase
    end
    // End of automatics
  end // gen_sim
endgenerate
//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------



endmodule //--emmc_cmd_proc--
`endif // __RTL_MODULE__EMMC_CMD_PROC__
