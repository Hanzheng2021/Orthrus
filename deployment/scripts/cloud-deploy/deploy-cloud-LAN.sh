#!/bin/bash
# in deploy folder run.
ssh_options_cloud='-i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60'

# source shutdown_instances.sh
num=$(python3 scripts/cloud-deploy/pyscript/find_insnum.py)
num_arr=(`echo $num | tr ',' ' '`)
totalnum=${num_arr[2]}
client_num=${num_arr[0]}
peer_num=${num_arr[1]}



if [ "$1" = "-i" ]; then
    echo "Init"
    shift
    if [ "$1" = "-r" ]; then
        shift
        aws configure set region us-east-1
        new_instance_info=$(aws ec2 run-instances \
         --launch-template LaunchTemplateId=lt-0854465890b2cf8e9 \
         --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Parallel-bft-instance"}]' \
         --count $totalnum)

        echo "sleep 60 seconds"
        sleep 60
    fi

    public_ip=$(
    aws ec2 describe-instances   \
    --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress"   \
    --output=text)
    
    private_ip=$(
    aws ec2 describe-instances   \
    --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress"   \
    --output=text)

    echo $public_ip
    echo $private_ip

    # show info of instance
    public_ip_arr=(`echo $public_ip | tr ',' ' '`)
    private_ip_arr=(`echo $private_ip | tr ',' ' '`)

    echo ${public_ip_arr[@]}
    echo ${private_ip_arr[@]}

    write_result=$(python3 scripts/cloud-deploy/pyscript/write_cloud_instance.py $client_num $peer_num ${public_ip_arr[@]} ${private_ip_arr[@]})
    echo $write_result


    if [ "$1" = "-k" ]; then
        shift
        # set root login, reference : https://www.youtube.com/watch?v=xE_oaWVhaV4
        echo "Start set root login..."
        for i in "${public_ip_arr[@]}"
        do
            # send local 'sshd_config' ssh config file to instance
            scp $ssh_options_cloud scripts/cloud-deploy/sshd_config ubuntu@$i:~ &
        done
        wait

        for i in "${public_ip_arr[@]}"
        do
            # set root login
            ssh $ssh_options_cloud ubuntu@$i "sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys;sudo cp ~/sshd_config /etc/ssh/sshd_config;sudo service sshd restart" &
        done
        wait

        echo "End set root login..."

        echo "Start set ssh key..."
        for i in "${public_ip_arr[@]}"
        do
            # send local 'sshd_config' ssh config file to instance
            scp $ssh_options_cloud 'scripts/cloud-deploy/key/id_rsa' root@$i:/root/.ssh &
            scp $ssh_options_cloud 'scripts/cloud-deploy/key/id_rsa.pub' root@$i:/root/.ssh &
            echo "$i sent ssh key done..."
        done
        wait

        for i in "${public_ip_arr[@]}"
        do
            ssh $ssh_options_cloud root@$i 'chmod 600 /root/.ssh/id_rsa;chmod 600 /root/.ssh/id_rsa.pub;echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3JeK5VQ3cRMLp5nHeMgIDTbbOvytBR6BDy4TK0QOqzyrGIlaSt966JkTsUfxXLw7Gc/cGRwpjVcszE3nGEvcquAEHuFOfYmt8Pat3cHuLgH4p/GPwBMbvKgrLNGrkRphFugK30IPN5yRvsUhpVzi/XJJN6iL68fRzdFzmOjQWgvmOcWPTVy7VV0GjX3XoO5XcmQU3/B52nZotypxCmDN91eJyNeVjpGgDdwT+Pc6eqr1yAx4PH/PDPOSQlrFC7x8zsuiwz+F+cLaUyVNmp5G/NSzcNoYKbxohnj11JVdVgnUj/CocG9dJjpxY4+NSCAaIRJ5kczF+9VVrzfhyId4D niu@niu-Standard-PC-i440FX-PIIX-1996 >> /root/.ssh/authorized_keys' &
            echo "$i sent ssh key done..."
        done
        wait

        echo "End set ssh key..."
    fi

    # for i in "${public_ip_arr[@]}"
    # do
    #     ssh $ssh_options_cloud root@$i 'tc qdisc del dev ens5 root' &
    #     echo 'End setting delay...'
    # done
    # wait

else
    echo "Not init"
fi

# peer_list=($(python3 scripts/cloud-deploy/pyscript/find_peer.py))
# bandwidth_cnt=0
# bandwidth=1000mbit
# bandwidth_low=1000mbit
# if [ "$1" = "-b" ]; then
#     shift
#     # echo 'in -b'
#     bandwidth_cnt=$1
#     shift
#     bandwidth_low=$1mbit
#     shift
# fi
# echo $bandwidth_cnt  
# echo $bandwidth_low 

# echo 'setting bandwidth'
# for peer in "${peer_list[@]}"
# do
#     ssh $ssh_options_cloud root@$peer "tc qdisc del dev ens5 root; tc qdisc add dev ens5 root tbf rate $bandwidth burst 320kbit latency 100ms" &
#     echo "$peer $bandwidth"
# done
# wait

# for ((c=0;c<$bandwidth_cnt;c++))
# do
#     ssh $ssh_options_cloud root@${peer_list[c]} "tc qdisc del dev ens5 root; tc qdisc add dev ens5 root tbf rate $bandwidth_low burst 320kbit latency 100ms" &
#     echo "${peer_list[c]} $bandwidth_low"
#     # Limiting the Egress Traffic
# done
# wait


if [ "$1" = "-d" ]; then
    shift
    echo "Start deployment..."
    ./deploy.sh remote scripts/cloud-deploy/cloud-instance-info new scripts/experiment-configuration/generate-config.sh
    echo "End deployment..."

    for i in "${public_ip_arr[@]}"
    do
        ssh $ssh_options_cloud root@$i 'tc qdisc del dev ens5 root' &
        echo 'End setting delay...'
    done
    wait

fi




# for ((c=0;c<$peer_num;c++)) do
#     ssh $ssh_options_cloud root@${public_ip_arr[c+bandwidth_cnt]} 'tc qdisc del dev ens5 root'
# done
# echo 'unsetting bandwidth'

# rm -rf scripts/cloud-deploy/experiment-output
# mkdir -p scripts/cloud-deploy/experiment-output

# echo "fetch result from client and peer"
# for i in "${public_ip_arr[@]:1:totalnum}"
# do
#     scp $ssh_options_cloud root@$i:/root/experiment-output-* scripts/cloud-deploy/experiment-output
#     echo "$i fetch experiment done..."
# done

# python3 scripts/cloud-deploy/Fairness_process/latency_each_stage.py >> scripts/cloud-deploy/Fairness_process/data_analyze.log





if [ "$1" = "-sd" ]; then
    shift
    aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text)
fi

if [ "$1" = "-st" ]; then
    shift
    aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text)
fi
# scp -r -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@35.180.54.180:/root/experiment-output .