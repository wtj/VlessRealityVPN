# Ubuntu + Docker Engine Runbook

## Success Criteria

- Ubuntu host 有 public IP，或 router 已把 TCP 443 forward 到 Ubuntu LAN IP。
- Docker Engine 與 Compose plugin 可用。
- Linux firewall 允許 TCP 443。
- `config/xray/server.json` 已替換所有 placeholder。
- `docker compose run --rm xray run -test -config /etc/xray/config.json` 通過。
- 外網 client 可連線。

## 1. Install Docker Engine

建議照 Docker 官方 Ubuntu 文件安裝 Docker Engine。安裝後確認：

```sh
docker version
docker compose version
```

若你的使用者不在 `docker` group，先用 `sudo docker ...`，或依公司/個人安全政策加入 docker group。注意：docker group 幾乎等同 root 權限。

## 2. Prepare Files

在本專案目錄：

```sh
cp .env.example .env
cp config/xray/server.template.json config/xray/server.json
```

## 3. Generate Secrets

```sh
docker run --rm --entrypoint xray ghcr.io/xtls/xray-core:26.5.9 uuid
docker run --rm --entrypoint xray ghcr.io/xtls/xray-core:26.5.9 x25519
openssl rand -hex 8
```

填入 `config/xray/server.json`：

- UUID -> `users[0].id`
- REALITY private key -> `realitySettings.privateKey`
- short ID -> `realitySettings.shortIds[0]`
- REALITY target domain -> `target` and `serverNames`

## 4. Host Network Behavior

本專案使用：

```yaml
network_mode: host
```

在 Docker Engine on Linux，host network 代表 container 共用 host network namespace。因此：

- Compose `ports:` 不需要，也不會生效。
- Xray config 的 inbound `port` 就是 host 上實際 listen 的 port。
- 同一台 host 上不能有其他 process 佔用同一個 port。

檢查 443 是否已被佔用：

```sh
sudo ss -ltnp 'sport = :443'
```

## 5. Firewall

如果使用 UFW：

```sh
sudo ufw allow 443/tcp comment 'Xray VLESS REALITY'
sudo ufw status verbose
```

如果使用雲端 VM，也要在 cloud security group 開 TCP 443。

## 6. Validate and Start

```sh
docker compose pull
docker compose run --rm xray run -test -config /etc/xray/config.json
docker compose up -d
docker compose ps
docker compose logs -f xray
```

## 7. Autostart

Compose 已設定：

```yaml
restart: unless-stopped
```

Docker daemon 開機後會自動拉起 container，除非你手動 `docker compose down` 或 `docker stop`。

確認 Docker daemon 開機自啟：

```sh
systemctl is-enabled docker
systemctl status docker
```

若未啟用：

```sh
sudo systemctl enable --now docker
```

## 8. Client Link

同 macOS runbook：

```text
vless://CLIENT_UUID@YOUR_PUBLIC_HOST:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=REALITY_TARGET_DOMAIN&fp=chrome&pbk=REALITY_PUBLIC_KEY&sid=REALITY_SHORT_ID_HEX&type=tcp&headerType=none#home-xray-reality
```

## Ubuntu vs macOS Differences

| Item | macOS + OrbStack | Ubuntu + Docker Engine |
| --- | --- | --- |
| Docker implementation | Linux VM integrated with macOS | Native Linux |
| Host network | OrbStack supports out of box | Docker Engine supports natively |
| Firewall | macOS firewall + router | UFW/nftables/security group |
| Sleep risk | High on desktop Mac | Usually low on server |
| Port conflict check | `lsof` | `ss` |
| Best deployment | Home Mac mini | VPS or home Linux server |

## Troubleshooting

### `bind: address already in use`

Another process is already using the configured port:

```sh
sudo ss -ltnp 'sport = :443'
```

Stop that process or change Xray inbound port and client link.

### Client cannot connect

Check:

- `docker compose ps`
- `docker compose logs xray`
- `sudo ufw status`
- router/NAT forwarding if behind home router
- public IP / CGNAT status

### Config validates but client fails

Compare server/client values exactly:

- UUID
- flow
- SNI/server name
- REALITY public key
- short ID
- port

## References

- Docker host networking: https://docs.docker.com/engine/network/drivers/host/
- Docker Engine networking overview: https://docs.docker.com/network/
- Xray-core releases: https://github.com/XTLS/Xray-core/releases
