#!/bin/bash
# This script is used to deploy cloud instances. Run it in the deploy folder.
# -i: Initialize instances
# -r: Set region
# -k: Set SSH keys
# -d: Deploy experiment
# -sd: Shut down instances after completion

# Define SSH options for connecting to cloud instances
ssh_options_cloud='-i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60'

# Source to shut down instances
# Retrieves instance numbers from the find_insnum.py script
num=$(python3 scripts/cloud-deploy/pyscript/find_insnum.py)
num_arr=(`echo $num | tr ',' ' '`) # Convert instance numbers to an array
totalnum=${num_arr[2]} # Total number of instances
client_num=${num_arr[0]} # Number of client instances
peer_num=${num_arr[1]} # Number of peer instances

# List of regions and launch template IDs for deploying instances
region_list=("us-east-1" "eu-west-2" "ap-northeast-2" "ap-southeast-2")
region_cnt=${#region_list[@]} # Count the number of regions
region_need_add_one=$(($totalnum%$region_cnt)) # Calculate the extra instances for regions
LaunchTemplateId_list=("lt-0854465890b2cf8e9" "lt-02621b1435fdd7f28" "lt-0b0483638d66438f2" "lt-0a82b62ee3edca658")

# If initialization flag (-i) is passed
if [ "$1" = "-i" ]; then
    echo "Init"
    shift
    if [ "$1" = "-r" ]; then
        shift
        echo "Region count is $region_cnt"
        # Loop through each region to deploy instances
        for ((i=0;i<$region_cnt;i++))    
        do
            count=$(($totalnum/$region_cnt)) # Calculate number of instances per region
            if [ $region_need_add_one -gt $i ]; then
                # If extra instances are needed for the region
                count=$(($count+1))
            fi
            echo "Region is ${region_list[$i]}, count is $count"
            
            # Deploy instances in AWS using the specified region and launch template
            aws configure set region ${region_list[$i]}
            new_instance_info=$(aws ec2 run-instances \
             --launch-template LaunchTemplateId=${LaunchTemplateId_list[$i]} \
             --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Parallel-bft-instance"}]' \
             --count $count)
        done

        echo "sleep 60 seconds" # Wait for instances to initialize
        sleep 60
    else
        sleep 0.1
    fi

    public_ip=""
    private_ip=""
    # Collect public IP addresses of instances from each region
    for region in "${region_list[@]}"
    do
        aws configure set region $region
        public_ip+=$(
        aws ec2 describe-instances   \
        --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].PublicIpAddress"   \
        --output=text)
        public_ip+=" "
        
        private_ip=$public_ip # Set private IP as public IP for simplicity
    done
    
    echo $public_ip
    echo $private_ip

    # Parse IP addresses into arrays
    public_ip_arr=(`echo $public_ip | tr ',' ' '`)
    private_ip_arr=(`echo $private_ip | tr ',' ' '`)

    echo ${public_ip_arr[@]}
    echo ${private_ip_arr[@]}

    # Write instance IP addresses to a file using the write_cloud_instance.py script
    write_result=$(python3 scripts/cloud-deploy/pyscript/write_cloud_instance.py $client_num $peer_num ${public_ip_arr[@]} ${private_ip_arr[@]})
    echo $write_result

    # If the key setup flag (-k) is passed
    if [ "$1" = "-k" ]; then
        shift
        echo "Start set root login..."
        # Send SSH configuration file to each instance
        for i in "${public_ip_arr[@]}"
        do
            scp $ssh_options_cloud scripts/cloud-deploy/sshd_config ubuntu@$i:~ &
        done
        wait

        # Set up root login for each instance
        for i in "${public_ip_arr[@]}"
        do
            ssh $ssh_options_cloud ubuntu@$i "sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys;sudo cp ~/sshd_config /etc/ssh/sshd_config;sudo service sshd restart" &
        done
        wait

        echo "End set root login..."

        echo "Start set ssh key..."
        # Send SSH keys to root account on each instance
        for i in "${public_ip_arr[@]}"
        do
            scp $ssh_options_cloud 'scripts/cloud-deploy/key/id_rsa' root@$i:/root/.ssh &
            scp $ssh_options_cloud 'scripts/cloud-deploy/key/id_rsa.pub' root@$i:/root/.ssh &
            echo "$i sent ssh key done..."
        done
        wait

        # Set permissions for the SSH keys
        for i in "${public_ip_arr[@]}"
        do
            ssh $ssh_options_cloud root@$i 'chmod 600 /root/.ssh/id_rsa;chmod 600 /root/.ssh/id_rsa.pub' &
            echo "$i set ssh key permissions..."
        done
        wait

        echo "End set ssh key..."

        # Send and execute the monitor script on each instance
        for i in "${public_ip_arr[@]}"
        do
            scp $ssh_options_cloud 'scripts/cloud-deploy/monitor.sh' root@$i:/root/ &
            echo "$i set monitor script done..."
        done
        wait

        for i in "${public_ip_arr[@]}"
        do
            ssh $ssh_options_cloud root@$i 'chmod u+x /root/monitor.sh && /root/monitor.sh' &
            echo "$i started monitor script..."
        done

    else 
        sleep 0.1
    fi

else
    echo "Not init"
fi

# If shutdown flag (-sd) is passed
if [ "$1" = "-sd" ]; then
    shift
    # Terminate all instances in each region
    for i in "${region_list[@]}" ; do
        aws configure set region $i
        aws ec2 terminate-instances --instance-ids \
        $(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text) \
        --no-cli-pager
    done
fi

# If stop flag (-st) is passed
if [ "$1" = "-st" ]; then
    shift
    # Stop all instances in each region
    for i in "${region_list[@]}" ; do
        aws configure set region $i
        aws ec2 stop-instances --instance-ids \
        $(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text) \
        --no-cli-pager
    done
fi
