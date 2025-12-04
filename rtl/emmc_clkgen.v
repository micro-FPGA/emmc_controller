// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_CLKGEN__
`define __RTL_MODULE__EMMC_CLKGEN__
//==========================================================================
// Module : emmc_clkgen
//==========================================================================
module emmc_clkgen #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                      SIMULATION    = 0
,parameter                      CNTRWID       = 8            // must be able to generate 400KHz,
                                                             // (e.g 200MHz input clock divided by (2*250 pulse width) = 400 KHz)
,parameter    [CNTRWID-1:0]     DEFAULT_RATE  = {{(CNTRWID-1){1'b0}},1'b1}
,parameter                      DEFAULT_CPOL  = 1'b0
,parameter                      DEFAULT_CPHA  = 1'b0
,parameter                      USE_CLKDIV1   = 0
,parameter                      CAPTURE_CSR   = 0            // add logic to capture CSR settings
,parameter                      EN_REGOUT     = 1

) //--end_param--

( //--begin_ports--
 input                          clk_i
,input                          rst_n_i

,input                          en_clk_gen      // generate clock output (advance clock gate)
,input                          clk_out_vld     // output clock gate

,input                          clk_updated
,input        [CNTRWID-1:0]     clk_divider     // 0 - div1, 1 - div2, 2 - div4, 3 - div6,...
,input                          clk_polarity    // 0 - idle at low, 1 - idle at high
,input                          clk_phase       // 0 - sample at odd number edges, 1 - sample at even number edges

,output wire                    clk_pos          // clock posedge pulse
,output wire                    clk_neg          // clock negedge pulse

,output wire                    clk_out         // output clock

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--


// -------------------
// clk_out
// -------------------
//         +--------+        +--------+        +--------+        +--------+
//         |        |        |        |        |        |        |        |
// --------+        +--------+        +--------+        +--------+        +
//
// -------------------
// clk_pos
// -------------------
//     +---+             +---+             +---+             +---+
//     |   |             |   |             |   |             |   |
// ----+   +-------------+   +-------------+   +-------------+   +---------
//
// -------------------
// clk_neg
// -------------------
//              +---+             +---+             +---+             +---+
//              |   |             |   |             |   |             |   |
// -------------+   +-------------+   +-------------+   +-------------+   +

//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
wire          [CNTRWID-1:0]     div_cnt_incr;
wire          [CNTRWID-1:0]     cur_clkdiv;
wire                            cur_cpol;
wire                            cur_cpha;
wire                            clk_toggle_nxt;
wire                            clkdiv_eq0_w;
wire                            clk_src;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg           [CNTRWID-1:0]     div_cnt;
reg                             clk_toggle;
reg                             clk_gen;


assign div_cnt_incr   = (div_cnt + (1 & {CNTRWID{1'b1}}));
assign clk_toggle_nxt = (div_cnt == cur_clkdiv);

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    clk_gen <= 1'h0;
    clk_toggle <= 1'h0;
    div_cnt <= {CNTRWID{1'b0}};
    // End of automatics
  end
  else begin
    div_cnt     <= (clk_toggle_nxt)? {CNTRWID{1'b0}} : div_cnt_incr;
    clk_toggle  <= clk_toggle_nxt;
    clk_gen     <= clk_toggle ^ clk_gen;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

generate
  if(EN_REGOUT) begin : gen_regout
    reg                             clk_gen_q;
    reg                             clk_pos_r;
    reg                             clk_neg_r;

    assign clk_src = (clkdiv_eq0_w & clk_out_vld)? ((cur_cpol ^ cur_cpha)? clk_i : ~clk_i) : 1'b0;
    assign clk_pos = clk_pos_r;
    assign clk_neg = clk_neg_r;
    assign clk_out = clk_src | clk_gen_q;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        clk_gen_q <= 1'h0;
        clk_neg_r <= 1'h0;
        clk_pos_r <= 1'h0;
        // End of automatics
      end
      else begin
        clk_pos_r <= (clk_toggle & ~clk_gen) | clkdiv_eq0_w;
        clk_neg_r <= (clk_toggle &  clk_gen) | clkdiv_eq0_w;
        clk_gen_q <= (clkdiv_eq0_w)? 1'b0 :
                     (en_clk_gen)? ((cur_cpol ^ cur_cpha)? clk_gen : ~clk_gen) : cur_cpol;
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_regout
  else begin : gen_noregout
    assign clk_src = (clkdiv_eq0_w)? clk_i : clk_gen;
    assign clk_pos = (clk_toggle & ~clk_gen) | clkdiv_eq0_w;
    assign clk_neg = (clk_toggle &  clk_gen) | clkdiv_eq0_w;
    assign clk_out = (clk_out_vld)? ((cur_cpol ^ cur_cpha)? clk_src : ~clk_src) : cur_cpol;
  end // gen_noregout

  if(USE_CLKDIV1) begin : gen_usediv1
    reg                             clkdiv_eq0;

    assign clkdiv_eq0_w   = clkdiv_eq0;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        /*AUTORESET*/
        // Beginning of autoreset for uninitialized flops
        clkdiv_eq0 <= 1'h0;
        // End of automatics
      end
      else begin
        clkdiv_eq0 <= ~|clk_divider;
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_usediv1
  else begin : gen_nodiv1
    assign clkdiv_eq0_w   = 1'b0;
  end // gen_nodiv1

  if(CAPTURE_CSR) begin : gen_regcsr
    reg           [CNTRWID-1:0]     reg_clkdiv;
    reg                             reg_cpol;
    reg                             reg_cpha;

    assign cur_clkdiv = reg_clkdiv;
    assign cur_cpol   = reg_cpol;
    assign cur_cpha   = reg_cpha;
    //--------------------------------------------
    //-- Sequential block --
    //--------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
      if(~rst_n_i) begin
        reg_cpol <= DEFAULT_CPOL;
        reg_cpha <= DEFAULT_CPHA;
        reg_clkdiv <= DEFAULT_RATE;
        /*AUTORESET*/
      end
      else begin
        // capture new setting
        if(clk_updated) begin
          reg_clkdiv  <= (clk_divider - {{(CNTRWID-1){1'b0}},1'b1});
          reg_cpol    <= clk_polarity;
          reg_cpha    <= clk_phase;
        end
      end
    end //--always @(posedge clk_i or negedge rst_n_i)--
  end // gen_regcsr
  else begin : gen_no_regcsr
    assign cur_clkdiv = (clk_divider - {{(CNTRWID-1){1'b0}},1'b1});
    assign cur_cpol   = clk_polarity;
    assign cur_cpha   = clk_phase;
  end // gen_no_regcsr

endgenerate

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------



endmodule //--emmc_clkgen--
`endif // __RTL_MODULE__EMMC_CLKGEN__
