# Variablen und Namen fuer das Projekt
locals {
  net_web_name  = "rcnet-web"
  net_db_name   = "rcnet-db"
  router_name   = "rcnet-router"
  
  keypair_name  = "RocketChat_Keypair"
  
  image_name    = "Ubuntu 20.04 - Focal Fossa - 64-bit - Cloud Based Image"
  flavor_name   = "m1.small"
  
  rcweb_secgrp  = "RocketChat_sec_grp_Web"
  rcdb_secgrp   = "RocketChat_sec_grp_DB"
  
  rcweb_loadbal = "RocketChat_lb_Web"
  
  rcweb_prefix  = "RocketChat_vm_Web"
  rcdb_prefix   = "RocketChat_vm_DB"
  
  repo_url      = "https://gitlab.cs.hs-fulda.de/fdai6185/ai1036-internetservices-projekt.git"
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
# Schlüsselpaare für RocketChat Systeme erzeugen.
# Wir nutzen für alle Systeme dieselben Schlüsselpaare.
#
###########################################################################

# import keypair, if public_key is not specified, create new keypair to use
resource "openstack_compute_keypair_v2" "terraform-keypair" {
  name        = keypair_name
  #public_key = file("~/.ssh/id_rsa.pub")
}



###########################################################################
#
# Sicherheitsgruppen fuer Datenbank und Web erstellen.
#
###########################################################################

resource "openstack_networking_secgroup_v2" "terraform-secgroup-rcweb" {
  name        = rcweb_secgrp
  description = "RocketChat Web SecGroup"
}

resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcweb-rule-http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcweb.id
}

resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcweb-rule-http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcweb.id
}

resource "openstack_networking_secgroup_v2" "terraform-secgroup-rcdb" {
  name        = rcdb_secgrp
  description = "RocketChat Web SecGroup"
}

resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcdb-rule-http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcdb.id
}

resource "openstack_networking_secgroup_rule_v2" "terraform-secgroup-rcdb-rule-http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 27017
  port_range_max    = 27019
  #remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.terraform-secgroup-rcdb.id
}


###########################################################################
#
# create network
#
###########################################################################

resource "openstack_networking_network_v2" "terraform-network-1" {
  name           = "my-terraform-network-1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "terraform-subnet-1" {
  name       = "my-terraform-subnet-1"
  network_id = openstack_networking_network_v2.terraform-network-1.id
  cidr       = "192.168.255.0/24"
  ip_version = 4
}

data "openstack_networking_router_v2" "router-1" {
  name = local.router_name
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = data.openstack_networking_router_v2.router-1.id
  subnet_id = openstack_networking_subnet_v2.terraform-subnet-1.id
}



###########################################################################
#
# create instances
#
###########################################################################

resource "openstack_compute_instance_v2" "terraform-instance-1" {
  name              = "my-terraform-instance-1"
  image_name        = local.image_name
  flavor_name       = local.flavor_name
  key_pair          = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups   = [openstack_networking_secgroup_v2.terraform-secgroup.name]

  network {
    uuid = openstack_networking_network_v2.terraform-network-1.id
  }

  depends_on = [ openstack_networking_subnet_v2.terraform-subnet-1 ]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get -y install apache2
    rm /var/www/html/index.html
    cat > /var/www/html/index.html << INNEREOF
    <!DOCTYPE html>
    <html>
      <body>
        <h1>It works!</h1>
        <p>hostname</p>
      </body>
    </html>
    INNEREOF
    sed -i "s/hostname/terraform-instance-1/" /var/www/html/index.html
    sed -i "1s/$/ terraform-instance-1/" /etc/hosts
  EOF
}

resource "openstack_compute_instance_v2" "terraform-instance-2" {
  name            = "my-terraform-instance-2"
  image_name      = local.image_name
  flavor_name     = local.flavor_name
  key_pair        = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups = [openstack_networking_secgroup_v2.terraform-secgroup.id]

  network {
    uuid = openstack_networking_network_v2.terraform-network-1.id
  }

  depends_on = [ openstack_networking_subnet_v2.terraform-subnet-1 ]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get -y install apache2
    rm /var/www/html/index.html
    cat > /var/www/html/index.html << INNEREOF
    <!DOCTYPE html>
    <html>
      <body>
        <h1>It works!</h1>
        <p>hostname</p>
      </body>
    </html>
    INNEREOF
    sed -i "s/hostname/terraform-instance-2/" /var/www/html/index.html
    sed -i "1s/$/ terraform-instance-2/" /etc/hosts
  EOF
}



###########################################################################
#
# create load balancer
#
###########################################################################
resource "openstack_lb_loadbalancer_v2" "lb_1" {
  vip_subnet_id = openstack_networking_subnet_v2.terraform-subnet-1.id
}

resource "openstack_lb_listener_v2" "listener_1" {
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1.id
  connection_limit = 1024
}

resource "openstack_lb_pool_v2" "pool_1" {
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.listener_1.id
}

resource "openstack_lb_members_v2" "members_1" {
  pool_id = openstack_lb_pool_v2.pool_1.id

  member {
    address       = openstack_compute_instance_v2.terraform-instance-1.access_ip_v4
    protocol_port = 80
  }

  member {
    address       = openstack_compute_instance_v2.terraform-instance-2.access_ip_v4
    protocol_port = 80
  }
}

resource "openstack_lb_monitor_v2" "monitor_1" {
  pool_id        = openstack_lb_pool_v2.pool_1.id
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
# assign floating ip to load balancer
#
###########################################################################
resource "openstack_networking_floatingip_v2" "fip_1" {
  pool    = "public1"
  port_id = openstack_lb_loadbalancer_v2.lb_1.vip_port_id
}

output "loadbalancer_vip_addr" {
  value = openstack_networking_floatingip_v2.fip_1
}
