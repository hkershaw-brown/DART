from pprint import pprint
import subprocess
import os
import sys
import shutil
from dart_tools import dart_dir
from time_window import TimeWindow

class Experiment:
    """ TIEGCM experiment """
    model = "TIEGCM"
    batch_script_templates_dir = "batch_script_templates"
    tiegcm_pbs_file = "run-tiegcm.pbs"
 

    def __init__(self, root, exe, data, account, resolution, cycle_delta, initial_time, end_time):
       """ Initialize an experiment
       
       root -- TIEGCM root directory
       exe -- full path to tiegcm.exe
       data -- TIEGCM data directory
       resolution -- TIEGCM resolution 2.5 or 5.0 degrees
       cycle_deta -- how often to stop TIEGCM
       initial_time -- start time of the experiment
       end_time - end time of the experiment
       
       """
       self.root = root 
       self.exe = exe
       self.data = data 
       self.account = account 
       self.resolution = resolution 
       self.cycle_delta = cycle_delta
       self.initial_time = initial_time
       self.end_time = end_time
       self.exp_directory = ""
       self.tiegcm_pbs_template = "run-tiegcm.pbs.template"

       self.win = TimeWindow(self.initial_time, self.end_time, self.cycle_delta)

    def info(self):
        """ Print out all the variables of the experiment """
        pprint(vars(self))
 
    def tiegcm_time(self, t):
        """ TIEGCM times
        
            t - datetime
            returns dict {year, yday, hour, minute}
            
            START 3-integer triplet: day,hour,minute
            START_YEAR: year
    
        """

        tgcm = {}
        tgcm['year'] = t.timetuple().tm_year
        tgcm['yday'] = t.timetuple().tm_yday
        tgcm['hour'] = t.timetuple().tm_hour
        tgcm['minute'] = t.timetuple().tm_min

        return tgcm

 
    def create_experiment_directory(self):
        try:
            os.makedirs(self.exp_directory)
        except FileExistsError:
            print("Experiment directory {} exists".format(self.exp_directory))
            sys.exit()
    
        
    def setup_pbs_options(self, pbs_template, pbs_file):
        """ Create PBS files from a template """
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
            
            creates:
              directory to run experiment
              PBS script to run tiegcm
        """
        self.exp_directory = directory
        self.create_experiment_directory()
        pbs_file = os.path.join(self.exp_directory, self.tiegcm_pbs_file)
        self.setup_pbs_options(self.tiegcm_pbs_template, pbs_file)
      

    def run(self, num_cycles):
        """ Submit tiegcm jobs """
        result = subprocess.run(['qsub', self.tiegcm_pbs_file], stdout=subprocess.PIPE)
        model_run = f"depend=afterok:{result.stdout.strip().decode('utf8')}"

        for cycle in range(num_cycles):
            jobarg = ['qsub', '-W', model_run, self.tiegcm_pbs_file]
            result = subprocess.run(jobarg, stdout=subprocess.PIPE)
            model_run = f"depend=afterok:{result.stdout.strip().decode('utf8')}"
        


class PerfectModelObs(Experiment):
    """ Perfect Model Obs experiment """
    
    def __init__(self, root, exe, data, account, resolution,
                 cycle_delta, initial_time, end_time,
                 obs_seq_in):
        super().__init__(root, exe, data, account, resolution, cycle_delta, initial_time, end_time)
        self.obs_seq_in = obs_seq_in
                
       
class Filter(Experiment):
    """ Filter experiment """
    filter_pbs_file = "submit_filter.pbs"
    assim_dir = "assim"
     
    def __init__(self, root, exe, data, account, resolution,
                 cycle_delta, initial_time, end_time,
                 obs_seq_dir, ens_size):
        super().__init__(root, exe, data, account, resolution, cycle_delta, initial_time, end_time)
        self.obs_seq_dir = obs_seq_dir
        self.ens_size = ens_size
        self.tiegcm_pbs_template = "run-array-tiegcm.pbs.template"
        
       
    def setup(self, directory):
        """ Setup a Data Assimilation experiment for TIEGCM
        
            directory - to be created for the experiment
        """
        super().setup(directory)
        
        # TIGCM array job file
        pbs_file = os.path.join(self.exp_directory, self.tiegcm_pbs_file)
        readFile = open(pbs_file)
        data = readFile.read()
        readFile.close()
        data = data.replace("{ens_size}", str(self.ens_size))
        writeFile = open(pbs_file, "w")
        writeFile.write(data)
        writeFile.close()
       
        # Directory for each ensemble member
        self.setup_members()
        self.setup_filter_pbs()
        
        # Create directory for assimilation
        os.makedirs(os.path.join(self.exp_directory, self.assim_dir))
        work = os.path.join(dart_dir(), "models/tiegcm/work")
        assim = os.path.join(self.exp_directory,self.assim_dir)
        shutil.copy(os.path.join(work, "input.nml"), assim)
        try:
            shutil.copy(os.path.join(work, "filter"), assim)
        except FileNotFoundError:
            print(" No filter found in {} ".format(work))
            sys.exit()
        
        # list of input and output members
        primary = [ "../mem{:03d}/tiegcm_restart_p.nc".format(x+1) for x in range(self.ens_size)]
        with open(os.path.join(assim, "restart_p_files.txt"), 'w') as f:
            for item in primary:
                 f.write(item + '\n')

        secondary = [ "../mem{:03d}/tiegcm_s.nc".format(x+1) for x in range(self.ens_size)]
        with open(os.path.join(assim, "secondary_files.txt"), 'w') as f:
            for item in secondary:
                 f.write(item + '\n')

        # output files same as input
        shutil.copy(os.path.join(assim, "restart_p_files.txt"), os.path.join(assim, "out_restart_p_files.txt"))
        shutil.copy(os.path.join(assim, "secondary_files.txt"), os.path.join(assim, "out_secondary_files.txt"))
 
        print("--------------------------")
        print("Filter experiment set up:")
        self.info()
        print("--------------------------")
        
    def setup_filter_pbs(self):
        """ create PBS file for submitting filter from template"""
        pbs_file = os.path.join(self.exp_directory, self.filter_pbs_file)
        self.setup_pbs_options("submit_filter.pbs.template", pbs_file)
        
    def setup_members(self):
        """ Directory for each ensemble member """
        
        # copy tiegcm.exe to the mem.setup directory
        shutil.copy(self.exe, "mem.setup/")
        [ self.copy_mem(x+1) for x in range(self.ens_size)]
        
    def copy_mem(self, x):
        mem = "mem{:03d}".format(x)
        shutil.copytree("mem.setup", os.path.join(self.exp_directory, mem))
        
    def run(self):
        """ Submit filter experiment """
        os.chdir(self.exp_directory)
        print(os.getcwd())

        result = subprocess.run(['qsub', self.tiegcm_pbs_file], stdout=subprocess.PIPE)
        print('result: ', result)

        for cycle in range(1): #range(self.win.num_cycles):
         
            obs_seq = 'obs_seq.out.' + self.win.model_times[cycle].strftime('%Y%m%d%H')
            tgcm_year = str(self.tiegcm_time(self.win.model_times[cycle])["year"])
            tgcm_yday = str(self.tiegcm_time(self.win.model_times[cycle])["yday"])
            tgcm_hour = str(self.tiegcm_time(self.win.model_times[cycle])["hour"])
            tgcm_minute = str(self.tiegcm_time(self.win.model_times[cycle])["minute"])
       
            if_model_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            print("One", if_model_ok)
            filter_jobarg = ['qsub', '-v', 
                             'OBS_SEQ='+ os.path.join(self.obs_seq_dir,obs_seq),
                             '-W', if_model_ok, 
                             self.filter_pbs_file]
            result = subprocess.run(filter_jobarg, stdout=subprocess.PIPE)
           
            if_filter_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            print("Two", if_filter_ok)
            model_jobarg = ['qsub', '-v',
                              ' YEAR='+tgcm_year 
                             +' YDAY='+tgcm_yday 
                             +' HOUR='+tgcm_hour 
                             +' MIN='+tgcm_minute,
                            '-W', if_filter_ok, self.tiegcm_pbs_file]
            result = subprocess.run(model_jobarg, stdout=subprocess.PIPE)

