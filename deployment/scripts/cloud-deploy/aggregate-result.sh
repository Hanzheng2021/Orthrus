#!/bin/bash

folder_path=$1
shift

for folder1 in "$folder_path"/*; do
    # # 检查是否是文件
    # if [ -f "$file" ]; then
    #     echo "File: $file"
    # fi

    # 检查是否是文件夹
    if [ -d "$folder1" ]; then
        echo "Directory1: $folder1"
        name=$(basename $folder1)
        echo "Directory name1: $name"
        cp -r "$folder1/result-summary.csv" /opt/gopath/src/github.com/Hanzheng2021/Orthrus/deployment/deployment-result-csv/$name.csv
    fi
done