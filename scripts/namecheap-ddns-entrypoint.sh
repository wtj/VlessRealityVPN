#!/bin/sh
set -eu

cron_expr="${NAMECHEAP_DDNS_CRON:-*/15 * * * *}"
ddns_enabled="${DDNS_ENABLED:-false}"

case "$ddns_enabled" in
  true|TRUE|1|yes|YES)
    ;;
  *)
    echo "namecheap-ddns: disabled by DDNS_ENABLED=$ddns_enabled"
    exec sleep infinity
    ;;
esac

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    echo "missing required environment variable: $name" >&2
    exit 64
  fi
}

b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

require_env NAMECHEAP_DDNS_HOST
require_env NAMECHEAP_DDNS_DOMAIN
require_env NAMECHEAP_DDNS_PASSWORD

umask 077
{
  printf 'NAMECHEAP_DDNS_HOST_B64=%s\n' "$(b64 "$NAMECHEAP_DDNS_HOST")"
  printf 'NAMECHEAP_DDNS_DOMAIN_B64=%s\n' "$(b64 "$NAMECHEAP_DDNS_DOMAIN")"
  printf 'NAMECHEAP_DDNS_PASSWORD_B64=%s\n' "$(b64 "$NAMECHEAP_DDNS_PASSWORD")"
  printf 'NAMECHEAP_DDNS_IP_B64=%s\n' "$(b64 "${NAMECHEAP_DDNS_IP:-}")"
  printf 'NAMECHEAP_DDNS_ENDPOINT_B64=%s\n' "$(b64 "${NAMECHEAP_DDNS_ENDPOINT:-https://dynamicdns.park-your-domain.com/update}")"
  printf 'NAMECHEAP_DDNS_DRY_RUN_B64=%s\n' "$(b64 "${NAMECHEAP_DDNS_DRY_RUN:-false}")"
  printf 'DDNS_ENABLED_B64=%s\n' "$(b64 "$ddns_enabled")"
} > /run/namecheap-ddns.env

cat > /etc/crontabs/root <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
$cron_expr /usr/local/bin/namecheap-ddns >> /proc/1/fd/1 2>> /proc/1/fd/2
EOF

echo "namecheap-ddns: cron installed: $cron_expr"
echo "namecheap-ddns: running one startup update"
/usr/local/bin/namecheap-ddns

exec "$@"
