# Deploying DQBFT

This document first describes the scripts that facilitate a deployment on the AWS cloud.

Next, it describes how to run experiments:
* on AWS cloud
* locally

Finally, it describes how to export plots from the experimental results.

**All the following commands should be run with `ladon/deployment` as working directory.**
## AWS cloud setup

Scripts to install and setup AWS Cloud CLI can be found [here](https://docs.aws.amazon.com/streams/latest/dev/setup-awscli.html): 

Installs the AWS Cloud CLI tools and set up the AWS Cloud CLI's access key.<br/>
Needs to be run only once on a machine (controller).<br/>


## Automated ISS Deployment
In a nutshell, to run a set of experiments one has to perform 2 steps:
1. Edit the configuration generation script to describe all desired experiments.
2. Run the deployment script `deploy-clould-***.sh` with the correct arguments

## Deployment

Each experiment will create a new deployment directory under `deployment-data` containing the configuration for one or more experiments and runs the experiments on AWS cloud.<br/>
In detail:
* It sets up a new deployment of virtual machines on AWS cloud, or uses an existing AWS cloud deployment, or builds the source code locally (see details below).
* For an AWS cloud deployment:
    * The deployment consists of a master machine and a set of peer (protocol nodes) and client machines.
    * The number, locations and system requirements of the virtual machines is defined in a configuration generation script which is provided as an argument.
* It runs a set of experiments according to the configuration generation script.
* It fetches to the master logs of the peers and clients per experiment.
* It analyzes on the master the the experiments based on the logs.
* It compresses the raw logs and fetches to the local machine the compressed logs and the results of the performance analysis per experiment.
* It summarized the results in a `summary.csv` file.

The deployment directory is named after the deployment type: `local-xxxx` or `remote-xxxx`, where `xxxx` is a monotonically increasing deployment number automatically assigned to the deployment based on existing contents of the `deployment-data` directory.

Usage:
### Local Deployment
```./deploy.sh local deployment-type deployment-configurations [exp-id-offset]```

This local deployment builds and runs the experiment locally.

**deployment-configurations:**
1. `new path-to-config-gen-script`: Creates a new set of experiment configurations based on the specified `config-gen-script` script. 
2. `deployment-data`: Uses the configuration in the specified `deployment-data` directory. 

**exp-id-offset**: the offset from which the numbering of the executed experiments starts. If not defined the default value is `0`. 


### AWS Cloud Deployment

This AWS Cloud Deployment builds and runs the experiment in AWS Cloud Service.

**WAN**: ```./deploy-cloud-WAN.sh [-i -r -k -d -sd]```

**LAN**: ```./deploy-cloud-LAN.sh [-i -r -k -d -sd]```

**options:**

`-i`: This command retrieves the basic information from AWS cloud.

- `-r`: This command launched new instances based on the configuration specified in generate-config.sh in AWS cloud.
- `-k`: This command initializes new instances and updates the necessary key settings.

`-d`: This command performs the experiment according to the configuraítions defined in generate-config.sh.

`-sd`: This command terminates all the running instances in AWS cloud.



### Deployment Example

*Example 1*:  the command below starts a new cloud setup and runs the experiments described in `scripts/experiment-configuration/generate-config.sh` :
```
./deploy-cloud-WAN.sh -i -r -k -d -sd
```

*Example 2*:  the command below builds the source code locally and runs the experiments described in `scripts/experiment-configuration/generate-local-config.sh` :
```
./deploy.sh local new scripts/experiment-configuration/generate-local-config.sh
```


### Monitoring the AWS cloud deployment
The cloud deployment may seem to hang for a while. However running and analyzing all the experiment takes time.<br/>
Meanwhile, you can monitor their progress by looking into the master logs:

Connect via ssh to the master machine (its IP can be found in `deployment-data/cloud-xxxx/cloud-instance-info` or `deployment-data/remote-xxxx/cloud-instance-info`).<br/>
You can look at the logs of the commands the master is running in `master-log.log`.<br/>
You can monitor the experiments that are being analyzed in `current-deployment-data/continuous-analysis.log`.
You can also fetch the more detailed log file from the working machine by command: `scripts/cloud-deploy/fetch_result_from_peer.sh`.

### Configuration generation script ###
This script generates the configuration of all the experiments for a deployment. <br/>
The script describes sets of parameters for all the experiments the deployment script will permorm. <br/>
A sample configuration generation script is found in: `scripts/experiment-configuration/generate-config.sh`. <br/>
The script explains the important configuration paramenters in comments.
The parameters one should change to produce experiment sets are the following:
* Number of client machines and client instances per machine instances: 
    * `clients1`: deploys 1 client machine which runs the specified number of client instances
    * `clients16`: deploys 16 client machines which run the specified number of client instances
    * `clients32`: deploys 32 client machines which run the specified number of client instances
* Number of *non faulty* nodes: `systemSizes`
* Number of nodes that will exibit a *faulty* behavior: `failureCounts`
    * A value must be specified for each system size. Set to `0` for non-faulty nodes.
    * The total number of nodes is the sum of the system size and failure count.
* The duration of the experiments in seconds: `durations`
* The consensus protocol: `orderers`
* The leader election policy: `leaderPolicies` - if set to `Single` the system simulates a single leader protocol.
* The type of faulty behavior, in case of faulty nodes: `crashTimings`
* The maximum batch size: `batchsizes`
* The number of batches per second all leaders produce: `batchrates`. It defines the batch timeout unless it is overwritten by the following:
    * The minimum batch timeout: `minBatchTimeout`
    * The maximum batch timeout: `maxBatchTimeout`
* How many bathces are proposed by each leader (segment lenght): `segmentLengths`
* The timeout after which a leader is suspected - its exact interpretation depends on the protocol: `viewChangeTimeouts` 
* The target throughput for each experiment which defines the rate at which clients send requests: see below the line `# Target throughput`

To generate experiment sets for multiple values of a certain parameter, separate the values with a space (e.g., `systemSizes="4 8 16"`). <br/>

For a *local* deployment use the script: `scripts/experiment-configuration/generate-local-config.sh`. <br/>
We strongly suggest to keep the number of nodes and client instances for a local deployment is small (e.g., 4 nodes, 1 client instance), to avoid running out of memory or/and overloading the CPU.<br/>
We also suggest running experiments with small target trhoughput (below 1000 req/s) on local deployment. <br/>
The local deployment might take a while to finish.
You can monitor the progress of the experiment by looking at the master log file: `deployment-data/local-xxxx/master-log.log`, where `local-xxxx`
is the directory for the experiment.

### Processing the results

For each set of experiments, after it is completed, the result summary can be found under `deployment/deployment-data/cloud-xxxx/experiment-output/result-summary.csv` (replace with `remote-xxxx` for a cloud deployment).<br/>
For each individual experiment results are under `deployment/deployment-data/cloud-xxxx/experiment-output/yyyy`,
where `yyyy` represents the experiment number.
There are two types of calculate results.<br/>
Timeseries (`.csv` suffix) and aggregate (average) values (`.val` suffix).<br/>


We provide a simple `Python` script for visualizing experimental results.

**NOTE** to run the script you need `python3` and `matplotlib`.

### x-y plots
Aggregate results can be plotted in a `x-y` diagram of two chosen dimentions.
The input is now the result summary document and the plot is generated for all the experiments in the set.
For example the command below creates a latency-throughput plot for all the experiments in the experiment set.
```
python3 scripts/analyze/plot-xy.py deployment-data/cloud-xxxx/result-summary.csv target-throughput throughput-trunc latency-avg-trunc
``` 

The command should be executed from the deployment directory.<br/>
The script outputs a `plot.png` file.

## Using TLS

The communication among peers and between clients and peers can be configured to use TLS encryption
using options in [../config/config.yml](../config/config.yml).
Keys and certificates are currently located / generated in [tls-data/](tls-data)
and the executables are expected to be run from the `deployment` directory,
unless the path to the key and certificate files is adjusted. 

The keys and certificates can be generated by running [tls-data/generate.sh](tls-data/generate.sh) without arguments.