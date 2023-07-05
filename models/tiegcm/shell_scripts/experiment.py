from pprint import pprint

class Experiment:
    """ TIEGCM experiment """
    model = "TIEGCM"


    def __init__(self, root, data, account, resolution, cycle_delta, initial_time):
       self.root = root 
       self.data = data 
       self.account = account 
       self.resolution = resolution 
       self.cycle_delta = cycle_delta
       self.inital_time = initial_time

    def info(self):
        pprint(vars(self))
        
    def setup_tiegcm_run(self, pbs_template):
        readFile = open("batch_script_templates/run-tiegcm.pbs.template")
        data = readFile.read()
        data = data.replace("{res}", str(self.resolution))
        data = data.replace("{account}", self.account)
        data = data.replace("{tgcmdata}", self.data)
        data = data.replace("{tiegcm_root}", self.root)
        
    
        if self.resolution == 2.5:
             nodes = "select=1:ncpus=32:mpiprocs=32:ompthreads=1"
        else:
            nodes = "select=1:ncpus=16:mpiprocs=16:ompthreads=1"
    
        data = data.replace("{nodes}", nodes)
    
        writeFile = open(pbs_template, "w")
        writeFile.write(data)

class Pmo(Experiment):
    """ Perfect Model Obs experiment """
    
    def __init__(self, root, data, account, resolution, cycle_delta, initial_time, obs_seq_in):
        super().__init__(root, data, account, resolution, cycle_delta, initial_time)
        self.obs_seq_in = obs_seq_in
                
       
class Filter(Experiment):
    """ Filter experiment """
     
    def __init__(self, root, data, account, resolution, cycle_delta, initial_time, obs_seq_out, ens_size):
        super().__init__(root, data, account, resolution, cycle_delta, initial_time)
        self.obs_seq_out = obs_seq_out
        self.ens_size = ens_size
         
    def setup_tiegcm_run(self, pbs_template):
        readFile = open("batch_script_templates/run-array-tiegcm.pbs.template")
        data = readFile.read()
        data = data.replace("{res}", str(self.resolution))
        data = data.replace("{account}", self.account)
        data = data.replace("{tgcmdata}", self.data)
        data = data.replace("{tiegcm_root}", self.root)
        data = data.replace("{ens_size}", str(self.ens_size))
    
        if self.resolution == 2.5:
             nodes = "select=1:ncpus=32:mpiprocs=32:ompthreads=1"
        else:
            nodes = "select=1:ncpus=16:mpiprocs=16:ompthreads=1"
    
        data = data.replace("{nodes}", nodes)
    
        writeFile = open(pbs_template, "w")
        writeFile.write(data)

