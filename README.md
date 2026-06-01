# VLESS REALITY VPN on Home Docker

這個專案是給家用 Mac mini 先跑起來的 VLESS + REALITY + Xray-core Docker 設定範本。第一版以 macOS + OrbStack 為主，Ubuntu + Docker Engine 也保留同一套 compose 入口。

## 成功狀態

完成後應該長這樣：

- 家用 Mac mini 固定在區網 IP，路由器把外部 TCP 443 轉到 Mac mini。
- OrbStack 啟動 `xray-vless-reality` container，container 用 host network 直接 listen `0.0.0.0:443`。
- 手機或電腦 client 匯入 VLESS REALITY 分享連結後，可以從外網連回家中網路出口。
- `docker compose logs xray` 沒有 config parse error，client 連線時能看到少量連線紀錄或無錯誤 warning。

## 運作機制

資料流：

```text
client app
  -> public DNS / DDNS name
  -> home router port forward TCP 443
  -> Mac mini OrbStack host network
  -> Xray container VLESS inbound
  -> REALITY transport handshake
  -> direct outbound from home internet
```

VLESS 負責 client 身分驗證，這裡用 UUID。REALITY 是 Xray 的傳輸層安全模式，不需要向 CA 申請 TLS 憑證；client 會用 server 的 REALITY public key、SNI、short ID 與 fingerprint 建立看起來像正常 TLS 的連線。Xray 收到合法 client 後把流量用 `freedom` outbound 從家裡網路送出去。

OrbStack 重點是 `network_mode: host`。在 OrbStack 上，container 可以直接共用 macOS host 的 localhost/port 空間，所以不需要 `ports:` port mapping。Ubuntu Docker Engine 也支援 host network，因此同一份 compose 可以沿用。

## 專案架構

```text
.
├── docker-compose.yml                 # 主要入口：啟動 Xray container
├── compose/
│   └── docker-compose.ports.yml       # fallback：不用 host network，改用明確 port publish
├── .env.example                       # image 與 compose project name 範例
├── config/
│   └── xray/
│       ├── server.template.json       # 可執行 JSON 範本，複製成 server.json 使用
│       └── server.annotated.jsonc     # 同設定的逐欄註解版，只給人讀
└── docs/
    ├── technical-design.md            # 技術文件與安全/網路設計
    ├── runbook-macos-orbstack.md      # Mac mini + OrbStack 詳細步驟
    ├── runbook-ubuntu-docker.md       # Ubuntu + Docker Engine 詳細步驟
    └── clients.md                     # 各平台 client 選擇與匯入方式
```

主要入口：

- 啟動服務：`docker compose up -d`
- fallback 啟動：`docker compose --project-directory . -f compose/docker-compose.ports.yml up -d`
- 檢查設定：`docker compose run --rm xray run -test -config /etc/xray/config.json`
- 看 log：`docker compose logs -f xray`
- 修改 server 設定：`config/xray/server.json`

## 快速開始

先看 Mac mini runbook：

1. 安裝 OrbStack 並確認 `docker version` 可用。
2. `cp .env.example .env`
3. `cp config/xray/server.template.json config/xray/server.json`
4. 用 runbook 產生 UUID、REALITY keypair、short ID，替換 `server.json` 的 placeholder。
5. 確認 router/DDNS/port forwarding。
6. `docker compose run --rm xray run -test -config /etc/xray/config.json`
7. `docker compose up -d`
8. 從 LAN 另一台設備與手機行動網路各測一次。
9. 若 OrbStack host network 在你的環境無法被 LAN/WAN 打到，改用 `compose/docker-compose.ports.yml` fallback。
10. 依 `docs/clients.md` 匯入 client。

## 文件入口

- [技術文件](docs/technical-design.md)
- [macOS + OrbStack runbook](docs/runbook-macos-orbstack.md)
- [Ubuntu + Docker Engine runbook](docs/runbook-ubuntu-docker.md)
- [Client 選型](docs/clients.md)
- [Namecheap Dynamic DNS container](docs/namecheap-ddns.md)

## 來源

- Xray-core official repo and Docker image: https://github.com/XTLS/Xray-core
- REALITY official example: https://github.com/XTLS/REALITY/blob/main/README.en.md
- Xray VLESS inbound config: https://xtls.github.io/en/config/inbounds/vless.html
- OrbStack host networking: https://docs.orbstack.dev/docker/host-networking
- Docker host network driver: https://docs.docker.com/engine/network/drivers/host/
