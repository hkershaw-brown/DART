from experiment import Experiment, Pmo, Filter


ex1 = Experiment('/Users/hkershaw/DART/Projects/TIEGCM/fake_tiegcm_root/', '/data/dir', '23423', 2.5, 1, 0)

ex2 = Pmo('/Users/hkershaw/DART/Projects/TIEGCM/fake_tiegcm_root/', '/data/dir', '23423', 5.0, 1, 0, 'obs_seq.in')

ex3 = Filter('/Users/hkershaw/DART/Projects/TIEGCM/fake_tiegcm_root/', '/data/dir', '23423', 5.0, 1, 0, 'obs_seq.out', 80)

#ex1.info()
#ex2.info()
#ex3.info()


#ex1.setup("Cycle")
#ex2.setup("PMO")
ex3.setup("Assimilation")

#ex1.run(4)
