# -----------------------------------------------------------------------------
#   Copyright (c) 2025 by Lattice Semiconductor Corporation
#   ALL RIGHTS RESERVED
#   Subject to Lattice's Software License Agreement
# -----------------------------------------------------------------------------
import os
import shutil
from sys import argv, exit

def setup_eval_dir():
    """Create eval directory and copy required files from testbench if needed."""
    if not os.path.exists('eval'):
        os.makedirs('eval')
        print("Created eval/ directory")

    # Copy dut_params.v from testbench to eval if not exists in eval
    if not os.path.exists('eval/dut_params.v') and os.path.exists('testbench/dut_params.v'):
        shutil.copy('testbench/dut_params.v', 'eval/dut_params.v')
        print("Copied testbench/dut_params.v to eval/")

    # Copy dut_inst.v from testbench to eval if not exists in eval
    if not os.path.exists('eval/dut_inst.v') and os.path.exists('testbench/dut_inst.v'):
        shutil.copy('testbench/dut_inst.v', 'eval/dut_inst.v')
        print("Copied testbench/dut_inst.v to eval/")

def load_parameter(param_name):
    f_params = open('eval/dut_params.v', 'r')
    while f_params:
        line = f_params.readline()
        if (param_name in line):
            str_spl = line.split('=')
            param = str_spl[-1]
            val = str_spl[1]
            f_val = val.replace(";\n",'')
            f_val2 = f_val.replace("\"",'')
            f_val3 = f_val2.replace(" ",'')
            break
    f_params.close()
    return (f_val3)

def load_macro(macro_name):
    f_macros = open('eval/dut_params.v', 'r')
    while f_macros:
        line = f_macros.readline()
        if (macro_name in line):
            str_spl = line.split(' ')
            macro = str_spl[1]
            val = str_spl[2]
            f_val = val.replace(";\n",'')
            f_val2 = f_val.replace("\"",'')
            f_val3 = f_val2.replace(" ",'')
            break
    f_macros.close()
    return (f_val3)

def gen_pdc():
    # Setup eval directory and copy required files
    setup_eval_dir()

    f_pdc               = open('eval/constraint.pdc', 'w')

    CLKI_FREQ           = float(load_parameter("CLKI_FREQ"))
    SPI_SCKDIV          = int(load_parameter("SPI_SCKDIV"))

    print("DEBUG: CLKI_FREQ = {}, SPI_SCKDIV = {}".format(CLKI_FREQ,SPI_SCKDIV))

    f_pdc.write("##================================================================================##\n")
    f_pdc.write("## Copy these constraints to your top-level pdc and replace path with actual path \n")
    f_pdc.write("##================================================================================##\n")

    CLKI_PERIOD = (1000.0/float(CLKI_FREQ))
    SCK_DIV     = 1
    SCK_PERIOD  = (1.0*CLKI_PERIOD)
    if(SPI_SCKDIV > 0):
        SCK_DIV     = (SPI_SCKDIV*2)
        SCK_PERIOD  = (1.0*CLKI_PERIOD*SCK_DIV)
    SCK_PERIOD_D2 = (SCK_PERIOD/2.0)

    f_pdc.write("set CLKI_FREQ %d\n" % CLKI_FREQ)
    f_pdc.write("set CLKI_PERIOD %0.4f\n" % CLKI_PERIOD)
    f_pdc.write("set SCK_DIV %d\n" % SCK_DIV)
    f_pdc.write("set SCK_PERIOD %0.4f\n" % SCK_PERIOD)
    f_pdc.write("set SCK_PERIOD_D2 %0.4f\n" % SCK_PERIOD_D2)
    f_pdc.write("\n")
    f_pdc.write("create_clock -name {clk_i} -period $CLKI_PERIOD [get_ports clk_i]\n")
    f_pdc.write("create_generated_clock -name {emmc_clk_o} -source [get_ports clk_i] -divide_by $SCK_DIV [get_ports emmc_clk_o]\n")
    f_pdc.write("\n")

    f_pdc.write("set_input_delay -clock [get_clocks emmc_clk_o] $SCK_PERIOD_D2 [get_ports {emmc_cmd_io emmc_dat_io[*]}]\n")

    if(SPI_SCKDIV > 0):
        f_pdc.write("set_multicycle_path -setup -start -from [get_clocks clk_i]     -to [get_clocks emmc_clk_o] %d\n" % SCK_DIV    )
        f_pdc.write("set_multicycle_path -hold  -start -from [get_clocks clk_i]     -to [get_clocks emmc_clk_o] %d\n" % (SCK_DIV-1))
        f_pdc.write("set_multicycle_path -setup -end   -from [get_clocks emmc_clk_o] -to [get_clocks clk_i    ] %d\n" % SCK_DIV    )
        f_pdc.write("set_multicycle_path -hold  -end   -from [get_clocks emmc_clk_o] -to [get_clocks clk_i    ] %d\n" % (SCK_DIV-1))

    f_pdc.write("set_output_delay -clock [get_clocks emmc_clk_o] $SCK_PERIOD_D2 [get_ports {emmc_cmd_io emmc_dat_io[*]}]\n")
    f_pdc.write("set_false_path -from [get_ports  {rst_n_i}]\n")
    f_pdc.write("set_false_path -from [get_ports  {emmc_*}]\n")
    f_pdc.write("set_false_path -to   [get_ports  {emmc_*}]\n")
    f_pdc.write("\n")


    f_pdc.write("\n")
    f_pdc.write("##================================END OF CONSTRAINTS==============================##\n")
    f_pdc.write("##This is not necessary, added only for eval\n")
    f_pdc.write("ldc_set_attribute {VIRTUAL_IO=TRUE} [get_ports {s_* m_*}]\n")
    f_pdc.write("\n")

    f_pdc.close()

gen_pdc()
print("Clean up script : ",os.path.realpath(argv[0]))
os.remove(os.path.realpath(argv[0]))
exit(0)
