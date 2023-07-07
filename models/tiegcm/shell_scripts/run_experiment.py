from experiment import Experiment, Pmo, Filter


tiegcm_root = '/Users/hkershaw/DART/Projects/TIEGCM/fake_tiegcm_root/'
tiegcm_data = '/data/dir'
account = '23423'
resolution = 2.5 # degrees
delta_time = 1 # hour
intial_time = '2010-12-22 23:55:59'
end_time = '2010-12-25 23:55:59'


ex1 = Experiment(tiegcm_root, tiegcm_data, account, resolution, delta_time, intial_time, end_time)

ex2 = Pmo(tiegcm_root, tiegcm_data, account, resolution, delta_time, intial_time, end_time, 'obs_seq.in')

obs_seq_dir = '/obs/seq/dir'
ens_size = 80
ex3 = Filter(tiegcm_root, tiegcm_data, account, resolution, delta_time, intial_time, end_time, obs_seq_dir, 80)

#ex1.info()
#ex2.info()
#ex3.info()


#ex1.setup("Cycle")
#ex2.setup("PMO")
ex3.setup("Assimilation")

ex3.run()
