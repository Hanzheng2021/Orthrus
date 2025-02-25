#!/bin/bash -e

echo "Killing previously running servers and clients"
pkill server
pkill client

echo "Chancing working directory"
cd /opt/gopath/src/github.com/Hanzheng2021/orthrus/client

echo "Removing previously created status files"
rm -rf status

echo "Starting client"
./client ../deployment/config/clientconfig/config.yml client &> client.out &

