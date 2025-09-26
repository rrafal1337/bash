#!/bin/bash
set -euo pipefail

# =============================================================================
# VictoriaMetrics mTLS Certificate Generator
# =============================================================================
#
# This script generates a complete PKI infrastructure for VictoriaMetrics with
# mutual TLS authentication (mTLS). It creates:
# - Root CA certificate for signing all other certificates
# - Server certificates for VictoriaMetrics instances
# - Client certificates for monitoring agents
#
# Features:
# - Uses modern ECDSA (P-384 for CA, P-256 for entities)
# - Supports both DNS names and IP addresses for servers
# - Proper certificate extensions for mTLS
# - Automatic key and CSR generation
#

# ==== CONFIGURATION ====

# CA settings
CA_COMMON_NAME="VictoriaMetrics" # Name for the Certificate Authority
CA_DAYS=3650                     # CA validity (10 years)

# Entity certificate duration (slightly less than CA to ensure validity)
ENTITY_DAYS=3649 # Entity certs valid for ~10 years

# Server and client tuples (format: "name:ip" or just "name" for DNS-only)
# Servers need both DNS and IP for proper certificate validation
SERVERS=(
  "victoriametrics:192.168.55.1"
)

# Clients only need DNS names as they are identified by hostname
CLIENTS=(
  "falcon"
  "seagull"
  "stork"
  "nightingale"
  "eagle"
  "lark"
  "harrier"
  "owl"
)

# Create directory for storing certificates
CERT_DIR="victoriametrics-mtls"
mkdir -p "$CERT_DIR"

# Define paths for CA files
CA_KEY="$CERT_DIR/ca.key"
CA_CERT="$CERT_DIR/ca.crt"

# ==== CREATE CA ====
# Check if CA already exists to prevent accidental overwrite
if [[ -f "$CA_KEY" && -f "$CA_CERT" ]]; then
  echo "🔐 CA already exists: $CA_KEY, $CA_CERT"
else
  # Generate new CA using ECDSA P-384 for higher security
  echo "🔐 Generating ECDSA P-384 CA certificate: CN=$CA_COMMON_NAME ..."
  openssl ecparam -name secp384r1 -genkey -noout -out "$CA_KEY"
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days "$CA_DAYS" \
    -subj "/CN=$CA_COMMON_NAME" -out "$CA_CERT"
fi

# ==== FUNCTION: GENERATE ENTITY CERT ====
# Arguments:
#   $1 - Entity name (and optional IP in format "name:ip")
#   $2 - Type ("server" or "client") for proper cert extensions
generate_cert() {
  local ENTITY="$1"
  local TYPE="$2" # "server" or "client"

  # Split name and IP
  local NAME
  local IP
  IFS=':' read -r NAME IP <<<"$ENTITY"

  ENTITY_KEY="$CERT_DIR/${NAME}.key"
  ENTITY_CSR="$CERT_DIR/${NAME}.csr"
  ENTITY_CERT="$CERT_DIR/${NAME}.crt"
  ENTITY_CONF="$CERT_DIR/${NAME}.cnf"

  if [[ -f "$ENTITY_KEY" && -f "$ENTITY_CERT" ]]; then
    echo "✅ Certificate for $NAME ($TYPE) already exists: $ENTITY_CERT"
    return
  fi

  echo "📄 Generating certificate for $NAME ($TYPE)"

  # Generate ECDSA key
  openssl ecparam -name prime256v1 -genkey -noout -out "$ENTITY_KEY"

  # Create OpenSSL config with conditional IP
  cat >"$ENTITY_CONF" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $NAME

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = ${TYPE}Auth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $NAME
EOF

  # Add IP if provided
  if [[ -n "$IP" ]]; then
    echo "IP.1 = $IP" >>"$ENTITY_CONF"
  fi

  # Create CSR
  openssl req -new -key "$ENTITY_KEY" -out "$ENTITY_CSR" -config "$ENTITY_CONF"

  # Sign cert
  openssl x509 -req -in "$ENTITY_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$ENTITY_CERT" -days "$ENTITY_DAYS" -sha256 \
    -extensions v3_req -extfile "$ENTITY_CONF"

  echo "✅ Created: $ENTITY_CERT"
}

# ==== GENERATE SERVER CERTS ====
# Create certificates for each VictoriaMetrics server instance
for NAME in "${SERVERS[@]}"; do
  generate_cert "$NAME" "server"
done

# ==== GENERATE CLIENT CERTS ====
# Create certificates for each monitoring agent
for NAME in "${CLIENTS[@]}"; do
  generate_cert "$NAME" "client"
done

echo "🎉 All certificates created in: $CERT_DIR"
