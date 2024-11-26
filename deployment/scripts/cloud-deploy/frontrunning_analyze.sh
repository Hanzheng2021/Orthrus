#!/bin/bash

if [ "$1" = "--dir" ]; then
    shift
    echo "Start analyzing frontrunning" > scripts/cloud-deploy/frontrunning_analyze_result.log
    for folder in `ls $1`
    do
        echo "-------------$folder-------------" >> scripts/cloud-deploy/frontrunning_analyze_result.log
        echo "python scripts/cloud-deploy/Fairness_data_process/latency_each_stage.py $1/$folder 5 >> scripts/cloud-deploy/frontrunning_analyze_result.log"
        python scripts/cloud-deploy/Fairness_data_process/latency_each_stage.py "$1/$folder" 5 >> scripts/cloud-deploy/frontrunning_analyze_result.log
    done
fi

# /opt/gopath/src/github.com/anonymous/orthrus/deployment/deployment-data-new/ISS_frontrunning
