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
}