#!/bin/bash
apt update
snap install rocketchat-server
snap set rocketchat-server port=80
snap set rocketchat-server mongo-url=mongodb://localhost:27017/savannasaurus
snap set rocketchat-server mongo-oplog-url=mongodb://localhost:27017/local
systemctl restart snap.rocketchat-server.rocketchat-server.service