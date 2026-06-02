#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
SERVER_TEMPLATE="$PROJECT_ROOT/config/xray/server.template.json"
SERVER_CONFIG="$PROJECT_ROOT/config/xray/server.json"
XRAY_IMAGE_DEFAULT="ghcr.io/xtls/xray-core:26.5.9"

cd "$PROJECT_ROOT"

say() {
  printf '\n%s\n' "$*" >&2
}

note() {
  printf '%s\n' "$*" >&2
}

die() {
  printf 'quick-setup: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

is_yes() {
  case "$1" in
    y|Y|yes|YES|true|TRUE|1) return 0 ;;
    *) return 1 ;;
  esac
}

env_get() {
  key="$1"
  [ -f "$ENV_FILE" ] || return 0
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE"
}

env_set() {
  key="$1"
  value="$2"
  tmp="$ENV_FILE.tmp"
  touch "$ENV_FILE"
  awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      found = 1
      next
    }
    { print }
    END {
      if (!found) {
        print key "=" value
      }
    }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
}

json_get() {
  filter="$1"
  [ -f "$SERVER_CONFIG" ] || return 0
  jq -r "$filter // empty" "$SERVER_CONFIG" 2>/dev/null || true
}

prompt() {
  label="$1"
  current="$2"
  help="$3"
  required="${4:-false}"

  say "$label"
  note "$help"
  if [ -n "$current" ]; then
    printf 'Current/default: %s\n' "$current" >&2
  fi

  while :; do
    printf '> ' >&2
    IFS= read -r answer
    if [ -z "$answer" ]; then
      answer="$current"
    fi
    if [ "$required" = "true" ] && [ -z "$answer" ]; then
      note "This value is required."
      continue
    fi
    printf '%s' "$answer"
    return 0
  done
}

prompt_bool() {
  label="$1"
  current="$2"
  help="$3"

  case "$current" in
    true|TRUE|1|yes|YES) current="true" ;;
    false|FALSE|0|no|NO|"") current="false" ;;
  esac

  say "$label"
  note "$help"
  printf 'Current/default: %s\n' "$current" >&2
  while :; do
    printf 'Enter true or false: ' >&2
    IFS= read -r answer
    [ -n "$answer" ] || answer="$current"
    case "$answer" in
      true|TRUE|1|yes|YES) printf 'true'; return 0 ;;
      false|FALSE|0|no|NO) printf 'false'; return 0 ;;
      *) note "Please enter true or false." ;;
    esac
  done
}

prompt_secret() {
  label="$1"
  current="$2"
  help="$3"
  required="${4:-false}"

  say "$label"
  note "$help"
  if [ -n "$current" ]; then
    note "Current/default: already set; press Enter to keep it."
  fi

  while :; do
    printf '> ' >&2
    stty -echo 2>/dev/null || true
    IFS= read -r answer
    stty echo 2>/dev/null || true
    printf '\n' >&2
    if [ -z "$answer" ]; then
      answer="$current"
    fi
    if [ "$required" = "true" ] && [ -z "$answer" ]; then
      note "This value is required."
      continue
    fi
    printf '%s' "$answer"
    return 0
  done
}

prompt_or_generate() {
  label="$1"
  current="$2"
  help="$3"
  generator="$4"
  required="${5:-true}"

  say "$label"
  note "$help"
  note "Press Enter to keep the current/default value, type a new value to overwrite it, or type generate to create a new one."
  if [ -n "$current" ]; then
    printf 'Current/default: %s\n' "$current" >&2
  fi

  while :; do
    printf '> ' >&2
    IFS= read -r answer
    if [ -z "$answer" ]; then
      answer="$current"
    fi
    if [ "$answer" = "generate" ]; then
      answer="$($generator)"
      note "Generated value: $answer"
    fi
    if [ "$required" = "true" ] && [ -z "$answer" ]; then
      note "This value is required."
      continue
    fi
    printf '%s' "$answer"
    return 0
  done
}

xray() {
  docker run --rm --entrypoint xray "$XRAY_IMAGE" "$@"
}

generate_uuid() {
  xray uuid | tr -d '\r\n'
}

generate_x25519() {
  xray x25519
}

public_from_private() {
  private_key="$1"
  xray x25519 -i "$private_key" | awk -F': ' '/Password \(PublicKey\)/ { print $2; exit }'
}

generate_short_id() {
  openssl rand -hex 8 | tr -d '\r\n'
}

validate_dependencies() {
  [ -f "$ENV_FILE" ] || cp "$ENV_EXAMPLE" "$ENV_FILE"

  need_cmd jq || die "jq is required. On macOS: brew install jq"
  need_cmd openssl || die "openssl is required."

  if ! need_cmd docker; then
    if [ "$(uname -s)" = "Darwin" ]; then
      cat >&2 <<'EOF'
Docker is not available.

For macOS, install OrbStack:
1. Download: https://orbstack.dev/
2. Open OrbStack once after install.
3. Confirm in a new terminal:
   docker version
   docker compose version

Then rerun:
   scripts/quick-setup.sh
EOF
      exit 1
    fi
    die "docker is required. Install Docker Engine and rerun this wizard."
  fi

  docker version >/dev/null 2>&1 || {
    if [ "$(uname -s)" = "Darwin" ]; then
      cat >&2 <<'EOF'
Docker CLI exists but cannot reach the Docker daemon.

For macOS/OrbStack:
1. Open the OrbStack app.
2. Wait until Docker is running.
3. Confirm:
   docker version
   docker compose version

Then rerun:
   scripts/quick-setup.sh
EOF
      exit 1
    fi
    die "docker cannot reach the Docker daemon."
  }
}

write_server_config() {
  port="$1"
  uuid="$2"
  target_domain="$3"
  private_key="$4"
  short_id="$5"

  jq \
    --argjson port "$port" \
    --arg uuid "$uuid" \
    --arg target_domain "$target_domain" \
    --arg private_key "$private_key" \
    --arg short_id "$short_id" \
    '
      .inbounds[0].port = $port
      | .inbounds[0].settings.users[0].id = $uuid
      | .inbounds[0].streamSettings.realitySettings.target = ($target_domain + ":443")
      | .inbounds[0].streamSettings.realitySettings.serverNames = [$target_domain]
      | .inbounds[0].streamSettings.realitySettings.privateKey = $private_key
      | .inbounds[0].streamSettings.realitySettings.shortIds = [$short_id]
    ' "$SERVER_TEMPLATE" > "$SERVER_CONFIG.tmp"
  mv "$SERVER_CONFIG.tmp" "$SERVER_CONFIG"
  chmod 0600 "$SERVER_CONFIG"
}

print_client_link() {
  public_host="$1"
  external_port="$2"
  uuid="$3"
  target_domain="$4"
  public_key="$5"
  short_id="$6"

  printf 'vless://%s@%s:%s?encryption=none&flow=xtls-rprx-vision&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp&headerType=none#home-xray-reality\n' \
    "$uuid" "$public_host" "$external_port" "$target_domain" "$public_key" "$short_id"
}

validate_port_number() {
  value="$1"
  case "$value" in
    *[!0-9]*|"") return 1 ;;
  esac
  [ "$value" -ge 1 ] && [ "$value" -le 65535 ]
}

main() {
  say "VLESS REALITY quick setup wizard"
  note "This wizard is safe to rerun. Existing .env and server.json values are used as defaults, and you can keep or replace each value."

  validate_dependencies

  existing_image="$(env_get XRAY_IMAGE)"
  XRAY_IMAGE="$(prompt "Xray Docker image" "${existing_image:-$XRAY_IMAGE_DEFAULT}" "Used for the Xray server and for generating UUID / REALITY keys. Keep the pinned tag unless you intentionally upgrade Xray." true)"
  env_set XRAY_IMAGE "$XRAY_IMAGE"

  say "Pull Xray image"
  note "This verifies Docker access and ensures key generation uses the same image tag as the server."
  if is_yes "$(prompt_bool "Pull now?" "true" "Set false only if this machine has no network right now.")"; then
    docker pull "$XRAY_IMAGE"
  fi

  existing_project="$(env_get COMPOSE_PROJECT_NAME)"
  compose_project="$(prompt "Compose project name" "${existing_project:-vless-reality-vpn}" "A local Docker Compose name. It only affects Docker labels/network names, not the VPN protocol." true)"
  env_set COMPOSE_PROJECT_NAME "$compose_project"

  current_port="$(json_get '.inbounds[0].port')"
  if [ "$(uname -s)" = "Darwin" ]; then
    say "macOS / OrbStack note"
    cat >&2 <<'EOF'
On macOS, binding privileged ports such as 443 can fail with permission denied.
The recommended home setup is:

  router WAN TCP 443 -> Mac mini LAN TCP 8443
  Xray listens on 8443
  clients still connect to YOUR_PUBLIC_HOST:443

OrbStack install guide if Docker is missing:
  https://orbstack.dev/
EOF
    default_port="${current_port:-8443}"
  else
    default_port="${current_port:-443}"
  fi

  while :; do
    internal_port="$(prompt "Xray internal listen port" "$default_port" "This is the port Xray binds on the server. On macOS use 8443 and forward router external 443 to internal 8443." true)"
    validate_port_number "$internal_port" && break
    note "Port must be an integer from 1 to 65535."
  done

  current_uuid="$(json_get '.inbounds[0].settings.users[0].id')"
  client_uuid="$(prompt_or_generate "VLESS UUID" "$current_uuid" "The UUID authenticates the client. Existing clients must use this exact value. Type generate only when rotating credentials." generate_uuid true)"

  current_target="$(json_get '.inbounds[0].streamSettings.realitySettings.serverNames[0]')"
  target_domain="$(prompt "REALITY target / SNI domain" "$current_target" "This is not your VPN hostname. It is the TLS SNI used by REALITY. Avoid Cloudflare/free CDN targets unless you understand fallback abuse risk." true)"

  current_private="$(json_get '.inbounds[0].streamSettings.realitySettings.privateKey')"
  say "REALITY private key"
  note "The server stores this private key. Clients use the derived public key. Press Enter to keep the current/default value, paste a private key to overwrite it, or type generate to create a new key pair."
  if [ -n "$current_private" ]; then
    printf 'Current/default: %s\n' "$current_private" >&2
  fi
  while :; do
    printf '> ' >&2
    IFS= read -r key_answer
    if [ -z "$key_answer" ]; then
      key_answer="$current_private"
    fi
    if [ "$key_answer" = "generate" ]; then
      key_output="$(generate_x25519)"
      reality_private="$(printf '%s\n' "$key_output" | awk -F': ' '/PrivateKey/ { print $2; exit }')"
      reality_public="$(printf '%s\n' "$key_output" | awk -F': ' '/Password \(PublicKey\)/ { print $2; exit }')"
      [ -n "$reality_private" ] && [ -n "$reality_public" ] || die "failed to parse x25519 key output"
      note "Generated REALITY private key: $reality_private"
      note "Generated REALITY public key: $reality_public"
      break
    fi
    if [ -z "$key_answer" ]; then
      note "This value is required."
      continue
    fi
    reality_private="$key_answer"
    reality_public="$(public_from_private "$reality_private" 2>/dev/null || true)"
    if [ -z "$reality_public" ]; then
      note "Could not derive a public key from that private key. Paste a valid Xray REALITY private key or type generate."
      continue
    fi
    note "Derived REALITY public key: $reality_public"
    break
  done

  current_short_id="$(json_get '.inbounds[0].streamSettings.realitySettings.shortIds[0]')"
  short_id="$(prompt_or_generate "REALITY short ID" "$current_short_id" "The short ID is a small client/server matching token. Existing clients must use this exact value. Type generate only when rotating credentials." generate_short_id true)"

  existing_public_host="$(env_get VPN_PUBLIC_HOST)"
  public_host="$(prompt "Client public host" "$existing_public_host" "The hostname or public IP clients connect to. If using Namecheap DDNS, this is usually vpn.example.com or your bare domain." false)"
  env_set VPN_PUBLIC_HOST "$public_host"

  existing_external_port="$(env_get VPN_PUBLIC_PORT)"
  while :; do
    external_port="$(prompt "Client external port" "${existing_external_port:-443}" "The router/WAN port clients connect to. With macOS workaround, this stays 443 while Xray listens internally on 8443." true)"
    validate_port_number "$external_port" && break
    note "Port must be an integer from 1 to 65535."
  done
  env_set VPN_PUBLIC_PORT "$external_port"

  write_server_config "$internal_port" "$client_uuid" "$target_domain" "$reality_private" "$short_id"

  say "Namecheap Dynamic DNS"
  ddns_enabled="$(prompt_bool "Enable Namecheap DDNS?" "$(env_get DDNS_ENABLED)" "Optional. If false, the DDNS container will not send updates even if started.")"
  env_set DDNS_ENABLED "$ddns_enabled"
  if is_yes "$ddns_enabled"; then
    ddns_host="$(prompt "Namecheap DDNS host" "$(env_get NAMECHEAP_DDNS_HOST)" "Use @ for the bare domain, or only the subdomain label such as vpn for vpn.example.com." true)"
    ddns_domain="$(prompt "Namecheap domain" "$(env_get NAMECHEAP_DDNS_DOMAIN)" "The registered domain at Namecheap, for example example.com." true)"
    ddns_password="$(prompt_secret "Namecheap DDNS password" "$(env_get NAMECHEAP_DDNS_PASSWORD)" "Use the Dynamic DNS password from Advanced DNS, not your Namecheap account password." true)"
    ddns_ip="$(prompt "Optional explicit DDNS IP" "$(env_get NAMECHEAP_DDNS_IP)" "Leave empty so Namecheap uses the public IP of this request." false)"
    ddns_cron="$(prompt "DDNS cron schedule" "$(env_get NAMECHEAP_DDNS_CRON)" "Default */15 * * * * means every 15 minutes." true)"
    ddns_dry_run="$(prompt_bool "DDNS dry run?" "$(env_get NAMECHEAP_DDNS_DRY_RUN)" "Use true for the first test; set false when ready to send real updates.")"

    env_set NAMECHEAP_DDNS_HOST "$ddns_host"
    env_set NAMECHEAP_DDNS_DOMAIN "$ddns_domain"
    env_set NAMECHEAP_DDNS_PASSWORD "$ddns_password"
    env_set NAMECHEAP_DDNS_IP "$ddns_ip"
    env_set NAMECHEAP_DDNS_CRON "$ddns_cron"
    env_set NAMECHEAP_DDNS_ENDPOINT "$(env_get NAMECHEAP_DDNS_ENDPOINT)"
    if [ -z "$(env_get NAMECHEAP_DDNS_ENDPOINT)" ]; then
      env_set NAMECHEAP_DDNS_ENDPOINT "https://dynamicdns.park-your-domain.com/update"
    fi
    env_set NAMECHEAP_DDNS_DRY_RUN "$ddns_dry_run"
  fi

  say "Validate generated files"
  jq empty "$SERVER_CONFIG"
  docker compose config >/dev/null

  if is_yes "$(prompt_bool "Build Namecheap DDNS image now?" "$ddns_enabled" "Builds the small cron container. It is only needed when DDNS is enabled.")"; then
    docker compose --profile ddns build namecheap-ddns
  fi

  say "Setup complete"
  note "Generated/updated:"
  note "  $ENV_FILE"
  note "  $SERVER_CONFIG"

  if [ -n "$public_host" ]; then
    say "Client VLESS link"
    print_client_link "$public_host" "$external_port" "$client_uuid" "$target_domain" "$reality_public" "$short_id"
  else
    say "Client values"
    note "Public host was left empty, so no complete link was printed."
    note "UUID: $client_uuid"
    note "SNI: $target_domain"
    note "Public key: $reality_public"
    note "Short ID: $short_id"
    note "External port: $external_port"
  fi

  say "Next commands"
  note "Validate Xray config:"
  note "  docker compose run --rm xray run -test -config /etc/xray/config.json"
  note "Start Xray:"
  note "  docker compose up -d"
  if is_yes "$ddns_enabled"; then
    note "Start DDNS:"
    note "  docker compose --profile ddns up -d --build namecheap-ddns"
    note "Watch DDNS logs:"
    note "  docker logs -f namecheap-ddns"
  fi
}

main "$@"
