# Client Choices

## Rule

只選支援 VLESS + REALITY + Vision flow 的 client。只支援 VMess/VLESS 但不支援 REALITY 的 client 不適合這份 server config。

通用匯入資料：

```text
Protocol: VLESS
Address: YOUR_PUBLIC_HOST
Port: 443
UUID: CLIENT_UUID
Encryption: none
Flow: xtls-rprx-vision
Transport: TCP or raw
Security: REALITY
SNI: REALITY_TARGET_DOMAIN
Fingerprint: chrome
Public key: REALITY_PUBLIC_KEY
Short ID: REALITY_SHORT_ID_HEX
```

分享連結模板：

```text
vless://CLIENT_UUID@YOUR_PUBLIC_HOST:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=REALITY_TARGET_DOMAIN&fp=chrome&pbk=REALITY_PUBLIC_KEY&sid=REALITY_SHORT_ID_HEX&type=tcp&headerType=none#home-xray-reality
```

## Recommendations by Platform

| Platform | First choice | Alternatives | Notes |
| --- | --- | --- | --- |
| Android phone/tablet | v2rayNG or Hiddify | NekoBox, sing-box for Android | v2rayNG is common for Xray links; Hiddify is simpler for non-technical users. |
| iOS / iPadOS | Streisand or V2Box | Shadowrocket, Loon, Egern, Hiddify, sing-box Apple platforms | Streisand and V2Box App Store pages list VLESS/REALITY support. |
| macOS | Hiddify or V2Box | v2rayN, Shadowrocket on supported Apple Silicon Macs | Hiddify is easiest; v2rayN is useful if you already use it on Windows/Linux. |
| Windows | v2rayN | Hiddify | v2rayN is the practical default for Xray/VLESS users. |
| Linux desktop | Hiddify | v2rayN, sing-box CLI, xray-core CLI | GUI first: Hiddify. Headless/manual first: CLI. |
| Android TV | Router/OpenWrt proxy first | sideload v2rayNG, NekoBox, Hiddify | TV UI/import can be awkward; router-level proxy is usually more reliable. |
| Apple TV | Stash or Shadowrocket | sing-box Apple platforms | tvOS support and App Store region matter; verify current version before buying. |
| Router/OpenWrt | PassWall / PassWall 2 / OpenWrt Xray packages | sing-box on OpenWrt | Only do router-level deployment if you understand routing loops and DNS behavior. |

## Android

### v2rayNG

Use when you want the most common Android Xray-style client.

Import:

1. Copy the `vless://` link to clipboard or show it as QR.
2. Add from clipboard or scan QR.
3. Confirm fields: REALITY, SNI, public key, short ID, flow.

Pros:

- Commonly used with Xray/VLESS.
- Good QR/link import support.

Watch-outs:

- UI wording may say TCP instead of raw.
- If connection fails, manually inspect REALITY fields after import.

### Hiddify

Use when you want a simpler cross-platform UI for Android/iOS/Windows/macOS/Linux.

Pros:

- Official site lists Reality, VLESS, Xray, sing-box, and all major desktop/mobile platforms.
- Easier for non-technical users than v2rayNG/v2rayN.

Watch-outs:

- Advanced Xray-specific fields may be less visible. After import, verify REALITY, flow, SNI, public key, and short ID.

### NekoBox

Use when you want sing-box-based Android client behavior.

Pros:

- Good protocol coverage.
- Often handles VLESS REALITY well.

Watch-outs:

- Download source matters. Prefer official GitHub/project links over random APK mirrors.

### sing-box for Android

Use when you want official Project S client and are comfortable with sing-box config concepts.

Pros:

- Official sing-box Android client.
- Good for advanced routing/TUN.

Watch-outs:

- The official docs call it experimental.
- Raw Xray `vless://` imports may need checking or conversion depending on app version.

## iOS / iPadOS

### Streisand

Use when you want a free iOS/iPadOS App Store client that explicitly lists `VLESS(Reality)`.

Import:

1. Copy `vless://` link.
2. Import from clipboard or the app's add profile flow.
3. Verify REALITY fields after import.

Pros:

- App Store listing includes `VLESS(Reality)`.
- Good first test client on iPhone/iPad.

Watch-outs:

- Regional availability can change.
- Some advanced fields may need manual inspection after import.

### V2Box

Use when you want a simple App Store client. The App Store listing explicitly mentions VLESS, Reality, VLESS Vision, and uTLS support.

Import:

1. Copy `vless://` link.
2. Add/import from clipboard in V2Box.
3. Verify `Reality`, `flow`, `SNI`, `pbk`, and `sid`.

Pros:

- Easy install from App Store in supported regions.
- Supports the needed feature set according to the App Store listing.

Watch-outs:

- App privacy and ads/tracking policy should be reviewed by the user.
- iOS background behavior is controlled by Apple VPN APIs; always test mobile data.

### Shadowrocket / Loon / Egern / Quantumult X

Use when you already own them or need stronger routing rule UI.

Pros:

- Mature iOS proxy clients.
- Good rule-based routing.

Watch-outs:

- Paid apps, regional availability varies.
- UI fields differ, so validate imported REALITY values.

### sing-box Apple platforms

Use when you prefer official sing-box ecosystem.

Pros:

- Official Project S Apple client line.
- Supports iOS/macOS/tvOS requirements in the docs.

Watch-outs:

- Official docs currently say App Store/macOS standalone updates are temporarily unavailable for non-technical reasons; TestFlight access may require sponsorship.

## Windows

### v2rayN

Use as default Windows client.

Import:

1. Copy `vless://` link.
2. Servers -> Import bulk URL from clipboard.
3. Select the profile.
4. Enable system proxy or TUN depending on need.

Pros:

- Official repo describes support for Windows, Linux, macOS, Xray, sing-box, and VLESS.
- Large user base.

Watch-outs:

- Windows Defender or SmartScreen may warn on downloaded binaries; verify release source.
- TUN mode requires elevated permissions.

## macOS

### Hiddify

Good first option if you want a low-friction GUI and consistent behavior across desktop/mobile.

Pros:

- Official site lists macOS, VLESS, Reality, Xray, and sing-box support.
- Simple import flow.

Watch-outs:

- For detailed per-field debugging, v2rayN or raw Xray/sing-box CLI may expose more.

### V2Box

Good first option if available on your Mac/App Store account.

Pros:

- Same UX as iOS.
- App Store listing includes Mac availability.

Watch-outs:

- Apple Silicon vs Intel availability can differ by app.

### v2rayN

Good cross-platform desktop option.

Pros:

- One client family across Windows/Linux/macOS.
- Supports Xray and sing-box cores.

Watch-outs:

- macOS permissions for network extension/system proxy may require manual approval.

## Linux

### Hiddify

Use if you want the simplest Linux GUI path.

Watch-outs:

- TUN, tray integration, DNS behavior, and permissions vary by distro/desktop environment.

### v2rayN

Use if you want GUI and the distro package works for you.

### sing-box or xray-core CLI

Use if you are comfortable writing config manually and want a minimal reliable service.

Pros:

- Scriptable.
- Works well with systemd.

Watch-outs:

- Not beginner-friendly.
- You may need to convert the Xray URI into sing-box outbound JSON.

## Android TV

Prefer router/OpenWrt-level proxy for Android TV and other TV devices. It avoids remote-control text entry, background VPN permission prompts, and app compatibility issues.

If you must run a TV app, start with v2rayNG, NekoBox, or Hiddify if the device allows install. If Play Store availability is poor, sideload only from trusted official releases.

Practical tips:

- Generate a QR code for the `vless://` link and scan it if the app supports camera import.
- If the TV has no camera, use a remote keyboard or import a subscription URL from a short private URL.
- Avoid TUN/routing changes until a basic app-level connection works.

## Apple TV / tvOS

Use Apple TV only if the app explicitly supports tvOS and your App Store region can install it.

Practical choices:

- Stash or Shadowrocket if available and current changelog/support confirms VLESS REALITY.
- sing-box Apple platforms if you already have access; official docs list Apple tvOS 17.0+, but also note App Store/TestFlight availability limits.

Import caveats:

- Some tvOS apps prefer Clash-style subscriptions instead of raw `vless://` links.
- Verify REALITY fields after import if the app exposes them.
- If the Apple TV is the only device that needs proxying, tvOS app is fine; if many TV/IoT devices need it, router/OpenWrt is usually cleaner.

## Router / OpenWrt

Router-level proxy is useful for Android TV, Apple TV, consoles, and devices where installing a client is painful.

Practical choices:

- PassWall / PassWall 2 with Xray core.
- sing-box on OpenWrt if your config and version explicitly support the needed VLESS REALITY fields.

Watch-outs:

- Router CPU/RAM may bottleneck encrypted proxy traffic.
- DNS and transparent routing mistakes can create loops.
- Start with one manual node and no complex rule sets; add routing rules only after basic connectivity is stable.

## Client Troubleshooting Checklist

- Client says `Reality`, not plain TLS.
- `flow` is exactly `xtls-rprx-vision`.
- `pbk` is public key, not private key.
- `sid` equals one of server `shortIds`.
- `sni` equals one of server `serverNames`.
- Fingerprint is `chrome` unless you intentionally changed it.
- Address is your home DDNS/public host, not the REALITY target domain.
- Try mobile data or another outside network, not only home Wi-Fi.

## Not Recommended as First Choice

NekoRay's original desktop repository was archived in 2025, so do not make it the primary recommendation for new Windows/macOS/Linux setups. If using a fork, verify current maintenance and release source.

## Sources Checked

- Xray-core client list and official image: https://github.com/XTLS/Xray-core
- sing-box graphical clients: https://sing-box.sagernet.org/clients/
- sing-box Apple platform status: https://sing-box.sagernet.org/clients/apple/
- V2Box App Store listing: https://apps.apple.com/us/app/v2box-v2ray-client/id6446814690
- Streisand App Store listing: https://apps.apple.com/us/app/streisand/id6450534064
- Hiddify official site: https://hiddify.com/
- v2rayN official repo: https://github.com/2dust/v2rayN
- v2rayNG official repo: https://github.com/2dust/v2rayNG
- sing-box VLESS outbound docs: https://sing-box.sagernet.org/configuration/outbound/vless/
- Xray REALITY transport docs: https://xtls.github.io/en/config/transports/reality.html
