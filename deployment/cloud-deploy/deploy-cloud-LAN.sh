#!/bin/bash

private_key_file="/opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/key/id_rsa"
ssh_options="-i $private_key_file -o StrictHostKeyChecking=no -o ServerAliveInterval=60"


public_ip=$(cat ../cloud-instance.info | awk '{ print $2}')
public_ip_arr=(`echo $public_ip | tr ',' ' '`)

private_ip=$(cat ../cloud-instance.info | awk '{ print $3}')
private_ip_arr=(`echo $private_ip | tr ',' ' '`)

if [ "$1" = "-i" ]; then
    echo "Init..."
    shift
    declare -i server=0
    declare -i client=0
    if [ "$1" = "-n" ]; then
        shift
        client=$1
        shift
        server=$1
        shift

    fi

    if [ "$1" = "-r" ]; then
        shift
        count=$(($server+$client))
        echo $count
        aws configure set region us-east-1
        new_instance_info=$(aws ec2 run-instances \
         --launch-template LaunchTemplateId=lt-0052a4dd500c7b168 \
         --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Parallel-bft-instance"}]' \
         --count $count)

        echo "sleep 60 seconds"
        sleep 60

    else
        sleep 0.1
    fi

    if [ "$1" = "-w" ]; then
        shift
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

        write_result=$(python3 pyscript/write_cloud_instance.py $server $client ${public_ip_arr[@]} ${private_ip_arr[@]})
        echo $write_result
    fi

    public_ip=$(cat ../cloud-instance.info | awk '{ print $2}')
    public_ip_arr=(`echo $public_ip | tr ',' ' '`)

    private_ip=$(cat ../cloud-instance.info | awk '{ print $3}')
    private_ip_arr=(`echo $private_ip | tr ',' ' '`)

    echo ${public_ip_arr[@]}
    echo ${private_ip_arr[@]}

    # set root login, reference : https://www.youtube.com/watch?v=xE_oaWVhaV4
    echo "Start set root login..."
    for i in "${public_ip_arr[@]}"
    do
        # send local 'sshd_config' ssh config file to instance
        echo $i
        scp $ssh_options sshd_config ubuntu@$i:~ &
    done
    wait

    for i in "${public_ip_arr[@]}"
    do
        # set root login
        ssh $ssh_options ubuntu@$i "sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys;sudo cp ~/sshd_config /etc/ssh/sshd_config;sudo service sshd restart" &
    done
    wait

    echo "End set root login..."

    echo "Start set ssh key..."

    for i in "${public_ip_arr[@]}"
    do
        # send local 'sshd_config' ssh config file to instance
        scp $ssh_options 'key/id_rsa' root@$i:/root/.ssh &
        scp $ssh_options 'key/id_rsa.pub' root@$i:/root/.ssh &
        echo "$i sent ssh key done..."
    done
    wait

    for i in "${public_ip_arr[@]}"
    do
        ssh $ssh_options root@$i 'chmod 600 /root/.ssh/id_rsa;chmod 600 /root/.ssh/id_rsa.pub;echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3JeK5VQ3cRMLp5nHeMgIDTbbOvytBR6BDy4TK0QOqzyrGIlaSt966JkTsUfxXLw7Gc/cGRwpjVcszE3nGEvcquAEHuFOfYmt8Pat3cHuLgH4p/GPwBMbvKgrLNGrkRphFugK30IPN5yRvsUhpVzi/XJJN6iL68fRzdFzmOjQWgvmOcWPTVy7VV0GjX3XoO5XcmQU3/B52nZotypxCmDN91eJyNeVjpGgDdwT+Pc6eqr1yAx4PH/PDPOSQlrFC7x8zsuiwz+F+cLaUyVNmp5G/NSzcNoYKbxohnj11JVdVgnUj/CocG9dJjpxY4+NSCAaIRJ5kczF+9VVrzfhyId4D niu@niu-Standard-PC-i440FX-PIIX-1996 >> /root/.ssh/authorized_keys' &
        echo "$i sent ssh key done..."
    done
    wait
fi

if [ "$1" = "-s" ]; then
    shift
    public_ip=$(cat ../cloud-instance.info | awk '{ print $2}')
    public_ip_arr=(`echo $public_ip | tr ',' ' '`)

    private_ip=$(cat ../cloud-instance.info | awk '{ print $3}')
    private_ip_arr=(`echo $private_ip | tr ',' ' '`)
    for i in "${public_ip_arr[@]}"
    do
        scp $ssh_options '/opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/setup.sh' root@$i:/root
        ssh $ssh_options root@$i 'source /root/setup.sh' &
        echo "$i sent ssh key done..."
    done
    wait
fi


cd /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment

if [ "$1" = "-c" ]; then
    shift
    echo "bash config-gen-$1.sh"
    bash config-gen-$1.sh
    shift
fi

if [ "$1" = "--wan" ]; then
    shift
    
    for i in "${public_ip_arr[@]}"
    do
        ssh $ssh_options root@$i 'sudo tc qdisc del dev ens5 root netem' &
        echo "$i del netem done..."
    done
    wait

    for i in "${public_ip_arr[@]}"
    do
        ssh $ssh_options root@$i 'sudo tc qdisc add dev ens5 root netem delay 80ms 20ms' &
        echo "$i add netem done..."
    done
    wait
fi

if [ "$1" = "--run" ]; then
    shift
    bash run.sh
fi

# bash deploy-cloud-LAN.sh -i -n 4 4 -r -w -c 1 --run

if [ "$1" = "-sd" ]; then
    shift
    aws ec2 terminate-instances --instance-ids \
    $(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Parallel-bft-instance" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
    # scripts/cloud-deploy/shutdown_instances.sh
fi
