====== Einleitung ======
Zum Abschluss des Moduls "Internet Services" (AI1034) im Wintersemester 2021 ist die Umsetzung eines Dienstes auf Basis der OpenStack Plattform als Projektabgabe erforderlich. Im Rahmen dieses Projektes wurde sich hierbei für die Kommunikations-Plattform **Rocket.Chat** entschieden. Ziel des Projektes ist es, eine funktionsfähige Installation von Rocket.Chat automatisiert auf der OpenStack Plattform der Hochschule Fulda bereitzustellen. Hierbei sind Aspekte wie Ausfallsicherheit, Redundanz, Backup/Restore und Logging zu beachten. 

===== Beteiligte =====
  * Christian Zieschang (Mat.-Nr.: **1254769**)
  * Julian Breitung (Mat.-Nr.: **1257070**)

===== Architektur =====
Die Architektur des Rocket.Chat Dienstes basiert auf den im Modul "Internet Services" erlernten Technologien und Strukturen für moderne Internet-Dienste. Die **Rocket.Chat Applikations-Server**, sowie die daran angebundenen **MongoDB Datenbank-Server** wurden im Rahmen des Projektes **dreifach repliziert** installiert. Zusätzlich zu diesen sechs Instanzen existiert ein "Maintenance-Node", über den Wartungsaufgaben ausgeführt werden können. Um den öffentlich zugänglichen Bereich (Rocket.Chat Applikations-Server) logisch vom Datenbestand des Dienstes zu trennen, wurde sich zudem dazu entschieden, getrennte Netzwerke einzuführen. Die jeweiligen Instanzen, deren Netzwerke und die Kommunikation untereinander lässt sich im folgenden Schaubild erkennen.

{{:dienst07ws2021:architektur.png?900|}}

===== Umgebung =====
  * **Software:** Rocket.Chat, MongoDB
  * **Betriebssystem:** Ubuntu 20.04 LTS
  * **Plattform:** OpenStack Xena
  * **Deployment:** Terraform
  * **Entwicklungsumgebung:** Visual Studio Code, Windows Terminal, VIM
  * **Versionierung:** GitHub

{{:dienst07ws2021:umgebung.png?900|}}

====== Installation ======
Für die erste Installation des Dienstes sind alle folgenden Schritte zu befolgen. Gegebenenfalls ausführbare Wartungsarbeiten oder erneute Deployments werden gesondert beschrieben.

===== Herunterladen der Installations-Dateien =====
//TODO: Git Clone und/oder ZIP entpacken erklären//

===== Einrichtung eines SSH-Keys =====
Noch vor der eigentlichen Installation muss sich dafür entschieden werden, von welchem SSH-Client aus der spätere Maintenance-Node erreichbar sein soll. Hierfür ist einzig und allein die Authentifizierung über einen SSH-Key möglich. Diesen gilt es deshalb vorab zu erstellen. Sofern Sie ein aktuelles Microsoft Windows benutzen, können Sie mit folgendem Befehl einen neuen SSH-Key generieren lassen.

<code batch>
ssh-keygen -t ed25519
</code>

Sofern Sie keinen anderen Pfad im folgenden Dialog angegeben haben, befinden sich im Anschluss im Ordner **.ssh** Ihres Heimatverzeichnisses zwei neue Dateien. Darin befinden sich der generierte privaten SSH-Key (**ssh_id**) und der zugehörige öffentliche SSH-Key (**ssh_id.pub**). Um den Inhalt der beiden Dateien anzuzeigen, können Sie den folgenden Befehl ausführen.

<code batch>
cat ssh_id* 
</code>

Im Anschluss wird Ihnen der Inhalt der beiden Dateien in der Konsole ausgegeben. **Bitte geben Sie den oben dargestellten privaten Schlüssel niemals weiter!** Den unten abgebildeten öffentlichen SSH-Key können Sie nun jedoch kopieren.

{{:dienst07ws2021:00_init_ssh_key_step3.png?900|}}

Nachdem der eigene öffentliche SSH-Key nun bekannt ist, muss dieser noch in das Terraform-Skript eingepflegt werden. Nur so wird dieser dann auch im Maintenance-Node hinterlegt, sodass eine Anmeldung von Außen erfolgen kann. Um den Schlüssel in Terraform zu hinterlegen, öffnen Sie bitte die Datei "**scripts/openstack_init.tf**" im Verzeichnis der Installations-Dateien. Dort suchen Sie bitte den folgenden Bereich.

<code>
###########################################################################
#
# Schlüsselpaare für RocketChat Systeme definieren.
# Falls noch nicht geschehen, hier bitte den Public-Key des
# Systems einfuegen, welches auf den Maintenance-Node zugreifen soll.
#
###########################################################################

resource "openstack_compute_keypair_v2" "terraform-keypair" {
  name        = local.keypair_name
  public_key  = "ssh-ed25519 AAAAC3Nza________________________________________zwzi6ffW"
}
</code>

Der öffentliche SSK-Key muss in zwischen die Anführungsstriche hinter dem Bezeichner "**public_key**" eingefügt werden. Im Anschluss kann die Datei gespeichert und wieder geschlossen werden.

===== Backup-Volume einrichten =====
In diesem Schritt wird ein Volume auf der OpenStack Plattform eingerichtet, welches später zur Aufbewahrung von Backups der Datenbanken verwendet wird. Da die Backups keinesfalls durch ein erneutes Deployment oder ein Undeployment überschrieben oder gar gelöscht werden sollen, wird das Volume einmalig initial manuell angelegt. So wird sichergestellt, dass die Deployment-Skripte und Terraform darauf keinen Einfluss nehmen.

Zum Erstellen eines neuen Volumes melden Sie sich zunächst in der OpenStack Umgebung an. Anschließend öffnen Sie über das Menü links die Seite "**Volumes -> Volumes**". Im Anschluss öffnen Sie den Dialog zum Erstellen eines neuen Volumes über den Button "**Create Volume**" oben rechts.

{{:dienst07ws2021:02_create_backup_volume.png?900|}}

Passen Sie dort die beiden Werte mit der roten Markierung an. Stellen Sie sicher, dass der Name des Volumes exakt "**RCNet_Backup_Vol**" ist. Die Größe des Volumes können Sie beliebig definieren.

mkfs.ext4 /dev/sdXY

===== Terraform ausführen =====

=== Clouds Yaml ===
Voraussetzung für die Nutzung von Terraform ist eine Valide „Clouds.yaml“ welche im gleichen Ordner wie die anzuwendende „openstack_init.tf“. In der „Clouds.yaml“ sind die folgenden Felder anzupassen: 

  * **auth_url**
  * **username**
  * **password**
  * **project_id**
  * **project_name**

<code yaml>
clouds:
  openstack:
    auth:
      auth_url: "<auth_url>"
      username: "<username>"
      password: "<password>"
      project_id: <project_id>
      project_name: "<project_name>"
      user_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
</code>

=== Cloud-Init Skripte ===
Nachdem die einzelnen Nodes per Terraform auf der OpenStack Plattform angelegt wurden, werden jeweils eigene Cloud-Init Skripte auf den VMs automatisch ausgeführt. Diese haben, je nachdem um welche Art von Node es sich handelt, unterschiedliche Befehle auszuführen. Anpassungen sollten daher vor dem „Terraform Apply“ stattfinden.

Grundlegend laden alle Cloud-Init Skripte der unterschiedlichen Nodes das Git-Repository mit allen weiteren Skripten von GitHub herunter. Hierzu wird via CURL die URL **https://github.com/jbreitung/openstack-rocketchat/archive/refs/heads/master.zip** heruntergeladen. 

Das heruntergeladene Repository wird vom Cloud-Init Skript nach **/tmp/setup/** kopiert und entpackt. Von dort aus werden alle weiteren Skripte, passend zum jeweiligen Node ausgeführt.

== Web Node ==
Der Web Node ist für die Bereitstellung des Rocket.Chat Frontends über dessen Node.js Server zuständig. Hierfür wird im Cloud-Init das Skript **/tmp/setup/openstack-rocketchat-master/scripts/web/cloud-init.sh** ausgeführt:
<code bash>
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

#Verschiebe die Konfiguration fuer Rsyslog
mv /tmp/setup/openstack-rocketchat-master/scripts/web/rsyslog.conf /etc/rsyslog.conf

#Rsyslog neustarten
systemctl restart rsyslog

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

#Zurueck ins Start-Verzeichnis wechseln.
cd $startDir

#Openstack API abfragen nach Loadbalancer für ROOT_URL und so.
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
</code>

Die Sources für den Rocket.Chat Node.js Server werden hierbei von den offiziellen Servern von Rocket.Chat heruntergeladen und entpackt. Anschließend wird die Installation via NPM im Verzeichnis **/opt/RocketChat/** ausgeführt.

Das Skript kopiert des Weiteren die Datei **/tmp/setup/openstack-rocketchat-master/scripts/web/rocketchat.service** nach **/etc/systemd/system/rocketchat.service**, sodass der Rocket.Chat Node.js Server als System-Service ausgeführt werden kann. Die Konfiguration dieses Services über die Datei sieht wiefolgt aus:

<code ini>
[Unit]
Description=RocketChat Server
After=network.target remote-fs.target nss-lookup.target

[Service]
ExecStart=/usr/local/bin/node /opt/RocketChat/bundle/main.js 
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog  
SyslogIdentifier=nodejs-rocketchat
User=rocketchat
Group=rocketchat
Environment=NODE_ENV=RC_RUNTYPE PORT=RC_PORT ROOT_URL=RC_ROOTURL MONGO_URL=RC_MONGOURL

[Install]
WantedBy=multi-user.target
</code>
Die hier zu sehenden Platzhalter hinter dem Schlüssel **Environment** werden durch das cloud-init.sh Skript durch die benötigten Werte automatisch ersetzt.

Des Weiteren wird Rsyslog durch das Kopieren der Datei **/tmp/setup/openstack-rocketchat-master/scripts/web/rsyslog.conf** nach **/etc/rsyslog.conf** aktiviert, sodass jegliche System-Logs auf dem Maintencance-Node bereitgestellt werden.

== Datenbank Node ==
Der Datenbank Node wird so konfiguriert, dass er die MongoDB-Datenbank bereitstellen kann. Hierfür wird das Skript **/tmp/setup/openstack-rocketchat-master/scripts/database/cloud-init.sh** ausgeführt. Es installiert die notwendigen Software-Pakete und konfiguriert die MongoDB automatisch für die Replikation über alle drei Datenbank-Nodes.

<code bash>
#!/bin/bash
#Initiales Start-Verzeichnis der Installation speichern.
startDir="$(pwd)"

#Initial erstmal alle Pakete aktualisieren
apt update
apt upgrade -y

#Grundlegende Pakete fuer sichere Kommunikation installieren
apt install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils

#Verschiebe die Konfiguration fuer Rsyslog
mv /tmp/setup/openstack-rocketchat-master/scripts/database/rsyslog.conf /etc/rsyslog.conf

#Rsyslog neustarten
systemctl restart rsyslog

#Public-Key des MongoDB-Repos hinzufuegen.
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
#MongoDB-Repo der Package-List hinzufuegen.
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

#Nochmal Paketlisten updaten, nun mit MongoDB-Repo.
apt update
#MongoDB-Server installieren
apt install -y mongodb-org

#Konfigurationsdatei von MongoDB verschieben.
mv /tmp/setup/openstack-rocketchat-master/scripts/database/mongod.conf /etc/mongod.conf

#MongoDB-Service neustarten und Auto-Start aktivieren.
systemctl stop mongod.service
systemctl start mongod.service
systemctl enable mongod

#Warte fuer einige Sekunden, sodass der MongoDB-Server starten kann.
sleep 15

#Lese eigene IP-Adresse
IP=$(hostname -I)

#Replica-Set initialisieren, welches von RocketChat benoetigt wird.
mongo --eval "rs.initiate({
              _id: 'rs0',
              members: [ 
                  { _id: 0, host: '10.0.200.10:27017' }, 
                  { _id: 1, host: '10.0.200.20:27017' }, 
                  { _id: 2, host: '10.0.200.30:27017' } 
              ]})"
</code>

Die Konfigurations-Datei der MongoDB wird durch das Skript automatisch von **/tmp/setup/openstack-rocketchat-master/scripts/database/mongod.conf** nach **/etc/mongod.conf** kopiert. Der letzte ausgeführte Befehl des Skriptes registriert die MongoDB Instanz in den Verbund für die Replikation über alle drei Datenbank Nodes.


== Maintenance Node ==
<code bash>
#!/bin/bash
BACKUP_PATH=/backup/mongodb/

#Initial erstmal alle Pakete aktualisieren
apt update
apt upgrade -y

#Grundlegende Pakete fuer sichere Kommunikation installieren
apt install -y --no-install-recommends ca-certificates curl wget gnupg dirmngr xz-utils

#Installieren von MongoDB-Tools fuer Backup und Restore
apt install -y --no-install-recommends mongo-tools

#Backup Mount Verzeichnis anlegen und mounten
mkdir -p $BACKUP_PATH

#Pruefen, ob das Filesystem auf dem Volume bereits erstellt wurde
fscheck=$(blkid -o value -s TYPE /dev/vdb)

if [ "$fscheck" = "ext4" ]
then
   echo "Filesystem already initialized."
else
   echo "Filesystem not initialized. Creating new EXT4 filesystem on /dev/vdb"

   mkfs.ext4 /dev/vdb
fi

mount /dev/vdb $BACKUP_PATH

#Initial führe einen Restore der evtl. bereits vorhandenen Backups aus
#sodass die Datenbanken wieder einen möglichen vorherigen Stand annehmen
if [ -z "$(ls -A $BACKUP_PATH)" ]; then
   echo "No existing backups found. Not performing restore."
else
   echo "Found exitsting backup files. Manual restore is recommended!"

   #sh /tmp/setup/openstack-rocketchat-master/scripts/maintenance/restore.sh
fi

#Verschieben des Backup-Scripts und einrichten des Cronjobs
mkdir -p /opt/rcnet/
mv /tmp/setup/openstack-rocketchat-master/scripts/maintenance/backup.sh /opt/rcnet/backup.sh
#Verschiebe ebenfalls das Restore-Script fuer manuellen Restore
mv /tmp/setup/openstack-rocketchat-master/scripts/maintenance/restore.sh /opt/rcnet/restore.sh
#Verschiebe die Konfiguration fuer Rsyslog
mv /tmp/setup/openstack-rocketchat-master/scripts/maintenance/rsyslog.conf /etc/rsyslog.conf

#Create folder for rsyslog
mkdir /var/log/remotelogs
chown -R syslog:adm /var/log/remotelogs

#Rsyslog neustarten
systemctl restart rsyslog

#Lese aktuelle Crontab, füge Zeile hinzu und schreibe sie wieder
crontab -l > /tmp/setup/openstack-rocketchat-master/scripts/maintenance/crontab
echo "*/15 * * * * /opt/rcnet/backup.sh" >> /tmp/setup/openstack-rocketchat-master/scripts/maintenance/crontab
crontab /tmp/setup/openstack-rocketchat-master/scripts/maintenance/crontab
rm /tmp/setup/openstack-rocketchat-master/scripts/maintenance/crontab
</code>

===== RocketChat konfigurieren =====

====== Abhängigkeiten ======
Netz, Storage, Server, ...

====== Monitoring/Überwachung/Logging/Reporting ======

====== Trouble Shooting ======

====== Wartungsaufgaben ======
Updates, Abrechnung, Speicherplatz bereitstellen, …

====== Authentifizierung, Autorisierung, Accounting ======
Identity Management, Neue Benutzer/Benutzer löschen

====== Benutzergruppen ======
z.B. für Benachrichtigung, spezielle Funktionen für PowerUser usw.

====== Backup/Restore/Failover/Disaster Recovery/Archiv ======

====== Skalierung ======
