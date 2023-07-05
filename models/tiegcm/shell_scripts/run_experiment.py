from experiment import Experiment, Pmo, Filter


ex1 = Experiment('/root/dir', '/data/dir', '23423', 5.0, 1, 0)

ex2 = Pmo('/root/dir', '/data/dir', '23423', 5.0, 1, 0, 'obs_seq.in')

ex3 = Filter('/root/dir', '/data/dir', '23423', 5.0, 1, 0, 'obs_seq.out', 80)

ex1.info()
ex2.info()
ex3.info()


ex1.setup("out.1.pbs")
ex2.setup("out.2.pbs")
ex3.setup("out.3.pbs")
