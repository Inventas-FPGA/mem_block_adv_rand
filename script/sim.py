import os
import sys

# ----------- USER HDLRegression PATH -----------------
# If HDLRegression is not installed as a Python package (see doc)
# then uncomment the following line and set the path for
# the HDLRegression install folder :
#sys.path.append("../tools/hdlregression")


from hdlregression import HDLRegression

hr = HDLRegression()

# Add DUT and TB files
hr.add_files("../tb/*.vhd", "test_lib")
hr.add_files("../src/*.vhd", "design_lib")

# Add UVVM components
hr.add_files("../tools/UVVM/uvvm_util/src/*.vhd", "uvvm_util")
hr.add_files("../tools/UVVM/uvvm_vvc_framework/src/*.vhd", "uvvm_vvc_framework")

hr.add_files("../tools/UVVM/bitvis_vip_sbi/src/*.vhd", "bitvis_vip_sbi")
hr.add_files("../tools/UVVM/uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_sbi")

hr.add_files("../tools/UVVM/bitvis_vip_clock_generator/src/*.vhd", "bitvis_vip_clock_generator")
hr.add_files("../tools/UVVM/uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_clock_generator")

hr.add_files("../tools/UVVM/bitvis_vip_scoreboard/src/*.vhd", "bitvis_vip_scoreboard")

hr.add_generics(
    entity="mem_block_tb",
    architecture="tb",
    generics=[
        "GC_SEED",           17,
        "GC_ADDR_WIDTH",     12,
        "GC_DATA_WIDTH",     32,
        "GC_ITERATIONS",     512,
        "GC_MAX_ITERATIONS", 1000,
    ],
)

hr.start()