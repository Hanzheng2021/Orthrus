#!/bin/bash -e

source stop.sh


# config-gen.sh -l N C

client=config/clientconfig
server=config/serverconfig


# for file in "$client"/*; do
#     number=${file#*_client}
#     number=${number%.yml}
#     ../client/client ../deployment/config/clientconfig/config_client$number.yml client$number > ../client/client-$number.out &
# done

# ./client ../deployment/config/clientconfig/config_client1.yml client1


for file in "$server"/*; do
    number=${file#*_server}
    number=${number%.yml}
    
    # echo "Element: $file, Number: $number"
    ../server/server ../deployment/config/serverconfig/config_server$number.yml server$number > ../server/server-$number.out &
    # ./server ../deployment/config/serverconfig/config_server1.yml server1
done


