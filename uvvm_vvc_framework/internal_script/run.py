#========================================================================================================================
# Copyright (c) 2018 by Bitvis AS.  All rights reserved.
# You should have received a copy of the license file containing the MIT License (see LICENSE.TXT), if not,
# contact Bitvis AS <support@bitvis.no>.
#
# UVVM AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR
# OTHER DEALINGS IN UVVM.
#========================================================================================================================

from os.path import join, dirname
from itertools import product
import os, sys, subprocess

sys.path.append("../../release/regression_test")
from testbench import Testbench


# Counters
num_tests_run = 0
num_failing_tests = 0


#=============================================================================================
#
# Define tests and run - user to edit this
#
#=============================================================================================

# Create testbench configuration with TB generics
def create_config(modes, data_widths, data_array_widths):
  config = []
  for mode, data_width, data_array_width in product(modes, data_widths, data_array_widths):
    config.append(str(mode) + ' ' + str(data_width) + ' ' + str(data_array_width))

  return config


def main(argv):
  global num_failing_tests

  tb = Testbench()
  tb.set_library("uvvm_vvc_framework")
  tb.check_arguments(argv)

  # Compile VIP, dependencies, DUTs, TBs etc
  tb.compile()

  tests = [ "Testing_2_Sequencer_Parallel_using_different_types_of_VVCs",
            "Testing_2_Sequencer_Parallel_using_same_types_of_VVCs_but_different_instances",
            "Testing_2_Sequencer_Parallel_using_same_instance_of_a_VVC_type_but_not_at_the_same_time",
            "Testing_get_last_received_cmd_idx",
            "Testing_differt_accesses_between_two_sequencer",
            "Testing_differt_single_sequencer_access",
            "Testing_shared_uvvm_status_await_any_completion_info"
            ]

  # Setup testbench and run
  tb.set_tb_name("internal_vvc_tb")
  tb.add_tests(tests)
  tb.run_simulation()

  tb.remove_tests()

  # Setup testbench and run
  tb.set_tb_name("simplified_data_queue_tb")
  tb.run_simulation()

  # Setup testbench and run
  tb.set_tb_name("generic_queue_tb")
  tb.run_simulation()

  # Setup testbench and run
  tb.set_tb_name("generic_queue_record_tb")
  tb.run_simulation()

  # Setup testbench and run
  tb.set_tb_name("generic_queue_array_tb")
  tb.run_simulation()


  # Print simulation results
  tb.print_statistics()

  # Read number of failing tests for return value
  num_failing_tests = tb.get_num_failing_tests()





if __name__ == "__main__":
  main(sys.argv)

  # Return number of failing tests to caller
  sys.exit(num_failing_tests)