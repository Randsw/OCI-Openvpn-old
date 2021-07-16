terraform {
   backend "s3" {
    endpoint                    = "https://frd8bsyrgar7.compat.objectstorage.eu-frankfurt-1.oraclecloud.com"
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    skip_credentials_validation = true
    bucket                      = "tf-state"
    key                         = "openvpn/terraform.tfstate"
    region                      = "eu-frankfurt-1"
  }
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
