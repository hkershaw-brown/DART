from experiment import FreeRun, PerfectModelObs, Filter

# Cheyenne
tiegcm_root = '/glade/work/hkershaw/tiegcm/tiegcm-cheyenne/tiegcm2.0/'
account = 'P86850054'

# 5.0 executable and data
tiegcm_exe = '/glade/work/hkershaw/tiegcm/tiegcm-cheyenne/tiegcm.exec5.0/tiegcm.exe'
tiegcm_data = '/glade/work/hkershaw/tiegcm/tiegcm-data/tiegcm_res5.0_data'
resolution = 5.0 # degrees
delta_time = 1 # hours (decimal 0.5 for 30 minutes)

# 2.5 degree is a different executable and data
#tiegcm_exe = '/glade/work/hkershaw/tiegcm/tiegcm-cheyenne/tiegcm.exec2.5/tiegcm.exe'
#tiegcm_data = '/glade/work/hkershaw/tiegcm/tiegcm-data/tiegcm_res2.5_data'
#resolution = 2.5 # degrees
#delta_time = 0.5 # hours (decimal 0.5 for 30 minutes)

# Experiment start and end time
#  Note I had to line this up with the available SOURCE data for tiegcm
intial_time = '2002-03-21 00:00:00'
end_time = '2002-03-21 02:00:00'


#----------------
# Cycle tiegcm
#   stop and restart tiegcm 
#   no dart, just to test you can cycle the model without problems

#ex1 = FreeRun(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, 'free_run')
#ex1.info()
#ex1.setup("Cycle")
#ex1.run()

#----------------

#----------------
# Create synthetic data with perfect model obs 
#   create n profiles evenly spaced on a sphere using golden spiral algorithm
#   create a set_def.out from these observation locations using create_obs_sequence (note error_var function)
#   create an obs_seq.in file for each time window using run_create_fixed_network_seq
#   runs perfect_model_obs for each time window to get obs_seq.out-YYMMDD-HH-MM 

#n_profiles = 10
#ex2 = PerfectModelObs(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, n_profiles)
#ex2.info()
#ex2.setup("PMO")
#ex2.run()

#----------------

#----------------
# Filter 
#  Runs a filter experiment
#  cycles:
#    run an ensemble of tiegcm 
#    run filter and update the tiegcm states
#
#  Expecting observation sequences obs_seq.out-YYMMDD-HH-MM 

obs_seq_dir = '/glade/scratch/hkershaw/DART/TIEGCM/Cycling/DART/models/tiegcm/shell_scripts/PMO/Observations'
ens_size = 3
ex3 = Filter(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, obs_seq_dir, ens_size)
ex3.info()
ex3.setup("Assimilation")
ex3.run()
