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

def create_obs_seq_definition(n_profiles):

    create_gps_profiles(n_profiles)
    create_obs_sequence = os.path.join(dart_dir(), "models/TIEGCM/work/create_obs_sequence")
    os.system(create_obs_sequence + " < create_obs_seq_input.txt")


