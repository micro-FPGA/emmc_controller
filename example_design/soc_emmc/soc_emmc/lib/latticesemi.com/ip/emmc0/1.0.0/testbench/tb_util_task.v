// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __TB_UTIL_TASK__
`define __TB_UTIL_TASK__

// Memory array access macro - updated to support both AXI4 and AHB-Lite memory models
// TB_MEM_INTF is defined by IP generation tool based on DATA_INTERFACE parameter (see emmc_controller_settings.xml)
// It will be set to either 'axi' or 'ahbl' string
`ifdef TB_MEM_INTF
  `define TB_MEM_GEN(INTF)  tb_top.gen_``INTF``_mem_model.u_``INTF``_mem_model.u_mem_dp.gen_lut.memArray
  `define TB_MEM_ARRAY      `TB_MEM_GEN(`TB_MEM_INTF)
`else
  // Fallback: Default to AXI4 memory model if TB_MEM_INTF not defined
  // (e.g., when running standalone testbench without IP generation)
  `define TB_MEM_ARRAY    tb_top.gen_axi_mem_model.u_axi_mem_model.u_mem_dp.gen_lut.memArray
`endif

`define TB_MEM_COMPARE  compare_mem_data

localparam                        SWITCH_CMD_CMDSET       = 0;
localparam                        SWITCH_CMD_SETBITS      = 1;
localparam                        SWITCH_CMD_CLRBITS      = 2;
localparam                        SWITCH_CMD_WR_BYTE      = 3;

localparam                        CMD_SET_STANDARD        = 0;
localparam                        EXT_CSD_BUS_WIDTH_IDX   = 183;

localparam                        BUS_WIDTH_1BIT          = 0;
localparam                        BUS_WIDTH_4BIT          = 1;
localparam                        BUS_WIDTH_8BIT          = 2;

localparam                        CMD_START               = 32'h0000_0080;

localparam                        BLKLEN_128B             = 4'd7
                                 ,BLKLEN_256B             = 4'd8
                                 ,BLKLEN_512B             = 4'd9
                                 ,BLKLEN_1KB              = 4'd10
                                 ,BLKLEN_2KB              = 4'd11
                                 ,BLKLEN_4KB              = 4'd12
                                 ,BLKLEN_8KB              = 4'd13
                                 ,BLKLEN_16KB             = 4'd14
                                 ,BLKLEN_32KB             = 4'd15
                                 ,BLKLEN_64B              = 4'd6
                                 ,BLKLEN_32B              = 4'd5
                                 ,BLKLEN_16B              = 4'd4
                                 ,BLKLEN_8B               = 4'd3
                                 ,BLKLEN_4B               = 4'd2
                                 ,BLKLEN_2B               = 4'd1
                                 ,BLKLEN_1B               = 4'd0
                                 ;

localparam                        EMMC_IO_DRIVE_PP1       = 1'b1
                                 ,EMMC_IO_DRIVE_OD0       = 1'b0
                                 ,EMMC_DDR_MODE           = 1'b1
                                 ,EMMC_SDR_MODE           = 1'b0
                                 ,EMMC_IO_WIDTH_X1        = 2'd0
                                 ,EMMC_IO_WIDTH_X4        = 2'd2
                                 ,EMMC_IO_WIDTH_X8        = 2'd3
                                 ;

                                  // Class 0 and 1
localparam                        CMD_GO_IDLE_STATE       = 6'd0
                                 ,CMD_SEND_OP_COND        = 6'd1
                                 ,CMD_ALL_SEND_CID        = 6'd2
                                 ,CMD_SET_RELATIVE_ADDR   = 6'd3
                                 ,CMD_SET_DSR             = 6'd4
                                 ,CMD_SLEEP_AWAKE         = 6'd5
                                 ,CMD_SWITCH              = 6'd6
                                 ,CMD_SELECT_CARD         = 6'd7
                                 ,CMD_SEND_EXT_CSD        = 6'd8
                                 ,CMD_SEND_CSD            = 6'd9
                                 ,CMD_SEND_CID            = 6'd10
                                 ,CMD_STOP_TRANSFER       = 6'd12
                                 ,CMD_SEND_STATUS         = 6'd13
                                 ,CMD_BUS_TEST_R          = 6'd14
                                 ,CMD_GO_INACTIVE_STATE   = 6'd15
                                 ,CMD_BUS_TEST_W          = 6'd19
                                  // Class 2
                                 ,CMD_SET_BLOCKLEN        = 6'd16
                                 ,CMD_RD_BLOCK_ONE        = 6'd17
                                 ,CMD_RD_BLOCK_MULT       = 6'd18
                                 ,CMD_SEND_TUNING_BLK     = 6'd21
                                  // Class 4
                                 ,CMD_SET_BLOCK_COUNT     = 6'd23
                                 ,CMD_WR_BLOCK_ONE        = 6'd24
                                 ,CMD_WR_BLOCK_MULT       = 6'd25
                                 ,CMD_PROGRAM_CID         = 6'd26
                                 ,CMD_PROGRAM_CSD         = 6'd27
                                 ,CMD_SET_TIME            = 6'd49
                                  // Class 6
                                 ,CMD_SET_WR_PROT         = 6'd28
                                 ,CMD_CLR_WR_PROT         = 6'd29
                                 ,CMD_SEND_WR_PROT        = 6'd30
                                 ,CMD_SEND_WR_PROT_TYP    = 6'd31
                                  // Class 5
                                 ,CMD_ERASE_GRP_START     = 6'd35
                                 ,CMD_ERASE_GRP_END       = 6'd36
                                 ,CMD_ERASE               = 6'd38
                                  // Class 9
                                 ,CMD_FAST_IO             = 6'd39
                                 ,CMD_GO_IRQ_STATE        = 6'd40
                                  // Class 7
                                 ,CMD_LOCK_UNLOCK         = 6'd42
                                  // Class 8
                                 ,CMD_APP_CMD             = 6'd55
                                 ,CMD_GEN_CMD             = 6'd56
                                  // Class 10
                                 ,CMD_PROTOCOL_RD         = 6'd53
                                 ,CMD_PROTOCOL_WR         = 6'd54
                                  // Class 11
                                 ,CMD_QUEUED_TASK_PARAMS  = 6'd44
                                 ,CMD_QUEUED_TASK_ADDR    = 6'd45
                                 ,CMD_EXECUTE_READ_TASK   = 6'd46
                                 ,CMD_EXECUTE_WRITE_TASK  = 6'd47
                                 ,CMD_CMDQ_TASK_MGMT      = 6'd48
                                 ;


// ------------------------------------------------------------------------------------------------------------
function [3:0] get_block_size_encoding;
  input [15:0]        num_bytes;
  reg   [3:0]         block_size;
  begin
    if      (num_bytes <= 16                        ) block_size = BLKLEN_16B ;
    else if (num_bytes <= 32    && num_bytes > 16   ) block_size = BLKLEN_32B ;
    else if (num_bytes <= 64    && num_bytes > 32   ) block_size = BLKLEN_64B ;
    else if (num_bytes <= 128   && num_bytes > 64   ) block_size = BLKLEN_128B;
    else if (num_bytes <= 256   && num_bytes > 128  ) block_size = BLKLEN_256B;
    else if (num_bytes <= 512   && num_bytes > 256  ) block_size = BLKLEN_512B;
    else if (num_bytes <= 1024  && num_bytes > 512  ) block_size = BLKLEN_1KB ;
    else if (num_bytes <= 2048  && num_bytes > 1024 ) block_size = BLKLEN_2KB ;
    else if (num_bytes <= 4096  && num_bytes > 2048 ) block_size = BLKLEN_4KB ;
    else if (num_bytes <= 8192  && num_bytes > 4096 ) block_size = BLKLEN_8KB ;
    else if (num_bytes <= 16384 && num_bytes > 8192 ) block_size = BLKLEN_16KB;
    else if (num_bytes <= 32768 && num_bytes > 16384) block_size = BLKLEN_32KB;
    else                                              block_size = BLKLEN_512B;

    get_block_size_encoding = block_size;
  end
endfunction

// ------------------------------------------------------------------------------------------------------------
task tgt_reset;
  begin
    `APB_WR32(`EMMC_CSR_ADDR(`EMMC_SOFTRST_ADDR),32'h0000_0002);
    `TIME_DELAY(10,clk_i)
    `APB_WR32(`EMMC_CSR_ADDR(`EMMC_SOFTRST_ADDR),32'h0000_0000);
    `TIME_DELAY(20,clk_i)
  end
endtask // tgt_reset

// ------------------------------------------------------------------------------------------------------------
task wait_ip_busy_status;
  input                       wait_value; // wait until this value is read
  reg                         emmc_busy;
  reg                         wait_done;
  reg     [31:0]              rdat;
  begin
    rdat            = 32'd0;
    emmc_busy        = ~wait_value;
    wait_done       = 1'b0;
    $display("\n");
    `N_MSG(("Polling Register emmc_busy Started..."))
    while(!wait_done) begin
      `APB_RD32(`EMMC_INFO_STS_ADDR,rdat); // read info status register
      emmc_busy       = rdat[0];
      wait_done       = (emmc_busy == wait_value);
      `D_MSG(("Polling Register emmc_busy=%0b...",emmc_busy))
      if(!wait_done) `TIME_DELAY(20,clk_i)
    end
    `N_MSG(("Polling Register emmc_busy Done. (value=%0b)",emmc_busy))
  end
endtask // wait_ip_busy_status

// ------------------------------------------------------------------------------------------------------------
task set_emmc_clock_freq;
  input real                  sck_freq;

  reg     [31:0]              rdat;
  reg     [CLKDIV_WID-1:0]    sck_rate;
  reg     [CLKDIV_WID-1:0]    new_rate;
  real                        new_sck_freq;
  begin
    $display("\n");
    `N_MSG(("SCK Frequency change started..."))
    if(sck_freq > CLKI_FREQ) begin
      `E_MSG(("Cannot set SCK frequency to %0f",sck_freq))
    end
    else begin
      // read configuration 0 register
      `APB_RD32(`EMMC_CFG0_ADDR,rdat);
      sck_rate = rdat[0+:CLKDIV_WID];
      new_rate = (sck_freq >= CLKI_FREQ)? {CLKDIV_WID{1'b0}} : (CLKI_FREQ / sck_freq / 2);
      new_sck_freq = (new_rate == 0)? CLKI_FREQ : (CLKI_FREQ / new_rate / 2.0);

      if(new_rate != sck_rate) begin
        // in case there is ongoing SPI transaction, wait until it is done
        wait_ip_busy_status(1'b0);
        // reprogram new rate
        rdat[0+:CLKDIV_WID] = new_rate;
        `APB_WR32(`EMMC_CFG0_ADDR,rdat);
        `TIME_DELAY(10,clk_i)
      end
      `N_MSG(("SCK Pulse width change: previous value = %0d, new value = %0d",sck_rate,new_rate))
      `N_MSG(("SCK New Frequency = %0f",new_sck_freq))
      `N_MSG(("SCK Frequency change Done."))
    end
  end
endtask // set_emmc_clock_freq

// ------------------------------------------------------------------------------------------------------------
task set_emmc_clk_io_config;
  input real                  sck_freq;
  input                       ddr_mode;
  input [1:0]                 io_width;
  input                       io_drive;   // open-drain or push-pull

  reg     [31:0]              rdat;
  reg     [CLKDIV_WID-1:0]    sck_rate;
  reg     [CLKDIV_WID-1:0]    new_rate;
  real                        new_sck_freq;
  begin
    $display("\n");
    `N_MSG(("eMMC Configuration change started..."))
    if(sck_freq > CLKI_FREQ) begin
      `E_MSG(("Cannot set SCK frequency to %0f",sck_freq))
    end
    else if(ddr_mode && (EN_DDR_MODE == 0)) begin
      `E_MSG(("Cannot set DDR Mode to %0d",ddr_mode))
    end
    else if((1 << io_width) > MAX_NUMLANE) begin
      `E_MSG(("Cannot set IO Width to %0d",io_width))
    end
    else begin
      // read configuration 0 register
      `APB_RD32(`EMMC_CFG0_ADDR,rdat);
      sck_rate = rdat[0+:CLKDIV_WID];
      new_rate = (sck_freq >= CLKI_FREQ)? {CLKDIV_WID{1'b0}} : (CLKI_FREQ / sck_freq / 2);
      new_sck_freq = (new_rate == 0)? CLKI_FREQ : (CLKI_FREQ / new_rate / 2.0);

      if((new_rate != sck_rate) ||
         (io_width != rdat[20+:2]) ||
         (ddr_mode != rdat[17+:1]) ||
         (io_drive != rdat[16+:1])) begin
        // in case there is ongoing SPI transaction, wait until it is done
        wait_ip_busy_status(1'b0);
        // reprogram new settings
        rdat[0+:CLKDIV_WID] = new_rate;
        rdat[16+:1]         = io_drive;
        rdat[17+:1]         = ddr_mode;
        rdat[20+:2]         = io_width;
        `APB_WR32(`EMMC_CFG0_ADDR,rdat);
        `TIME_DELAY(10,clk_i)
      end
      `N_MSG(("SCK Pulse width change: previous value = %0d, new value = %0d",sck_rate,new_rate))
      `N_MSG(("SCK New Frequency = %0f",new_sck_freq))
      `N_MSG(("DDR Mode = %0d",ddr_mode))
      `N_MSG(("IO Width = %0d",io_width))
      `N_MSG(("IO Drive = %0d",io_drive))
      `N_MSG(("eMMC Configuration change change Done."))
    end
  end
endtask // set_emmc_clk_io_config

// ------------------------------------------------------------------------------------------------------------
task emmc_get_resp_data;
  input   [2:0]               s_idx;
  input   [2:0]               e_idx;
  output  [5*32-1:0]          resp_data;
  begin

    resp_data = {(5*32){1'b1}};

    if(s_idx == 0             ) `APB_RD32(`EMMC_RESP_D0_ADDR,(resp_data[0*32+:32]));
    if(s_idx <= 1 && e_idx > 0) `APB_RD32(`EMMC_RESP_D1_ADDR,(resp_data[1*32+:32]));
    if(s_idx <= 2 && e_idx > 1) `APB_RD32(`EMMC_RESP_D2_ADDR,(resp_data[2*32+:32]));
    if(s_idx <= 3 && e_idx > 2) `APB_RD32(`EMMC_RESP_D3_ADDR,(resp_data[3*32+:32]));
    if(s_idx <= 4 && e_idx > 3) `APB_RD32(`EMMC_RESP_D4_ADDR,(resp_data[4*32+:32]));

  end
endtask // emmc_get_resp_data

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_go_idle;
  reg   [31:0]        emmc_cfg0;
  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Go IDLE State"))

    cmd_arg = 32'd0;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                     // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                           // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_GO_IDLE_STATE));   // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Go IDLE State"))
  end
endtask // emmc_cmd_go_idle

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_send_op_cond;
  reg   [31:0]        emmc_cfg0;
  reg   [31:0]        cmd_arg;
  reg                 cmd_done;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Send Operating Condition"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[7]      = 1'b1;
    cmd_arg[23:15]  = {9{1'b1}};
    cmd_arg[30:29]  = 2'b10;      // sector mode
    cmd_arg[31]     = 1'b1;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument

    cmd_done = 1'b0;
    while(!cmd_done) begin
      `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SEND_OP_COND));   // start, cmd index
      `TIME_DELAY(10,clk_i)

      wait_ip_busy_status(1'b0);

      emmc_get_resp_data(1,1,rsp_dat);
      `N_MSG(("eMMC Device OCR: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

      cmd_done = rsp_dat[1*32+31+:1];
    end

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Send Operating Condition"))
  end
endtask // emmc_cmd_send_op_cond

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_all_send_cid;
  reg   [31:0]        emmc_cfg0;
  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  reg                 cmd_done;
  begin
    cmd_done = 1'b0;

    $display("\n");
    `N_MSG(("eMMC Command Started: All Send CID"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    while (!cmd_done) begin
      `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_ALL_SEND_CID));   // start, cmd index
      `TIME_DELAY(10,clk_i)

      wait_ip_busy_status(1'b0);

      // when command is done, check that it is not due to timeout
      `APB_RD32(`EMMC_INT_STS_ADDR,rdat);
      cmd_done = (rdat[21:20] == 2'b00);
      // clear interrupt status
      `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});
    end

    emmc_get_resp_data(1,4,rsp_dat);
    `N_MSG(("eMMC Device CID[127: 96]: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))
    `N_MSG(("eMMC Device CID[ 95: 64]: 0x%4h_%4h",rsp_dat[2*32+16+:16],rsp_dat[2*32+0+:16]))
    `N_MSG(("eMMC Device CID[ 63: 32]: 0x%4h_%4h",rsp_dat[3*32+16+:16],rsp_dat[3*32+0+:16]))
    `N_MSG(("eMMC Device CID[ 31:  0]: 0x%4h_%4h",rsp_dat[4*32+16+:16],rsp_dat[4*32+0+:16]))

    `N_MSG(("eMMC Command Done: All Send CID"))
  end
endtask // emmc_cmd_all_send_cid

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_set_relative_addr;
  input [15:0]        tgt_addr;

  reg   [31:0]        emmc_cfg0;
  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Set Relative Address"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[31:16]  = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SET_RELATIVE_ADDR));   // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Set Relative Address"))
  end
endtask // emmc_cmd_set_relative_addr

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_switch;
  input [1:0]         access; // 0 - command set, 1 - set bits, 2 - clear bits, 3 - write byte
  input [7:0]         index;  // byte index
  input [7:0]         value;
  input [2:0]         cmd_set;

  reg   [31:0]        emmc_cfg0;
  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Switch"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[25:24]  = access;
    cmd_arg[23:16]  = index;
    cmd_arg[15: 8]  = value;
    cmd_arg[ 2: 0]  = cmd_set;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SWITCH));         // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Switch"))
  end
endtask // emmc_cmd_switch

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_select_deselect_card;
  input [15:0]        tgt_addr;

  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Select/Deselect Card"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[31:16]  = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SELECT_CARD));   // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Select/Deselect Card"))
  end
endtask // emmc_cmd_select_deselect_card

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_send_ext_csd;
  input [31:0]        dst_addr;

  reg   [15:0]        num_blocks;
  reg   [3:0]         block_length;
  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  integer             idx;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Send Extended CSD"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd16,16'd0});   // set timeout setting

    `APB_WR32(`EMMC_SRC_DST_ADDR,dst_addr); // memory address/location to put the return data

    num_blocks      = 16'd1;
    block_length    = BLKLEN_512B;
    cmd_arg         = 32'd0;
    `APB_WR32(`EMMC_CTRL0_ADDR,{num_blocks,12'd0,block_length});  // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SEND_EXT_CSD));   // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    `N_MSG(("eMMC Device Extended CSD:"))
    for(idx=0; idx<128; idx=idx+1) begin
      rdat = `TB_MEM_ARRAY[dst_addr[2+:12]+idx];
      `N_MSG(("EXT_CSD[%3d][31:0]: 0x%4h_%4h",idx,rdat[0*32+16+:16],rdat[0*32+0+:16]))
    end

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Send Extended CSD"))
  end
endtask // emmc_cmd_send_ext_csd

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_send_csd;
  input [15:0]        tgt_addr;

  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Send CSD"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[31:16]  = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SEND_CSD));       // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,4,rsp_dat);
    `N_MSG(("eMMC Device CSD[127: 96]: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))
    `N_MSG(("eMMC Device CSD[ 95: 64]: 0x%4h_%4h",rsp_dat[2*32+16+:16],rsp_dat[2*32+0+:16]))
    `N_MSG(("eMMC Device CSD[ 63: 32]: 0x%4h_%4h",rsp_dat[3*32+16+:16],rsp_dat[3*32+0+:16]))
    `N_MSG(("eMMC Device CSD[ 31:  0]: 0x%4h_%4h",rsp_dat[4*32+16+:16],rsp_dat[4*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Send CSD"))
  end
endtask // emmc_cmd_send_csd

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_send_cid;
  input [15:0]        tgt_addr;

  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Send CID"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[31:16]  = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SEND_CID));       // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,4,rsp_dat);
    `N_MSG(("eMMC Device CID[127: 96]: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))
    `N_MSG(("eMMC Device CID[ 95: 64]: 0x%4h_%4h",rsp_dat[2*32+16+:16],rsp_dat[2*32+0+:16]))
    `N_MSG(("eMMC Device CID[ 63: 32]: 0x%4h_%4h",rsp_dat[3*32+16+:16],rsp_dat[3*32+0+:16]))
    `N_MSG(("eMMC Device CID[ 31:  0]: 0x%4h_%4h",rsp_dat[4*32+16+:16],rsp_dat[4*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Send CID"))
  end
endtask // emmc_cmd_send_cid

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_stop_transmission;
  input [15:0]        tgt_addr;

  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Stop Transmission"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[31:16]  = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_STOP_TRANSFER));  // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Stop Transmission"))
  end
endtask // emmc_cmd_stop_transmission

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_send_status;
  input [15:0]        tgt_addr;

  reg   [31:0]        cmd_arg;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Send Status"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = 32'd0;
    cmd_arg[31:16]  = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                    // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                          // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SEND_STATUS));    // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Send Status"))
  end
endtask // emmc_cmd_send_status

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_set_block_length;
  input [31:0]        blocklen;

  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Set Block Length"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = blocklen;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                   // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                         // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SET_BLOCKLEN));  // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Set Block Length"))
  end
endtask // emmc_cmd_set_block_length

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_set_block_count;
  input [31:0]        blockcnt;

  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Set Block Count"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    cmd_arg         = blockcnt;
    `APB_WR32(`EMMC_CTRL0_ADDR,32'h0000_0000);                   // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                         // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_SET_BLOCK_COUNT));  // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Set Block Count"))
  end
endtask // emmc_cmd_set_block_count

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_write_block;
  input [31:0]        tgt_addr;
  input [31:0]        src_addr;
  input [3:0]         block_length;
  input [15:0]        num_blocks;

  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Write Block"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd16,16'd0});   // set timeout setting

    `APB_WR32(`EMMC_SRC_DST_ADDR,src_addr); // memory address/location to fetch data

    cmd_arg         = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,{num_blocks,12'd0,block_length});      // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                         // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_WR_BLOCK_ONE));  // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Write Block"))
  end
endtask // emmc_cmd_write_block

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_read_block;
  input [31:0]        tgt_addr;
  input [31:0]        dst_addr;
  input [3:0]         block_length;
  input [15:0]        num_blocks;

  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Read Block"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd16,16'd0});   // set timeout setting

    `APB_WR32(`EMMC_SRC_DST_ADDR,dst_addr); // memory address/location to put the return data

    cmd_arg         = tgt_addr;
    `APB_WR32(`EMMC_CTRL0_ADDR,{num_blocks,12'd0,block_length});      // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                         // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_RD_BLOCK_ONE));  // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Read Block"))
  end
endtask // emmc_cmd_read_block

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_bustest_w;
  input [31:0]        src_addr;
  input [15:0]        num_bytes;

  reg   [3:0]         block_length;
  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Bus Test Write"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd0,16'd0});   // set timeout setting

    `APB_WR32(`EMMC_SRC_DST_ADDR,src_addr); // memory address/location to fetch data

    cmd_arg         = 0;
    block_length    = get_block_size_encoding(num_bytes);
    `APB_WR32(`EMMC_CTRL0_ADDR,{16'd1,12'd0,block_length});      // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                         // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_BUS_TEST_W));    // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Bus Test Write"))
  end
endtask // emmc_cmd_bustest_w

// ------------------------------------------------------------------------------------------------------------
task emmc_cmd_bustest_r;
  input [31:0]        dst_addr;
  input [15:0]        num_bytes;

  reg   [3:0]         block_length;
  reg   [31:0]        cmd_arg;
  reg   [31:0]        rdat;
  begin
    $display("\n");
    `N_MSG(("eMMC Command Started: Bus Test Read"))
    `APB_WR32(`EMMC_CFG1_ADDR,{16'd4,16'd0});   // set timeout setting

    `APB_WR32(`EMMC_SRC_DST_ADDR,dst_addr); // memory address/location to put the return data

    cmd_arg         = 0;
    block_length    = get_block_size_encoding(num_bytes);
    `APB_WR32(`EMMC_CTRL0_ADDR,{16'd1,12'd0,block_length});      // num blocks, block length
    `APB_WR32(`EMMC_CTRL1_ADDR,cmd_arg);                         // argument
    `APB_WR32(`EMMC_CTRL2_ADDR,(CMD_START | CMD_BUS_TEST_R));    // start, cmd index
    `TIME_DELAY(10,clk_i)

    wait_ip_busy_status(1'b0);

    emmc_get_resp_data(1,1,rsp_dat);
    `N_MSG(("eMMC Device Status: 0x%4h_%4h",rsp_dat[1*32+16+:16],rsp_dat[1*32+0+:16]))

    // clear interrupt status
    `APB_WR32(`EMMC_INT_STS_ADDR,{32{1'b1}});

    `N_MSG(("eMMC Command Done: Bus Test Read"))
  end
endtask // emmc_cmd_bustest_r

// ------------------------------------------------------------------------------------------------------------
task compare_mem_data;
  input [16-1:0]      exp_ptr;
  input [16-1:0]      obs_ptr;
  input [16  :0]      num_dat;

  integer             idx;
  reg   [32-1:0]      exp_dat;
  reg   [32-1:0]      obs_dat;
  begin
    for(idx=0; idx<num_dat; idx=idx+1) begin
      exp_dat = `TB_MEM_ARRAY[exp_ptr+idx];
      obs_dat = `TB_MEM_ARRAY[obs_ptr+idx];
      if(obs_dat !== exp_dat) begin
        `E_MSG(("[MISCOMPARE] Exp_Addr:0x%8h Exp_Data:0x%8h, Obs_Addr:0x%8h Obs_Data:0x%8h",
                (4*(exp_ptr+idx)),exp_dat,(4*(obs_ptr+idx)),obs_dat))
      end
      else begin
        `N_MSG(("[DATA_MATCH] Exp_Addr:0x%8h Exp_Data:0x%8h, Obs_Addr:0x%8h Obs_Data:0x%8h",
                (4*(exp_ptr+idx)),exp_dat,(4*(obs_ptr+idx)),obs_dat))
      end
    end // for
  end
endtask // compare_mem_data

// ------------------------------------------------------------------------------------------------------------

`endif // __TB_UTIL_TASK__
