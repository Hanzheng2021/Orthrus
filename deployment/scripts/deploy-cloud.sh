
totalnum=2
for ((c=1;c<=$totalnum;c++))
do
    new_instance_info=$(aws ec2 run-instances \
    --launch-template LaunchTemplateId=lt-0854465890b2cf8e9 \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="test"}]')
done

public_ip=$(
    aws ec2 describe-instances   \
    --query "Reservations[*].Instances[*].PublicIpAddress"   \
    --output=text)
# echo $public_ip
instances_id=$(
    aws ec2 describe-instances  \
    --filter "Name=network-interface.status,Values=in-use,in-use"   \
    --query "Reservations[*].Instances[*].InstanceId"   \
    --output=text)
# echo $instances_id

public_ip_arr=(`echo $public_ip | tr ',' ' '`)
for i in "${public_ip_arr[@]}"
do
   echo "$i"
done

instances_id_arr=(`echo $instances_id | tr ',' ' '`)
for i in "${instances_id_arr[@]}"
do
   echo "$i"
done







# for i in "${instances_id_arr[@]}"
# do
#     terminate_instance_info=$(aws ec2 terminate-instances --instance-ids $i)
# done

# Find out instance name, public ip, private ip, region
# echo into cloud-instance-info

# ./deploy.sh remote ../cloud-instance-info new scripts/experiment-configuration/generate-config.sh
