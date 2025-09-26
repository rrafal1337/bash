#!/bin/bash

# =============================================================================
# OpenVPN Multi-Client Certificate Generator
# =============================================================================
#
# This script generates certificates and configurations for OpenVPN with
# mutual TLS authentication (mTLS). It creates:
# - CA certificate and key
# - Server certificates and configurations
# - Client certificates and configurations
#
# Features:
# - Uses ECDSA for better performance and security
# - Generates complete OpenVPN configs for both servers and clients
# - Supports multiple server instances
# - Configurable number of client certificates
#

# Certificate generation parameters
days_valid=3650        # Certificate validity (10 years)
ecdsa_curve=prime256v1 # ECDSA curve - NIST P-256 for good security/performance
dir="${HOME}/Work/openvpn-mtls"
servers_no=3   # Number of server instances to create
clients_no=500 # Number of client certificates to generate

# OpenVPN configuration parameters
# Choose appropriate cipher based on CPU capabilities:
#ovpn_ciphers="AES-256-GCM"      # For CPUs with AES-NI support
ovpn_ciphers="CHACHA20-POLY1305" # For CPUs without AES-NI
ovpn_port="1010"
ovpn_host="example.org"
ovpn_maxclients="500"

# Generate server OpenVPN configuration
# Arguments:
#   $1 - Server number (1-N)
generate_ovpn_server() {
  cat >server${1}.ovpn <<EOFF
port ${ovpn_port}
proto udp
dev tun0
# Network specified for this configuration
# peers will get IP from there
server 192.168.4.0 255.255.254.0
# Keep IP information in this file
ifconfig-pool-persist server${1}-ipp.txt
# Push routes configuration to clients
# so they will know this network is on this server
push "route 192.168.100.0 255.255.255.0"
push "route 192.168.55.0 255.255.255.0"
push "route 192.168.4.0 255.255.254.0"
# Server set this route locally on server
# so it will know this comes from openvpn
route 192.168.55.0 255.255.255.0
# Configuration from specified clients
# so they can have a peer specific config
# like iroute or something else
client-config-dir ccd
topology subnet
# Test connection every 10 seconds, 120 seconds timeout
keepalive 10 120
# Encryption ciphers
cipher ${ovpn_ciphers}
data-ciphers ${ovpn_ciphers}
# Maximum amount of clients connected
max-clients ${ovpn_maxclients}
# Effective ID and GID for openvpn process
# Have to be removed on some distros like Archlinux
user openvpn
group openvpn
persist-key
persist-tun
status server${1}-status.log
# Be verbose
verb 2
# key-direction 0 for server and 1 for client
key-direction 0
<tls-auth>
$(cat ta.key)
</tls-auth>
<cert>
$(cat server${1}.crt)
</cert>
<ca>
$(cat ca.crt)
</ca>
<key>
$(cat server${1}.key)
</key>
<dh>
$(cat dh.pem)
</dh>
EOFF
}

# Generate client OpenVPN configuration
# Arguments:
#   $1 - Client number (1-N)
generate_ovpn_client() {
  cat >client${1}.ovpn <<EOFF
client
dev tun
proto udp
remote ${ovpn_host} ${ovpn_port}
resolv-retry infinite
nobind
persist-key
persist-tun
# Encryption ciphers
cipher ${ovpn_ciphers}
data-ciphers ${ovpn_ciphers}
# Test connection every 10 seconds, 120 seconds timeout
ping 15
ping-restart 135
# Verification common name of server
# set field to "server1" for CN=server1
verify-x509-name "server1" name
# Native tls way of verification for server certificate
# remote-cert-tls server
# Be verbose
verb 2
# key-direction 0 for server and 1 for client
key-direction 1
<tls-auth>
$(cat ta.key)
</tls-auth>
<cert>
$(cat client${1}.crt)
</cert>
<ca>
$(cat ca.crt)
</ca>
<key>
$(cat client${1}.key)
</key>
EOFF
}

# Main script execution starts here
# Create working directory
mkdir -p "$dir"
cd "$dir" || exit 1

# Generate CA (Certificate Authority) infrastructure
# Uses ECDSA instead of RSA for better performance
openssl ecparam -genkey -name "$ecdsa_curve" -out ca.key
openssl req -new -x509 -days "$days_valid" -key ca.key -out ca.crt -subj "/CN=OpenVPN-CA"

# Generate DH parameters for key exchange
# Still required by OpenVPN even when using ECDSA
openssl dhparam -out dh.pem 2048

# Generate TLS authentication key
# Provides additional protection against DoS attacks
openvpn --genkey secret ta.key

# Generate server certificates and configurations
for ((i = 1; i <= servers_no; i++)); do
  # Create server certificate using ECDSA
  openssl ecparam -genkey -name "$ecdsa_curve" -out server${i}.key
  openssl req -new -key server${i}.key -out server${i}.csr -subj "/CN=server${i}"
  openssl x509 -req -in server${i}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server${i}.crt -days "$days_valid"
  generate_ovpn_server ${i}
done

# Generate client certificates and configurations
for ((i = 1; i <= clients_no; i++)); do
  # Create client certificate using ECDSA
  openssl ecparam -genkey -name "$ecdsa_curve" -out client${i}.key
  openssl req -new -key client${i}.key -out client${i}.csr -subj "/CN=client${i}"
  openssl x509 -req -in client${i}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out client${i}.crt -days "$days_valid"
  generate_ovpn_client ${i}
done
