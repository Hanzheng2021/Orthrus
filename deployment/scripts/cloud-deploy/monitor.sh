#!/bin/bash

echo '' > ~/top.log
while true
do
    top -b | head -15  >> ~/top.log
    sleep 1
done