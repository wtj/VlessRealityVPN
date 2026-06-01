# Technical Design

## Scope

本專案只處理一件事：在自己家裡的主機上，用 Docker/OrbStack 跑 Xray-core，提供 VLESS + REALITY server。第一目標是 macOS Mac mini + OrbStack；Ubuntu + Docker Engine 是第二目標。

不包含：

- Web 管理面板，例如 3X-UI、Marzban。
- 多使用者流量統計、訂閱服務、付款或 quota。
- 自動化申請網域或 DDNS provider API。
- TUN gateway、全家路由器透明代理。

## Components

- `docker-compose.yml`：唯一啟動入口，使用官方 `ghcr.io/xtls/xray-core` image。
- `compose/docker-compose.ports.yml`：OrbStack/macOS fallback，改用明確 TCP port publishing。
- `config/xray/server.json`：實際 runtime config，不進 git。
- `config/xray/server.template.json`：無註解 JSON，複製成 runtime config。
- `config/xray/server.annotated.jsonc`：同內容註解版，負責解釋每個重要欄位。
- `docs/runbook-*.md`：分 OS 操作手冊。

## Protocol Stack

```text
TCP 443
└── VLESS inbound
    ├── UUID client authentication
    ├── flow = xtls-rprx-vision
    └── REALITY transport security
        ├── X25519 key pair
        ├── serverNames / SNI allow-list
        ├── shortIds
        └── uTLS browser fingerprint on clients
```

VLESS 是輕量 stateless protocol，client 以 UUID 驗證。`decryption` 必須明確設定為 `none`。REALITY 是 transport security，取代傳統 TLS 憑證；server 端持有 private key，client 端持有 public key。

## Network Design

### macOS + OrbStack

OrbStack 支援 `--net host`。這代表 Xray 在 container 裡 listen 的 port，會直接出現在 Mac 上；本專案因此不使用 compose `ports:`。好處是設定接近 Linux host network，少一層 port mapping 與 NAT。

實務上仍要從 LAN 與 WAN 實測。若 `network_mode: host` 在某台 Mac/OrbStack 版本上只滿足本機 localhost 測試，但 router port forwarding 進不來，就改用 `compose/docker-compose.ports.yml`，讓 Docker/OrbStack 明確 publish `0.0.0.0:443:443/tcp`。

第一版只承諾 IPv4。必要外部條件：

- 家裡網路要有可被外部連到的 public IPv4。
- 如果 ISP 使用 CGNAT，外部 client 不能直接連進來；需要換 public IP、改用 VPS 中繼，或用其他反向連線設計。
- Router 需要把外部 TCP 443 forward 到 Mac mini 的固定 LAN IP。
- Mac mini 不能睡眠，否則 VPN 會中斷。

### Ubuntu + Docker Engine

Docker Engine on Linux 原生支援 host network。container 會共用 Linux host network namespace，`ports:` 在 host mode 會被忽略。防火牆需要允許 TCP 443。

## REALITY Target Choice

`target` 與 `serverNames` 是 REALITY camouflage 重要參數。Xray 會把 REALITY 驗證失敗的流量轉發到 `target`，所以這不是隨便填一個熱門網站就好。

保守選法：

- 使用真實、穩定、可從 server 連線的 TLS 網站，並確認它的 SNI/SAN 行為符合你的 `serverNames`。
- `target` 使用 `domain:443`。
- `serverNames` 放同一個 domain。
- 不要填自己的 DDNS 名稱；client 連進來用你的 DDNS，但 REALITY SNI 應該是 camouflage target。
- 避免免費 CDN target，例如 Cloudflare 後面的站；官方文件警告這可能讓你的 server 變成被濫用的 port forwarder。

替換範例：

```json
"target": "www.example.com:443",
"serverNames": ["www.example.com"]
```

## Client Link Shape

實際分享連結需要用 runtime 產生值替換：

```text
vless://CLIENT_UUID@YOUR_PUBLIC_HOST:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=REALITY_TARGET_DOMAIN&fp=chrome&pbk=REALITY_PUBLIC_KEY&sid=REALITY_SHORT_ID_HEX&type=tcp&headerType=none#home-xray-reality
```

注意：

- Server config 目前使用 Xray 官方範例的 `network: raw`。
- 很多 client UI 或 URI 仍把這個 transport 稱為 `tcp`；若 client 支援 `raw` 可選 raw，否則選 TCP。
- `pbk` 是 public key，不能填 private key。
- `sid` 必須與 server `shortIds` 其中一個完全相同。
- `sni` 必須落在 server `serverNames`。

## Security Notes

- `config/xray/server.json` 不進 git，因為裡面有 UUID 與 private key。
- 不要公開 `REALITY_PRIVATE_KEY`。
- 每個使用者最好有不同 UUID，未來撤銷單一裝置才容易。
- Router 只開必要 TCP port，不要把 OrbStack/Docker API 暴露到外網。
- macOS 避免把 SSH、VNC、檔案共享一起暴露在同一個 port forward 規則。
- 預設封鎖 BitTorrent protocol，避免家庭出口被濫用。

## Operations

常用操作：

```sh
# Validate config before start or restart.
docker compose run --rm xray run -test -config /etc/xray/config.json

# Start in background.
docker compose up -d

# Follow logs.
docker compose logs -f xray

# Restart after config change.
docker compose restart xray

# Stop.
docker compose down

# Fallback mode with explicit port publishing.
docker compose --project-directory . -f compose/docker-compose.ports.yml up -d
```

## References

- Xray-core official repo: https://github.com/XTLS/Xray-core
- REALITY official example: https://github.com/XTLS/REALITY/blob/main/README.en.md
- VLESS config: https://xtls.github.io/en/config/inbounds/vless.html
- OrbStack host networking: https://docs.orbstack.dev/docker/host-networking
- Docker host networking: https://docs.docker.com/engine/network/drivers/host/
