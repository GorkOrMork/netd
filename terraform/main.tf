# Переменные
variable yc_token {}
variable yc_cloud_id {}
variable yc_folder_id {}
variable yc_public_key {}
variable yc_private_key {}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

data "yandex_compute_image" "debian" {
  family = "debian-11"
}

# Провайдер
provider "yandex" {
  token        = var.yc_token
  cloud_id     = var.yc_cloud_id
  folder_id    = var.yc_folder_id
}
#=======================
#=======================
# Создание сети
resource "yandex_vpc_network" "network3" {
  name = "network3"
}
# Создание подсетей
resource "yandex_vpc_subnet" "subnet1" {
  name = "subnet1"
  zone = "ru-central1-a"
  network_id = yandex_vpc_network.network3.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}
resource "yandex_vpc_subnet" "subnet2" {
  name = "subnet2"
  zone = "ru-central1-b"
  network_id = yandex_vpc_network.network3.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}
#=======================
#Создание vm1, vm2

resource "yandex_compute_instance" "nginxserver1" {
  name = "nginxserver1"
  zone = "ru-central1-a"
  
  resources{
    cores = 2
    core_fraction = 20
    memory = 8
  }

  boot_disk{
    initialize_params {
      image_id = "fd8il24jjf1hg8d4nq7i"
      size = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }
  metadata = {
    user-data = "${file("./meta.txt")}"
  }
}

resource "yandex_compute_instance" "nginxserver2" {
  name = "nginxserver2"
  zone = "ru-central1-b"
  
  resources{
    cores = 2
    core_fraction = 20
    memory = 4
  }

  boot_disk{
    initialize_params {
      image_id = "fd8il24jjf1hg8d4nq7i"
      name = "nginx2-disk"
      size = 10
      description = "boot disk for nginx_server1"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet2.id
    nat = true
  }
  metadata = {
    user-data = "${file("./meta.txt")}"
  }
}

resource "yandex_compute_instance" "elastic"{
  name = "elastic"
  zone = "ru-central1-a"
  
  resources {
    cores = 4
    core_fraction = 20
    memory = 8
  }

  boot_disk {
#    disk_id = "elastic-disk"
    initialize_params {
      image_id = "fd8il24jjf1hg8d4nq7i"
#      disk_id = "elastic-disk"
      size = 20
      description = "boot disk for elastic"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }
  metadata = {
    user-data = "${file("./meta.txt")}"
  }
}

resource "yandex_compute_instance" "kibana" {
  name = "kibana"
  zone = "ru-central1-a"
  
  resources{
    cores = 4
    core_fraction = 20
    memory = 8
  }

  boot_disk{
    initialize_params {
      image_id = "fd8il24jjf1hg8d4nq7i"
#      disk_шв = "kibana-disk"
      size = 20
      description = "boot disk for kibana"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }
  metadata = {
    user-data = "${file("./meta.txt")}"
  }
}

#target group
resource "yandex_lb_target_group" "tgtest"{
  name = "tgtest"

  target {
    subnet_id = "${yandex_vpc_subnet.subnet1.id}"
    address = "${yandex_compute_instance.nginxserver1.network_interface.0.ip_address}"
}

  target {
    subnet_id = "${yandex_vpc_subnet.subnet2.id}"
    address = "${yandex_compute_instance.nginxserver2.network_interface.0.ip_address}"
}

}

resource "yandex_lb_network_load_balancer" "foo" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.tgtest.id}"

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_compute_instance" "zabbix_vm" {
  name = "zabbix-vm"
  zone = "ru-central1-a"

  resources {
    cores = 2
    core_fraction = 20
    memory = 6
  }

  boot_disk {
#    disk_id = "zabbix-disk"
    initialize_params {
      image_id = "fd8il24jjf1hg8d4nq7i"
#      disk_id = "zabbix-disk"
      size = 20
      description = "boot disk for zabbix"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }

  metadata = {
    ssh-keys = "${file("./meta.txt")}"
  }
}

resource "yandex_compute_snapshot" "nginx1-snapshot" {
  name           = "nginx1-snapshot"
  source_disk_id = yandex_compute_instance.nginxserver1.boot_disk[0].disk_id

  timeouts {
    update = "168h"
  }
}

resource "yandex_compute_snapshot" "nginx2-snapshot" {
  name           = "nginx2-snapshot"
  source_disk_id = yandex_compute_instance.nginxserver2.boot_disk[0].disk_id

  timeouts { 
    update = "168h"
  }
}

resource "yandex_compute_snapshot" "elastic-snapshot" {
  name           = "elastic-snapshot"
  source_disk_id = yandex_compute_instance.elastic.boot_disk[0].disk_id

  timeouts { 
    update = "168h"
  }
}

resource "yandex_compute_snapshot" "kibana-snapshot" {
  name = "kibana-disk"
  source_disk_id           = yandex_compute_instance.kibana.boot_disk[0].disk_id

  timeouts { 
    update = "168h"
  }
}

resource "yandex_compute_snapshot" "zabbix-snapshot" {
  name = "zabbix-disk"
  source_disk_id           = yandex_compute_instance.zabbix_vm.boot_disk[0].disk_id

  timeouts { 
    update = "168h"
  }
}
