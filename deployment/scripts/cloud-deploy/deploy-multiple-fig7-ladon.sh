#!/bin/bash

# Step 1: Copy the crash faults configuration file to the main config file location
cp scripts/experiment-configuration/generate-crash-faults.sh scripts/experiment-configuration/generate-config.sh
echo "cp scripts/experiment-configuration/generate-crash-faults.sh scripts/experiment-configuration/generate-config.sh"  # Log the copy command

# Step 2: Start the deployment process
# -i: Initialize instances
# -r: Set region
# -k: Set SSH keys
# -d: Deploy experiment
# -sd: Shut down instances after completion
bash scripts/cloud-deploy/deploy-cloud-WAN.sh -i -r -k -d -sd
