#!/bin/bash
# This script should be run in the deploy folder. It handles instance initialization, configuration, key setup, and deployment.
# -i: Initialize instances
# -r: Set region
# -k: Set SSH keys
# -d: Deploy experiment
# -sd: Shut down instances after completion

# SSH options for secure connection to cloud instances
ssh_options_cloud='-i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60'

# Fetch instance details (number of instances)
num=$(python3 scripts/cloud-deploy/pyscript/find_insnum.py)
num_arr=(`echo $num | tr ',' ' '`)  # Convert instance data into array
totalnum=${num_arr[2]}  # Total number of instances
client_num=${num_arr[0]}  # Number of client instances
peer_num=${num_arr[1]}  # Number of peer instances

# Check for initialization (-i) flag
if [ "$1" = "-i" ]; then
    echo "Init"
    shift
    # If the region flag (-r) is passed
    if [ "$1" = "-r" ]; then
        shift
        aws configure set region us-east-1  # Set AWS region
        new_instance_info=$(aws ec2 run-instances \
         --launch-template LaunchTemplateId=lt-0854465890b2cf8e9 \
         --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Parallel-bft-instance"}]' \
         --count $totalnum)  # Launch instances

        echo "sleep 60 seconds"  # Wait for instances to start
        sleep 60
    fi

    # Get the public and private IPs of the running instances
    public_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress" --output=text)

    private_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" --output=text)

    echo $public_ip
    echo $private_ip

    # Convert IPs into arrays for further use
    public_ip_arr=(`echo $public_ip | tr ',' ' '`)
    private_ip_arr=(`echo $private_ip | tr ',' ' '`)

    echo ${public_ip_arr[@]}
    echo ${private_ip_arr[@]}

    # Write the cloud instance information into a file
    write_result=$(python3 scripts/cloud-deploy/pyscript/write_cloud_instance.py $client_num $peer_num ${public_ip_arr[@]} ${private_ip_arr[@]})
    echo $write_result

    # If key setup (-k) flag is passed
    if [ "$1" = "-k" ]; then
        shift
        echo "Start setting root login..."
        # Send SSH configuration to each instance to enable root login
        for i in "${public_ip_arr[@]}"
        do
            scp $ssh_options_cloud scripts/cloud-deploy/sshd_config ubuntu@$i:~ &
        done
        wait

        # Configure root login on each instance
        for i in "${public_ip_arr[@]}"
        do
            ssh $ssh_options_cloud ubuntu@$i "sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys;sudo cp ~/sshd_config /etc/ssh/sshd_config;sudo service sshd restart" &
        done
        wait

        echo "Root login setup complete."

        echo "Start setting SSH keys..."
        # Send SSH keys to each instance
        for i in "${public_ip_arr[@]}"
        do
            scp $ssh_options_cloud 'scripts/cloud-deploy/key/id_rsa' root@$i:/root/.ssh &
            scp $ssh_options_cloud 'scripts/cloud-deploy/key/id_rsa.pub' root@$i:/root/.ssh &
            echo "$i SSH key sent."
        done
        wait

        # Set permissions for the SSH keys
        for i in "${public_ip_arr[@]}"
        do
            ssh $ssh_options_cloud root@$i 'chmod 600 /root/.ssh/id_rsa;chmod 600 /root/.ssh/id_rsa.pub;echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3JeK5VQ3cRMLp5nHeMgIDTbbOvytBR6BDy4TK0QOqzyrGIlaSt966JkTsUfxXLw7Gc/cGRwpjVcszE3nGEvcquAEHuFOfYmt8Pat3cHuLgH4p/GPwBMbvKgrLNGrkRphFugK30IPN5yRvsUhpVzi/XJJN6iL68fRzdFzmOjQWgvmOcWPTVy7VV0GjX3XoO5XcmQU3/B52nZotypxCmDN91eJyNeVjpGgDdwT+Pc6eqr1yAx4PH/PDPOSQlrFC7x8zsuiwz+F+cLaUyVNmp5G/NSzcNoYKbxohnj11JVdVgnUj/CocG9dJjpxY4+NSCAaIRJ5kczF+9VVrzfhyId4D niu@niu-Standard-PC-i440FX-PIIX-1996 >> /root/.ssh/authorized_keys' &
            echo "$i SSH key setup complete."
        done
        wait

        echo "SSH key setup finished."
    fi

    # Remove any existing network delay setup
    for i in "${public_ip_arr[@]}"
    do
        ssh $ssh_options_cloud root@$i 'tc qdisc del dev ens5 root' &
        echo 'Network delay removed.'
    done
    wait

    # Add network delay to simulate real-world latency
    for i in "${public_ip_arr[@]}"
    do
        ssh $ssh_options_cloud root@$i 'sudo tc qdisc add dev ens5 root netem delay 50ms 30ms' &
        echo 'Network delay set.'
    done
    wait

else
    echo "Not init"  # No initialization flag passed
fi

# If the deployment flag (-d) is passed
if [ "$1" = "-d" ]; then
    shift
    echo "Start deployment..."
    # Execute the deployment script with the specified config
    ./deploy.sh remote scripts/cloud-deploy/cloud-instance-info new scripts/experiment-configuration/generate-config.sh
    echo "Deployment completed."
fi

# If shutdown flag (-sd) is passed, terminate instances
if [ "$1" = "-sd" ]; then
    shift
    aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text) --no-cli-pager
fi

# If stop flag (-st) is passed, stop instances
if [ "$1" = "-st" ]; then
    shift
    aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text) --no-cli-pager
fi
