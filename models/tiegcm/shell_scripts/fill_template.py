#!/usr/bin/python3

import argparse

def parse_arguments():

    parser = argparse.ArgumentParser()
    parser.add_argument('--res', type=str, required=True, choices=['2.5', '5.0'])
    parser.add_argument('--account', type=str, required=True)
    parser.add_argument('--ens_size', type=str, required=True)
    parser.add_argument('--tgcmdata', type=str, required=True)
    parser.add_argument('--tiegcm_root', type=str, required=True)

    args = parser.parse_args()

    return args

def create_tiegcm_run_script(res, account, ens_size, tiegcm_root, tgcmdata):

    readFile = open("run-tiegcm.pbs.template", "r")

    data = readFile.read()
    
    data = data.replace("{res}", res)
    data = data.replace("{account}", account)
    data = data.replace("{ens_size}", ens_size)
    data = data.replace("{tgcmdata}", tgcmdata)
    data = data.replace("{tiegcm_root}", tiegcm_root)
    
    if res == 2.5:
        nodes = "select=1:ncpus=32:mpiprocs=32:ompthreads=1"
    else:
        nodes = "select=1:ncpus=16:mpiprocs=16:ompthreads=1"
    
    data = data.replace("{nodes}", nodes)
    
    writeFile = open("run-tigcm.pbs.out", "w")
    writeFile.write(data)

if __name__ == "__main__":

    args = parse_arguments()
    
    create_tiegcm_run_script(args.res, args.account, args.ens_size, args.tgcmdata, args.tiegcm_root)

