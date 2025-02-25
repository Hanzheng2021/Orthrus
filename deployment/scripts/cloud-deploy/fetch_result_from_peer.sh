#!/bin/bash

# Fetch the list of peer nodes from the find_peer.py script
peer_list=($(python3 scripts/cloud-deploy/pyscript/find_peer.py))

# Loop through each peer node in the peer_list
for peer in "${peer_list[@]}"
do
    # Print the peer's IP or hostname
    echo $peer
    
    # Securely copy the experiment output from the peer node to the local machine
    scp -r -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@$peer:/root/experiment-output . &
    
    # Securely copy the top.log file from the peer node to a local file named after the peer
    scp -r -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@$peer:/root/top.log ./$peer.log &
    
    # Optionally, this commented-out line would run a command on the peer node to update a Go package (disabled in this version)
    # ssh -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@$peer "go get -u github.com/orcaman/concurrent-map" &
done

# Wait for all background tasks (file transfers) to finish before proceeding
wait

# Indicate that the fetching of files is complete
echo "Fetch Over."
