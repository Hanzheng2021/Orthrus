#!/bin/bash -e

getIP() {
	grep -w $1 cloud-instance.info | awk '{ print $2}'
}

servers=$(grep server cloud-instance.info | awk '{ print $1}')
clients=$(grep client cloud-instance.info | awk '{ print $1}')
C=$(grep -c client cloud-instance.info)
S=$(grep -c server cloud-instance.info)

. vars.sh

if [ "$1" = "--copy-only" ] || [ "$1" = "-c" ]; then
  copy_only=true
  shift
else
  copy_only=false
fi

if [ "$copy_only" = "false" ]; then
    for p in $clients; do
        pub=$(getIP $p)
        scp $ssh_options run-client.sh $ssh_user@$pub: &
    done
    wait

    for p in $clients; do
        pub=$(getIP $p)
        ssh $ssh_user@$pub $ssh_options "source run-client.sh" &
    done
    # wait

    for p in $servers; do
        pub=$(getIP $p)
        scp $ssh_options run-server.sh $ssh_user@$pub: &
        scp $ssh_options stop.sh $ssh_user@$pub: &
    done
    wait

    for p in $servers; do
        pub=$(getIP $p)
        ssh $ssh_user@$pub $ssh_options "source stop.sh  > /dev/null 2>&1 & " &
    done
    wait

    for p in $servers; do
        pub=$(getIP $p)
        ssh $ssh_user@$pub $ssh_options "source run-server.sh  > /dev/null 2>&1 & " &
    done
    wait

    echo "new status ..."

    ready="0"
    while [ $ready -lt $C ]; do
        for p in $clients; do
            pub=$(getIP $p)
            scp $ssh_options $ssh_user@$pub:/opt/gopath/src/github.com/Hanzheng2021/orthrus/client/STATUS.sh .
            . STATUS.sh
            echo $p $status
            if [ "$status" = "FINISHED" ]; then
                ready=$[$ready+1]
            fi
        done
        if [ $ready -lt $C ]; then
            ready="0"
        fi
        echo "Experiment still running"
        sleep 1
    done

    rm STATUS.sh

    echo "All clients finished"
fi

mkdir -p experiment-output

for p in $servers; do
    pub=$(getIP $p)
    ssh $ssh_user@$pub $ssh_options "source stop.sh" &
done

for p in $servers; do
    pub=$(getIP $p)
    scp $ssh_options $ssh_user@$pub:/opt/gopath/src/github.com/Hanzheng2021/orthrus/server/server.out experiment-output/$p.out &
done
wait

echo "All servers stopped, server log files are copied in deployment/experiment-output/"

for p in $clients; do
    pub=$(getIP $p)
    # if ssh $ssh_user@$pub $ssh_options stat /opt/gopath/src/github.com/Hanzheng2021/orthrus/client/client.out \> /dev/null 2\>\&1; then
    scp $ssh_options $ssh_user@$pub:/opt/gopath/src/github.com/Hanzheng2021/orthrus/client/client.out experiment-output/$p.out &
    # else
        # echo "Client log file does not exist. Client $p did not start."
    # fi
    clientNum="${p:7}"
    clientNum=$((clientNum-1))
    traceFileSufix=$(printf %03d $clientNum)
    # if ssh $ssh_user@$pub $ssh_options stat /opt/gopath/src/github.com/Hanzheng2021/orthrus/client/client-$traceFileSufix.trc \> /dev/null 2\>\&1; then
    scp -r $ssh_options $ssh_user@$pub:/opt/gopath/src/github.com/Hanzheng2021/orthrus/client/client-$traceFileSufix.trc experiment-output &
    # else
        # echo "Client trace file does not exist. Client $p did not finish gracefully."
    # fi
done
wait

echo "All clients stopped, client trace and log files are copied in deployment/experiment-output/"

python /opt/gopath/src/github.com/Hanzheng2021/orthrus/tools/perf-eval.py $S $C /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/experiment-output/server*.out /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/experiment-output/client*.trc
# python /opt/gopath/src/github.com/Hanzheng2021/orthrus/tools/perf-eval.py 16 8 /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/cloud-deploy/experiment-output16peer-1straggler-delay4s/server*.out /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/cloud-deploy/experiment-output16peer-1straggler-delay4s/client*.trc
echo "python /opt/gopath/src/github.com/Hanzheng2021/orthrus/tools/perf-eval.py $S $C /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/experiment-output/server*.out /opt/gopath/src/github.com/Hanzheng2021/orthrus/deployment/experiment-output/client*.trc"
