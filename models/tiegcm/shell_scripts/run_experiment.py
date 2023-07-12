from experiment import Experiment, Pmo, Filter


tiegcm_root = '/glade/work/hkershaw/tiegcm/tiegcm-cheyenne/tiegcm2.0/'
tiegcm_exe = '/glade/work/hkershaw/tiegcm/tiegcm-cheyenne/tiegcm.exec5.0/tiegcm.exe'
tiegcm_data = '/glade/work/hkershaw/tiegcm/tiegcm-data/tiegcm_res5.0_data'
account = 'P86850054'
resolution = 5.0 # degrees
delta_time = 1 # hour
intial_time = '2010-12-22 23:55:59'
end_time = '2010-12-23 00:56:50'


ex1 = Experiment(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time)

ex2 = Pmo(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, 'obs_seq.in')

obs_seq_dir = '/obs/seq/dir'
ens_size = 20
ex3 = Filter(tiegcm_root, tiegcm_exe, tiegcm_data, account, resolution, delta_time, intial_time, end_time, obs_seq_dir, ens_size)

#ex1.info()
#ex2.info()
#ex3.info()


#ex1.setup("Cycle")
#ex2.setup("PMO")
ex3.setup("/glade/scratch/hkershaw/DART/TIEGCM/Cycling/Assimilation")

ex3.run()
