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
  source_file = "secret_dep.sops.yaml"
}

provider "oci" {
  region           = data.sops_file.secret.data["region"]
  tenancy_ocid     = data.sops_file.secret.data["tenancy"]
  user_ocid        = data.sops_file.secret.data["user"]
  fingerprint      = data.sops_file.secret.data["fingerprint"]
  private_key_path = data.sops_file.secret.data["key_file"]
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
}

# resource "oci_identity_compartment" "openvpn-compartment" {
#     # Required
#     compartment_id = data.sops_file.secret.data["tenancy"]
#     description = "Compartment for Terraform resources."
#     name = "OpenVPN-compartment"
#     freeform_tags = {"App"= "OpenVPN"}
# }

data "oci_identity_compartments" "openvpn_compartments" {
    compartment_id = data.sops_file.secret.data["tenancy"]
    access_level = "ACCESSIBLE"
    name = "OpenVPN"
    state = "ACTIVE"
}

resource "oci_core_vcn" "internal" {
  dns_label      = "internal"
  cidr_block     = "172.16.0.0/20"
  compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
  display_name   = "OpenVPN VCN"
  freeform_tags = {"App"= "OpenVPN"}
}

resource "oci_core_subnet" "openvpn" {
  vcn_id                      = oci_core_vcn.internal.id
  cidr_block                  = "172.16.0.0/24"
  compartment_id              = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
  display_name                = "OpenVPN server subnet"
  dns_label                   = "openvpn"
  route_table_id              = oci_core_route_table.OpenVPN-Server.id
  freeform_tags               = {"App"= "OpenVPN"}
  dhcp_options_id             = oci_core_vcn.internal.default_dhcp_options_id
  security_list_ids           = [oci_core_security_list.OpenVPN_security_list.id]
}

resource "oci_core_route_table" "OpenVPN-Server" {

    compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
    vcn_id = oci_core_vcn.internal.id


    display_name = "OpenVPN Route Table"
    freeform_tags = {"App"= "OpenVPN"}
    route_rules {
        network_entity_id = oci_core_internet_gateway.OpenVPN_internet_gateway.id
        description = "OpenVPN route rule"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
    }
}

resource "oci_core_internet_gateway" "OpenVPN_internet_gateway" {
    compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
    vcn_id = oci_core_vcn.internal.id
    enabled = true
    display_name = "OpenVPN IG"
    freeform_tags = {"App"= "OpenVPN"}
}

resource "oci_core_security_list" "OpenVPN_security_list" {
    compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
    vcn_id = oci_core_vcn.internal.id
    display_name = "OpenVPN Security List"
    freeform_tags = {"App"= "OpenVPN"}
    egress_security_rules {
        protocol    = "6"
        destination = "0.0.0.0/0"
    }
    ingress_security_rules {
        protocol = "6"
        source   = "0.0.0.0/0"
        description = "Allow ssh"
        tcp_options {
            max = "22"
            min = "22"
        }
    }
    ingress_security_rules {
        protocol = 17
        source = "0.0.0.0/0"
        description = "OpenVPN UDP rule"
        udp_options {
            max = 1194
            min = 1194
        }
    }
    ingress_security_rules {
        protocol = 6
        source = "0.0.0.0/0"
        description = "OpenVPN TCP rule"
        tcp_options {
            max = 443
            min = 443
        }
    }
}

resource "oci_core_instance" "OpenVPN" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  compartment_id      = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
  display_name        = "OpenVPN Server"
  shape               = "VM.Standard.E2.1.Micro"
  freeform_tags       = {"App"= "OpenVPN"}

  create_vnic_details {
    subnet_id        = oci_core_subnet.openvpn.id
    display_name     = "OpenVpn Server"
    assign_public_ip = true
    hostname_label   = "openvpn-server"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.image_id[var.region]}"
  }

  metadata = {
    ssh_authorized_keys = "${file(var.ssh_key_public)}"
  }

  connection {
      host        = "${self.public_ip}"
      type        = "ssh"
      user        = "opc"
      private_key = "${file(var.ssh_key_private)}"
    }
  provisioner "remote-exec" {
    inline = ["sudo yum check-update", "sudo yum install python3 -y", "echo Done!"]
   }
}

resource "null_resource" "ansible_provision" {
   provisioner "local-exec" {
     command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u opc -i '${oci_core_instance.OpenVPN.public_ip},' --private-key ${var.ssh_key_private} ansible/openvpn-server.yml"
   }
}

output "comparement" {
  value = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
}

output "private-ip-address" {
  value = oci_core_instance.OpenVPN.private_ip
}

output "public-ip-address" {
  value = oci_core_instance.OpenVPN.public_ip
}

output "all-availability-domains-in-your-tenancy" {
  value = data.oci_identity_availability_domains.ads.availability_domains
}

