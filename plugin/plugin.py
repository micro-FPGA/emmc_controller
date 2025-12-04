
import re
from math import ceil,log


def get_device_name(value):
    x = runtime_info.device_info.architecture(value)
    return x

def get_data_intf_name(intf_type):
    intf_id = {'AXI4':0, 'AXI4L':1, 'APB':2, 'AHBL':3}
    intf_name = 'AXI4'
    if(intf_type == 'APB'):
        intf_name = 'APB'
    elif(intf_type == 'AXI4L'):
        intf_name = 'AXI4L'

    return intf_id[intf_name]

def get_csr_intf_name(intf_type):
    intf_id = {'AXI4':0, 'AXI4L':1, 'APB':2, 'AHBL':3}
    intf_name = 'AXI4'
    if(intf_type == 'APB' or intf_type == 'AXI4_APB'):
        intf_name = 'APB'
    elif(intf_type == 'AXI4L' or intf_type == 'AXI4_AXI4L'):
        intf_name = 'AXI4L'

    return intf_id[intf_name]

def get_intf_opts(en_tgt_map):
    intf_opts = [('AXI4',      'AXI4'  )
                ,('AXI4-Lite', 'AXI4L' )
                ,('APB',       'APB'   )
                 ]
    if(en_tgt_map):
        intf_opts = intf_opts + [('DATA: AXI4; CSR: AXI4',      'AXI4_AXI4'  )
                                ,('DATA: AXI4; CSR: AXI4-Lite', 'AXI4_AXI4L' )
                                ,('DATA: AXI4; CSR: APB',       'AXI4_APB'   )
                                 ]
    return intf_opts

def check_valid_cfg_mspi(device_name):
    status = 1 if(device_name[0:6] == "LFMXO5" or \
                  device_name[0:9] == "LFD2NX-35" or \
                  device_name[0:9] == "LFD2NX-65" ) \
               else 0
    return status

def get_mem_opts(device_name):
    mem_opts = [('EBR',0),('LUT',1),('HARD IP',2)] \
                    if(device_name == "LIFCL" or \
                       device_name == "LFCPNX" or \
                       device_name == "LFD2NX" or \
                       device_name == "LFMXO5" or \
                       device_name == "UT24C" or \
                       device_name == "UT24CP" or \
                       device_name == "kr6a00" or \
                       device_name == "LN2-CT" or \
                       device_name == "LN2-MH" or \
                       device_name == "ap6a00" or \
                       device_name == "LAV-AT" \
                       ) \
                    else [('EBR',0),('LUT',1)]

    return mem_opts

def get_mem_impl(fifo_impl_sel):
    mem_impl = "HARD_IP" if(fifo_impl_sel == 2) else \
               ("LUT" if(fifo_impl_sel == 1) else "EBR")
    return mem_impl

def get_protocol_opts(device_name):
    ###if(device_name[0:8] == 'LAV-AT-X'):
    ###    prot_supported = [('Custom',0),('JEDEC xSPI',1),('Intel eSPI',2)]
    ###else:
    ###    prot_supported = [('Custom',0),('Intel eSPI',2)]

    if(device_name[0:8] == 'LAV-AT-X'):
        prot_supported = [('Custom',0),('JEDEC xSPI',1)]
    else:
        prot_supported = [('Custom',0)]

    return prot_supported

def get_max_numlane_opts():
    max_numlane_opts = [('X1',1),('X4',4),('X8',8)]
    return max_numlane_opts

def get_dut_name():
    return 'tb_top.u_' + runtime_info.ip_inst_name + '.lscc_emmc_controller_inst'


def is_hex(string_value):
    hex_pattern = '^[0-9a-fA-F]+$'
    match = re.match(hex_pattern, string_value)

    return bool(match)


def hex_value_drc(value,exp_len):
    result                    = {'status':1,'msg':'OK'}
    hexnum                    = value
    hexlen                    = len(hexnum) if(is_hex(hexnum)) else 0
    if(hexlen > 0):
        if(hexlen > exp_len):
            result['status']  = 0
            result['msg']     = 'Parameter value width is greater than ' + str(exp_len*4) + 'bits!'
    else:
        result['status']      = 0
        result['msg']         = 'Parameter value should be in hexadecimal format.'
    if(not result['status']):
        PluginUtil.post_error(result['msg'])
    return result['status']

def check_addr_align(addr_in_hex,size_align):
    result = {'status':1,'msg':'OK'}
    mod_addr_size = int(addr_in_hex,16) % (size_align << 10)
    if(mod_addr_size != 0):
        result['status'] = 0
        result['msg']    = 'Address must be aligned to '+str(size_align)+\
                           'KB size (set lower '+str(int(ceil(log((size_align << 10),2))))+' bits to 0)'

    if(not result['status']):
        PluginUtil.post_error(result['msg'])
    return result['status']

def check_addr_range_overlap(addr_in_hex0,size0,addr_in_hex1,size1):
    result = {'status':1,'msg':'OK'}
    addr_int_start0 = int(addr_in_hex0,16)
    addr_int_end0   = addr_int_start0+(size0 << 10)
    addr_int_start1 = int(addr_in_hex1,16)
    addr_int_end1   = addr_int_start1+(size1 << 10)
    if((addr_int_start0 in range(addr_int_start1,addr_int_end1)) or
       (addr_int_start1 in range(addr_int_start0,addr_int_end0))):
        result['status'] = 0
        result['msg']    = 'Address range should not overlap with Register block.'
    if(not result['status']):
        PluginUtil.post_error(result['msg'])
    return result['status']

def addr_range_drc(value,exp_len,size_align):
    result = {'status':1,'msg':'OK'}
    result['status'] = hex_value_drc(value,exp_len)
    if(result['status']):
        result['status'] = check_addr_align(value,size_align)
    return result['status']

def get_tgt_mem_range(num_tgt):
    max_idx = 22 - num_tgt
    mem_range = [(1 << idx) for idx in range(max_idx+1)]
    return mem_range

def get_sysclk_range(min_sck_freq):
    sysclk_lo = 1.0*min_sck_freq if(min_sck_freq >= 50) else 2.0*min_sck_freq
    sysclk_hi = 200.0
    return (sysclk_lo,sysclk_hi)

def get_clkdiv_range(clk_freq,en_ddr,min_sck_freq,max_speed):
    max_sck_freq = 200 if(max_speed >= 200) else max_speed
    min_div = 0 if(max_sck_freq >= 50) else ceil(clk_freq/max_sck_freq/2)
    # Note: min_sck_freq is in KHz
    max_div = ceil((1000*clk_freq)/min_sck_freq/2)
    return (min_div,max_div)

def calc_default_clkdiv(sys_clk_freq,min_sck_freq):
    def_clkdiv = ceil(sys_clk_freq*500/min_sck_freq)
    return def_clkdiv

def get_oscdiv_range(sck_freq,use_osc_clk):
    osc_freq = 450.0
    min_div  = ceil(osc_freq/sck_freq)
    clkdiv_range = (min_div,256) if(use_osc_clk) else (2,256)
    return clkdiv_range

def get_tot_mem_size(mem_size,num_tgt):
    next_powerof2 = (2**ceil(log(num_tgt,2)))
    tot_mem_size = mem_size*next_powerof2
    return tot_mem_size

def calc_addr_align(mem_size=1):
    addr_align = int('FFFF_FFFF',16) - ((mem_size << 10)-1)
    addr_align_str = '32\'h' + hex(addr_align)[2:].upper()
    return addr_align_str

def gen_list_block_size(min_idx=8):
    list_block_size = [(1 << blk_size) for blk_size in range(min_idx,15)]
    return list_block_size

def gen_fifo_depth(max_blk_size):
    fifo_depth = [int(blk_size/2) for blk_size in gen_list_block_size() if max_blk_size <= blk_size <= 16384]
    return fifo_depth


def calc_tid_width(max_req):
    tid_width = 1 if(max_req == 1) else ceil(log(max_req,2))
    return tid_width

def calc_cntr_bitwidth(max_cnt):
    bit_width = ceil(log((max_cnt+1),2))
    return bit_width


def get_tb_path(tbfile):
    tbPath   = '"'+runtime_info.ip_inst_dir+'/testbench/'+tbfile+'"'
    return tbPath

# ==============================================================================
# plugin.py
# ==============================================================================
