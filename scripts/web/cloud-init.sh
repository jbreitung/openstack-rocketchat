#!/bin/bash
#Umgebungsvariablen fuer Rocketchat definieren.
NODE_ENV=production
NODE_VERSION=12.22.7
ROCKETCHAT_VERSION=4.0.5
ARCH=x64

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

#Python3 Openstack-Client via PIP installieren.
pip install python-openstackclient

#Definierte Umgebungsvariablen des OpenStack API Sktiptes einlesen.
source ./openstack.sh

#Openstack API abfragen nach Loadbalancer für ROOT_URL und so.