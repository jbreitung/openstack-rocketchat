#!/bin/bash
#Verbindung zum MongoDB Replication-Master und mongodump ausfuehren.
BACKUP_PATH=/backup/mongodb/

cd $BACKUP_PATH
mongodump --forceTableScan --uri="mongodb://10.0.200.10:27017,10.0.200.20:27017,10.0.200.30:27017/rocketchat?replicaSet=rs0"