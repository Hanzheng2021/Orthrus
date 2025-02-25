We implentment DQBFT on top of the ISS. The installation and deployment is similar with ISS and Ladon.

Supported Consensus Protocols: PBFT

## Installation
### Cloning the repository
Create a GOPATH directory and make sure you are the owner of it:

`sudo mkdir -p /opt/gopath/`

`sudo chown -R $user:$group  /opt/gopath/`

where `$user` and `$group` your user and group respectively.

Create a directory to clone the repository into:

`mkdir -p /opt/gopath/src/github.com/hyperledger-labs/`

Clone this repository unter the directory you created:

`cd /opt/gopath/src/github.com/hyperledger-labs/`

`git clone https://github.com/Hanzheng2021/orthrus.git`

Checkout the`research-dqbft` branch.

### Installing Dependencies
With `/opt/gopath/src/github.com/Hanzheng2021/orthrus` as working directory, go to the deployment directory:

`cd deployment`

Configure the `user` and `group` in `vars.sh`

To install Golang and requirements: 

`source scripts/install-local.sh`

**NOTE**: The `install-local.sh` script, among other dependencies, installs `Go` in the home directory, sets GOPATH to `/opt/gopath/bin/` and edits `~/.bashrc`.

The default path to the repository is set to: `/opt/gopath/src/github.com/Hanzheng2021/orthrus/`.


### Installation
The `run-protoc.sh` script needs to be run from the project root directory (i.e. `mirbft`) before compiling the Go
files. 

**IMPORTANT**: go modules are not supported. Disable with the command: `export GO111MODULE=off` before installation.

Compile and install the go code by running `go install ./...` from the project root directory.


## Deployment & Permformance Metrics
Same with Ladon.
