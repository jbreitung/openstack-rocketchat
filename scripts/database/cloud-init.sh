#!/bin/bash
#Initiales Start-Verzeichnis der Installation speichern.
startDir="$(pwd)"

#Initial erstmal alle Pakete aktualisieren
apt update
apt upgrade -y

#Grundlegende Pakete fuer sichere Kommunikation installieren
apt install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils

#Public-Key des MongoDB-Repos hinzufuegen.
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
#MongoDB-Repo der Package-List hinzufuegen.
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

#Nochmal Paketlisten updaten, nun mit MongoDB-Repo.
apt update
#MongoDB-Server installieren
apt install -y mongodb-org

#Konfigurationsdatei von MongoDB verschieben.
mv ./mongod.conf /etc/mongod.conf

#MongoDB-Service neustarten und Auto-Start aktivieren.
systemctl stop mongod.service
systemctl start mongod.service
systemctl enable mongod

#Warte fuer einige Sekunden, sodass der MongoDB-Server starten kann.
sleep 15

#Replica-Set initialisieren, welches von RocketChat benoetigt wird.
mongo --eval "rs.initiate({
              _id: 'rs0',
              members: [ { _id: 0, host: 'localhost:27017' } ]})"