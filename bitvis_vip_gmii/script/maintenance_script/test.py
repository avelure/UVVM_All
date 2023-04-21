import sys
import os
import shutil
from itertools import product


try:
    from hdlregression import HDLRegression
except:
    print('Unable to import HDLRegression module. See HDLRegression documentation for installation instructions.')
    sys.exit(1)


def cleanup(msg='Cleaning up...'):
    print(msg)

    sim_path = os.getcwd()

    for files in os.listdir(sim_path):
        path = os.path.join(sim_path, files)
        try:
            shutil.rmtree(path)
        except:
            os.remove(path)


print('Verify Bitvis VIP GMII')

cleanup('Removing any previous runs.')

hr = HDLRegression(simulator='modelsim')

# Add util, fw and VIP Scoreboard
hr.add_files("../../../uvvm_util/src/*.vhd", "uvvm_util")
hr.add_files("../../../uvvm_vvc_framework/src/*.vhd", "uvvm_vvc_framework")
hr.add_files("../../../bitvis_vip_scoreboard/src/*.vhd",
             "bitvis_vip_scoreboard")

# Add GMII VIP
hr.add_files("../../src/*.vhd", "bitvis_vip_gmii")
hr.add_files(
    "../../../uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_gmii")

# Add TB/TH
hr.add_files("../../tb/maintenance_tb/*.vhd", "bitvis_vip_gmii")
hr.add_files("../../tb/*.vhd", "bitvis_vip_gmii")

sim_options = None
if hr.settings.get_simulator_name() in ['MODELSIM', 'RIVIERA']:
    sim_options = '-t ns'

hr.start(sim_options=sim_options)

num_failing_tests = hr.get_num_fail_tests()
num_passing_tests = hr.get_num_pass_tests()

# No tests run error
if num_passing_tests == 0:
    sys.exit(1)
# Remove output only if OK
if hr.check_run_results(exp_fail=0) is True:
    cleanup('Removing simulation output')
# Return number of failing tests
sys.exit(num_failing_tests)
