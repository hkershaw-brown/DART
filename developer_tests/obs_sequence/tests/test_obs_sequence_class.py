from subprocess import check_output
import os

class TestObsSeqTool():

    def test_FO_values_present(self):
        os.system("../work/obs_sequence_tool") 
        assert int(check_output(["wc", "-l", "obs_seq.xx"]).split()[0]) == 21
    
    def test_x(self):
        assert True
