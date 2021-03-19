from subprocess import check_output

def test_FO_values_present():
    assert int(check_output(["wc", "-l", "obs_seq.xx"]).split()[0]) == 64
    

def test_x():
    assert True
