from pprint import pprint

class Experiment:
    """ TIEGCM experiment """
    model = 'TIEGCM'


    def __init__(self, root, data, account, resolution, cycle_delta, initial_time):
       self.root = root 
       self.data = data 
       self.account = account 
       self.resolution = resolution 
       self.cycle_delta = cycle_delta
       self.inital_time = initial_time

    def info(self):
        pprint(vars(self))
        
        
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
