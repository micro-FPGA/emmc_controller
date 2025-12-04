
#include <stdio.h>
#include <stdlib.h>
#include "sys_platform.h"
#include "hal.h"

#ifdef EMMC0_INST_BASE_ADDR
/*#define EMMC_DEVICE_ADDRESS     0x00010000*/
#define EMMC_DEVICE_ADDRESS     0x4C530000
#include "emmc_controller.h"

emmc_ctl_handle_t emmc_c0;
emmc_ctl_handle_t *emmc_c0_inst = (emmc_ctl_handle_t *)(&emmc_c0);
unsigned int test_loop_cntr = 0;

// ------------------------------------------------------------------------------------------------------
unsigned char compare_data(unsigned int *exp_data, unsigned int *obs_data, unsigned int num_data)
{
  unsigned char  status=SUCCESS;
  unsigned int cnt;

  for(cnt=0; cnt<num_data; cnt++)
  {
    if(obs_data[cnt] != exp_data[cnt])
    {
      printf("[%d] Data Mismatch! exp_data = %x, obs_data = %x \n",cnt, exp_data[cnt],obs_data[cnt]);
      printf("exp_addr = %x, obs_addr = %x \n",&exp_data[cnt], &obs_data[cnt]);
      return FAILURE;
    }
  }

  return status;
}

// ------------------------------------------------------------------------------------------------------
unsigned char print_response_data(emmc_ctl_handle_t *handle, unsigned int idx_s, unsigned int num_data)
{
  unsigned char   status=SUCCESS;
  unsigned char   cnt, start, end_cnt;

  start   = (idx_s < 0)? 0 : idx_s;
  end_cnt = (num_data > 5)? 5 :
            (num_data < 1)? 1 : num_data;

  emmc_get_resp_data(handle);

  printf("Response Data Register: \n");
  for(cnt=start; cnt<end_cnt; cnt++)
  {
    printf("\tData[%0d] = 0x%8x\n",cnt, handle->rsp_data[cnt]);
  }

  return status;
}

// ------------------------------------------------------------------------------------------------------
// Main Test Sequence
// ------------------------------------------------------------------------------------------------------
unsigned char emmc_test(unsigned int *cmd_buf, unsigned int *rsp_buf)
{
  unsigned char status=SUCCESS;
  unsigned int  axi4_start_addr;

  // initial settings
  emmc_c0_inst->base_addr         = EMMC0_INST_BASE_ADDR;
  emmc_c0_inst->sck_rate          = SET_ALL_BITS;
  emmc_c0_inst->io_width          = EMMC_IO_X1;
  emmc_c0_inst->ddr_mode          = EMMC_SDR;
  emmc_c0_inst->max_num_lane      = EMMC0_INST_MAX_NUMLANE;
  emmc_c0_inst->sys_clk_freq_khz  = MHZ_TO_KHZ(EMMC0_INST_GUI_SYSCLK_FREQ);
  emmc_c0_inst->max_num_blocks    = EMMC0_INST_GUI_MAX_NUM_BLK;
  emmc_c0_inst->interrupt_enable  = ZERO;

  if(emmc_ctl_init(emmc_c0_inst))
  {
    emmc_c0_inst->init_done = SUCCESS;
    printf("eMMC Init Done.\n");
  } else {
    printf("Fail to initialize eMMC Controller\n");
    return FAILURE;
  }

  status &= set_emmc_clk_io_config(emmc_c0_inst, 100 /* KHz*/, EMMC_SDR, EMMC_IO_X1, EMMC_OPEN_DRAIN); // configure initial operation at 100 KHz

  status &= emmc_cmd_go_idle(emmc_c0_inst);

  status &= emmc_cmd_send_op_cond(emmc_c0_inst);
  print_response_data(emmc_c0_inst,0,2);

  status &= emmc_cmd_all_send_cid(emmc_c0_inst);
  /*print_response_data(emmc_c0_inst,0,5);*/

  status &= emmc_cmd_set_relative_addr(emmc_c0_inst,EMMC_DEVICE_ADDRESS);
  /*print_response_data(emmc_c0_inst,0,2);*/

  // after initialization, can operate now at 25 MHz, io_drive is push-pull
  status &= set_emmc_clk_io_config(emmc_c0_inst, MHZ_TO_KHZ(25)/* KHz*/, EMMC_SDR, EMMC_IO_X1, EMMC_PUSH_PULL);

  status &= emmc_cmd_send_status(emmc_c0_inst);
  print_response_data(emmc_c0_inst,0,2);

  status &= emmc_cmd_send_csd(emmc_c0_inst);
  print_response_data(emmc_c0_inst,0,5);

  status &= emmc_cmd_send_cid(emmc_c0_inst);
  /*print_response_data(emmc_c0_inst,0,5);*/

  /*status &= emmc_cmd_send_status(emmc_c0_inst);*/
  /*print_response_data(emmc_c0_inst,0,2);*/

  status &= emmc_cmd_select_card(emmc_c0_inst);
  print_response_data(emmc_c0_inst,0,2);

  /*status &= emmc_cmd_set_block_length(emmc_c0_inst, 512);*/
  /*print_response_data(emmc_c0_inst,0,2);*/

  /*axi4_start_addr = (unsigned int)(&rsp_buf[128]);*/
  /*status &= emmc_cmd_send_ext_csd(emmc_c0_inst,axi4_start_addr);*/
  /*print_response_data(emmc_c0_inst,0,2);*/

  rsp_buf[128+0] = 0x80808080;
  rsp_buf[128+1] = 0x40404040;
  rsp_buf[128+2] = 0xA0A0A0A0;
  rsp_buf[128+3] = 0x50505050;
  axi4_start_addr = (unsigned int)(&rsp_buf[128]) | SYSMEM0_INST_AXI4_S1_MODEL_MEM_MAP_BASE_ADDR;
  status &= emmc_cmd_bustest_w(emmc_c0_inst, axi4_start_addr, EMMC0_INST_MIN_BLOCK_SIZE);
  print_response_data(emmc_c0_inst,0,2);

  status &= emmc_cmd_bustest_r(emmc_c0_inst, axi4_start_addr, EMMC0_INST_MIN_BLOCK_SIZE);
  print_response_data(emmc_c0_inst,0,2);

  unsigned int rdata;
  rdata = *(unsigned int *)(axi4_start_addr);
  printf("Debug: rdata = 0x%8x",rdata);

  return status;

}


// rsp_buf: memory map
// [  0:  0] - OCR
// [  1:  1] - rsvd
// [  2:  2] - rsvd
// [  3:  3] - rsvd
// [  7:  4] - CID
// [ 11:  8] - CSD
// [127: 12] - rsvd
// [255:128] - ext_CSD

#endif /* EMMC0_INST_BASE_ADDR */
