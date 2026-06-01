# Namecheap Dynamic DNS Container

## Success Criteria

- Namecheap Advanced DNS has Dynamic DNS enabled.
- The target host record is `A + Dynamic DNS`.
- `.env` has `DDNS_ENABLED=true`.
- `.env` contains the Namecheap DDNS host, domain, and DDNS password.
- `namecheap-ddns` logs `update accepted`.

## Namecheap Request Shape

Namecheap's official HTTPS update endpoint is:

```text
https://dynamicdns.park-your-domain.com/update?host=HOST&domain=DOMAIN&password=DDNS_PASSWORD
```

Use the Dynamic DNS password from Namecheap Advanced DNS, not your Namecheap account password.

## Configure `.env`

For the bare domain:

```dotenv
DDNS_ENABLED=true
NAMECHEAP_DDNS_HOST=@
NAMECHEAP_DDNS_DOMAIN=example.com
NAMECHEAP_DDNS_PASSWORD=replace-with-namecheap-ddns-password
```

For `vpn.example.com`:

```dotenv
DDNS_ENABLED=true
NAMECHEAP_DDNS_HOST=vpn
NAMECHEAP_DDNS_DOMAIN=example.com
NAMECHEAP_DDNS_PASSWORD=replace-with-namecheap-ddns-password
```

Optional values:

```dotenv
# Leave empty so Namecheap uses the public IP of the request.
NAMECHEAP_DDNS_IP=

# Default: every 15 minutes.
NAMECHEAP_DDNS_CRON=*/15 * * * *

# Useful for testing container wiring without sending an update.
NAMECHEAP_DDNS_DRY_RUN=false
```

## Start

The DDNS service is behind a Compose profile so it does not start until the
Namecheap values are configured. It also has a second feature flag:

```dotenv
DDNS_ENABLED=false
```

When `DDNS_ENABLED=false`, the DDNS container will not send updates even if the
`ddns` profile is started.

```sh
docker compose --profile ddns up -d --build namecheap-ddns
```

Check logs:

```sh
docker logs -f namecheap-ddns
```

Run one manual update:

```sh
docker compose --profile ddns run --rm namecheap-ddns /usr/local/bin/namecheap-ddns
```

## Security Notes

- `.env` is gitignored and should hold the real DDNS password.
- The container logs never print the DDNS password or full update URL.
- Anyone with Docker admin access can inspect container environment/config, so treat Docker access as trusted admin access.

## References

- Namecheap Dynamic DNS HTTPS update docs: https://www.namecheap.com/support/knowledgebase/article.aspx/29/11/how-to-dynamically-update-the-hosts-ip-with-an-http-request/
