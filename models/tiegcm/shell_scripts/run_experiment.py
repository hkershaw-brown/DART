from experiment import FreeRun, PerfectModelObs, Filter

# Cheyenne
tiegcm_root = '/glade/work/hkershaw/tiegcm/tiegcm-cheyenne/tiegcm2.0/'

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

#tiegcm_root = '/Users/hkershaw/DART/Projects/TIEGCM/fake_tiegcm_root/'
#tiegcm_exe = '/Users/hkershaw/DART/Projects/TIEGCM/fake_tiegcm_root/tiegcm.exe'
#tiegcm_data = '/glade/work/hkershaw/tiegcm/tiegcm-data/tiegcm_res5.0_data'

account = 'P86850054'
intial_time = '2002-03-21 00:00:00'
end_time = '2002-03-21 02:00:00'

#ex1 = FreeRun(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, 'free_run')

#n_profiles = 10
#ex2 = PerfectModelObs(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, n_profiles)

obs_seq_dir = '/glade/scratch/hkershaw/DART/TIEGCM/Cycling/DART/models/tiegcm/shell_scripts/PMO/Observations'
ens_size = 3
ex3 = Filter(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, obs_seq_dir, ens_size)

#ex1.info()
#ex2.info()
ex3.info()


#ex1.setup("Cycle")
#ex2.setup("PMO")
ex3.setup("Assimilation")

#ex1.run()
#ex2.run()
ex3.run()
