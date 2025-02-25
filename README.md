# Ladon - High-Performance Multi-BFT Consensus via Dynamic Global Ordering
[![DOI](https://zenodo.org/badge/850962286.svg)](https://zenodo.org/doi/10.5281/zenodo.13714937)

This is the accompanying code to the paper "Ladon: High-Performance Multi-BFT Consensus via Dynamic Global Ordering" which was accepted to EuroSys 2025. A technical report is available [here](./doc/eurosys25-ae-spring-paper8.pdf).

## ABSTRACT
Multi-BFT consensus runs multiple leader-based consensus instances in parallel, circumventing the leader bottleneck of a single instance. 
However, it contains an Achilles’ heel: the need to globally order output blocks across instances. Deriving this global ordering is challenging because it must cope with different rates at which blocks are produced by instances. Prior Multi-BFT designs assign each block a global index before creation, leading to poor performance. We propose Ladon, a high-performance Multi-BFT protocol that allows varying instance block rates. Our key idea is to order blocks across instances dynamically, which eliminates blocking on slow instances. We achieve dynamic global ordering by assigning monotonic ranks to blocks. We pipeline rank coordination with the consensus process to reduce protocol overhead and combine aggregate signatures with rank information to reduce message complexity. Besides, the dynamic ordering enables blocks to be globally ordered according to their generation, which respects inter-block causality.

Ladon is a distributed consensus framework built on top of the ISS framework from Hyperledger-labs. For a detailed modular explanation and a glossary of terms, please refer to [here](../../tree/research-iss/README.md). The main task of the service is to maintain a totally ordered _Log_ of client _Requests_, using multiple consensus protocol instances whose outputs are multiplexed into the final _Log_. The _Manager_ module orchestrates these instances, determining parameters and creating _Segments_—logical parts of the _Log_ assigned to specific protocol instances. Each _Log_ entry has a _sequence number_ (_SN_) and contains a _Batch_ of _Requests_. _Client Requests_ are partitioned into _Buckets_ based on their hashes, and each _Segment_ is assigned a unique _Bucket_. The _Manager_ monitors the _Log_, creating new _Segments_ as needed and triggering the _Orderer_ to commit _Entries_ with the corresponding _SNs_. Periodically, the _Manager_ initiates _Checkpointer_ to create checkpoints and advances the _Segments_ as the _watermark window_ shifts.

Ladon extends the capabilities of ISS by incorporating the following modifications:

Pipeline the Rank Collection in the Consensus Protocol: Ladon introduces a pipelined step in the consensus protocol for collecting the ranks of participating nodes, which is then utilized for the global ordering of blocks.

Dynamic Global Ordering Algorithm: Ladon replaces the existing global ordering algorithm in ISS with a dynamic ordering algorithm. This new algorithm enhances system performance and efficiency, particularly in the presence of stragglers.

### Supported Consensus Protocols: 
- PBFT (Practical Byzantine Fault Tolerance) 
- HotStuff

## Main Directory Structure
- [checkpoint](checkpoint): 

    Module responsible for creating checkpoints of the _Log_. The _Checkpointer_ listens to the _Manager_, which notifies the _Checkpointer_ about each _SN_ at which a checkpoint should occur. The _Checkpointer_ triggers a separate instance of the checkpointing protocol for each such _SN_. When a checkpoint is stable, the _Checkpointer_ submits it to the _Log_.
- [crypto](crypto): 

    Implements cryptographic primitives, such as encryption and digital signatures.
- [deployment](deployment): 
    
    Deployment scripts and configurations for setting up and running Ladon in different environments. For more detailed descriptions, please refer to the [deployment](deployment/) folder.
- [log](log): 

    The _Log_ is a sequence of _Entries_. Each _Entry_ has a 32-bit integer _sequence number_ (_SN_) defining its position in the _Log_, and contains a _Batch_ of _Requests_. 
- [manager](manager): 

    The _Manager_ observes the _Log_ and creates new _Segments_ as the _Log_ fills up. When the _Manager_ creates a new _Segment_, it triggers the _Orderer_ that orders the _Segment_. Ordering a _Segment_ means committing new _Entries_ with the _SNs_ of that _Segment_. Periodically, the _Manager_ triggers the _Checkpointer_ to create checkpoints of the _Log_. The _Manager_ observes the created checkpoints and issues new _Segments_ as the checkpoints advance, respecting the _watermark window_.
- [membership](membership): 

    The _membership_ module is designed to manage the identities and membership information of nodes within a distributed system. It plays a crucial role in maintaining a consistent view of the network's composition.
- [orderer](orderer): 

    Module implementing the consensus protocols which actual order _Batches_, i.e., committing new _Entries_ to the _Log_. The _Orderer_ listens to the _Manager_ for new _Segments_. Whenever the _Manager_ issues a new _Segment_, the _Orderer_ creates a new instance of the ordering protocol that proposes and agrees on _Request_ _Batches_, one for each _SN_ that is part of the _Segment_. When a _Batch_ has been agreed upon for a particular _SN_, the _Orderer_ commits the (_SN_, _Batch_) pair as an _Entry_ to the _Log_.
- [request](request): 

    Opaque client data. Each _Request_ deterministically maps to a _Bucket_, which is a subset of all possible client _Requests_. Each _Request_ maps to exactly one _Bucket_ (mapping is based on the _Request_'s hash). The _Manager_ assigns one _Bucket_ to each _Segment_ and the _Orderer_ of the _Segment_ only uses _Requests_ from the assigned _Bucket_ to propose new _Batches_. _Batch_ is an ordered sequence of client _Requests_. All _Requests_ in a _Batch_ must belong to the same _Bucket_.
- [tls-data](tls-data): 

    The _tls-data_ module is designed for generating and managing TLS certificates and keys. It stores these certificates and keys and provides scripts to automate their creation and management, ensuring secure communication by providing all necessary cryptographic materials and tools for their efficient generation and management.


## Installation

### Cloning the repository
Create a GOPATH directory and make sure you are the owner of it:

`sudo mkdir -p /opt/gopath/`

`sudo chown -R $user:$group  /opt/gopath/`

where `$user` and `$group` your user and group respectively.

Create a directory to clone the repository into:

`mkdir -p /opt/gopath/src/github.com/Hanzheng2021/`

Clone this repository unter the directory you created:

`cd /opt/gopath/src/github.com/Hanzheng2021/`

`git clone https://github.com/Hanzheng2021/ladon.git`

Checkout the`research-ladon` branch.

### Installing Dependencies
With `/opt/gopath/src/github.com/Hanzheng2021/ladon` as working directory, go to the deployment directory:

`cd deployment`

Configure the `user` and `group` in [vars.sh](./deployment/vars.sh)

We use Ubuntu 22.04, Go 1.21.2 and Python 3.10. You will need to install the required dependencies.

- Ubuntu: (Included in `source scripts/install-local.sh`)
    - protobuf-compiler
    - protobuf-compiler-grpc
    - git
    - openssl
    - jq
    - graphviz
    - make
    - gcc
    - libc6

- Go: (Included in `source scripts/install-local.sh`)
    - google.golang.org/grpc
    - github.com/golang/protobuf/protoc-gen-go
    - github.com/rs/zerolog/log
    - github.com/c9s/goprocinfo/linux
    - go.dedis.ch/kyber
    - go.dedis.ch/fixbuf
    - golang.org/x/crypto/blake2b
    - gopkg.in/yaml.v2
    - github.com/op/go-logging

- Python: (Need to manually install)
    - sqlite3
    - numpy
    - matplotlib

**To install Golang and other related requirements:**

`source scripts/install-local.sh`

**NOTE**: The `install-local.sh` script, among other dependencies, installs `Go` in the home directory, sets GOPATH to `/opt/gopath/bin/` and edits `~/.bashrc`.

The default path to the repository is set to: `/opt/gopath/src/github.com/Hanzheng2021/orthrus/`.


### Ladon Installation
The `run-protoc.sh` script needs to be run from the project root directory (i.e. `ladon`) before compiling the Go files. 

**IMPORTANT**: go modules are not supported. Disable with the command: `export GO111MODULE=off` before installation.

Compile and install the go code by running `go install ./...` from the project root directory.


## Deployment & Permformance Metrics
Detailed instructions can be found [deployment](./deployment/) folder.

