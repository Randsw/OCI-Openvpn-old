terraform {
  required_providers {
    oci = {
        source  = "hashicorp/oci"
        version = ">= 4.0.0"
    }
    sops = {
      source = "carlpett/sops"
      version = "~> 0.5"
    }
  }
}

data "sops_file" "secret" {
  source_file = "secret.sops.yaml"
}

provider "oci" {
  region           = data.sops_file.secret.data["region"]
  tenancy_ocid     = data.sops_file.secret.data["tenancy"]
  user_ocid        = data.sops_file.secret.data["user"]
  fingerprint      = data.sops_file.secret.data["fingerprint"]
  private_key_path = data.sops_file.secret.data["key_file"]
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = data.sops_file.secret.data["tenancy"]
}


# resource "oci_identity_compartment" "tf-compartment" {
#     # Required
#     compartment_id = data.sops_file.secret.data["tenancy"]
#     description = "Compartment for Terraform resources."
#     name = "Rand-OCI-compartment"
# }


resource "oci_core_vcn" "internal" {
  dns_label      = "internal"
  cidr_block     = "172.16.0.0/20"
  compartment_id = data.sops_file.secret.data["tenancy"]
  display_name   = "OpenVPN VCN"
}

resource "oci_core_subnet" "openvpn" {
  vcn_id                      = oci_core_vcn.internal.id
  cidr_block                  = "172.16.0.0/24"
  compartment_id              = data.sops_file.secret.data["tenancy"]
  display_name                = "OpenVPN server subnet"
  dns_label                   = "dev"
}



resource "oci_core_instance" "OpenVPN" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  compartment_id      = data.sops_file.secret.data["tenancy"]
  display_name        = "OpenVPN Server"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.openvpn.id
    display_name     = "OpenVpn Server"
    assign_public_ip = true
    hostname_label   = "openvpn-server"
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaymguk5srho2luw7w627fm3sshgtgpsfkzmeiec3qrrwsy3ys76fa"
  }

  metadata = {
    ssh_authorized_keys = "${file(var.ssh_key_public)}"
  }

#   connection {
#       host        = "${self.public_ip}"
#       type        = "ssh"
#       user        = "opc"
#       private_key = "${file("~/ya_rsa")}"
#     }
#   provisioner "remote-exec" {
#     inline = ["sudo yum check-update", "sudo yum install python3 -y", "echo Done!"]
#    }
}


# resource "yandex_vpc_network" "openvpn-net" {
#     name = "yandex-openvpn-terraform"
# }

# resource "yandex_vpc_subnet" "ya-openvpn-subnet" {
#   name = "ya-subnet-1"
#   v4_cidr_blocks = ["10.2.0.0/16"]
#   zone       = "ru-central1-a"
#   network_id = "${yandex_vpc_network.openvpn-net.id}"
# }

# resource "yandex_dns_zone" "openvpn-test" {
#   name    = "tls-cert-zone"
#   zone    = "rand-tls-test.ga."
#   public  = true
# }

# resource "yandex_dns_recordset" "rs1" {
#   zone_id = "${yandex_dns_zone.openvpn-test.id}"
#   name    = "rand-tls-test.ga."
#   type    = "A"
#   ttl     = 200
#   data    = ["${yandex_compute_instance.yandex-openvpn.network_interface.0.nat_ip_address}"]
# }

# resource "yandex_compute_instance" "yandex-openvpn" {
#   name        = "openvpn-server"
#   platform_id = "standard-v1"
#   zone        = "ru-central1-a"

#   resources {
#     cores  = 2
#     memory = 2
#     core_fraction = 20
#   }

#   boot_disk {
#     initialize_params {
#       image_id = "fd878e3sgmosqaquvef5"
#       size = 20
#       type = "network-hdd"
#     }
#   }

#   network_interface {
#     subnet_id = "${yandex_vpc_subnet.ya-openvpn-subnet.id}"
#     nat = true
#   }

#   metadata = {
#     ssh-keys = "cloud-user:${file("~/ya_rsa.pub")}"
#   }

#   connection {
#       host        = "${self.network_interface.0.nat_ip_address}"
#       type        = "ssh"
#       user        = "cloud-user"
#       private_key = "${file("~/ya_rsa")}"
#     }
#   provisioner "remote-exec" {
#     inline = ["sudo yum check-update", "sudo yum install python3 -y", "echo Done!"]
#    }
# }

# resource "null_resource" "ansible_provision" {
#    provisioner "local-exec" {
#      command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u opc -i '${oci_core_instance.OpenVPN.public_ip},' --private-key ${var.ssh_key_private} ansible/openvpn-server.yml"
#    }
# }

output "Private-ip-address" {
  value = oci_core_instance.OpenVPN.private_ip
}

output "public-ip-address" {
  value = oci_core_instance.OpenVPN.public_ip
}

output "all-availability-domains-in-your-tenancy" {
  value = data.oci_identity_availability_domains.ads.availability_domains
}

#Ubuntu 20.04
#ocid1.image.oc1.eu-frankfurt-1.aaaaaaaakdtauwupkvi54552qmli3ozzj5zdwlhdfzcluphhyawzv7tqeu7q