#!/bin/bash
# First clone the full repository with all important
# deployment scripts for all kinds of nodes.
sudo apt-get update
mkdir /tmp/setup
apt-get update
apt install unzip
curl -L -O https://github.com/jbreitung/openstack-rocketchat/archive/refs/heads/master.zip
unzip master.zip -d "'/tmp/setup'"
rm -f master.zip   

# Now we can run the cloud-init script for web nodes.
sh ./web/cloud-init.sh