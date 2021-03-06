# Variablen und Namen fuer das Projekt
locals {
  net_web_name    = "rcnet-web"
  subnet_web_name = "rcsubnet-web"
  net_db_name     = "rcnet-db"
  subnet_db_name  = "rcsubnet-db"
  net_mtn_name    = "rcnet-mtn"
  subnet_mtn_name = "rcsubnet-mtn"
  router_name     = "rcnet-router"
  
  keypair_name  = "RocketChat_Keypair"
  
  image_name    = "Ubuntu 20.04 - Focal Fossa - 64-bit - Cloud Based Image"
  flavor_name   = "m1.small"
  
  rcweb_secgrp  = "RocketChat_sec_grp_Web"
  rcdb_secgrp   = "RocketChat_sec_grp_DB"
  rcmtn_secgrp  = "RocketChat_sec_grp_Mtn"
  
  rcweb_loadbal = "RocketChat_lb_Web"
  
  rcweb_prefix  = "RocketChat_vm_Web"
  rcdb_prefix   = "RocketChat_vm_DB"
  rcmtn_prefix  = "RocketChat_vm_Maintenance"
  
  repo_url      = "https://github.com/jbreitung/openstack-rocketchat.git"

  user_data_db  = "${file("run_db.sh")}"
  user_data_web = "${file("run_web.sh")}"
  user_data_mtn = "${file("run_mtn.sh")}"
}

# 01. Keypair erzeugen: $keypair_name
# 02. RocketChat Web-Netzwerk erstellen: $net_web_name
# 03. RocketChat Web-Subnet im Netzwerk $net_web_name erstellen
# 04. RocketChat DB-Netzwerk erstellen: $net_db_name
# 05. RocketChat DB-Subnet im Netzwerk $net_db_name erstellen
# 06. RocketChat Router erstellen: $router_name
# 07. RocketChat Web- und DB-Netzwerke mit Router verbinden
# 08. Sicherheitsgruppe für Web-VMs erstellen: $rcweb_secgrp
# 09. Sicherheitsgruppe für DB-VMs erstellen: $rcdb_secgrp
# 10. Load-Balancer erstellen: $rcweb_loadbal
# 11. MongoDB-VM erstellen: $rcdb_prefix-$num
#	  Cloud-Init Script setzen:
#		- Git clone Repo
#		- Chmod +x auf /scripts/db/cloud-init.sh
#		- Script ausführen lassen
# 12. RocketChat-VMs erstellen: $rcweb_prefix-$num
#	  Cloud-Init Script setzen:
#		- Git clone Repo
#		- Load-Balancer IP abfragen
#		- MongoDB IP abfragen
#		- ENV-Variablen setzen für RocketChat ROOT_URL und MongoDB URL
#		- Chmod +x auf /scripts/web/cloud-init.sh
#		- Script ausführen lassen	
# 13. RocketChat-VMs dem Load-Balancer Pool zuweisen

# Genutzter OpenStack Provider
terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.40.0"
    }
  }
}

# OpenStack Provider setzen
provider "openstack" {
  cloud = "openstack"
  # we use Octavia-based load balancers in the NetLab @ HS-Fulda
  use_octavia = true
}

###########################################################################
#
# Schlüsselpaare für RocketChat Systeme definieren.
# Falls noch nicht geschehen, hier bitte den Public-Key des
# Systems einfuegen, welches auf den Maintenance-Node zugreifen soll.
#
###########################################################################

resource "openstack_compute_keypair_v2" "terraform-keypair" {
  name        = local.keypair_name
  public_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH/t5oB4e1y29QjjiVn5e080F79P0T0k+dmE960gFObH"
}

###########################################################################
#
# Sicherheitsgruppen fuer Datenbank und Web erstellen.
#
###########################################################################

# Uebergeordnete Sicherheitsgruppe von Web-VM
resource "openstack_networking_secgroup_v2" "terraform-secgroup-rcweb" {
  name        = local.rcweb_secgrp
  description = "RocketChat Web SecGroup"
}

# Regel fuer eingehenden SSH Traffic
resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcweb-rule-ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcweb.id
}

# Regel fuer eingehenden HTTP Traffic auf Port 3000 von RocketChat
resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcweb-rule-http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcweb.id
}

# Uebergeordnete Sicherheitsgruppe von DB-VM
resource "openstack_networking_secgroup_v2" "terraform-secgroup-rcdb" {
  name        = local.rcdb_secgrp
  description = "RocketChat Web SecGroup"
}

# Regel fuer eingehenden SSH Traffic
resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcdb-rule-ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcdb.id
}

# Regel fuer eingehenden MongoDB Traffic auf Ports 27017, 27018 und 27019
resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcdb-rule-db" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 27017
  port_range_max    = 27019
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcdb.id
}

# Uebergeordnete Sicherheitsgruppe von Maintenance-VM
resource "openstack_networking_secgroup_v2" "terraform-secgroup-rcmtn" {
  name        = local.rcmtn_secgrp
  description = "RocketChat Maintenance SecGroup"
}

# Regel fuer eingehenden SSH Traffic
resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcmtn-rule-ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcmtn.id
}

# Regel fuer eingehenden Rsyslog UDP Traffic
resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcmtn-rule-rsyslog" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 514
  port_range_max    = 514
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcmtn.id
}

###########################################################################
#
# Netzwerke fuer Web- und Datenbank VMs erstellen.
# Zusaetzlich Router erstellen fuer Routing zwischen den Netzen.
#
###########################################################################

# Uebergeordnetes Web-Netzwerk erstellen
resource "openstack_networking_network_v2" "terraform-network-web" {
  name           = local.net_web_name
  admin_state_up = "true"
}

# Web-Subnetz erstellen
resource "openstack_networking_subnet_v2" "terraform-subnet-web" {
  name       = local.subnet_web_name
  network_id = openstack_networking_network_v2.terraform-network-web.id
  cidr       = "10.0.100.0/24"
  ip_version = 4
}

resource "time_sleep" "wait_30_seconds_x1" {
  depends_on = [openstack_networking_subnet_v2.terraform-subnet-web]

  destroy_duration = "15s"
}

# Uebergeordnetes DB-Netzwerk erstellen
resource "openstack_networking_network_v2" "terraform-network-db" {
  name           = local.net_db_name
  admin_state_up = "true"

  depends_on = [time_sleep.wait_30_seconds_x1]
}

# DB-Subnetz erstellen
resource "openstack_networking_subnet_v2" "terraform-subnet-db" {
  name       = local.subnet_db_name
  network_id = openstack_networking_network_v2.terraform-network-db.id
  cidr       = "10.0.200.0/24"
  ip_version = 4
}

resource "time_sleep" "wait_30_seconds_x2" {
  depends_on = [openstack_networking_subnet_v2.terraform-subnet-db]

  destroy_duration = "15s"
}

# Maintenance-Netzwerk erstellen
resource "openstack_networking_network_v2" "terraform-network-mtn" {
  name           = local.net_mtn_name
  admin_state_up = "true"

  depends_on = [time_sleep.wait_30_seconds_x2]
}

# Maintenance-Subnetz erstellen
resource "openstack_networking_subnet_v2" "terraform-subnet-mtn" {
  name       = local.subnet_mtn_name
  network_id = openstack_networking_network_v2.terraform-network-mtn.id
  cidr       = "10.0.50.0/24"
  ip_version = 4
}

# Public-Netzwerk abfragen
data "openstack_networking_network_v2" "terraform-network-public" {
  name = "public1"
}

# Router fuer Verbindung der Netzer erstellen
# Verlinke direkt das externe Netzwerk (public1).
resource "openstack_networking_router_v2" "terraform-router-rcnet" {
  name                = local.router_name
  external_network_id = data.openstack_networking_network_v2.terraform-network-public.id
  admin_state_up      = "true"
}

# Router-Interface fuer Web-Subnet erstellen
resource "openstack_networking_router_interface_v2" "terraform-router-if-web" {
  router_id = openstack_networking_router_v2.terraform-router-rcnet.id
  subnet_id = openstack_networking_subnet_v2.terraform-subnet-web.id
}

# Router-Interface fuer DB-Subnet erstellen
resource "openstack_networking_router_interface_v2" "terraform-router-if-db" {
  router_id = openstack_networking_router_v2.terraform-router-rcnet.id
  subnet_id = openstack_networking_subnet_v2.terraform-subnet-db.id
}

# Router-Interface fuer Maintenance-Subnet erstellen
resource "openstack_networking_router_interface_v2" "terraform-router-if-mtn" {
  router_id = openstack_networking_router_v2.terraform-router-rcnet.id
  subnet_id = openstack_networking_subnet_v2.terraform-subnet-mtn.id
}

###########################################################################
#
# Persistentes Volume fuer Backups abfragen
#
###########################################################################

# Backup-Volume abfragen, welches existieren muss
data "openstack_blockstorage_volume_v3" "terraform-volume-backup" {
  name = "RCNet_Backup_Vol"
}

###########################################################################
#
# Virtuelle Maschinen erstellen.
#
###########################################################################

# Virtuelle Maschine 1 fuer Datenbank (MongoDB)
resource "openstack_compute_instance_v2" "terraform-instance-db-1" {
  name              = "${local.rcdb_prefix}-1"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcdb.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-db.id
    fixed_ip_v4 = "10.0.200.10"
  }

  depends_on = [
    openstack_networking_subnet_v2.terraform-subnet-db 
  ]

  user_data = local.user_data_db
}

# Virtuelle Maschine 2 fuer Datenbank (MongoDB)
resource "openstack_compute_instance_v2" "terraform-instance-db-2" {
  name              = "${local.rcdb_prefix}-2"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcdb.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-db.id
    fixed_ip_v4 = "10.0.200.20"
  }

  depends_on = [
    openstack_networking_subnet_v2.terraform-subnet-db 
  ]

  user_data = local.user_data_db
}

# Virtuelle Maschine 3 fuer Datenbank (MongoDB)
resource "openstack_compute_instance_v2" "terraform-instance-db-3" {
  name              = "${local.rcdb_prefix}-3"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcdb.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-db.id
    fixed_ip_v4 = "10.0.200.30"
  }

  depends_on = [
    openstack_networking_subnet_v2.terraform-subnet-db 
  ]

  user_data = local.user_data_db
}

# Virtuelle Maschine fuer Maintenance (RocketChat und Database)
# Darf erst nach Erstellung der Datenbank-Server erstellt werden.
resource "openstack_compute_instance_v2" "terraform-instance-maintenance" {
  name              = "${local.rcmtn_prefix}"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcmtn.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-mtn.id
    fixed_ip_v4 = "10.0.50.10"
  }

  depends_on = [ 
    openstack_compute_instance_v2.terraform-instance-db-1,
    openstack_compute_instance_v2.terraform-instance-db-2,
    openstack_compute_instance_v2.terraform-instance-db-3,
    openstack_networking_subnet_v2.terraform-subnet-mtn 
  ]

  user_data = local.user_data_mtn
}

# Volume fuer Backup-Daten attachen.
resource "openstack_compute_volume_attach_v2" "terraform-attach-backup" {
  instance_id = "${openstack_compute_instance_v2.terraform-instance-maintenance.id}"
  volume_id   = "${data.openstack_blockstorage_volume_v3.terraform-volume-backup.id}"
}

# Virtuelle Maschine 1 fuer Webserver (RocketChat)
# Darf erst nach Erstellung der Datenbank-Server erstellt werden.
resource "openstack_compute_instance_v2" "terraform-instance-web-1" {
  name              = "${local.rcweb_prefix}-1"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcweb.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-web.id
  }

  depends_on = [ 
    openstack_compute_instance_v2.terraform-instance-db-1,
    openstack_compute_instance_v2.terraform-instance-db-2,
    openstack_compute_instance_v2.terraform-instance-db-3,
    openstack_networking_subnet_v2.terraform-subnet-web,
    openstack_compute_instance_v2.terraform-instance-maintenance 
  ]

  user_data = local.user_data_web
}

# Virtuelle Maschine 2 fuer Webserver (RocketChat)
# Darf erst nach Erstellung der Datenbank-Server erstellt werden.
resource "openstack_compute_instance_v2" "terraform-instance-web-2" {
  name              = "${local.rcweb_prefix}-2"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcweb.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-web.id
  }

  depends_on = [ 
    openstack_compute_instance_v2.terraform-instance-db-1,
    openstack_compute_instance_v2.terraform-instance-db-2,
    openstack_compute_instance_v2.terraform-instance-db-3,
    openstack_networking_subnet_v2.terraform-subnet-web,
    openstack_compute_instance_v2.terraform-instance-maintenance 
  ]

  user_data = local.user_data_web
}

# Virtuelle Maschine 3 fuer Webserver (RocketChat)
# Darf erst nach Erstellung der Datenbank-Server erstellt werden.
resource "openstack_compute_instance_v2" "terraform-instance-web-3" {
  name              = "${local.rcweb_prefix}-3"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup-rcweb.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-web.id
  }

  depends_on = [ 
    openstack_compute_instance_v2.terraform-instance-db-1,
    openstack_compute_instance_v2.terraform-instance-db-2,
    openstack_compute_instance_v2.terraform-instance-db-3,
    openstack_networking_subnet_v2.terraform-subnet-web,
    openstack_compute_instance_v2.terraform-instance-maintenance 
  ]

  user_data = local.user_data_web
}

###########################################################################
#
# Load Balancer erstellen
#
###########################################################################

# Load Balancer fuer Webserver (RocketChat)
resource "openstack_lb_loadbalancer_v2" "terraform-lb-web" {
  name          = local.rcweb_loadbal
  vip_subnet_id = openstack_networking_subnet_v2.terraform-subnet-web.id
}

# Listener fuer Load Balancer erstellen 
resource "openstack_lb_listener_v2" "terraform-lb-listener-web" {
  name            = "${local.rcweb_loadbal}-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.terraform-lb-web.id
  connection_limit = 1024
}

# Pool fuer Load Balancer erstellen
resource "openstack_lb_pool_v2" "terraform-lb-pool-web" {
  protocol    = "HTTP"
  lb_method   = "SOURCE_IP"
  listener_id = openstack_lb_listener_v2.terraform-lb-listener-web.id
}

# Mitglieder des Pools definieren
resource "openstack_lb_members_v2" "terraform-lb-pool-members-web" {
  pool_id = openstack_lb_pool_v2.terraform-lb-pool-web.id

  member {
    address       = openstack_compute_instance_v2.terraform-instance-web-1.access_ip_v4
    protocol_port = 3000
  }
  
  member {
    address       = openstack_compute_instance_v2.terraform-instance-web-2.access_ip_v4
    protocol_port = 3000
  }

  member {
    address       = openstack_compute_instance_v2.terraform-instance-web-3.access_ip_v4
    protocol_port = 3000
  }
}

# Health-Monitor fuer Load Balancer erstellen
resource "openstack_lb_monitor_v2" "terraform-lb-monitor-web" {
  pool_id        = openstack_lb_pool_v2.terraform-lb-pool-web.id
  type           = "HTTP"
  delay          = 5
  timeout        = 5
  max_retries    = 3
  http_method    = "GET"
  url_path       = "/"
  expected_codes = 200
}

###########################################################################
#
# Oeffentliche Floating-IP fuer Load Balancer zuweisen
#
###########################################################################

# Floating-IP Ressource erstellen
resource "openstack_networking_floatingip_v2" "terraform-floating-ip-lb-web" {
  pool    = "public1"
  port_id = openstack_lb_loadbalancer_v2.terraform-lb-web.vip_port_id
}

# Floating-IP Ressource ausgeben
output "loadbalancer_vip_addr" {
  value = openstack_networking_floatingip_v2.terraform-floating-ip-lb-web
}

###########################################################################
#
# Oeffentliche Floating-IP fuer Maintenance-Server zuweisen
#
###########################################################################

# Floating-IP Ressource erstellen
resource "openstack_networking_floatingip_v2" "terraform-floating-ip-maintenance" {
  pool    = "public1"
}

# Floating IP zuweisen
resource "openstack_compute_floatingip_associate_v2" "terraform-floating-ip-maintenance-assoc" {
  floating_ip = openstack_networking_floatingip_v2.terraform-floating-ip-maintenance.address
  instance_id = openstack_compute_instance_v2.terraform-instance-maintenance.id
}

# Floating-IP Ressource ausgeben
output "maintenance_vip_addr" {
  value = openstack_networking_floatingip_v2.terraform-floating-ip-maintenance
}
