#!/bin/bash

# List of different numbers of stragglers to test (0 to 5)
stragglerNum_list=("0" "1" "2" "3" "4" "5")

# List of strategies: regular stragglers and Byzantine stragglers
strategy_list=("straggler" "byzantinestraggler")

# Step 1: Launch cloud instances using a specific configuration for straggler experiments
cp scripts/experiment-configuration/generate-config-different-straggler.sh scripts/experiment-configuration/generate-config.sh
bash scripts/cloud-deploy/deploy-cloud-WAN.sh -i -r -k  # Initialize, set region, and set SSH keys

# Step 2: Loop through strategies and straggler numbers
for strategy in "${strategy_list[@]}"; do
    echo "============================="
    
    # Loop through each number of stragglers
    for stragglerNum in "${stragglerNum_list[@]}"; do
        echo "Node: 16, StragglerStrategy: $strategy, StragglerNumber: $stragglerNum"
        
        # Update the straggler count in the configuration file for each strategy
        sed -i '' "s/StragglerCnt=(.*)/StragglerCnt=($stragglerNum)/" scripts/experiment-configuration/generate-config-different-${strategy}.sh

        # Copy the modified configuration file to the main config file location
        echo "cp scripts/experiment-configuration/generate-config-different-${strategy}.sh scripts/experiment-configuration/generate-config.sh"
        cp scripts/experiment-configuration/generate-config-different-${strategy}.sh scripts/experiment-configuration/generate-config.sh
        
        # Deploy the experiment with the current configuration and shut down instances after completion
        bash scripts/cloud-deploy/deploy-cloud-WAN.sh -i -r -k -d -sd
    done
    echo "============================="
done

# Step 3: Ensure all instances are shut down after the experiments
bash scripts/cloud-deploy/deploy-cloud-WAN.sh -sd
