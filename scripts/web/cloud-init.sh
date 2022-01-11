#!/bin/bash
#Umgebungsvariablen fuer Rocketchat definieren.
NODE_ENV=production
NODE_VERSION=12.22.7
ROCKETCHAT_VERSION=4.0.5
ARCH=x64

#Initiales Start-Verzeichnis der Installation speichern.
startDir="$(pwd)"

#Initial erstmal alle Pakete aktualisieren
apt update
apt upgrade -y

#Grundlegende Pakete fuer sichere Kommunikation installieren
apt install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils

#NodeJS installieren
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz"
tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner
rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz"

#Benutzergruppen fuer RocketChat erstellen und einen entsprechenden Benutzer erstellen.
groupadd -r rocketchat
useradd -r -g rocketchat rocketchat

#Upload-Verzeichnis fuer Mediendateien erstellen.
mkdir -p /app/uploads
#Dem Verzeichnis den Owner RocketChat setzen.
chown rocketchat:rocketchat /app/uploads

#Fontconfig Paket installieren, welches von RocketChat benoetigt wird.
apt install -y --no-install-recommends fontconfig
#Pakete fuer RocketChat Deployment installieren.
apt install -y --no-install-recommends g++ make python ca-certificates curl gnupg

#Definierte Version von Rocketchat herunterladen und entpacken.
curl -fSL "https://releases.rocket.chat/${ROCKETCHAT_VERSION}/download" -o rocket.chat.tgz
tar zxf rocket.chat.tgz
rm rocket.chat.tgz

#In das entpackte Installationsverzeichnis von RocketChat wechseln.
cd bundle/programs/server
#NPM Paket von RocketChat installieren, danach sicherheitshalber den Cache leeren.
npm install
npm cache clear --force

#Das gesamte App-Verzeichnis dem RocketChat-Benutzer geben.
chown -R rocketchat:rocketchat /app

#Ordentlichen Installations-Pfad fuer RocketChat anlegen und Installation dorthin verschieben.
mkdir -p /opt/RocketChat
cd ../../../
mv bundle/ /opt/RocketChat/
cd /opt/RocketChat/

#Installieren von PIP
apt install -y python3-pip
#Python3 Openstack-Client via PIP installieren.
pip install python-openstackclient

#Zurueck ins Start-Verzeichnis wechseln.
cd $startDir

#Definierte Umgebungsvariablen des OpenStack API Sktiptes einlesen.
#source /tmp/setup/openstack-rocketchat-master/scripts/web/openstack.sh

#openstack server list --name="RocketChat_vm_DB-[1-3]"

#Openstack API abfragen nach Loadbalancer für ROOT_URL und so.
#TODO: Replace these example values by rsheal values fetched from OpenStack API.
ROCKETCHAT_URL=http:\\/\\/chat.example.org
ROCKETCHAT_PORT=3000
MONGODB_URL=mongodb:\\/\\/10.0.200.10:27017,10.0.200.20:27017,10.0.200.30:27017\\/rocketchat?replicaSet=rs0

#Ersetzen der Placeholder in der Service-Definition von RocketChat.
sed -i 's/RC_RUNTYPE/'$NODE_ENV'/g' /tmp/setup/openstack-rocketchat-master/scripts/web/rocketchat.service
sed -i 's/RC_PORT/'$ROCKETCHAT_PORT'/g' /tmp/setup/openstack-rocketchat-master/scripts/web/rocketchat.service
sed -i 's/RC_ROOTURL/'$ROCKETCHAT_URL'/g' /tmp/setup/openstack-rocketchat-master/scripts/web/rocketchat.service
sed -i 's/RC_MONGOURL/'$MONGODB_URL'/g' /tmp/setup/openstack-rocketchat-master/scripts/web/rocketchat.service

#Verschieben der Service-Definition nach /etc/systemd/system/
mv /tmp/setup/openstack-rocketchat-master/scripts/web/rocketchat.service /etc/systemd/system/rocketchat.service

#Aktivieren des Service und Starten
systemctl enable /etc/systemd/system/rocketchat.service
systemctl start rocketchat.service