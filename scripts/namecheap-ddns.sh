#!/bin/sh
set -eu

config_file="${NAMECHEAP_DDNS_CONFIG:-/run/namecheap-ddns.env}"
if [ -f "$config_file" ]; then
  # shellcheck disable=SC1090
  . "$config_file"
fi

decode() {
  var_name="$1"
  eval "encoded=\${$var_name:-}"
  if [ -n "$encoded" ]; then
    printf '%s' "$encoded" | base64 -d
  fi
}

host="${NAMECHEAP_DDNS_HOST:-$(decode NAMECHEAP_DDNS_HOST_B64)}"
domain="${NAMECHEAP_DDNS_DOMAIN:-$(decode NAMECHEAP_DDNS_DOMAIN_B64)}"
password="${NAMECHEAP_DDNS_PASSWORD:-$(decode NAMECHEAP_DDNS_PASSWORD_B64)}"
ip="${NAMECHEAP_DDNS_IP:-$(decode NAMECHEAP_DDNS_IP_B64)}"
endpoint="${NAMECHEAP_DDNS_ENDPOINT:-$(decode NAMECHEAP_DDNS_ENDPOINT_B64)}"
dry_run="${NAMECHEAP_DDNS_DRY_RUN:-$(decode NAMECHEAP_DDNS_DRY_RUN_B64)}"
ddns_enabled="${DDNS_ENABLED:-$(decode DDNS_ENABLED_B64)}"

endpoint="${endpoint:-https://dynamicdns.park-your-domain.com/update}"
dry_run="${dry_run:-false}"
ddns_enabled="${ddns_enabled:-false}"

case "$ddns_enabled" in
  true|TRUE|1|yes|YES)
    ;;
  *)
    echo "namecheap-ddns: disabled by DDNS_ENABLED=$ddns_enabled"
    exit 0
    ;;
esac

if [ -z "$host" ] || [ -z "$domain" ] || [ -z "$password" ]; then
  echo "namecheap-ddns: NAMECHEAP_DDNS_HOST, NAMECHEAP_DDNS_DOMAIN, and NAMECHEAP_DDNS_PASSWORD are required" >&2
  exit 64
fi

ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fqdn="$domain"
if [ "$host" != "@" ]; then
  fqdn="$host.$domain"
fi

echo "namecheap-ddns: $ts updating host=$host domain=$domain fqdn=$fqdn"

if [ "$dry_run" = "true" ]; then
  echo "namecheap-ddns: dry run enabled; request not sent"
  exit 0
fi

response_file="$(mktemp)"
cleanup() {
  rm -f "$response_file"
}
trap cleanup EXIT

set -- \
  --silent \
  --show-error \
  --fail \
  --get \
  --connect-timeout 10 \
  --max-time 30 \
  --data-urlencode "host=$host" \
  --data-urlencode "domain=$domain" \
  --data-urlencode "password=$password"

if [ -n "$ip" ]; then
  set -- "$@" --data-urlencode "ip=$ip"
fi

# Intentionally do not print the full URL; it contains the DDNS password.
# Namecheap returns XML with ErrCount=0 on success.
curl "$@" "$endpoint" > "$response_file"

if grep -q '<ErrCount>0</ErrCount>' "$response_file"; then
  current_ip="$(sed -n 's:.*<IP>\([^<]*\)</IP>.*:\1:p' "$response_file" | head -n 1)"
  if [ -n "$current_ip" ]; then
    echo "namecheap-ddns: update accepted; ip=$current_ip"
  else
    echo "namecheap-ddns: update accepted"
  fi
  exit 0
fi

echo "namecheap-ddns: update failed; response follows" >&2
cat "$response_file" >&2
exit 1
