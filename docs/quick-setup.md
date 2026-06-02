# Quick Setup Wizard

Run:

```sh
scripts/quick-setup.sh
```

The wizard is safe to rerun. It reads existing `.env` and
`config/xray/server.json` values as defaults, then asks whether to keep or
replace each value.

For editable values, the interaction model is:

- Press Enter to keep the current/default value.
- Type a new value to overwrite it.
- For UUID, REALITY private key, and short ID, type `generate` to rotate the
  value.

## What It Configures

- Xray Docker image tag.
- Docker Compose project name.
- Xray internal listen port.
- VLESS client UUID.
- REALITY target / SNI domain.
- REALITY private/public key pair.
- REALITY short ID.
- Optional public hostname and external port for printing the client link.
- Optional Namecheap Dynamic DNS settings.

## macOS / OrbStack Guidance

If Docker is not available on macOS, the wizard prints OrbStack installation
guidance and exits. It does not install OrbStack automatically.

On macOS, binding privileged ports such as `443` may fail with permission
denied. The wizard therefore explains this recommended layout:

```text
router WAN TCP 443 -> Mac mini LAN TCP 8443
Xray listens on 8443
clients connect to YOUR_PUBLIC_HOST:443
```

## Repeat Runs

Use repeat runs to fix mistakes:

- Press Enter to keep a current/default value.
- Type a replacement value to overwrite a wrong setting.
- Type `generate` at UUID, REALITY private key, or short ID prompts to rotate
  credentials.
- Re-enter the REALITY target if the SNI domain was wrong.
- Re-enter the public host/port to regenerate the client link.

## After It Finishes

Validate Xray config:

```sh
docker compose run --rm xray run -test -config /etc/xray/config.json
```

Start Xray:

```sh
docker compose up -d
```

If Namecheap DDNS is enabled:

```sh
docker compose --profile ddns up -d --build namecheap-ddns
docker logs -f namecheap-ddns
```
