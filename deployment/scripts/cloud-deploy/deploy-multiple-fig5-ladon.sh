#!/bin/bash

# Define two network modes: WAN and LAN
network_mode=("WAN" "LAN")

# Define a list of possible straggler numbers (0 and 1)
stragglerNum_list=("0" "1")

# Define a list of node counts to test (8, 16, 32, 64, 128)
nodeNum_list=("8" "16" "32" "64" "128")

# Iterate over the network modes
for networkMode in "${network_mode[@]}"; do
    # Iterate over the straggler numbers
    for stragglerNum in "${stragglerNum_list[@]}"; do
        echo "============================="
        # Iterate over the node numbers
        for nodeNum in "${nodeNum_list[@]}"; do
            echo "Node: $nodeNum, Straggler: $stragglerNum, Network: $networkMode"
            
            # Copy the appropriate configuration file for the current experiment setup
            cp scripts/experiment-configuration/generate-config-${nodeNum}peer-${stragglerNum}straggler-$networkMode.sh scripts/experiment-configuration/generate-config.sh
            
            # Run the deployment script for the selected network mode
            bash scripts/cloud-deploy/deploy-cloud-$networkMode.sh -i -r -k -d -sd
        done
        echo "============================="
    done
done
