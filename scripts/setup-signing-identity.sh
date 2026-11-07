#!/bin/zsh
set -euo pipefail

identity_name=${LINEFEED_LOCAL_IDENTITY_NAME:-"Linefeed Local Development"}
root_name=${LINEFEED_LOCAL_ROOT_NAME:-"Linefeed Local Signing Root"}
keychain_path=${LINEFEED_KEYCHAIN_PATH:-$(security default-keychain -d user | tr -d '"')}

if security find-identity -v -p codesigning "$keychain_path" | grep -Fq "\"$identity_name\""; then
  print "Code-signing identity already available: $identity_name"
  exit 0
fi

existing_certificate=$(security find-certificate -a -c "$identity_name" -Z "$keychain_path")
if [[ -n "$existing_certificate" ]]; then
  print -u2 "A certificate named '$identity_name' exists but is not a valid code-signing identity."
  print -u2 "Remove or rename that certificate before running this setup again."
  exit 1
fi

existing_root=$(security find-certificate -a -c "$root_name" -Z "$keychain_path")
if [[ -n "$existing_root" ]]; then
  print -u2 "A root certificate named '$root_name' already exists without a valid Linefeed identity."
  print -u2 "Remove that stale certificate before running this setup again."
  exit 1
fi

signing_work_dir=$(mktemp -d /tmp/linefeed-signing-XXXXXX)
root_private_key="$signing_work_dir/linefeed-root.key"
root_certificate="$signing_work_dir/linefeed-root.crt"
private_key="$signing_work_dir/linefeed-development.key"
certificate_request="$signing_work_dir/linefeed-development.csr"
certificate="$signing_work_dir/linefeed-development.crt"
identity_archive="$signing_work_dir/linefeed-signing.p12"
archive_passphrase=$(openssl rand -hex 24)

cleanup() {
  rm -rf "$signing_work_dir"
}
trap cleanup EXIT

openssl req \
  -x509 \
  -newkey rsa:3072 \
  -sha256 \
  -days 3650 \
  -nodes \
  -subj "/CN=$root_name/O=Linefeed/OU=Local Development" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -keyout "$root_private_key" \
  -out "$root_certificate" \
  >/dev/null 2>&1

openssl req \
  -new \
  -newkey rsa:3072 \
  -sha256 \
  -nodes \
  -subj "/CN=$identity_name/O=Linefeed/OU=Local Development" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -keyout "$private_key" \
  -out "$certificate_request" \
  >/dev/null 2>&1

openssl x509 \
  -req \
  -in "$certificate_request" \
  -CA "$root_certificate" \
  -CAkey "$root_private_key" \
  -CAcreateserial \
  -days 3650 \
  -sha256 \
  -copy_extensions copy \
  -out "$certificate" \
  >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -legacy \
  -name "$identity_name" \
  -inkey "$private_key" \
  -in "$certificate" \
  -certfile "$root_certificate" \
  -passout "pass:$archive_passphrase" \
  -out "$identity_archive" \
  >/dev/null 2>&1

security import "$identity_archive" \
  -k "$keychain_path" \
  -f pkcs12 \
  -P "$archive_passphrase" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  >/dev/null

security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$keychain_path" \
  "$root_certificate"

identity_hash=$(
  security find-identity -v -p codesigning "$keychain_path" \
    | awk -v name="$identity_name" 'index($0, "\"" name "\"") { print $2; exit }'
)

if [[ -z "$identity_hash" ]]; then
  print -u2 "The certificate was imported, but macOS did not accept it as a valid code-signing identity."
  exit 1
fi

print "Installed stable local code-signing identity: $identity_name ($identity_hash)"
