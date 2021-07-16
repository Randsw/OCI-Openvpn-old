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