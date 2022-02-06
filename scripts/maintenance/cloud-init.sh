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

#Dateirechte zum ausfuehren setzen
chmod +x /opt/rcnet/*.sh

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