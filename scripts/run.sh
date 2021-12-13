#! /bin/bash
sudo apt-get update
mkdir /tmp/setup
apt-get update
apt install unzip
curl -L -O https://github.com/jbreitung/openstack-rocketchat/archive/refs/heads/master.zip
unzip master.zip -d "'/tmp/setup'"
rm -f master.zip   