// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_AHBL_M__
`define __RTL_MODULE__EMMC_AHBL_M__
//==========================================================================
// Module : emmc_ahbl_m
// Description: AHB-Lite Master for eMMC Controller
//==========================================================================
module emmc_ahbl_m #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          SIMULATION      = 0

,parameter                          DEVICE_FAMILY   = "LAV-AT"
,parameter                          FIFO_IMPL       = "PMI"             // "PMI"/"pmi" or "RTL"/"rtl" or "REG"/"reg"
,parameter                          MEM_IMPL        = "EBR"             // "EBR" or "LUT" or "HARD_IP"
,parameter                          PIPE_IMPL       = "FIFOREG"         // "SHREG" or "FIFOREG"
,parameter                          CLKDOMAIN       = "SYNC"            // "SYNC" - sck_src_i clock is the same as clk_i

,parameter                          MIN_BLOCK_SIZE  = 512
,parameter                          MAX_BLOCK_SIZE  = 4096
,parameter                          MAX_NUM_BLOCK   = 65536
,parameter                          FIFO_DEPTH      = ((2*MAX_BLOCK_SIZE)/4)

,parameter                          AXI4_TID_WIDTH  = 1                 // Not used for AHBL, kept for compatibility
,parameter                          AXI4_LEN_WIDTH  = 8                 // Not used for AHBL, kept for compatibility
,parameter                          AXI4_ADR_WIDTH  = 32
,parameter                          AXI4_DAT_WIDTH  = 32
,parameter                          AXI4_STB_WIDTH  = ((AXI4_DAT_WIDTH + 7) / 8)

) //--end_param--

( //--begin_ports--

 input                              clk_i               // system clock
,input                              rst_n_i

// ----------------------------------------------------
// AHB-Lite Manager interface
,output wire                        ahbl_hsel_o
,output wire  [AXI4_ADR_WIDTH-1:0]  ahbl_haddr_o
,output wire  [1:0]                 ahbl_htrans_o
,output wire                        ahbl_hwrite_o
,output wire  [2:0]                 ahbl_hsize_o
,output wire  [2:0]                 ahbl_hburst_o
,output wire  [3:0]                 ahbl_hprot_o
,output wire                        ahbl_hmastlock_o
,output wire  [AXI4_DAT_WIDTH-1:0]  ahbl_hwdata_o

,input                              ahbl_hready_i
,input                              ahbl_hresp_i
,input        [AXI4_DAT_WIDTH-1:0]  ahbl_hrdata_i
// ----------------------------------------------------

,input        [3:0]                 csr_emmc_block_len      // 0 - 1 byte, 1 - 2 bytes,...,8- 256 bytes, 9 - 512 bytes,..., 14 - 16KB
,input        [15:0]                csr_emmc_num_blocks     // 0 - no data, 1 - 1 data block, 2 - 2 data blocks,...,
,input        [31:0]                csr_src_dst_addr        // must be aligned to block size - minimum alignment should be 512 bytes

,output wire                        det_bus_wr_error
,output wire                        det_bus_rd_error

// from command processor
,input                              emmc_memrd_req          // for eMMC read request, write the data to AHB
,input                              emmc_memwr_req          // for eMMC write request, need to fetch data from AHB
,output wire                        emmc_req_done

,output wire                        cmd_proc_mem_avail
,output wire  [31:0]                cmd_proc_mem_rdat
,input                              cmd_proc_mem_rden

,output wire                        cmd_proc_mem_free
,input        [31:0]                cmd_proc_mem_wdat
,input                              cmd_proc_mem_wren
)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------
// AHB-Lite HTRANS encoding
localparam                          HTRANS_IDLE   = 2'b00;
localparam                          HTRANS_BUSY   = 2'b01;
localparam                          HTRANS_NONSEQ = 2'b10;
localparam                          HTRANS_SEQ    = 2'b11;

// AHB-Lite HBURST encoding
localparam                          HBURST_SINGLE = 3'b000;
localparam                          HBURST_INCR   = 3'b001;
localparam                          HBURST_WRAP4  = 3'b010;
localparam                          HBURST_INCR4  = 3'b011;
localparam                          HBURST_WRAP8  = 3'b100;
localparam                          HBURST_INCR8  = 3'b101;
localparam                          HBURST_WRAP16 = 3'b110;
localparam                          HBURST_INCR16 = 3'b111;

// AHB-Lite HSIZE encoding
localparam                          HSIZE_BYTE    = 3'b000;
localparam                          HSIZE_HWORD   = 3'b001;
localparam                          HSIZE_WORD    = 3'b010;
localparam                          HSIZE_DWORD   = 3'b011;

// State machine
localparam                          // auto enum state_1
                                    ST_BUSREQ_IDLE  = 4'd0
                                   ,ST_BUSREQ_WAIT  = 4'd1
                                   ,ST_BUSREQ_READ  = 4'd2
                                   ,ST_BUSREQ_WRITE = 4'd4
                                   ,ST_BUSREQ_DONE  = 4'd8
                                   ;

localparam                          FIFO_AFUL_LVL = (FIFO_DEPTH-2);
localparam                          FCNTWID       = $clog2(FIFO_DEPTH+1);
localparam                          BLKCNTWID     = $clog2(MAX_NUM_BLOCK);  // block counter width
localparam                          PBCNTWID      = (MAX_BLOCK_SIZE > 16384)? 6 :
                                                    (MAX_BLOCK_SIZE >  8192)? 5 :
                                                    (MAX_BLOCK_SIZE >  4096)? 4 :
                                                    (MAX_BLOCK_SIZE >  2048)? 3 : 2; // partial block counter width

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

wire          [15:0]                num_blocks;
wire          [15:0]                block_size;
wire                                block_last;
wire                                incr_blk_cnt;

wire                                wr_dat_vld;
wire                                wr_dat_done;
wire                                rd_dat_vld;
wire                                rd_dat_done;

wire                                dat_fifo_full;
wire                                dat_fifo_aful;
wire                                dat_fifo_emty;
wire                                dat_fifo_aemt;
wire          [31:0]                dat_fifo_rdata;
wire                                dat_fifo_rden;

wire          [8:0]                 axlen_p1_d;
wire          [8:0]                 axlen_d;
wire          [AXI4_ADR_WIDTH-1:0]  axaddr_base;
wire          [AXI4_ADR_WIDTH-1:0]  next_addr;

wire                                ahb_addr_phase;
wire                                ahb_data_phase;
wire                                transfer_done;
wire                                in_transfer;
wire                                rd_req_done;
wire                                wr_req_done;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [3:0]                 // auto enum state_1
                                    busreq_cs;

reg           [8:0]                 axlen_p1;
reg           [8:0]                 burst_count;        // counts transfers in current burst
reg           [8:0]                 data_count;         // counts data beats (1 cycle behind address)
reg           [AXI4_ADR_WIDTH-1:0]  axaddr_r;
reg                                 addr_issued;        // tracks if address was issued last cycle

reg                                 dat_fifo_wren;
reg           [31:0]                dat_fifo_wdata;

reg                                 bus_wr_error;
reg                                 bus_rd_error;

reg           [FCNTWID-1:0]         fifo_cntr;
reg                                 mem_avail;
reg                                 mem_free;
reg                                 fifocnt_gteq_axlen;

reg           [BLKCNTWID-1:0]       blk_cntr;           // used for number of blocks
reg                                 all_blocks_done;

// Internal registers for AHB-Lite control signals
reg                                 ahbl_hsel_r;
reg           [AXI4_ADR_WIDTH-1:0]  ahbl_haddr_r;
reg           [1:0]                 ahbl_htrans_r;
reg                                 ahbl_hwrite_r;
reg           [2:0]                 ahbl_hsize_r;
reg           [2:0]                 ahbl_hburst_r;
reg           [3:0]                 ahbl_hprot_r;
reg                                 ahbl_hmastlock_r;
reg           [AXI4_DAT_WIDTH-1:0]  ahbl_hwdata_r;

//--------------------------------------------------------------------------
//--- Assignments ---
//--------------------------------------------------------------------------

// AHB-Lite output assignments
assign ahbl_hsel_o      = ahbl_hsel_r;
assign ahbl_haddr_o     = ahbl_haddr_r;
assign ahbl_htrans_o    = ahbl_htrans_r;
assign ahbl_hwrite_o    = ahbl_hwrite_r;
assign ahbl_hsize_o     = ahbl_hsize_r;
assign ahbl_hburst_o    = ahbl_hburst_r;
assign ahbl_hprot_o     = ahbl_hprot_r;
assign ahbl_hmastlock_o = ahbl_hmastlock_r;
assign ahbl_hwdata_o    = ahbl_hwdata_r;

// FIFO interface
assign cmd_proc_mem_rdat  = dat_fifo_rdata;
// For writes to AHB (emmc_memrd_req): read FIFO during data phase to present write data
// For reads from AHB (emmc_memwr_req): read FIFO when command processor requests it
assign dat_fifo_rden      = (emmc_memrd_req & ~dat_fifo_emty & ahb_data_phase & ahbl_hready_i) |
                            (emmc_memwr_req & ~dat_fifo_emty & cmd_proc_mem_rden);

// Status signals
assign det_bus_wr_error   = bus_wr_error;
assign det_bus_rd_error   = bus_rd_error;
assign cmd_proc_mem_avail = mem_avail;
assign cmd_proc_mem_free  = mem_free;
assign emmc_req_done      = all_blocks_done & (busreq_cs == ST_BUSREQ_WAIT);

// Transfer tracking
assign in_transfer        = (busreq_cs == ST_BUSREQ_READ || busreq_cs == ST_BUSREQ_WRITE || busreq_cs == ST_BUSREQ_DONE);
assign ahb_addr_phase     = (busreq_cs == ST_BUSREQ_READ || busreq_cs == ST_BUSREQ_WRITE) && ahbl_hready_i && (burst_count < axlen_p1);
assign ahb_data_phase     = addr_issued;

// Address/request done signals - when all addresses for a block are issued
assign rd_req_done        = (busreq_cs == ST_BUSREQ_READ) && ahbl_hready_i && (burst_count >= axlen_p1);
assign wr_req_done        = (busreq_cs == ST_BUSREQ_WRITE) && ahbl_hready_i && (burst_count >= axlen_p1);

// Data transfer signals
assign wr_dat_vld         = in_transfer & ahbl_hwrite_r & ahbl_hready_i & (data_count > 9'd0) & (data_count <= axlen_p1);
assign wr_dat_done        = wr_dat_vld & (data_count == axlen_p1);
assign rd_dat_vld         = in_transfer & ~ahbl_hwrite_r & ahbl_hready_i & (data_count > 9'd0) & (data_count <= axlen_p1);
assign rd_dat_done        = rd_dat_vld & (data_count == axlen_p1);
assign transfer_done      = rd_dat_done | wr_dat_done;

// Address calculation
assign axaddr_base        = (MIN_BLOCK_SIZE >=    4)? {csr_src_dst_addr[2 +:AXI4_ADR_WIDTH-2 ],{2 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=    8)? {csr_src_dst_addr[3 +:AXI4_ADR_WIDTH-3 ],{3 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=   16)? {csr_src_dst_addr[4 +:AXI4_ADR_WIDTH-4 ],{4 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=   32)? {csr_src_dst_addr[5 +:AXI4_ADR_WIDTH-5 ],{5 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=   64)? {csr_src_dst_addr[6 +:AXI4_ADR_WIDTH-6 ],{6 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=  128)? {csr_src_dst_addr[7 +:AXI4_ADR_WIDTH-7 ],{7 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=  256)? {csr_src_dst_addr[8 +:AXI4_ADR_WIDTH-8 ],{8 {1'b0}}} :
                            (MIN_BLOCK_SIZE >=  512)? {csr_src_dst_addr[9 +:AXI4_ADR_WIDTH-9 ],{9 {1'b0}}} :
                            (MIN_BLOCK_SIZE >= 1024)? {csr_src_dst_addr[10+:AXI4_ADR_WIDTH-10],{10{1'b0}}} :
                            (MIN_BLOCK_SIZE >= 2048)? {csr_src_dst_addr[11+:AXI4_ADR_WIDTH-11],{11{1'b0}}} :
                            (MIN_BLOCK_SIZE >= 4096)? {csr_src_dst_addr[12+:AXI4_ADR_WIDTH-12],{12{1'b0}}} :
                                                      {csr_src_dst_addr[13+:AXI4_ADR_WIDTH-13],{13{1'b0}}};

assign axlen_d            = axlen_p1 - 9'd1;
assign axlen_p1_d         = ((csr_emmc_block_len == 4'd9) && (MIN_BLOCK_SIZE >= 512))? 9'd128 :
                            ((csr_emmc_block_len == 4'd8) && (MIN_BLOCK_SIZE >= 256))? 9'd64  :
                            ((csr_emmc_block_len == 4'd7) && (MIN_BLOCK_SIZE >= 128))? 9'd32  :
                            ((csr_emmc_block_len == 4'd6) && (MIN_BLOCK_SIZE >=  64))? 9'd16  :
                            ((csr_emmc_block_len == 4'd5) && (MIN_BLOCK_SIZE >=  32))? 9'd8   :
                            ((csr_emmc_block_len == 4'd4) && (MIN_BLOCK_SIZE >=  16))? 9'd4   :
                            ((csr_emmc_block_len == 4'd3) && (MIN_BLOCK_SIZE >=   8))? 9'd2   :
                            ((csr_emmc_block_len == 4'd2) && (MIN_BLOCK_SIZE >=   4))? 9'd1   : 9'd256;

assign num_blocks         = (blk_cntr & 16'hFFFF);
assign block_size         = ({15'd0,1'b1} << csr_emmc_block_len);
assign next_addr          = axaddr_r + {{(AXI4_ADR_WIDTH-3){1'b0}}, 3'd4}; // increment by 4 bytes (word)

//--------------------------------------------
//-- Main State Machine --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    busreq_cs <= ST_BUSREQ_IDLE;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    addr_issued <= 1'h0;
    all_blocks_done <= 1'h0;
    axaddr_r <= {AXI4_ADR_WIDTH{1'b0}};
    axlen_p1 <= 9'h0;
    blk_cntr <= {BLKCNTWID{1'b0}};
    burst_count <= 9'h0;
    data_count <= 9'h0;
    bus_rd_error <= 1'h0;
    bus_wr_error <= 1'h0;
    // End of automatics
  end
  else begin
    all_blocks_done   <= (num_blocks == csr_emmc_num_blocks);
    blk_cntr          <= blk_cntr + {{(BLKCNTWID-1){1'b0}},incr_blk_cnt};

    // Track if address was issued last cycle (for pipelined data phase)
    addr_issued       <= ahb_addr_phase;

    // Track data beats (continues even after last address is issued)
    if(busreq_cs == ST_BUSREQ_IDLE || busreq_cs == ST_BUSREQ_WAIT) begin
      data_count <= 9'd0;
    end
    else if((addr_issued || busreq_cs == ST_BUSREQ_DONE) && ahbl_hready_i && (data_count < axlen_p1)) begin
      data_count <= data_count + 9'd1;
    end

    // Pulse on error detection (not sticky) - used for interrupt triggering
    bus_wr_error      <= (wr_dat_vld & ahbl_hresp_i);
    bus_rd_error      <= (rd_dat_vld & ahbl_hresp_i);

    case(busreq_cs)
      ST_BUSREQ_WAIT : begin
        busreq_cs     <= ST_BUSREQ_WAIT;

        if(all_blocks_done) begin
          if(~(emmc_memwr_req | emmc_memrd_req)) begin
            busreq_cs <= ST_BUSREQ_IDLE;
          end
        end
        else if(emmc_memwr_req) begin
          busreq_cs    <= ST_BUSREQ_READ;
          burst_count  <= 9'd0;
        end
        else if(emmc_memrd_req & fifocnt_gteq_axlen) begin
          busreq_cs    <= ST_BUSREQ_WRITE;
          burst_count  <= 9'd0;
        end
      end // ST_BUSREQ_WAIT

      ST_BUSREQ_READ : begin
        // Pipelined AHB-Lite: present address every cycle when ready
        if(ahbl_hready_i && (burst_count < axlen_p1)) begin
          burst_count <= burst_count + 9'd1;
          // Increment address after presenting current address
          axaddr_r    <= next_addr;
        end

        // Check if we've issued all address beats
        if(burst_count >= axlen_p1) begin
          busreq_cs <= ST_BUSREQ_DONE;
        end
      end // ST_BUSREQ_READ

      ST_BUSREQ_WRITE : begin
        // Pipelined AHB-Lite: present address every cycle when ready
        if(ahbl_hready_i && (burst_count < axlen_p1)) begin
          burst_count <= burst_count + 9'd1;
          // Increment address after presenting current address
          axaddr_r    <= next_addr;
        end

        // Check if we've issued all address beats
        if(burst_count >= axlen_p1) begin
          busreq_cs <= ST_BUSREQ_DONE;
        end
      end // ST_BUSREQ_WRITE

      ST_BUSREQ_DONE : begin
        busreq_cs <= ST_BUSREQ_DONE;

        // Wait for the last data beat to complete
        if(transfer_done) begin
          busreq_cs <= ST_BUSREQ_WAIT;
          // Capture the last address used for next block start
          axaddr_r  <= ahbl_haddr_r;
        end
      end // ST_BUSREQ_DONE

      default : begin // ST_BUSREQ_IDLE
        busreq_cs     <= ST_BUSREQ_IDLE;

        blk_cntr      <= {(BLKCNTWID){1'b0}};
        burst_count   <= 9'd0;
        data_count    <= 9'd0;
        axaddr_r      <= axaddr_base;
        axlen_p1      <= axlen_p1_d;

        if(emmc_memwr_req | emmc_memrd_req) begin
          busreq_cs   <= ST_BUSREQ_WAIT;
        end
      end // ST_BUSREQ_IDLE
    endcase
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- AHB-Lite Control Signals --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    ahbl_hsel_r      <= 1'b0;
    ahbl_haddr_r     <= {AXI4_ADR_WIDTH{1'b0}};
    ahbl_htrans_r    <= HTRANS_IDLE;
    ahbl_hwrite_r    <= 1'b0;
    ahbl_hsize_r     <= HSIZE_WORD;
    ahbl_hburst_r    <= HBURST_INCR;
    ahbl_hprot_r     <= 4'b0011; // Data access, privileged
    ahbl_hmastlock_r <= 1'b0;
  end
  else begin
    case(busreq_cs)
      ST_BUSREQ_READ : begin
        ahbl_hsel_r <= 1'b1;
        ahbl_hwrite_r <= 1'b0;  // Read
        ahbl_haddr_r  <= (ahbl_hready_i)? axaddr_r : ahbl_haddr_r;

        // Present new address every cycle when ready
        if(ahbl_hready_i && (burst_count < axlen_p1)) begin
          ahbl_htrans_r <= (burst_count == 9'd0) ? HTRANS_NONSEQ : HTRANS_SEQ;
        end
        else begin
          ahbl_htrans_r <= HTRANS_IDLE;
        end
      end

      ST_BUSREQ_WRITE : begin
        ahbl_hsel_r <= 1'b1;
        ahbl_hwrite_r <= 1'b1;  // Write
        ahbl_haddr_r  <= (ahbl_hready_i)? axaddr_r : ahbl_haddr_r;

        // Present new address every cycle when ready
        if(ahbl_hready_i && (burst_count < axlen_p1)) begin
          ahbl_htrans_r <= (burst_count == 9'd0) ? HTRANS_NONSEQ : HTRANS_SEQ;
        end
        else begin
          ahbl_htrans_r <= HTRANS_IDLE;
        end
      end

      default: begin
        // Deassert HSEL and set IDLE when not in active transfer
        ahbl_hsel_r   <= 1'b0;
        ahbl_htrans_r <= HTRANS_IDLE;
      end
    endcase
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- AHB-Lite Write Data --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    ahbl_hwdata_r <= 32'h0;
  end
  else begin
    // Write data is presented in data phase (one cycle after address)
    if(ahb_data_phase & ahbl_hready_i & ~dat_fifo_emty) begin
      ahbl_hwdata_r <= dat_fifo_rdata;
    end
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- FIFO Write Logic (from AHB reads or command processor) --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    dat_fifo_wdata <= 32'h0;
    dat_fifo_wren <= 1'h0;
    // End of automatics
  end
  else begin
    dat_fifo_wren   <= (emmc_memrd_req & ~dat_fifo_full & cmd_proc_mem_wren) |
                       (emmc_memwr_req & ~dat_fifo_full & rd_dat_vld);
    dat_fifo_wdata  <= (emmc_memrd_req)? cmd_proc_mem_wdat : ahbl_hrdata_i;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- FIFO Counter and Flow Control --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    fifo_cntr <= {FCNTWID{1'b0}};
    fifocnt_gteq_axlen <= 1'h0;
    mem_avail <= 1'h0;
    mem_free <= 1'h0;
    // End of automatics
  end
  else begin
    fifocnt_gteq_axlen <= (fifo_cntr >= axlen_p1);
    mem_avail <= |fifo_cntr & (fifo_cntr >= (block_size[15:2] & {FCNTWID{1'b1}}));
    mem_free  <= (fifo_cntr <= (block_size[15:2] & {FCNTWID{1'b1}}));

    case({dat_fifo_wren,dat_fifo_rden})
      2'b01   : fifo_cntr <= fifo_cntr - {{(FCNTWID-1){1'b0}},1'b1};
      2'b10   : fifo_cntr <= fifo_cntr + {{(FCNTWID-1){1'b0}},1'b1};
      default : fifo_cntr <= fifo_cntr;
    endcase
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Block Counter Logic --
//--------------------------------------------
generate
  if(MAX_BLOCK_SIZE > 1024) begin : gen_blk_gt1KB
    reg           [PBCNTWID-1:0]        partial_bcnt;
    reg                                 block_last_r;
    reg           [1:0]                 req_done_dly;

    wire          [5:0]                 max_partial_bcnt;

    assign incr_blk_cnt = req_done_dly[1] & block_last;
    assign block_last   = block_last_r;

    assign max_partial_bcnt = (MAX_BLOCK_SIZE <  4096)? (block_size[11:10] & {6{1'b1}}) :
                              (MAX_BLOCK_SIZE <  8192)? (block_size[12:10] & {6{1'b1}}) :
                              (MAX_BLOCK_SIZE < 16384)? (block_size[13:10] & {6{1'b1}}) :
                              (MAX_BLOCK_SIZE < 32768)? (block_size[14:10] & {6{1'b1}}) : 6'd0;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        block_last_r <= 1'h0;
        partial_bcnt <= {PBCNTWID{1'b0}};
        req_done_dly <= 2'h0;
        // End of automatics
      end
      else begin
        req_done_dly <= {req_done_dly[0],(wr_req_done | rd_req_done)}; // need to delay to wait for updated block_last_r
        if(busreq_cs == ST_BUSREQ_IDLE) begin
          partial_bcnt  <= {PBCNTWID{1'b0}};
          block_last_r  <= 1'b0;
        end
        else begin
          block_last_r    <= (partial_bcnt == (max_partial_bcnt & {PBCNTWID{1'b1}}));
          if(wr_req_done | rd_req_done) begin
            partial_bcnt  <= partial_bcnt + {{(PBCNTWID-1){1'b0}},~block_last_r};
          end
          else if(incr_blk_cnt) begin
            partial_bcnt  <= {PBCNTWID{1'b0}};
          end
        end
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--

  end // gen_blk_gt1KB
  else begin : gen_blk_lteq1KB
    assign block_last   = 1'b1;
    assign incr_blk_cnt = (wr_req_done | rd_req_done) & block_last;
  end // gen_blk_lteq1KB

  if(SIMULATION) begin : gen_sim
    // -----------------------------------
    // For Simulation use only
    // State in ASCII for readability
    // -----------------------------------

    /*AUTOASCIIENUM("busreq_cs", "_bus_cs_", "ST_BUSREQ_")*/
    // Beginning of automatic ASCII enum decoding
    reg         [39:0]        _bus_cs_;         // Decode of busreq_cs
    always @(busreq_cs) begin
       case ({busreq_cs})
         ST_BUSREQ_IDLE:  _bus_cs_ = "idle ";
         ST_BUSREQ_WAIT:  _bus_cs_ = "wait ";
         ST_BUSREQ_READ:  _bus_cs_ = "read ";
         ST_BUSREQ_WRITE: _bus_cs_ = "write";
         ST_BUSREQ_DONE:  _bus_cs_ = "done ";
         default:         _bus_cs_ = "%Erro";
       endcase
    end
    // End of automatics
  end // gen_sim
endgenerate

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
emmc_fifo #
(
 // Parameters
 .SIMULATION                            (SIMULATION),
 .DEVICE_FAMILY                         (DEVICE_FAMILY),
 .FIFO_IMPL                             (FIFO_IMPL),
 .MEM_IMPL                              (MEM_IMPL),
 .PIPE_IMPL                             (PIPE_IMPL),
 .CLKDOMAIN                             (CLKDOMAIN),
 .DWID                                  (32),
 .SIZE                                  (FIFO_DEPTH),
 .AFUL_LVL                              (FIFO_AFUL_LVL),
 .INV_PMI_WCLK                          (0),
 .INV_PMI_RCLK                          (0))
u_dat_fifo
(
 // Inputs
 .wclk                                  (clk_i),
 .rclk                                  (clk_i),
 .wrst_n                                (rst_n_i),
 .rrst_n                                (rst_n_i),
 .wren                                  (dat_fifo_wren),
 .wdat                                  (dat_fifo_wdata[31:0]),
 .rden                                  (dat_fifo_rden),
 // Outputs
 .rdat                                  (dat_fifo_rdata[31:0]),
 .emty                                  (dat_fifo_emty),
 .full                                  (dat_fifo_full),
 .aful                                  (dat_fifo_aful),
 .aemt                                  (dat_fifo_aemt)
 );


endmodule //--emmc_ahbl_m--
`endif // __RTL_MODULE__EMMC_AHBL_M__
