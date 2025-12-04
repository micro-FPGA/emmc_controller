// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __RTL_MODULE__EMMC_IOLOGIC__
`define __RTL_MODULE__EMMC_IOLOGIC__
//==========================================================================
// Module : emmc_iologic
//==========================================================================
module emmc_iologic #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                      SIMULATION          = 0
,parameter                      USE_IO_PRIMITIVE    = 1

,parameter                      EN_DDR_MODE         = 1
,parameter                      EN_DDR_WIDE         = 1
,parameter                      MAX_NUMLANE         = 8     // [1,4,8]
,parameter                      SPI_WID             = (EN_DDR_MODE && EN_DDR_WIDE)? 2*MAX_NUMLANE : MAX_NUMLANE
,parameter                      NUM_REG_IN          = 1
,parameter                      EN_NEG_SAMPLE       = 0 // For CLKDIV=1


) //--end_param--

( //--begin_ports--

 input                          clk_i
,input                          rst_n_i

// eMMC interface from SERDES
,input                          emmc_tx_ckp
,input                          emmc_tx_ckn
// TODO: sampling point can be adjusted either by parameter or programmable
,output wire                    emmc_rx_ckp
,output wire                    emmc_rx_ckn

,input                          emmc_clk_out

,output wire                    emmc_cmd_clk_vld_i
,output wire                    emmc_cmd_crc_en_i
,output wire                    emmc_cmd_dlast_i
,output wire                    emmc_cmd_stb_i
,output wire                    emmc_cmd_dti_i

,input                          emmc_cmd_clk_vld_o
,input                          emmc_cmd_pp1_od0_o
,input                          emmc_cmd_crc_en_o
,input                          emmc_cmd_dc_en_o
,input                          emmc_cmd_dlast_o
,input                          emmc_cmd_doe_o
,input                          emmc_cmd_dto_o

,output wire                    emmc_dat_clk_vld_i
,output wire                    emmc_dat_ddr_mode_i
,output wire                    emmc_dat_crc_en_i
,output wire                    emmc_dat_dlast_i
,output wire  [1:0]             emmc_dat_io_width_i
,output wire                    emmc_dat_stb_i
,output wire  [SPI_WID-1:0]     emmc_dat_dti_i

,input                          emmc_dat_clk_vld_o
,input                          emmc_dat_pp1_od0_o
,input                          emmc_dat_crc_en_o
,input                          emmc_dat_dc_en_o
,input                          emmc_dat_dlast_o
,input                          emmc_dat_ddr_mode_o
,input        [1:0]             emmc_dat_io_width_o
,input                          emmc_dat_doe_o
,input        [SPI_WID-1:0]     emmc_dat_dto_o

// eMMC IO interface
,output wire                    emmc_clk_o

,inout                          emmc_cmd_io         // command signal bidirectional

,input                          emmc_cmd_i          // command input
,output wire                    emmc_cmd_o          // command output
,output wire                    emmc_cmd_oe_o       // command output enable
,output wire                    io_cmd_in           // command input - for debug

,inout        [MAX_NUMLANE-1:0] emmc_dat_io         // data signal bidirectional

,input        [MAX_NUMLANE-1:0] emmc_dat_i          // data input
,output wire  [MAX_NUMLANE-1:0] emmc_dat_o          // data output
,output wire  [MAX_NUMLANE-1:0] emmc_dat_oe_o       // data output enable
,output wire  [MAX_NUMLANE-1:0] io_dat_in           // data input - for debug

// eMMC data strobe signal - optional (for HS200 and HS400)
,input                          emmc_dat_ds_i       // data strobe input

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------
reg                             det_cmd_stb_nxt;
reg                             det_dat_stb_nxt;

wire                            emmc_cmd_dti_w /* synthesis syn_keep=1 */;
wire          [SPI_WID-1:0]     emmc_dat_dti_w /* synthesis syn_keep=1 */;
wire                            emmc_dti_neg;

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------
reg                             det_cmd_stb;
reg                             det_dat_stb;
reg           [1:0]             dat_dti_0_r;

assign emmc_clk_o   = emmc_clk_out;
assign emmc_dti_neg = emmc_rx_ckp & ~emmc_dat_dti_w[0] & dat_dti_0_r[0];

//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  det_cmd_stb_nxt = det_cmd_stb;
  if(det_cmd_stb) begin
    det_cmd_stb_nxt = emmc_cmd_clk_vld_o & ~emmc_cmd_dc_en_o;
  end
  else begin
    det_cmd_stb_nxt = ~emmc_cmd_dti_w &
                      emmc_cmd_clk_vld_o & ~emmc_cmd_dc_en_o;
  end
end //--always @*--

//--------------------------------------------
//-- Combinatorial block --
//--------------------------------------------
always @* begin
  det_dat_stb_nxt = det_dat_stb;
  if(det_dat_stb) begin
    det_dat_stb_nxt = (emmc_rx_ckp)? emmc_dat_clk_vld_o & ~emmc_dat_dc_en_o : det_dat_stb;
  end
  else begin
    det_dat_stb_nxt = emmc_dti_neg & ((~emmc_dat_ddr_mode_o |  emmc_dat_ds_i) &
                                      emmc_dat_clk_vld_o);
  end
end //--always @*--

//--------------------------------------------
//-- Sequential block --
//--------------------------------------------
always @(posedge clk_i or negedge rst_n_i) begin
  if(~rst_n_i) begin
    dat_dti_0_r <= {2{1'd1}};
    /*AUTORESET*/
    // Beginning of autoreset for uninitialized flops
    det_cmd_stb <= 1'h0;
    det_dat_stb <= 1'h0;
    // End of automatics
  end
  else begin
    det_cmd_stb <= det_cmd_stb_nxt;
    det_dat_stb <= det_dat_stb_nxt;
    dat_dti_0_r <= (emmc_rx_ckp)? {dat_dti_0_r[0],emmc_dat_dti_w[0]} : dat_dti_0_r;
  end
end //--always @(posedge clk_i or negedge rst_n_i)--

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------
genvar i;
generate
  if(USE_IO_PRIMITIVE) begin : gen_io_prim
    wire                            emmc_cmd_oe_n_w;
    wire                            emmc_cmd_dti_pad;
    wire          [SPI_WID-1:0]     emmc_dat_dti_pad;

    assign emmc_cmd_oe_n_w = ~((emmc_cmd_pp1_od0_o)? emmc_cmd_doe_o : ~emmc_cmd_dto_o);
    assign emmc_cmd_o      = emmc_cmd_dto_o;
    assign emmc_cmd_oe_o   = ((emmc_cmd_pp1_od0_o)? emmc_cmd_doe_o : ~emmc_cmd_dto_o);
    assign io_cmd_in       = emmc_cmd_dti_pad;

    BB u_dt_pad
    (
     .B                               (emmc_cmd_io),           // B
     .I                               (emmc_cmd_dto_o),        // I
     .T                               (emmc_cmd_oe_n_w),       // OEn
     .O                               (emmc_cmd_dti_pad)       // O
    );

    for(i=0; i<MAX_NUMLANE; i=i+1) begin : gen_dat_io
      wire                            emmc_dat_oe_n_w;

      assign emmc_dat_oe_n_w    = (emmc_dat_io_width_o == 2'd0 && (i > 0))? 1'b1 :
                                  (emmc_dat_io_width_o == 2'd2 && (i > 3))? 1'b1 :
                                                                            ~((emmc_dat_pp1_od0_o)? emmc_dat_doe_o : ~emmc_dat_dto_o[i]);
      assign emmc_dat_o[i]      = emmc_dat_dto_o[i];
      assign emmc_dat_oe_o[i]   = ((emmc_dat_pp1_od0_o)? emmc_dat_doe_o : ~emmc_dat_dto_o[i]);
      assign io_dat_in[i]       = emmc_dat_dti_pad[i];

      BB u_dt_pad
      (
       .B                               (emmc_dat_io[i]),           // B
       .I                               (emmc_dat_dto_o[i]),        // I
       .T                               (emmc_dat_oe_n_w),          // OEn
       .O                               (emmc_dat_dti_pad[i])       // O
      );
    end // gen_dat_io

    if(EN_NEG_SAMPLE) begin : gen_neg_sample
      reg                             emmc_cmd_dti_neg;
      reg           [SPI_WID-1:0]     emmc_dat_dti_neg;

      assign emmc_cmd_dti_w = emmc_cmd_dti_neg;
      assign emmc_dat_dti_w = emmc_dat_dti_neg;

      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(negedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          emmc_cmd_dti_neg <= 1'b1;
          emmc_dat_dti_neg <= {SPI_WID{1'b1}};
          /*AUTORESET*/
        end
        else begin
          emmc_cmd_dti_neg <= emmc_cmd_dti_pad;
          emmc_dat_dti_neg <= emmc_dat_dti_pad;
        end
      end //--always @(negedge clk_i or negedge rst_n_i)--

    end // gen_neg_sample
    else begin : gen_raw_sample
      assign emmc_cmd_dti_w = emmc_cmd_dti_pad;
      assign emmc_dat_dti_w = emmc_dat_dti_pad;
    end// gen_raw_sample

  end // gen_io_prim
  else begin : gen_no_io_prim
    assign emmc_cmd_dti_w   = emmc_cmd_i;
    assign emmc_dat_dti_w   = emmc_dat_i;
    assign emmc_cmd_o       = emmc_cmd_dto_o;
    assign emmc_cmd_oe_o    = ((emmc_cmd_pp1_od0_o)? emmc_cmd_doe_o : ~emmc_cmd_dto_o);
    assign emmc_dat_o       = emmc_dat_dto_o;
    assign emmc_dat_oe_o    = ((emmc_dat_pp1_od0_o)? emmc_dat_doe_o : ~emmc_dat_dto_o);

    assign io_cmd_in        = emmc_cmd_i;
    assign io_dat_in        = emmc_dat_i;
  end // gen_no_io_prim

  if(NUM_REG_IN) begin : gen_regin
    reg           [NUM_REG_IN-1:0]            cmd_clk_vld_r;
    reg           [NUM_REG_IN-1:0]            cmd_crc_en_r;
    reg           [NUM_REG_IN-1:0]            cmd_dlast_r;
    reg           [NUM_REG_IN-1:0]            cmd_stb_r;
    reg           [NUM_REG_IN-1:0]            cmd_dti_r;
    reg           [NUM_REG_IN-1:0]            dat_clk_vld_r;
    reg           [NUM_REG_IN-1:0]            dat_ddr_mode_r;
    reg           [NUM_REG_IN-1:0]            dat_crc_en_r;
    reg           [NUM_REG_IN-1:0]            dat_dlast_r;
    reg           [NUM_REG_IN-1:0]            dat_stb_r;
    reg           [NUM_REG_IN*2-1:0]          dat_io_width_r;
    reg           [NUM_REG_IN*SPI_WID-1:0]    dat_dti_r;
    reg           [NUM_REG_IN-1:0]            rx_ckp_r;
    reg           [NUM_REG_IN-1:0]            rx_ckn_r;

    assign emmc_cmd_clk_vld_i   = cmd_clk_vld_r [0];
    assign emmc_cmd_crc_en_i    = cmd_crc_en_r  [0];
    assign emmc_cmd_dlast_i     = cmd_dlast_r   [0];
    assign emmc_cmd_stb_i       = cmd_stb_r     [0];
    assign emmc_cmd_dti_i       = cmd_dti_r     [0];

    assign emmc_dat_clk_vld_i   = dat_clk_vld_r [0+:1];
    assign emmc_dat_ddr_mode_i  = dat_ddr_mode_r[0+:1];
    assign emmc_dat_crc_en_i    = dat_crc_en_r  [0+:1];
    assign emmc_dat_dlast_i     = dat_dlast_r   [0+:1];
    assign emmc_dat_io_width_i  = dat_io_width_r[0+:2];
    assign emmc_dat_stb_i       = dat_stb_r     [0+:1];
    assign emmc_dat_dti_i       = dat_dti_r     [0+:SPI_WID];

    assign emmc_rx_ckp          = rx_ckp_r[0];
    assign emmc_rx_ckn          = rx_ckn_r[0];

    if(NUM_REG_IN > 1) begin : gen_gt1
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          cmd_dti_r <= {NUM_REG_IN{1'b1}};
          dat_dti_r <= {(1+(NUM_REG_IN*SPI_WID-1)){1'b1}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          cmd_clk_vld_r <= {NUM_REG_IN{1'b0}};
          cmd_crc_en_r <= {NUM_REG_IN{1'b0}};
          cmd_dlast_r <= {NUM_REG_IN{1'b0}};
          cmd_stb_r <= {NUM_REG_IN{1'b0}};
          dat_clk_vld_r <= {NUM_REG_IN{1'b0}};
          dat_crc_en_r <= {NUM_REG_IN{1'b0}};
          dat_ddr_mode_r <= {NUM_REG_IN{1'b0}};
          dat_dlast_r <= {NUM_REG_IN{1'b0}};
          dat_io_width_r <= {(1+(NUM_REG_IN*2-1)){1'b0}};
          dat_stb_r <= {NUM_REG_IN{1'b0}};
          rx_ckn_r <= {NUM_REG_IN{1'b0}};
          rx_ckp_r <= {NUM_REG_IN{1'b0}};
          // End of automatics
        end
        else begin
          if(emmc_tx_ckp) begin
            cmd_clk_vld_r   <= {(emmc_cmd_clk_vld_o & ~emmc_cmd_dc_en_o) , cmd_clk_vld_r [1*1+:(NUM_REG_IN-1)*1]};
            cmd_crc_en_r    <= {emmc_cmd_crc_en_o                        , cmd_crc_en_r  [1*1+:(NUM_REG_IN-1)*1]};
            cmd_dlast_r     <= {emmc_cmd_dlast_o                         , cmd_dlast_r   [1*1+:(NUM_REG_IN-1)*1]};
            cmd_stb_r       <= {det_cmd_stb_nxt                          , cmd_stb_r     [1*1+:(NUM_REG_IN-1)*1]};
            cmd_dti_r       <= {emmc_cmd_dti_w                           , cmd_dti_r     [1*1+:(NUM_REG_IN-1)*1]};

            dat_clk_vld_r   <= {(emmc_dat_clk_vld_o & ~emmc_dat_dc_en_o) , dat_clk_vld_r [1*1+:(NUM_REG_IN-1)*1]};
            dat_ddr_mode_r  <= {emmc_dat_ddr_mode_o                      , dat_ddr_mode_r[1*1+:(NUM_REG_IN-1)*1]};
            dat_crc_en_r    <= {emmc_dat_crc_en_o                        , dat_crc_en_r  [1*1+:(NUM_REG_IN-1)*1]};
            dat_dlast_r     <= {emmc_dat_dlast_o                         , dat_dlast_r   [1*1+:(NUM_REG_IN-1)*1]};
            dat_stb_r       <= {det_dat_stb_nxt                          , dat_stb_r     [1*1+:(NUM_REG_IN-1)*1]};
            dat_io_width_r  <= {emmc_dat_io_width_o                      , dat_io_width_r[2*1+:(NUM_REG_IN-1)*2]};
            dat_dti_r       <= {emmc_dat_dti_w                           , dat_dti_r     [SPI_WID*1+:(NUM_REG_IN-1)*SPI_WID]};
          end

          // driving and sampling are 180 degrees apart
          rx_ckp_r        <= {emmc_tx_ckn, rx_ckp_r[1*1+:(NUM_REG_IN-1)*1]};
          rx_ckn_r        <= {emmc_tx_ckp, rx_ckn_r[1*1+:(NUM_REG_IN-1)*1]};
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_gt1
    else begin : gen_eq1
      //--------------------------------------------
      //-- Sequential block --
      //--------------------------------------------
      always @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
          cmd_dti_r <= {NUM_REG_IN{1'b1}};
          dat_dti_r <= {(1+(NUM_REG_IN*SPI_WID-1)){1'b1}};
          /*AUTORESET*/
          // Beginning of autoreset for uninitialized flops
          cmd_clk_vld_r <= {NUM_REG_IN{1'b0}};
          cmd_crc_en_r <= {NUM_REG_IN{1'b0}};
          cmd_dlast_r <= {NUM_REG_IN{1'b0}};
          cmd_stb_r <= {NUM_REG_IN{1'b0}};
          dat_clk_vld_r <= {NUM_REG_IN{1'b0}};
          dat_crc_en_r <= {NUM_REG_IN{1'b0}};
          dat_ddr_mode_r <= {NUM_REG_IN{1'b0}};
          dat_dlast_r <= {NUM_REG_IN{1'b0}};
          dat_io_width_r <= {(1+(NUM_REG_IN*2-1)){1'b0}};
          dat_stb_r <= {NUM_REG_IN{1'b0}};
          rx_ckn_r <= {NUM_REG_IN{1'b0}};
          rx_ckp_r <= {NUM_REG_IN{1'b0}};
          // End of automatics
        end
        else begin
          if(emmc_tx_ckp) begin
            cmd_clk_vld_r   <= (emmc_cmd_clk_vld_o & ~emmc_cmd_dc_en_o) ;
            cmd_crc_en_r    <= emmc_cmd_crc_en_o                        ;
            cmd_dlast_r     <= emmc_cmd_dlast_o                         ;
            cmd_stb_r       <= det_cmd_stb_nxt                          ;
            cmd_dti_r       <= emmc_cmd_dti_w                           ;

            dat_clk_vld_r   <= (emmc_dat_clk_vld_o & ~emmc_dat_dc_en_o) ;
            dat_ddr_mode_r  <= emmc_dat_ddr_mode_o                      ;
            dat_crc_en_r    <= emmc_dat_crc_en_o                        ;
            dat_dlast_r     <= emmc_dat_dlast_o                         ;
            dat_stb_r       <= det_dat_stb_nxt                          ;
            dat_io_width_r  <= emmc_dat_io_width_o                      ;
            dat_dti_r       <= emmc_dat_dti_w                           ;
          end

          // driving and sampling are 180 degrees apart
          rx_ckp_r        <= emmc_tx_ckn;
          rx_ckn_r        <= emmc_tx_ckp;
        end
      end //--always @(posedge clk_i or negedge rst_n_i)--
    end // gen_eq1

  end // gen_regin
  else begin : gen_noregin
    assign emmc_cmd_clk_vld_i   = emmc_cmd_clk_vld_o & ~emmc_cmd_dc_en_o;
    assign emmc_cmd_crc_en_i    = emmc_cmd_crc_en_o;
    assign emmc_cmd_dlast_i     = emmc_cmd_dlast_o;
    assign emmc_cmd_stb_i       = det_cmd_stb_nxt;
    assign emmc_cmd_dti_i       = emmc_cmd_dti_w;

    assign emmc_dat_clk_vld_i   = emmc_dat_clk_vld_o & ~emmc_dat_dc_en_o;
    assign emmc_dat_ddr_mode_i  = emmc_dat_ddr_mode_o;
    assign emmc_dat_crc_en_i    = emmc_dat_crc_en_o;
    assign emmc_dat_dlast_i     = emmc_dat_dlast_o;
    assign emmc_dat_io_width_i  = emmc_dat_io_width_o;
    assign emmc_dat_stb_i       = det_dat_stb_nxt;
    assign emmc_dat_dti_i       = emmc_dat_dti_w;

    // driving and sampling are 180 degrees apart
    assign emmc_rx_ckp          = emmc_tx_ckn;
    assign emmc_rx_ckn          = emmc_tx_ckp;
  end // gen_noregin
endgenerate



endmodule //--emmc_iologic--
`endif // __RTL_MODULE__EMMC_IOLOGIC__
