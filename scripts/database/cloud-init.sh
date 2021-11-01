#!/bin/bash
apt-get update
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
touch /etc/apt/sources.list.d/mongodb-org-5.0.list
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
apt-get update
apt-get install -y mongodb-org