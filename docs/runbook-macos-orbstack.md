# macOS Mac mini + OrbStack Runbook

## Success Criteria

- Mac mini 有固定 LAN IP，且不會睡眠。
- Router 外部 TCP 443 轉到 Mac mini LAN IP 的 TCP 443。
- OrbStack 可執行 Docker/Compose。
- `config/xray/server.json` 已替換所有 placeholder。
- `docker compose run --rm xray test -config /etc/xray/config.json` 通過。
- 外網 client 可用 VLESS REALITY 連線。

## 0. Prerequisites

你需要先決定：

- `YOUR_PUBLIC_HOST`：外部 client 連線用的 domain/DDNS，例如 `vpn.example.com`。
- `REALITY_TARGET_DOMAIN`：REALITY camouflage SNI，例如你已確認適合的真實 TLS 網站 hostname。
- `SERVER_PORT`：預設 `443`。

不要把 `YOUR_PUBLIC_HOST` 與 `REALITY_TARGET_DOMAIN` 混在一起。前者是連到你家，後者是 REALITY 偽裝用的 SNI/target。

## 1. Install OrbStack

Homebrew 方式：

```sh
brew install orbstack
```

或到 OrbStack 官網下載 app。打開 OrbStack 後確認 Docker CLI 可用：

```sh
docker version
docker compose version
```

預期：兩個指令都應該印出版本，不應該出現 cannot connect to Docker daemon。

## 2. Prepare Project Files

在本專案目錄：

```sh
cp .env.example .env
cp config/xray/server.template.json config/xray/server.json
```

`.env` 欄位：

```dotenv
# Xray official Docker image.
# 若要穩定重現，建議之後改成你驗證過的 stable tag。
XRAY_IMAGE=ghcr.io/xtls/xray-core:26.5.9

# Compose project name，只影響 container/network 命名。
COMPOSE_PROJECT_NAME=vless-reality-vpn
```

## 3. Generate Secrets

產生 client UUID：

```sh
docker run --rm ghcr.io/xtls/xray-core:26.5.9 uuid
```

產生 REALITY X25519 keypair：

```sh
docker run --rm ghcr.io/xtls/xray-core:26.5.9 x25519
```

輸出會包含 `Private key` 與 `Public key`：

- `Private key` 放進 server config 的 `privateKey`。
- `Public key` 放進 client link 的 `pbk`。

產生 short ID：

```sh
openssl rand -hex 8
```

這會產生 16 個 hex 字元，放進 server config `shortIds`，也放進 client link `sid`。

## 4. Edit Xray Runtime Config

打開 `config/xray/server.json`，替換：

- `__CLIENT_UUID__` -> 第 3 步產生的 UUID。
- `__REALITY_PRIVATE_KEY__` -> 第 3 步產生的 private key。
- `__REALITY_SHORT_ID_HEX__` -> 第 3 步產生的 short ID。
- `__REALITY_TARGET_DOMAIN__` -> 你的 REALITY target domain。不要直接套用免費 CDN target，例如 Cloudflare 後面的站；Xray 官方文件警告驗證失敗的流量會被轉發到 target，可能讓你的 server 被濫用。

設定註解請看 `config/xray/server.annotated.jsonc`。實際執行檔 `server.json` 必須保持合法 JSON。

## 5. Reserve Mac mini LAN IP

在家用 router DHCP 設定裡，替 Mac mini 設定 DHCP reservation，例如：

```text
Mac mini MAC address -> 192.168.1.20
```

在 macOS 查目前 LAN IP：

```sh
ipconfig getifaddr en0
```

如果你用 Wi-Fi，可能還是 `en0`；如果查不到，用：

```sh
networksetup -listallhardwareports
```

找到 active interface 後再查 IP。

## 6. Disable Sleep for Server Use

GUI 建議：

- System Settings -> Lock Screen：關閉自動睡眠或把時間拉長。
- System Settings -> Energy：啟用網路喚醒若可用。

指令檢查：

```sh
pmset -g
```

如果這台 Mac mini 會長期當 server，用電源模式避免 sleep。不要讓磁碟或系統進入會中斷網路的睡眠狀態。

## 7. Router Port Forwarding

在 router 上新增規則：

```text
Protocol: TCP
External port: 443
Internal IP: Mac mini LAN IP, e.g. 192.168.1.20
Internal port: 443
```

只需要 TCP。這份 VLESS REALITY 設定不是 WireGuard，不需要 UDP port。

如果 TCP 443 已被 NAS、Caddy、Nginx 或 router 管理介面使用，先停掉衝突服務，或改用其他 port。若改 port，要同步改：

- `config/xray/server.json` 的 inbound `port`
- router external/internal port
- client link 的 port

## 8. Check Public Reachability

確認你不是 CGNAT：

1. Router WAN IP。
2. 外部網站看到的 public IP。
3. 兩者應該一致或至少 router WAN IP 是 public address。

如果 router WAN IP 是 `10.x.x.x`、`100.64.x.x`、`172.16-31.x.x`、`192.168.x.x`，多半是 private/CGNAT，外部 client 不能直接連進來。

DDNS 可用你的 router 內建功能，或 provider app。這份 runbook 不指定 provider，因為不同品牌差很多。

## 9. Validate Config

先拉 image：

```sh
docker compose pull
```

檢查設定：

```sh
docker compose run --rm xray test -config /etc/xray/config.json
```

通過後再啟動：

```sh
docker compose up -d
```

看狀態：

```sh
docker compose ps
docker compose logs -f xray
```

接著從 LAN 另一台設備測 Mac mini LAN IP，再從手機行動網路測 DDNS/public host。不要只用 Mac mini 本機 `localhost` 判斷成功。

如果 host network 模式本機可通、但 LAN/WAN 打不到，改用 fallback compose：

```sh
docker compose down
docker compose --project-directory . -f compose/docker-compose.ports.yml up -d
docker compose --project-directory . -f compose/docker-compose.ports.yml logs -f xray
```

fallback 檔案使用明確 port publishing：

```yaml
ports:
  - "0.0.0.0:443:443/tcp"
```

## 10. Build Client Link

用這個模板替換：

```text
vless://CLIENT_UUID@YOUR_PUBLIC_HOST:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=REALITY_TARGET_DOMAIN&fp=chrome&pbk=REALITY_PUBLIC_KEY&sid=REALITY_SHORT_ID_HEX&type=tcp&headerType=none#home-xray-reality
```

欄位對照：

- `CLIENT_UUID`：server `users[0].id`
- `YOUR_PUBLIC_HOST`：你的 DDNS/domain，不是 REALITY target
- `443`：server public port
- `REALITY_TARGET_DOMAIN`：server `serverNames[0]`
- `REALITY_PUBLIC_KEY`：`xray x25519` 產生的 public key
- `REALITY_SHORT_ID_HEX`：server `shortIds[0]`

如果 client 有手動欄位：

```text
Protocol: VLESS
Address: YOUR_PUBLIC_HOST
Port: 443
UUID: CLIENT_UUID
Encryption: none
Flow: xtls-rprx-vision
Transport: TCP or raw
Security: REALITY
SNI / Server name: REALITY_TARGET_DOMAIN
Fingerprint: chrome
Public key: REALITY_PUBLIC_KEY
Short ID: REALITY_SHORT_ID_HEX
```

## 11. Test from Outside

不要只用家中 Wi-Fi 測。請用手機行動網路測：

1. 關閉 Wi-Fi。
2. 匯入 client link。
3. 連線。
4. 打開 `https://ifconfig.me` 或類似網站，確認出口 IP 是家裡 ISP。

Server 端看 log：

```sh
docker compose logs -f xray
```

## 12. Maintenance

重啟服務：

```sh
docker compose restart xray
```

更新 image：

```sh
docker compose pull
docker compose up -d
```

更新前建議先看 Xray-core release notes。若要可重現，將 `.env` 的 `XRAY_IMAGE` pin 到你驗證過的 tag。

## Troubleshooting

### `server.json` parse error

多半是 JSON 格式錯誤。確認：

- 沒有註解。
- 字串用雙引號。
- 最後一個陣列/物件項目後面沒有多餘逗號。

### Client timeout

檢查順序：

1. Mac mini 沒睡眠。
2. `docker compose ps` 顯示 running。
3. Router port forward 指到正確 LAN IP。
4. ISP 沒有 CGNAT。
5. macOS firewall 沒擋 OrbStack/Xray。

### Client handshake failed

通常是 client 欄位不一致：

- `pbk` 填錯，或誤填 private key。
- `sid` 與 server short ID 不同。
- `sni` 不在 server `serverNames`。
- flow 沒設 `xtls-rprx-vision`。
- client transport 選錯。先試 TCP；若支援 raw 再試 raw。

### Port 443 conflict

找出佔用者：

```sh
sudo lsof -nP -iTCP:443 -sTCP:LISTEN
```

停掉衝突服務或改用其他 port。

## References

- OrbStack quick start: https://docs.orbstack.dev/quick-start
- OrbStack host networking: https://docs.orbstack.dev/docker/host-networking
- Xray-core official Docker image list: https://github.com/XTLS/Xray-core
