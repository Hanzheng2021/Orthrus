#!/bin/bash
export user=$(id -un)
export group=$(id -gn)

export PATH=$PATH:~/go/bin/:/opt/gopath/bin/
export GOPATH=/opt/gopath
export GOROOT=~/go
export GO111MODULE=off

sudo mkdir -p /opt/gopath/src/github.com/Hanzheng2021/
sudo chown -R $user:$group  /opt/gopath/
cd /opt/gopath/src/github.com/Hanzheng2021/
if [ ! -d "/opt/gopath/src/github.com/Hanzheng2021/orthrus" ]; then
  git clone https://github.com/JeffXiesk/mirbft.git
fi
cd /opt/gopath/src/github.com/Hanzheng2021/orthrus
git checkout research
git pull
./run-protoc.sh
cd /opt/gopath/src/github.com/Hanzheng2021/orthrus/server
go build
cd /opt/gopath/src/github.com/Hanzheng2021/orthrus/client
go build