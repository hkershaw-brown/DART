from datetime import datetime, timedelta

class TimeWindow:
    """ Observations for a TIEGCM experiment """
    
    def __init__(self, start_time, end_time, delta):
        """ Initializes the observations associated with a TIEGCM experiment
        
        start_time - string '%Y-%m-%d %H:%M:%S' model start time of experiment
        end_time   - string '%Y-%m-%d %H:%M:%S' model end time of experiment
        delta - integer  assimilation window time in hours
        
        model_time is the center of the window.
        
        observation_time_window = model_time +/- 0.5*delta
        
        The assimilation window has to be non-overlapping,
        so start the window at +1 second and end on
        exactly the time boundary.
                
        """
        
        if delta > 23:
          raise ValueError("invalid delta {} should be [0-23] hours".format(delta))
        
        self.start_time = datetime.strptime(start_time, '%Y-%m-%d %H:%M:%S')
        self.end_time = datetime.strptime(end_time, '%Y-%m-%d %H:%M:%S')
        self.delta = delta
        self.delta_half = delta / 2
            
        # create a list of times for the experiment
        #   (model_end_time + 0.5*delta) - (model_start_time - 0.5*delta)
        runtime_hours = int((self.end_time - self.start_time + timedelta(hours=self.delta)).total_seconds()/3600)

        self.window_start_times = [ self.start_time-timedelta(hours=self.delta_half)+x*timedelta(hours=self.delta) for x in range(runtime_hours)]
        
        self.window_end_times = [x+timedelta(hours=self.delta) for x in self.window_start_times]
        self.model_times = [x+timedelta(hours=self.delta_half) for x in self.window_start_times]
        self.window_start_times = [ x+timedelta(seconds=1) for x in self.window_start_times] # +1 second to window start
        
        self.num_cycles = len(self.model_times)
        #print("win start  ", self.window_start_times[0])
        #print("model time ", self.model_times[0])
        #print("win end    ", self.window_end_times[0])
        
        #print("win start  ", self.window_start_times[1])
        #print("model time ", self.model_times[1])
        #print("win end    ", self.window_end_times[1])
        

        #print("win start  ", self.window_start_times[-1])
        #print("model time ", self.model_times[-1])
        #print("win emd   ", self.window_end_times[-1])
        
