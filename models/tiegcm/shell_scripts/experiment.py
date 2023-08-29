from pprint import pprint
import subprocess
import os
import sys
import shutil
from dart_tools import dart_dir
from time_window import TimeWindow
from synthetic_obs import create_obs_seq_definition, run_create_fixed_network_seq

class Experiment:
    """ TIEGCM experiment """
    model = "TIEGCM"
    batch_script_templates_dir = "batch_script_templates"
    tiegcm_pbs_file = "run-tiegcm.pbs"
    mem_single = "mem.single" 
 

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
       self.setup_called = False
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
       self.inp_template = "tiegcm_res"+str(resolution)+".inp.template"
       self.inp_template_continue = self.inp_template+".continue"
       self.inp = "tiegcm_res"+str(resolution)+".inp"
       self.primary = "tiegcm_res"+str(resolution)+"_mareqx_smin_prim_001.nc"
       self.secondary = "tiegcm_res"+str(resolution)+"_mareqx_smin_sech_001.nc"

       self.win = TimeWindow(self.initial_time, self.end_time, self.cycle_delta)

    def info(self):
        """ Print out all the variables of the experiment """
        pprint(vars(self))
        self.win.info()
 
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

 
    def create_experiment_directory(self,directory):
        try:
            os.makedirs(directory) 
        except FileExistsError:
            print("Experiment directory {} exists".format(directory))
            sys.exit()
   
        last = os.getcwd() 
        os.chdir(directory)
        self.exp_directory = os.getcwd()
        os.chdir(last)
        
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
        self.create_experiment_directory(directory)
        pbs_file = os.path.join(self.exp_directory, self.tiegcm_pbs_file)
        self.setup_pbs_options(self.tiegcm_pbs_template, pbs_file)
      
        self.setup_called = True

    def assert_setup(self):
        """ Exits if experiment.setup has not been called
        """
        if not self.setup_called:
            print("Error : need to call setup before run")
            sys.exit()

    def set_tiegcm_stop_start(self,tiegcm_inp,cycle, continue_run):
        """ Create a tiegcm_inp file with start and stop times
            for a cycle

            tiegcm_inp - .inp file to be created
            cycle - 0:n which step of the experiment
            continue_run - Boolean. False to use tiegcm.inp with SOURCE and SOURCE_START

        """

        start_year = str(self.tiegcm_time(self.win.model_times[cycle])["year"])
        start_yday = str(self.tiegcm_time(self.win.model_times[cycle])["yday"])
        start_hour = str(self.tiegcm_time(self.win.model_times[cycle])["hour"])
        start_minute = str(self.tiegcm_time(self.win.model_times[cycle])["minute"])

        stop_year = str(self.tiegcm_time(self.win.model_end_times[cycle])["year"])
        stop_yday = str(self.tiegcm_time(self.win.model_end_times[cycle])["yday"])
        stop_hour = str(self.tiegcm_time(self.win.model_end_times[cycle])["hour"])
        stop_minute = str(self.tiegcm_time(self.win.model_end_times[cycle])["minute"])

        inp_template = 'tiegcm_res'+str(self.resolution)+'.inp.template'
        if continue_run:
            template = self.inp_template_continue
        else:
            template = self.inp_template

        readFile = open(os.path.join(dart_dir(), "models/tiegcm/shell_scripts", 
                        self.batch_script_templates_dir, template))
        data = readFile.read()
        readFile.close()

        data = data.replace("{start_year}", start_year)
        data = data.replace("{start_yday}", start_yday)
        data = data.replace("{start_hour}", start_hour)
        data = data.replace("{start_minute}", start_minute)

        data = data.replace("{stop_year}", stop_year)
        data = data.replace("{stop_yday}", stop_yday)
        data = data.replace("{stop_hour}", stop_hour)
        data = data.replace("{stop_minute}", stop_minute)

        writeFile = open(tiegcm_inp, "w")
        writeFile.write(data)
        writeFile.close()




class FreeRun(Experiment): 
    """ Free run cyle of TIEGCM """

    def __init__(self, root, exe, data, account, resolution,
                 cycle_delta, initial_time, end_time, free_run):
        super().__init__(root, exe, data, account, resolution, cycle_delta, initial_time, end_time)
        self.free_run = free_run


    def setup(self, directory):
        """ Setup a Free Run experiment for TIEGCM 

            directory - to be created for the experiment
        """
        super().setup(directory)

        # populate experiment directory
        shutil.copy(self.exe, "mem.setup/") # cp tiegcm.exe
        shutil.copytree("mem.setup", os.path.join(self.exp_directory, self.mem_single))

    def run(self):
        """ Submit tiegcm Free Run jobs 

        """

        self.assert_setup()
        print("self.tiegcm_pbs_file", self.tiegcm_pbs_file)

        os.chdir(self.exp_directory)

        self.set_tiegcm_stop_start(os.path.join(self.mem_single,self.inp+'-'+str(0)), 0, continue_run=False) 
        jobarg = ['qsub', '-v', 'CYCLE=0', self.tiegcm_pbs_file]

        result = subprocess.run(jobarg, stdout=subprocess.PIPE)

        print("number of cycles", self.win.num_cycles)
        print("Cycle #", 0 , "of ", self.win.num_cycles)

        for cycle in range(1,self.win.num_cycles):

            print("Cycle #",cycle, "of ", self.win.num_cycles)

            self.set_tiegcm_stop_start(os.path.join(self.mem_single,self.inp+'-'+str(cycle)), cycle, continue_run=True) 

            if_model_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            jobarg = ['qsub', '-v', 'CYCLE='+str(cycle), '-W', if_model_ok, self.tiegcm_pbs_file]
            result = subprocess.run(jobarg, stdout=subprocess.PIPE)


class PerfectModelObs(Experiment):
    """ Perfect Model Obs experiment """
    obs_seq_dir = "Observations"
    pmo_pbs_file = "submit_pmo.pbs"
    pmo_pbs_template = "submit_pmo.pbs.template"
    
    def __init__(self, root, exe, data, account, resolution,
                 cycle_delta, initial_time, end_time,
                 n_profiles):
        super().__init__(root, exe, data, account, resolution, cycle_delta, initial_time, end_time)
        self.n_profiles = n_profiles
        
    def setup(self, directory):
        """ Setup a Perfect Models Obs experiment for TIEGCM
        
            directory - to be created for the experiment
        """
        self.setup_called = False
        print("Setting up")
        super().setup(directory)

        # populate experiment dirctory
        shutil.copy(self.exe, "mem.setup/") # cp tiegcm.exe
        shutil.copytree("mem.setup", os.path.join(self.exp_directory, self.mem_single))
        self.work = os.path.join(dart_dir(), "models/tiegcm/work")
        os.makedirs(os.path.join(self.exp_directory, self.obs_seq_dir))
        self.observations = os.path.join(self.exp_directory, self.obs_seq_dir)
        shutil.copy(os.path.join(self.work, "input.nml"), self.observations)

        # tiegcm run script
        pbs_file = os.path.join(self.exp_directory, self.tiegcm_pbs_file)
        self.setup_pbs_options(self.tiegcm_pbs_template, pbs_file)
       
        # pmo run script
        pbs_file = os.path.join(self.exp_directory, self.pmo_pbs_file)
        self.setup_pbs_options(self.pmo_pbs_template, pbs_file)
 

        try:
            shutil.copy(os.path.join(self.work, "perfect_model_obs"), self.observations)
        except FileNotFoundError:
            print(" No perfect_model_obs found in {} ".format(self.work))
            sys.exit()

        # need a tiegcm_restart_p.nc and tiegcm_s.nc for init_model_mod
        print("HACK: need tiegcm restarts")
        shutil.copy(os.path.join(self.work, "tiegcm_restart_p.nc"), self.observations)
        shutil.copy(os.path.join(self.work, "tiegcm_s.nc"), self.observations)

        # set up obs_seq.in for each cycle
        os.chdir(self.observations)
        create_obs_seq_definition(self.n_profiles)
                       
        for cycle in range(1,self.win.num_cycles):

            try:
                run_create_fixed_network_seq(self.win.model_times[cycle], self.win.delta, cycles=1)
            except:
                 print("create_fixed_network_seq FAILED")
                 sys.exit()

            obs_seq = 'obs_seq.in.' + self.win.model_times[cycle].strftime('%Y%m%d-%H-%M')
            os.rename('obs_seq.in', obs_seq)

        self.setup_called = True

    def run(self):
        """ Submit Perfect Model Obs experiment """
        self.assert_setup()


        #    remove HACK files need for create_obs_seq but not used 
        hack_file = os.path.join(self.exp_directory,self.obs_seq_dir, "tiegcm_restart_p.nc")
        os.remove(hack_file)
        hack_file = os.path.join(self.exp_directory,self.obs_seq_dir, "tiegcm_s.nc")
        os.remove(hack_file)

        # set up links to tiegcm output 
        os.symlink(os.path.join(self.exp_directory,self.mem_single,self.primary), os.path.join(self.exp_directory,self.obs_seq_dir, "tiegcm_restart_p.nc") )
        os.symlink(os.path.join(self.exp_directory,self.mem_single,self.secondary), os.path.join(self.exp_directory,self.obs_seq_dir, "tiegcm_s.nc") )

        os.chdir(self.exp_directory)
 
        self.set_tiegcm_stop_start(os.path.join(self.mem_single,self.inp+'-'+str(0)), 0, continue_run=False) 
        jobarg = ['qsub', '-v', 'CYCLE=0', self.tiegcm_pbs_file] 
        result = subprocess.run(jobarg, stdout=subprocess.PIPE)

   
        print("Cycle #", 0 , "of ", self.win.num_cycles)
 
        for cycle in range(1,self.win.num_cycles):

            # link obs_seq.in
            # run perfect_model_obs
            # mv obs_seq.out obs_seq.out.'%Y%m%d-%H-%M'
     
            print("Cycle #",cycle, "of ", self.win.num_cycles)

            obs_seq_in = 'obs_seq.in.' + self.win.model_times[cycle].strftime('%Y%m%d-%H')
            self.set_tiegcm_stop_start(os.path.join(self.mem_single,self.inp+'-'+str(cycle)), cycle, continue_run=True)
            
            if_model_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            pmo_jobarg = ['qsub', '-v',
                             'OBS_SEQ='+obs_seq_in,
                             '-W', if_model_ok,
                             self.pmo_pbs_file]
            result = subprocess.run(pmo_jobarg, stdout=subprocess.PIPE)
      
            if_pmo_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            model_jobarg = ['qsub', '-v', 'CYCLE='+str(cycle), '-W', if_pmo_ok, self.tiegcm_pbs_file]
            result = subprocess.run(model_jobarg, stdout=subprocess.PIPE)

 
 
       
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
       
        self.setup_called = False 
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
        primary = [ "../mem{:03d}/".format(x+1)+self.primary for x in range(self.ens_size)]
        with open(os.path.join(assim, "restart_p_files.txt"), 'w') as f:
            for item in primary:
                 f.write(item + '\n')

        secondary = [ "../mem{:03d}/".format(x+1)+self.secondary for x in range(self.ens_size)]
        with open(os.path.join(assim, "secondary_files.txt"), 'w') as f:
            for item in secondary:
                 f.write(item + '\n')

        # output files same as input
        shutil.copy(os.path.join(assim, "restart_p_files.txt"), os.path.join(assim, "out_restart_p_files.txt"))
        shutil.copy(os.path.join(assim, "secondary_files.txt"), os.path.join(assim, "out_secondary_files.txt"))

        # set up links to tiegcm output 
        os.symlink(os.path.join(self.exp_directory,"mem001",self.primary), os.path.join(self.exp_directory,self.assim_dir, "tiegcm_restart_p.nc") )
        os.symlink(os.path.join(self.exp_directory,"mem001",self.secondary), os.path.join(self.exp_directory,self.assim_dir, "tiegcm_s.nc") )
 
        self.setup_called = True
        
    def setup_filter_pbs(self):
        """ create PBS file for submitting filter from template"""
        pbs_file = os.path.join(self.exp_directory, self.filter_pbs_file)
        self.setup_pbs_options("submit_filter.pbs.template", pbs_file)
        
    def setup_members(self):
        """ Directory for each ensemble member """
        
        # copy tiegcm.exe to the mem.setup directory
        shutil.copy(self.exe, "mem.setup/")

        # tiegcm input for each step of the cycle
        self.set_tiegcm_stop_start(os.path.join("mem.setup/",self.inp+'-'+str(0)), 0, continue_run=False)
        for cycle in range(1,self.win.num_cycles): 
            self.set_tiegcm_stop_start(os.path.join("mem.setup/",self.inp+'-'+str(cycle)), cycle, continue_run=True)

        [ self.copy_mem(x+1) for x in range(self.ens_size)]

        # remove tiegcm_.inp-cycle from mem.setup
        for cycle in range(self.win.num_cycles):
            temp_file = os.path.join("mem.setup/",self.inp+'-'+str(cycle)) 
            os.remove(temp_file)
        
    def copy_mem(self, x):
        mem = "mem{:03d}".format(x)
        shutil.copytree("mem.setup", os.path.join(self.exp_directory, mem))
        
    def run(self):
        """ Submit filter experiment """
        self.assert_setup()
        os.chdir(self.exp_directory)

        jobarg = ['qsub', '-v', 'CYCLE=0', self.tiegcm_pbs_file] 
        result = subprocess.run(jobarg, stdout=subprocess.PIPE)

        print("Cycle #", 0 , "of ", self.win.num_cycles)

        for cycle in range(1,self.win.num_cycles):
        
            print("Cycle #",cycle, "of ", self.win.num_cycles)
 
            obs_seq = 'obs_seq.out.' + self.win.model_times[cycle].strftime('%Y%m%d-%H-%M')
       
            if_model_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            filter_jobarg = ['qsub', '-v', 
                             'OBS_SEQ='+ os.path.join(self.obs_seq_dir,obs_seq),
                             '-W', if_model_ok, 
                             self.filter_pbs_file]
            result = subprocess.run(filter_jobarg, stdout=subprocess.PIPE)
           
            if_filter_ok = f"depend=afterok:{result.stdout.strip().decode('utf8').strip()}"
            model_jobarg = ['qsub', '-v', 'CYCLE='+str(cycle), '-W', if_filter_ok, self.tiegcm_pbs_file]
            result = subprocess.run(model_jobarg, stdout=subprocess.PIPE)

