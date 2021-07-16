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

resource "oci_dns_zone" "openvpn_zone" {
    compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
    name = "rand-vpn.tk"
    zone_type = "PRIMARY"
    freeform_tags = {"App"= "OpenVPN"}
}

resource "oci_dns_rrset" "openvpn-server" {
    domain = "rand-vpn.tk"
    rtype = "A"
    zone_name_or_id = oci_dns_zone.openvpn_zone.id

    compartment_id = data.oci_identity_compartments.openvpn_compartments.compartments[0].id
    items {
        domain = oci_dns_zone.openvpn_zone.name
        rdata = oci_core_instance.OpenVPN.public_ip
        rtype = "A"
        ttl = 3600
    }
}