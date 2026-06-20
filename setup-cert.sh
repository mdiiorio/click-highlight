#!/bin/bash
# One-time setup: creates a local self-signed code signing certificate.
# This gives the app a stable signing identity so macOS TCC can store
# Screen Recording permission permanently across rebuilds.
set -euo pipefail

CERT_NAME="click-highlight-dev"
KEYCHAIN=~/Library/Keychains/login.keychain-db

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "Certificate '$CERT_NAME' already exists — nothing to do."
    exit 0
fi

echo "Creating self-signed code-signing certificate '$CERT_NAME'..."

TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

cat > "$TMP/cert.cfg" << EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $CERT_NAME
[ext]
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
EOF

# Use system LibreSSL — Homebrew OpenSSL 3.x produces PKCS12 that security import rejects
/usr/bin/openssl req -x509 -newkey rsa:2048 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -config "$TMP/cert.cfg" 2>/dev/null

/usr/bin/openssl pkcs12 -export \
    -out "$TMP/cert.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -passout pass:build -name "$CERT_NAME" 2>/dev/null

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "build" -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign "$TMP/cert.pem"

echo ""
echo "Done. Certificate '$CERT_NAME' is ready."
echo "You may see a keychain prompt on the first build — enter your login password."
