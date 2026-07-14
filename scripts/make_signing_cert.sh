#!/bin/zsh
set -euo pipefail

# Generates a STABLE self-signed code-signing certificate (no Apple Developer
# account required) and prints the values to paste into GitHub repository
# Secrets so every release is signed with the same identity.
#
# A stable identity keeps macOS "Input Monitoring" permission across updates.
# It does NOT remove the Gatekeeper first-launch warning and cannot be
# notarized -- only a paid Developer ID can do that.
#
# Usage:
#   zsh scripts/make_signing_cert.sh
#
# Then add to Settings -> Secrets and variables -> Actions:
#   MACOS_CERT_P12       = the printed base64 blob
#   MACOS_CERT_PASSWORD  = the printed password
#
# Keep signing-cert.p12 (and this password) safe: reusing the SAME cert on
# future releases is what preserves the permission. Losing it just means one
# more re-grant after you generate a new one.

IDENTITY_NAME="${IDENTITY_NAME:-KeyboardWaiter Signing}"
OUT_DIR="${OUT_DIR:-$(cd "$(dirname "$0")/.." && pwd)/dist}"
P12_PATH="$OUT_DIR/signing-cert.p12"
P12_PASSWORD="${P12_PASSWORD:-$(openssl rand -base64 18 | tr -d '\n')}"

TEMP_DIR="$(mktemp -d /tmp/keyboard_waiter_cert.XXXXXX)"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

mkdir -p "$OUT_DIR"

cat > "$TEMP_DIR/openssl.cnf" <<EOF
[ req ]
default_bits = 2048
prompt = no
distinguished_name = dn
x509_extensions = v3_codesign

[ dn ]
CN = $IDENTITY_NAME

[ v3_codesign ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl req \
    -new -newkey rsa:2048 -x509 -sha256 -days 3650 -nodes \
    -config "$TEMP_DIR/openssl.cnf" \
    -keyout "$TEMP_DIR/key.pem" \
    -out "$TEMP_DIR/cert.pem" >/dev/null 2>&1

# macOS `security import` needs the legacy PKCS#12 encryption algorithms.
pkcs12_legacy_args=()
if openssl pkcs12 -help 2>&1 | grep -q -- '-legacy'; then
    pkcs12_legacy_args=(-legacy)
fi

openssl pkcs12 -export \
    "${pkcs12_legacy_args[@]}" \
    -inkey "$TEMP_DIR/key.pem" \
    -in "$TEMP_DIR/cert.pem" \
    -out "$P12_PATH" \
    -name "$IDENTITY_NAME" \
    -certpbe PBE-SHA1-3DES \
    -keypbe PBE-SHA1-3DES \
    -macalg sha1 \
    -passout "pass:$P12_PASSWORD"

chmod 600 "$P12_PATH"

echo "Created $P12_PATH"
echo
echo "=== GitHub Secret: MACOS_CERT_PASSWORD ==="
echo "$P12_PASSWORD"
echo
echo "=== GitHub Secret: MACOS_CERT_P12 (base64) ==="
base64 < "$P12_PATH"
echo
echo "Add both as repository Actions secrets, then push a tag to release."
echo "Reuse the SAME signing-cert.p12 for every release to keep permissions."
