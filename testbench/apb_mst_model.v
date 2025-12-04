// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps
`include "tb_common.v"
`ifndef __RTL_MODULE__APB_MST_MODEL__
`define __RTL_MODULE__APB_MST_MODEL__
//==========================================================================
// Module : apb_mst_model
//==========================================================================
module apb_mst_model #

( //--begin_param--
//----------------------------
// Parameters
//----------------------------
 parameter                          ADDR_WIDTH      = 32
,parameter                          DATA_WIDTH      = 32
,parameter                          APB_BFM_MSGS_ON = 1

) //--end_param--

( //--begin_ports--
 input                              apb_pclk_i
,input                              apb_preset_n_i
,input                              apb_pready_o
,input                              apb_pslverr_o
,input        [DATA_WIDTH-1:0]      apb_prdata_o
,input                              int_o

,output reg                         apb_penable_i
,output reg                         apb_psel_i
,output reg                         apb_pwrite_i
,output reg   [ADDR_WIDTH-1:0]      apb_paddr_i
,output reg   [DATA_WIDTH-1:0]      apb_pwdata_i

)/* synthesis LATTICE_IP_MODULE=1 */; //--end_ports--



//--------------------------------------------------------------------------
//--- Local Parameters/Defines ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Combinational Wire/Reg ---
//--------------------------------------------------------------------------

//--------------------------------------------------------------------------
//--- Registers ---
//--------------------------------------------------------------------------

initial begin
  init;
end

task init;
begin
    apb_penable_i = 0;
    apb_psel_i    = 0;
    apb_pwrite_i  = 0;
    apb_paddr_i   = 0;
    apb_pwdata_i  = 0;
end
endtask

task apb_wr;
input   [ADDR_WIDTH-1:0]    addr;
input   [DATA_WIDTH-1:0]    data;
begin
    // SETUP phase
    @(posedge apb_pclk_i) begin
        apb_paddr_i  <= addr;
        apb_pwrite_i <= 1'b1;
        apb_psel_i   <= 1'b1;
        apb_pwdata_i <= data;
    end

    // ACCESS phase
    @(posedge apb_pclk_i) begin
        apb_penable_i <= 1'b1;
    end

    // extended until apb_pready_o is asserted
    @(negedge apb_pclk_i);
    wait (apb_pready_o);

    @(posedge apb_pclk_i) begin
        apb_psel_i    <= 1'b0;
        apb_penable_i <= 1'b0;
        apb_pwdata_i  <= {DATA_WIDTH{1'b0}};
    end

    if(APB_BFM_MSGS_ON) begin
      `N_MSG(("[APB Write] addr %2x data %2x",addr, data))
    end
end
endtask // apb_wr

task apb_rd;
input   [ADDR_WIDTH-1:0]    addr;
input   [DATA_WIDTH-1:0]    chk;
input                       verify;
output  [DATA_WIDTH-1:0]    rdata;
reg                         slverr;
begin
    // SETUP phase
    @(posedge apb_pclk_i) begin
        apb_paddr_i  <= addr;
        apb_pwrite_i <= 1'b0;
        apb_psel_i   <= 1'b1;
    end

    // ACCESS phase
    @(posedge apb_pclk_i) begin
        apb_penable_i <= 1'b1;
    end

    // extended until apb_pready_o is asserted
    @(negedge apb_pclk_i);
    wait (apb_pready_o);

    @(posedge apb_pclk_i) begin
        apb_psel_i    <= 1'b0;
        apb_penable_i <= 1'b0;
    end

    rdata  = apb_prdata_o;
    slverr = apb_pslverr_o;

    if (verify && apb_prdata_o != chk) begin
        `E_MSG(("[APB Read ] addr %2x data %2x != exp %2x",addr, apb_prdata_o, chk))
    end
    else begin
      if(APB_BFM_MSGS_ON) begin
        `N_MSG(("[APB Read ] addr %2x data %2x",addr, apb_prdata_o))
      end
    end

    if(slverr) begin
        `E_MSG(("[APB PSLVERR ] APB error detected (apb_pslverr_o=%0d)",slverr))
    end
end
endtask // apb_rd

task wait_int;
  begin
    wait(int_o === 1'b1);
  end
endtask

task apb_wr_multiple;
  input   [ADDR_WIDTH-1:0]      addr;
  input   [257*DATA_WIDTH-1:0]  data;
  input   [12:0]                bytelen; // max 4KB

  reg     [ADDR_WIDTH-1:0]      next_addr;
  reg     [12:0]                remaining_cnt;
  reg     [12:0]                dword_cnt;
  reg     [DATA_WIDTH-1:0]      wdata;
  integer                       idx, datofst;
  begin
    `N_MSG(("[APB Write Multiple] Start Addr = 32'h%4h_%4h : Byte Length = %0d",addr[31:16],addr[15:0], bytelen))

    next_addr     = addr;
    remaining_cnt = bytelen;
    datofst       = 0;
    if(|addr[1:0]) begin
      wdata         = (addr[1:0] == 3)? {data[0+: 8],{24{1'b1}}} :
                      (addr[1:0] == 2)? {data[0+:16],{16{1'b1}}} :
                      (addr[1:0] == 1)? {data[0+:24],{ 8{1'b1}}} :
                                        data[0+:32];
      apb_wr(next_addr,wdata);

      next_addr     = {next_addr[31:2],2'd0} + 4;
      remaining_cnt = bytelen - (4 - addr[1:0]);
      datofst       = (addr[1:0] == 3)?  8 :
                      (addr[1:0] == 2)? 16 :
                      (addr[1:0] == 1)? 24 : 0;
    end
    dword_cnt = remaining_cnt[12:2] + (|remaining_cnt[1:0]);

    for(idx=0; idx<dword_cnt; idx=idx+1) begin
      apb_wr(next_addr,data[datofst+(idx*DATA_WIDTH)+:DATA_WIDTH]);
      next_addr     = {next_addr[31:2],2'd0} + 4;
    end

  end
endtask // apb_wr_multiple

task apb_rd_multiple;
  input   [ADDR_WIDTH-1:0]      addr;
  output  [257*DATA_WIDTH-1:0]  data;
  input   [12:0]                bytelen; // max 4KB

  reg     [ADDR_WIDTH-1:0]      next_addr;
  reg     [12:0]                remaining_cnt;
  reg     [12:0]                dword_cnt;
  reg     [DATA_WIDTH-1:0]      rdata;
  integer                       idx, datofst;
  begin
    `N_MSG(("[APB Read Multiple] Start Addr = 32'h%4h_%4h : Byte Length = %0d",addr[31:16],addr[15:0], bytelen))

    next_addr     = addr;
    remaining_cnt = bytelen;
    datofst       = 0;
    data          = 0;
    if(|addr[1:0]) begin
      apb_rd(next_addr,0,0,rdata);

      next_addr     = {next_addr[31:2],2'd0} + 4;
      remaining_cnt = bytelen - (4 - addr[1:0]);
      datofst       = (addr[1:0] == 3)?  8 :
                      (addr[1:0] == 2)? 16 :
                      (addr[1:0] == 1)? 24 : 0;

      data[31:0]    = (addr[1:0] == 3)? {{24{1'b0}},rdata[31:24]} :
                      (addr[1:0] == 2)? {{16{1'b0}},rdata[31:16]} :
                      (addr[1:0] == 1)? {{ 8{1'b0}},rdata[31: 8]} :
                                        rdata;
    end
    dword_cnt = remaining_cnt[12:2] + (|remaining_cnt[1:0]);

    for(idx=0; idx<dword_cnt; idx=idx+1) begin
      apb_rd(next_addr,0,0,rdata);
      data[datofst+(idx*DATA_WIDTH)+:DATA_WIDTH] = rdata;
      next_addr     = {next_addr[31:2],2'd0} + 4;
    end

  end
endtask // apb_wr_multiple

//--------------------------------------------------------------------------
//--- Module Instantiation ---
//--------------------------------------------------------------------------



endmodule //--apb_mst_model--
`endif // __RTL_MODULE__APB_MST_MODEL__
