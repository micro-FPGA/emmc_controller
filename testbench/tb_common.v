// -----------------------------------------------------------------------------
//   Copyright (c) 2025 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   Subject to Lattice's Software License Agreement
// -----------------------------------------------------------------------------
`ifndef __TB_COMMON__
`define __TB_COMMON__

`define TIME_DELAY(num_cycles,clk) repeat((num_cycles)) @(posedge (clk));
`define INC(cnt) cnt=((cnt)+1);
`define DEC(cnt) cnt=((cnt)-1);

`ifndef ERROR_MSG
  `define ERROR_MSG   "ON"
`endif

`ifndef WARNING_MSG
  `define WARNING_MSG "ON"
`endif

`ifndef NORMAL_MSG
  `define NORMAL_MSG  "ON"
`endif

`ifndef DEBUG_MSG
  `define DEBUG_MSG   "OFF"
`endif

`define MSG_FORMAT0(tag,msg) $display("[%12t]:%0s%0s%0s%0s[%m]",\
                                      $time,tag,"--- ",($sformatf msg),"---");

`define MSG_FORMAT1(tag,msg) $display("[%12t]:%0s%0s%0s",\
                                      $time,tag,"--- ",($sformatf msg));

`define LOG_MSG(on_off,cntr,msg_fmt) \
        begin                \
          if(on_off == "ON") \
          begin              \
            `INC(cntr)       \
            msg_fmt          \
          end                \
        end

`define E_MSG(msg)  `LOG_MSG(`ERROR_MSG,  tb_top.e_msg_cnt,`MSG_FORMAT0("[Error  ]",msg))
`define W_MSG(msg)  `LOG_MSG(`WARNING_MSG,tb_top.w_msg_cnt,`MSG_FORMAT0("[Warning]",msg))
`define N_MSG(msg)  `LOG_MSG(`NORMAL_MSG, tb_top.n_msg_cnt,`MSG_FORMAT0("[Info   ]",msg))
`define D_MSG(msg)  `LOG_MSG(`DEBUG_MSG,  tb_top.d_msg_cnt,`MSG_FORMAT0("[Debug  ]",msg))

`define E_MSG1(msg) `LOG_MSG(`ERROR_MSG,  tb_top.e_msg_cnt,`MSG_FORMAT1("[Error  ]",msg))
`define W_MSG1(msg) `LOG_MSG(`WARNING_MSG,tb_top.w_msg_cnt,`MSG_FORMAT1("[Warning]",msg))
`define N_MSG1(msg) `LOG_MSG(`NORMAL_MSG, tb_top.n_msg_cnt,`MSG_FORMAT1("[Info   ]",msg))
`define D_MSG1(msg) `LOG_MSG(`DEBUG_MSG,  tb_top.d_msg_cnt,`MSG_FORMAT1("[Debug  ]",msg))

`define TIMED_FINISH(num_cycles,clk) `TIME_DELAY(num_cycles,clk) `W_MSG(("Timeout reached!")) $finish;
`define TIMED_STOP(num_cycles,clk) `TIME_DELAY(num_cycles,clk) `W_MSG(("Timeout reached!")) $stop;

`define ENDSIM(num_cycles,clk) \
        begin                         \
          `TIME_DELAY(num_cycles,clk) \
          tb_top.report;              \
          $stop;                      \
        end

`define WAIT_TIMEOUT(clk,timer,t_limit,msg,done,er1nor0,msgfreq) \
        begin                                                                                 \
          timer  = 0;                                                                         \
          while((timer < t_limit) && !done) begin                                             \
            if((timer % msgfreq) == 0)                                                        \
              `N_MSG(("[TIMER] : %0s : [timer=%0d] : [Limit=%0d]",                            \
                      msg,timer,t_limit))                                                     \
            @(posedge clk) timer = timer + 1;                                                 \
          end                                                                                 \
          if(!done) begin                                                                     \
            if(er1nor0) `E_MSG(("[TIMER] : Timeout reached! %0s : [timer=%0d] : [Limit=%0d]", \
                                msg,timer,t_limit))                                           \
            else        `N_MSG(("[TIMER] : Timeout reached! %0s : [timer=%0d] : [Limit=%0d]", \
                                msg,timer,t_limit))                                           \
            `ENDSIM(100,clk)                                                                  \
          end                                                                                 \
        end

`define CLOCK_GENERATOR(clkname,CLKPERIOD) \
        initial begin                        \
        clkname = 1'b0;                      \
        forever begin                        \
        clkname = #(CLKPERIOD/2.0) ~clkname; \
        end                                  \
        end

`define TB_MAIN_RESET(clkname,rstname) \
        integer  n_msg_cnt;     \
        integer  w_msg_cnt;     \
        integer  d_msg_cnt;     \
        integer  e_msg_cnt;     \
        reg      test_en;       \
        reg      tb_rst_n;      \
        reg      tb_clk;        \
        initial begin           \
        n_msg_cnt   = 0;        \
        w_msg_cnt   = 0;        \
        d_msg_cnt   = 0;        \
        e_msg_cnt   = 0;        \
        test_en     = 1'b0;     \
        rstname     = 1'b0;     \
        `TIME_DELAY(10,clkname) \
        rstname     = 1'b1;     \
        `TIME_DELAY(10,clkname) \
        test_en     = 1'b1;     \
        end


`define TB_REPORT_TASK \
        task automatic report();                           \
          begin                                            \
            $display("[%12t]:Ending Simulation...",$time); \
            $display("************************");          \
            $display("***Message Counters*****");          \
            $display("     Info   : %0d",n_msg_cnt);       \
            $display("     Warning: %0d",w_msg_cnt);       \
            $display("     Debug  : %0d",d_msg_cnt);       \
            $display("     Error  : %0d",e_msg_cnt);       \
            $display("************************");          \
            if(e_msg_cnt) begin                            \
              $display("***SIMULATION FAILED***");         \
            end                                            \
            else begin                                     \
              $display("***SIMULATION PASSED***");         \
            end                                            \
          end                                              \
        endtask // report

`endif // __TB_COMMON__
