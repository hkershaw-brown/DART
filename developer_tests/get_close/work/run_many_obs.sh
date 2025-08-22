#!/bin/bash
# Script to run test_get_close with different my_num_state values

# List of my_num_state values to test
#state_list=(10 100 1000 10000 100000 1000000 10000000 20000000 40000000 80000000 100000000 200000000 400000000 800000000 1000000000)
#state_list=(10 100 1000 10000 100000 1000000 10000000 20000000 40000000 80000000)
state_list=(10 100 1000 10000 100000 1000000 10000000)
num_obs=1000

# Check for executable argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <executable>" >&2
    exit 1
fi
exe=$1

for state in "${state_list[@]}"; do
    echo "Running $exe with my_num_state=$state"
    #                num_state elements, num obs
    ./$exe $state $num_obs 2>> $exe.out
    echo "---"
done
