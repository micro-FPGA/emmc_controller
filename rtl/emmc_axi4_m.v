// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_AXI4_M__
`define __RTL_MODULE__EMMC_AXI4_M__
//==========================================================================
// Module : emmc_axi4_m
//==========================================================================
module emmc_axi4_m #

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

,parameter                          AXI4_TID_WIDTH  = 1
,parameter                          AXI4_LEN_WIDTH  = 8
,parameter                          AXI4_ADR_WIDTH  = 32
,parameter                          AXI4_DAT_WIDTH  = 32
,parameter                          AXI4_STB_WIDTH  = ((AXI4_DAT_WIDTH + 7) / 8)

) //--end_param--

( //--begin_ports--

 input                              clk_i               // system clock
,input                              rst_n_i

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

,input        [3:0]                 csr_emmc_block_len      // 0 - 1 byte, 1 - 2 bytes,...,8- 256 bytes, 9 - 512 bytes,..., 14 - 16KB
,input        [15:0]                csr_emmc_num_blocks     // 0 - no data, 1 - 1 data block, 2 - 2 data blocks,...,
,input        [31:0]                csr_src_dst_addr        // must be aligned to block size - minimum alignment should be 512 bytes

,output wire                        det_bus_wr_error
,output wire                        det_bus_rd_error

// from command processor
,input                              emmc_memrd_req          // for eMMC read request, write the data to AXI
,input                              emmc_memwr_req          // for eMMC write request, need to fetch data from AXI
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
localparam                          // auto enum state_1
                                    ST_BUSREQ_IDLE  = 4'd0
                                   ,ST_BUSREQ_WAIT  = 4'd1
                                   ,ST_BUSREQ_READ  = 4'd2
                                   ,ST_BUSREQ_WRITE = 4'd4
                                   ,ST_BUSREQ_DONE  = 4'd8
                                   ;

localparam                          AXI4_FIXED  = 2'b00
                                   ,AXI4_INCR   = 2'b01
                                   ,AXI4_WRAP   = 2'b10
                                   ;

localparam                          AXI4_SIZE_08  = 3'b011
                                   ,AXI4_SIZE_16  = 3'b100
                                   ,AXI4_SIZE_32  = 3'b101
                                   ;

localparam                          FIFO_AFUL_LVL = (FIFO_DEPTH-2);
localparam                          FCNTWID       = $clog2(FIFO_DEPTH+1);
localparam                          BLKCNTWID     = $clog2(MAX_NUM_BLOCK);  // block counter width - max 16 bits
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
wire                                wr_req_done;
wire                                wr_rsp_done;
wire                                rd_req_done;

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

wire                                axi4_wdatq_emty;
wire                                axi4_wdatq_full;

wire          [8:0]                 axlen_p1_d;
wire          [8:0]                 axlen_d;
wire          [AXI4_ADR_WIDTH-1:0]  axaddr_base;
wire          [7:0]                 wcntr_d;

reg                                 axi4_wdatq_wren;
//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [3:0]                 // auto enum state_1
                                    busreq_cs;

reg           [8:0]                 axlen_p1;
reg           [7:0]                 axlen_r;
reg           [AXI4_ADR_WIDTH-1:2]  axaddr_r;
reg                                 wlast_r;
reg           [7:0]                 wcntr;

reg                                 dat_fifo_wren;
reg           [31:0]                dat_fifo_wdata;

reg                                 bus_wr_error;
reg                                 bus_rd_error;

reg           [FCNTWID-1:0]         fifo_cntr;
reg                                 mem_avail;
reg                                 mem_free;

reg           [BLKCNTWID-1:0]       blk_cntr;       // used for number of blocks
reg                                 all_blocks_done;
reg                                 fifocnt_gteq_axlen;

assign m_axi4_awid_o      = {AXI4_TID_WIDTH{1'b0}};
assign m_axi4_awsize_o    = AXI4_SIZE_32;
assign m_axi4_awburst_o   = AXI4_INCR;
assign m_axi4_awaddr_o    = {axaddr_r[2+:AXI4_ADR_WIDTH-2],2'd0};
assign m_axi4_awlen_o     = axlen_r;
assign m_axi4_wstrb_o     = {AXI4_STB_WIDTH{1'b1}};
assign m_axi4_bready_o    = 1'b1;   // always ready

assign m_axi4_arid_o      = {AXI4_TID_WIDTH{1'b0}};
assign m_axi4_arsize_o    = AXI4_SIZE_32;
assign m_axi4_arburst_o   = AXI4_INCR;
assign m_axi4_araddr_o    = {axaddr_r[2+:AXI4_ADR_WIDTH-2],2'd0};
assign m_axi4_arlen_o     = axlen_r;

assign m_axi4_awvalid_o   = (busreq_cs == ST_BUSREQ_WRITE);
assign m_axi4_wvalid_o    = ~axi4_wdatq_emty & (busreq_cs == ST_BUSREQ_DONE);
assign m_axi4_arvalid_o   = (busreq_cs == ST_BUSREQ_READ );
assign m_axi4_rready_o    = ~dat_fifo_aful;


assign wr_req_done        = m_axi4_awvalid_o & m_axi4_awready_i;
assign wr_dat_vld         = m_axi4_wvalid_o & m_axi4_wready_i;
assign wr_dat_done        = wr_dat_vld & m_axi4_wlast_o;
assign wr_rsp_done        = m_axi4_bvalid_i & m_axi4_bready_o;

assign rd_req_done        = m_axi4_arvalid_o & m_axi4_arready_i;
assign rd_dat_vld         = m_axi4_rvalid_i & m_axi4_rready_o;
assign rd_dat_done        = rd_dat_vld & m_axi4_rlast_i;

assign emmc_req_done      = all_blocks_done & (busreq_cs == ST_BUSREQ_WAIT);

assign cmd_proc_mem_rdat  = dat_fifo_rdata;
assign dat_fifo_rden      = (emmc_memrd_req & ~dat_fifo_emty & axi4_wdatq_wren) |
                            (emmc_memwr_req & ~dat_fifo_emty & cmd_proc_mem_rden);

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
assign wcntr_d            = (wcntr - {7'd0,(|wcntr & axi4_wdatq_wren)});

assign det_bus_wr_error   = bus_wr_error;
assign det_bus_rd_error   = bus_rd_error;

assign cmd_proc_mem_avail = mem_avail;
assign cmd_proc_mem_free  = mem_free;

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    busreq_cs <= ST_BUSREQ_IDLE;
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    all_blocks_done <= 1'h0;
    axaddr_r <= {(1+(AXI4_ADR_WIDTH-1)-(2)){1'b0}};
    axlen_p1 <= 9'h0;
    axlen_r <= 8'h0;
    blk_cntr <= {BLKCNTWID{1'b0}};
    bus_rd_error <= 1'h0;
    bus_wr_error <= 1'h0;
    wcntr <= 8'h0;
    wlast_r <= 1'h0;
    // End of automatics
  end
  else begin
    axlen_r           <= axlen_d[7:0];
    all_blocks_done   <= (num_blocks == csr_emmc_num_blocks);
    blk_cntr          <= blk_cntr + {{(BLKCNTWID-1){1'b0}},incr_blk_cnt};
    wcntr             <= wcntr_d;
    wlast_r           <= ~|wcntr_d;
    bus_wr_error      <= wr_rsp_done & (|m_axi4_bresp_i);
    bus_rd_error      <= rd_dat_vld & (|m_axi4_rresp_i);
    case(busreq_cs)
      ST_BUSREQ_WAIT : begin
        busreq_cs     <= ST_BUSREQ_WAIT;
        wcntr         <= axlen_r;

        if(all_blocks_done) begin
          if(~(emmc_memwr_req | emmc_memrd_req)) begin
            busreq_cs <= ST_BUSREQ_IDLE;
          end
        end
        else if(emmc_memwr_req) begin
          busreq_cs   <= ST_BUSREQ_READ;
        end
        else if(emmc_memrd_req & fifocnt_gteq_axlen) begin
          busreq_cs   <= ST_BUSREQ_WRITE;
        end
      end // ST_BUSREQ_WAIT

      ST_BUSREQ_READ : begin
        busreq_cs     <= ST_BUSREQ_READ;

        if(rd_req_done) begin
          busreq_cs   <= ST_BUSREQ_DONE;
        end
      end // ST_BUSREQ_READ

      ST_BUSREQ_WRITE : begin
        busreq_cs     <= ST_BUSREQ_WRITE;

        if(wr_req_done) begin
          busreq_cs   <= ST_BUSREQ_DONE;
        end
      end // ST_BUSREQ_WRITE

      ST_BUSREQ_DONE : begin
        busreq_cs     <= ST_BUSREQ_DONE;

        if(wr_dat_done | rd_dat_done) begin
          busreq_cs   <= ST_BUSREQ_WAIT;
          axaddr_r    <= axaddr_r + {{(AXI4_ADR_WIDTH-2-9){1'b0}}, axlen_p1};
        end
      end // ST_BUSREQ_DONE

      default : begin // ST_BUSREQ_IDLE
        busreq_cs     <= ST_BUSREQ_IDLE;

        blk_cntr      <= {(BLKCNTWID){1'b0}};
        wcntr         <= 8'd0;
        wlast_r       <= 1'b0;
        axaddr_r      <= axaddr_base[2+:AXI4_ADR_WIDTH-2];
        axlen_p1      <= axlen_p1_d;
        if(emmc_memwr_req | emmc_memrd_req) begin
          busreq_cs   <= ST_BUSREQ_WAIT;
        end
      end // ST_BUSREQ_IDLE
    endcase
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  if((busreq_cs == ST_BUSREQ_IDLE) ||
     (busreq_cs == ST_BUSREQ_WAIT)) begin
    axi4_wdatq_wren = 1'b0;
  end
  else begin
    axi4_wdatq_wren = emmc_memrd_req & ~dat_fifo_emty & (axi4_wdatq_emty | wr_dat_vld);
  end
end //--always @*--

//--------------------------------------------
//-- Sequential block --
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
    dat_fifo_wdata  <= (emmc_memrd_req)? cmd_proc_mem_wdat : m_axi4_rdata_i;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------
//-- Sequential block --
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
    fifocnt_gteq_axlen <= (fifo_cntr >= axlen_r);
    mem_avail <= |fifo_cntr & (fifo_cntr >= (block_size[15:2] & {FCNTWID{1'b1}}));
    mem_free  <= (fifo_cntr <= (block_size[15:2] & {FCNTWID{1'b1}}));

    case({dat_fifo_wren,dat_fifo_rden})
      2'b01   : fifo_cntr <= fifo_cntr - {{(FCNTWID-1){1'b0}},1'b1};
      2'b10   : fifo_cntr <= fifo_cntr + {{(FCNTWID-1){1'b0}},1'b1};
      default : fifo_cntr <= fifo_cntr;
    endcase
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

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
            partial_bcnt  <= {{(PBCNTWID-1){1'b0}},~block_last_r};
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

shreg_fifo #
(
 .DWID                                  (32+1),
 .RNUM                                  (1)
)
u_axi4_wdatq
(
 // Inputs
 .clk                                   (clk_i),
 .rst_n                                 (rst_n_i),
 .clr                                   (1'b0),
 .wren                                  (axi4_wdatq_wren),
 .dtin                                  ({wlast_r
                                         ,dat_fifo_rdata[31:0]
                                         }),
 .rden                                  (wr_dat_vld),
 // Outputs
 .dtout                                 ({m_axi4_wlast_o
                                         ,m_axi4_wdata_o[31:0]
                                         }),
 .emty                                  (axi4_wdatq_emty),
 .full                                  (axi4_wdatq_full)
 );


endmodule //--emmc_axi4_m--
`endif // __RTL_MODULE__EMMC_AXI4_M__
