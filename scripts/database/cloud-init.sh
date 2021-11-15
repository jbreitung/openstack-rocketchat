#!/bin/bash

apt update
apt upgrade -y

apt install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils

curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

apt update
apt install -y mongodb-org

mv ./mongod.conf /etc/mongod.conf

systemctl stop mongod.service
systemctl start mongod.service
systemctl enable mongod

mongo --eval "rs.initiate({
              _id: 'rs0',
              members: [ { _id: 0, host: 'localhost:27017' } ]})"
			  
