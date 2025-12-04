localparam DEVICE_FAMILY = "LFMXO5";
localparam AXI4_TID_WIDTH = 3;
localparam EN_DDR_MODE = 0;
localparam MAX_NUMLANE = 8;
localparam DEF_BLOCK_SIZE = 512;
localparam MIN_BLOCK_SIZE = 512;
localparam MAX_BLOCK_SIZE = 1024;
localparam MAX_NUM_BLOCK = 32;
localparam CSR_INTERFACE = "APB";
localparam DATA_INTERFACE = "AXI4";
localparam EN_FULLADDR_DECODE = 0;
localparam REG_BASE_ADDR = 32'h00000000;
localparam FIFO_DEPTH = 512;
localparam MEM_IMPL = "HARD_IP";
localparam CLKI_FREQ = 50.000000;
localparam CLKDIV_WID = 8;
localparam SPI_SCKDIV = 250;
localparam USE_CLKDIV1 = 1;
localparam USE_IO_PRIMITIVE = 1;
`define jd5f00
`define LFMXO5
`define LFMXO5_100T
`define DUT_INST_NAME tb_top.u_emmc0.lscc_emmc_controller_inst
`define TB_MEM_INTF axi
