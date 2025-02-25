#!/bin/bash
# in deploy folder run.
ssh_options_cloud='-i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60'

# source shutdown_instances.sh
num=$(python3 scripts/cloud-deploy/pyscript/find_insnum.py)
num_arr=(`echo $num | tr ',' ' '`)
totalnum=${num_arr[2]}
client_num=${num_arr[0]}
peer_num=${num_arr[1]}
# echo $totalnum
# echo $client_num
# echo $peer_num

# "us-east-2" "lt-0e560d976efbab859"
# "ap-southeast-2" "lt-0a82b62ee3edca658"
region_list=("us-east-1" "eu-west-2" "ap-northeast-2" "ap-southeast-2")
region_cnt=${#region_list[@]}
region_need_add_one=$(($totalnum%$region_cnt))
LaunchTemplateId_list=("lt-0854465890b2cf8e9" "lt-02621b1435fdd7f28" "lt-0b0483638d66438f2" "lt-0a82b62ee3edca658")

if [ "$1" = "-i" ]; then
    echo "Init"
    shift
    if [ "$1" = "-r" ]; then
        shift
        echo "Region count is $region_cnt"
        # echo "region_need_add_one is $region_need_add_one"
        for ((i=0;i<$region_cnt;i++))    
        do
            count=$(($totalnum/$region_cnt))
            if [ $region_need_add_one -gt $i ]; then
                # echo "region_need_add_one is $region_need_add_one, i is $i"
                # echo "add one"
                count=$(($count+1))
            fi
            echo "Region is ${region_list[$i]}, count is $count"
            
            aws configure set region ${region_list[$i]}
            new_instance_info=$(aws ec2 run-instances \
             --launch-template LaunchTemplateId=${LaunchTemplateId_list[$i]} \
             --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Parallel-bft-instance"}]' \
             --count $count)
        done

        echo "sleep 60 seconds"
        sleep 60
    else
        sleep 0.1
    fi

    public_ip=""
    private_ip=""
    for region in "${region_list[@]}"
    do
        aws configure set region $region
        public_ip+=$(
        aws ec2 describe-instances   \
        --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].PublicIpAddress"   \
        --output=text)
        public_ip+=" "
        
        # private_ip+=$(
        # aws ec2 describe-instances   \
        # --filter "Name=network-interface.status,Values=available,in-use"   \
        # --query "Reservations[*].Instances[*].PrivateIpAddress"   \
        # --output=text)
        # private_ip+=" "
        private_ip=$public_ip
    done
    
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

        # for i in "${public_ip_arr[@]}"
        # do
        #     ssh $ssh_options_cloud root@$i 'sudo tc qdisc add dev ens5 root netem delay 90ms 20ms' &
        #     echo 'End setting delay...'
        # done
        # wait

        for i in "${public_ip_arr[@]}"
        do
            # send local 'sshd_config' ssh config file to instance
            scp $ssh_options_cloud 'scripts/cloud-deploy/monitor.sh' root@$i:/root/ &
            echo "$i set monitor done..."
        done
        wait

        for i in "${public_ip_arr[@]}"
        do
            # send local 'sshd_config' ssh config file to instance
            ssh $ssh_options_cloud root@$i 'chmod u+x /root/monitor.sh && /root/monitor.sh' &
            echo "$i set monitor done..."
        done

    else 
        sleep 0.1
    fi

else
    echo "Not init"
fi

# bandwidth_cnt=0
# bandwidth=1000mbit
# if [ "$1" = "-b" ]; then
#     shift
#     # echo 'in -b'
#     bandwidth_cnt=$1
#     shift
#     bandwidth=$1mbit
# fi
# echo $bandwidth_cnt  
# echo $bandwidth 

# echo 'setting bandwidth'
# echo $public_ip_arr
# for ((c=0;c<$peer_num;c++))
# do
#     ssh $ssh_options_cloud root@${public_ip_arr[c]} 'tc qdisc del dev ens5 root'
#     ssh $ssh_options_cloud root@${public_ip_arr[c]} 'tc qdisc add dev ens5 root tbf rate 1000mbit burst 320kbit latency 100ms'
#     echo ${public_ip_arr[c]} '1000mbit'
# done

# for ((c=1+$client_num;c<1+$client_num+$bandwidth_cnt;c++))    
# do
#     ssh $ssh_options_cloud root@${public_ip_arr[c]} 'tc qdisc del dev ens5 root'
#     ssh $ssh_options_cloud root@${public_ip_arr[c]} "tc qdisc add dev ens5 root tbf rate $bandwidth burst 320kbit latency 100ms"
#     echo ${public_ip_arr[c]} $bandwidth 
#     # Limiting the Egress Traffic
# done



if [ "$1" = "-d" ]; then
    shift
    echo "Start deployment..."
    ./deploy.sh remote scripts/cloud-deploy/cloud-instance-info new scripts/experiment-configuration/generate-config.sh
    echo "End deployment..."
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
    for i in "${region_list[@]}" ; do
        aws configure set region $i
        aws ec2 terminate-instances --instance-ids \
        $(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)
        # scripts/cloud-deploy/shutdown_instances.sh
    done
fi

if [ "$1" = "-st" ]; then
    shift
    for i in "${region_list[@]}" ; do
        aws configure set region $i
        aws ec2 stop-instances --instance-ids \
        $(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)
        # scripts/cloud-deploy/shutdown_instances.sh
    done
fi
# scp -r -i scripts/cloud-deploy/key/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 root@35.180.54.180:/root/experiment-output .
