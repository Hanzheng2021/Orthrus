#!/bin/bash
rm -rf ./experiment-output

peer_list=($(python3 scripts/cloud-deploy/pyscript/find_peer.py))
mkdir -p ./experiment-output/peer

for peer in "${peer_list[@]}"
do
    echo $peer
    scp -r -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@$peer:/root/experiment-output ./experiment-output/peer &
done
wait

client_list=($(python3 scripts/cloud-deploy/pyscript/find_client.py))
mkdir -p ./experiment-output/client

for client in "${client_list[@]}"
do
    echo $client
    scp -r -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@$client:/root/experiment-output ./experiment-output/client/ &
done
wait

echo "Fetch Over."