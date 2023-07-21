from dart_tools import golden_spiral, xyz_to_lat_lon, plot_points, dart_dir
import os

def error_var(obs_type):
    """ error variance 

        no idea what to set this too
    """
    
    return 0.1


def create_gps_profiles(n_profiles):
    """ create input for create_obs_sequence

        n - number of profiles
    """

    lowest_height_m = 160000 
    top_height_m = 450000
    step_m = 10000
    
    heights = [x for x in range(lowest_height_m, top_height_m+1, step_m)]
 
    n_heights = len(heights)
    
    print("number of profiles: ", n_profiles)
    print("number of heights: ", n_heights)
  
    unit_sphere = golden_spiral(n_profiles)
    lon, lat = xyz_to_lat_lon(unit_sphere)     

    #plot_points(unit_sphere)
 
    # GPS profile obs
    obs_type = 'GPS_PROFILE'

    with open("create_obs_seq_input.txt", "w") as f:
        f.write("{}\n".format(n_heights*n_profiles)) # upper bound on number of obs in sequence
        f.write('0\n') # copies of data (0 for definition)
        f.write('0\n') # qc values

        for p in range(n_profiles):
            for i, height in enumerate(heights) :
                f.write('0\n') # -1 for no more obs
                f.write(obs_type+'\n') # name of obs_type
                f.write('3\n')   # vertical coorinate (height == 3)
                f.write("{}\n".format(height))  # height in m 
                f.write("{}\n".format(lon[p])) # longitude [0 - 360]
                f.write("{}\n".format(lat[p])) # latitude [-90 - 90]
                # dummy time - this is overwritten by create_network_seqeunce 
                # {yyyy} {month} {day} {hour} {minute} {second}
                f.write("{0} {1} {2} {3} {4} {5}\n".format(2002, 12, 26, 0, 0, 0))
                f.write("{}\n".format(error_var(obs_type)))  # error variance

        f.write("set_def.out")

def network_seq_options(start_time, delta_time, cycles):
    """ create a file for input into create_network_sequence 

         start_time - datetime object: start of experiment
         delta_time - int: cycle period for the experiment in hours
    
    """

    year   = start_time.timetuple().tm_year
    month  = start_time.timetuple().tm_mon
    day    = start_time.timetuple().tm_mday
    hour   = start_time.timetuple().tm_hour
    minute = start_time.timetuple().tm_min
    second = start_time.timetuple().tm_sec

    seconds = delta_time*3600 # TIEGCM delta_time is in hours
    days = 0
    

    with open("create_network_seq_input.txt", "w") as f:
        f.write("set_def.out\n")  # filename for network definition sequence
        f.write("1\n") # regularly repeating time sequence enter 1
        f.write("{}\n".format(cycles)) # number of observation times in sequence
        f.write("{0} {1} {2} {3} {4} {5}\n".format(year, month, day, hour, minute, second)) # initial time in sequence
        f.write("{0} {1}\n".format(days, seconds)) # period of obs in sequence in days and seconds
        f.write("obs_seq.in")

def create_obs_seq_definition(n_profiles):

    create_gps_profiles(n_profiles)
    create_obs_sequence = os.path.join(dart_dir(), "models/tiegcm/work/create_obs_sequence")
    os.system(create_obs_sequence + " < create_obs_seq_input.txt")


def run_create_fixed_network_seq(start_time, delta_time, cycles):
    """ create an obs_seq.in for perfect_model_obs 

         start_time - datetime object: start of experiment
         delta_time - int: cycle period for the experiment in hours
         cycles - number of cycles. Use 1 for non-subroutine callable models.

    """

    network_seq_options(start_time, delta_time, cycles)
    create_fixed_network_seq = os.path.join(dart_dir(), "models/tiegcm/work/create_fixed_network_seq")
    exit_status =  os.system(create_fixed_network_seq + " < create_network_seq_input.txt")
    if exit_status != 0:
        sys.exit()


