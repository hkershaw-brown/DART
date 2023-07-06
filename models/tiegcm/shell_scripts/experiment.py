from pprint import pprint
import subprocess
import os
import sys
import shutil

class Experiment:
    """ TIEGCM experiment """
    model = "TIEGCM"
    batch_script_templates_dir = "batch_script_templates"
    tiegcm_pbs_file = "run-tiegcm.pbs"
 

    def __init__(self, root, data, account, resolution, cycle_delta, initial_time):
       self.root = root 
       self.data = data 
       self.account = account 
       self.resolution = resolution 
       self.cycle_delta = cycle_delta
       self.inital_time = initial_time

    def info(self):
        pprint(vars(self))
        
    def setup_pbs_options_tiegcm(self, pbs_template, pbs_file):
        """ Create PBS files for tiegcm run """
        readFile = open(os.path.join(self.batch_script_templates_dir, pbs_template))
        data = readFile.read()
        readFile.close()
        data = data.replace("{res}", str(self.resolution))
        data = data.replace("{account}", self.account)
        data = data.replace("{tgcmdata}", self.data)
        data = data.replace("{tiegcm_root}", self.root)
    
        if self.resolution == 2.5:
             nodes = "select=1:ncpus=32:mpiprocs=32:ompthreads=1"
        else:
            nodes = "select=1:ncpus=16:mpiprocs=16:ompthreads=1"
    
        data = data.replace("{nodes}", nodes)
            
        writeFile = open(pbs_file, "w")
        writeFile.write(data)
        writeFile.close()
             
    def setup(self, directory):
        """ Setup a cycling experiment for TIEGCM
            directory - to be created for the experiment
        """
        try:
            os.makedirs(directory)
        except FileExistsError:
            print("Experiment directory {} exists".format(directory))
            sys.exit()
        pbs_file = os.path.join(directory, "run-tiegcm.pbs")
        self.setup_pbs_options_tiegcm("run-tiegcm.pbs.template", pbs_file)
      

    def run(self, num_cycles):
        """ Submit tiegcm jobs """
        result = subprocess.run(['qsub', 'submit.sh'], stdout=subprocess.PIPE)
        model_run = f"depend=afterok:{result.stdout.strip().decode('utf8')}"

        for cycle in range(num_cycles):
            jobarg = ['qsub', '-W', model_run, 'submit.sh']
            result = subprocess.run(jobarg, stdout=subprocess.PIPE)
            model_run = f"depend=afterok:{result.stdout.strip().decode('utf8')}"
        


class Pmo(Experiment):
    """ Perfect Model Obs experiment """
    
    def __init__(self, root, data, account, resolution, cycle_delta, initial_time, obs_seq_in):
        super().__init__(root, data, account, resolution, cycle_delta, initial_time)
        self.obs_seq_in = obs_seq_in
                
       
class Filter(Experiment):
    """ Filter experiment """
    filter_pbs_file = "submit_filter.pbs"
     
    def __init__(self, root, data, account, resolution, cycle_delta, initial_time, obs_seq_out, ens_size):
        super().__init__(root, data, account, resolution, cycle_delta, initial_time)
        self.obs_seq_out = obs_seq_out
        self.ens_size = ens_size
        
         
    def setup(self, directory):
        """ Setup a Data Assimilation experiment for TIEGCM
            directory - to be created for the experiment
        """
        try:
            os.makedirs(directory)
            self.directory = directory
        except FileExistsError:
            print("Experiment directory {} exists".format(directory))
            sys.exit()
        pbs_file = os.path.join(self.directory, self.tiegcm_pbs_file)
        
        self.setup_pbs_options_tiegcm("run-array-tiegcm.pbs.template", pbs_file)
        readFile = open(pbs_file)
        data = readFile.read()
        readFile.close()
        data = data.replace("{ens_size}", str(self.ens_size))
        writeFile = open(pbs_file, "w")
        writeFile.write(data)
        writeFile.close()
       
        self.setup_members()
        self.setup_filter_pbs()
        
    def setup_filter_pbs(self):
        pbs_file = os.path.join(self.directory, self.filter_pbs_file)
        self.setup_pbs_options_tiegcm("submit_filter.pbs.template", pbs_file)
        
    def setup_members(self):
        [ self.copy_mem(x) for x in range(self.ens_size)]

    def copy_mem(self, x):
        mem = "mem{:03d}".format(x)
        shutil.copytree("mem.setup", os.path.join(self.directory, mem))
        
    def run(self, num_cycles):
        """ Submit filter experiment """
        result = subprocess.run(['qsub', self.pbs_tiegcm], stdout=subprocess.PIPE)

        for cycle in range(num_cycles):
        
            if_model_ok = f"depend=afterok:{result.stdout.strip().decode('utf8')}"
            filter_jobarg = ['qsub', '-W', if_model_ok, self.filter_pbs_file]
            result = subprocess.run(filter_jobarg, stdout=subprocess.PIPE)
            
            if_filter_ok = f"depend=afterok:{result.stdout.strip().decode('utf8')}"
            model_jobarg = ['qsub', '-W', if_filter_ok, self.tiegcm_pbs_file]
            result = subprocess.run(filter_jobarg, stdout=subprocess.PIPE)

