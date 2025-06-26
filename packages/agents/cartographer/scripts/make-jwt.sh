#!/usr/bin/env bash
# make-jwt.sh – generate an HS256 JWT for the `api` role used by PostgREST
# Requires: openssl (present on any macOS / Linux)

set -euo pipefail

########################################
# pick up the secret
########################################
SECRET="${1:-${PGRST_JWT_SECRET:-}}"
if [[ -z "$SECRET" ]]; then
    echo "Usage: PGRST_JWT_SECRET=secret $0            # or"
    echo "       $0 secret"
    exit 1
fi

########################################
# helper: base64url-encode without padding
########################################
b64url() {
    # shellcheck disable=SC2046
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

########################################
# header & payload
########################################
header='{"alg":"HS256","typ":"JWT"}'
payload='{"role":"api"}' # add any extra claims you need

########################################
# base64url encode them
########################################
header_b64=$(printf '%s' "$header" | b64url)
payload_b64=$(printf '%s' "$payload" | b64url)

########################################
# sign   (HMAC-SHA256)
########################################
sig=$(printf '%s.%s' "$header_b64" "$payload_b64" |
    openssl dgst -binary -sha256 -hmac "$SECRET" | b64url)

echo "${header_b64}.${payload_b64}.${sig}"
