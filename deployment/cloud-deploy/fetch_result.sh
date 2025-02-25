#!/bin/bash -e

private_key_file="/opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/key/id_rsa"
ssh_options="-i $private_key_file -o StrictHostKeyChecking=no -o ServerAliveInterval=60"

servers=$(grep server ../cloud-instance.info | awk '{ print $2}')
serversName=$(grep server ../cloud-instance.info | awk '{ print $1}')
clients=$(grep client ../cloud-instance.info | awk '{ print $2}')

public_ip_arr=(`echo $public_ip | tr ',' ' '`)

declare -i cnt=1

if [ -d "experiment-output" ]; then
  rm -rf experiment-output
fi
mkdir -p experiment-output/log

for i in $servers
do
    echo $i $cnt
    scp $ssh_options root@$i:/opt/gopath/src/github.com/Hanzheng2021/orthrus/server/server.out ./experiment-output/log/server-$cnt.log &
    cnt+=1
done
wait

cnt=1
for i in $clients
do
    echo $i $cnt
    scp $ssh_options root@$i:/opt/gopath/src/github.com/Hanzheng2021/orthrus/client/client.log ./experiment-output/log/client-$cnt.log &
    cnt+=1
done
wait
