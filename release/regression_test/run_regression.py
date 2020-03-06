import sys
import subprocess
import os
import glob
import shutil



def delete_sim_content(path):
  keep_files = ["bitvis_irqc.mpf"]

  num_files_deleted = 0
  num_paths_deleted = 0
  files = glob.glob(path + "/*", recursive=True)

  for file in files:
    file = file.replace('\\', '/')

    filename = file[file.rfind('/') + 1:].lower()
    if not(filename in keep_files):

      try:
        if os.path.isfile(file):
          os.remove(file)
          num_files_deleted += 1
        elif os.path.isdir(file):
          shutil.rmtree(file)
          num_paths_deleted += 1    

      except OSError as e:
        print("Unable to remove %s from /sim folder [%s]." %(file, e.strerror))

    else:
      print("Keeping: %s" %(file))

  print("Removed: %d files, %s dirs." %(num_files_deleted, num_paths_deleted))


def cd_to_module(module):
  sim_path = '../../' + module.lower() + '/sim'

  if module == None or len(module) == 0:
    return
  else:
    if not os.path.exists(sim_path):
        os.mkdir(sim_path)

    delete_sim_content(sim_path)
    os.chdir(sim_path)


def get_module_list():
  modules = []
  for line in open("module_list.txt", 'r'):
    if not line[0].strip() == "#":
      modules.append(line.lower().rstrip('\n'))

  return modules


def simulate_module(module):
  print("\nSimulating module: " + module)
  if module == None or len(module) == 0:
    return 0

  try:
    print(' '.join(sys.argv[1:]))
    subprocess.check_call([sys.executable, "../../" + str(module) + "/internal_script/run.py", ' '.join(sys.argv[1:])])
    return 0
  except subprocess.CalledProcessError as e:
    print("Number of failing tests: " + str(e.returncode))
    return int(e.returncode)


def present_results(num_failing_tests):
  print("---------------------------------------------")
  if num_failing_tests > 0:
    print("Regression test FAILED with a total of " + str(num_failing_tests) + " failing tests.")
  else:
    print("Regression test SUCCEEDED with a total of 0 failing tests.")



def main():
  if sys.version_info[0] < 3:
    raise Exception("Python version 3 is required to run this script!")

  modules = get_module_list()
  num_failing_tests = 0

  for idx, module in enumerate(modules):
    print("\n%s" %(50*'-'))
    print("Running module %d: %s." %(idx + 1, module))
    print("Num failing tests in regression run: %d" %(num_failing_tests))

    cd_to_module(module)
    num_failing_tests += simulate_module(module)

  present_results(num_failing_tests)




if __name__ == "__main__":
  main()