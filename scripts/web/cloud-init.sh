#!/bin/bash
NODE_ENV=production
NODE_VERSION=12.22.7
ROCKETCHAT_VERSION=4.0.5
ARCH=x64

apt update
apt upgrade -y

apt install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils

curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz"
tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner
rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz"

groupadd -r rocketchat
useradd -r -g rocketchat rocketchat
mkdir -p /app/uploads
chown rocketchat:rocketchat /app/uploads

apt install -y --no-install-recommends fontconfig
apt install -y --no-install-recommends g++ make python ca-certificates curl gnupg

curl -fSL "https://releases.rocket.chat/${ROCKETCHAT_VERSION}/download" -o rocket.chat.tgz
tar zxf rocket.chat.tgz
rm rocket.chat.tgz

cd bundle/programs/server
npm install
npm cache clear --force

chown -R rocketchat:rocketchat /app

mkdir -p /opt/RocketChat
cd ../../../
mv bundle/ /opt/RocketChat/
cd /opt/RocketChat/

apt install -y python3-pip
pip install openstackclient

source ./openstack.sh

//Openstack API abfragen nach Loadbalancer für ROOT_URL und so.