# openwrt-xfrpc_loader

**English** / **[中文](README_zh.md)**

> This is the **OpenWrt package feed** for [`xfrpc_loader`](https://github.com/monkfish-iot/xfrpc_loader), the non-invasive helper that batch-onboards OpenWrt devices to frps with centralized web-login auth. See the xfrpc_loader README for design, architecture, and full system overview.

This repository contains the OpenWrt package definition (the `Makefile`) and the packaged runtime files (the `files/` tree). The C source itself is **not** vendored here — it is fetched at build time from the standalone `xfrpc_loader` git repository.

---

## What This Package Provides

| Path | Role |
|------|------|
| `Makefile` | OpenWrt package definition; clones the C source from git at build time |
| `files/xfrpc_loader.uci` | Default UCI configuration (management + auth sections) |
| `files/xfrpc_loader.init` | procd init script; generates `/tmp/xfrpc_loader.json` from UCI and starts the daemon |
| `files/skey_gen.sh` | Generates local RSA keys + device_id (`LOCAL_SKEY=1` mode) |
| `files/show_luci_passwd.sh` | Decrypts & prints the current LuCI root password |
| `files/etc/nginx/conf.d/luci.conf` | nginx reverse proxy + `auth_request` centralized auth config |

---

## Requirements

- OpenWrt build tree (e.g. SDK / source tree).
- On the device: **xfrpc 5.x** binary and, for the auth chain, `nginx` + `luci-mod-rpc`.
- Runtime libraries: `libevent2`, `libcurl`, `libjson-c`, `libopenssl`.

---

## Build in an OpenWrt Source Tree

```sh
cp -r openwrt-xfrpc_loader openwrt/package/xfrpc_loader/
cd openwrt
make menuconfig              # enable xfrpc_loader under Network
make -j$(nproc) V=s package/xfrpc_loader/compile
```

> At build time the package `git clone`s the C source from `https://github.com/monkfish-iot/xfrpc_loader.git`. The build machine needs access to GitHub (or a pre-populated `dl/`).

Optional build flags:

```sh
LOCAL_SKEY=1                 # default: local OpenSSL keys (device_id in /etc/config/skey/)
LOCAL_SKEY=0                 # use vendor libskey
INSTALL_PASSWD_SH=0          # skip installing show_luci_passwd.sh
```

### Offline builds

If the build machine cannot reach GitHub, run `make package/xfrpc_loader/download V=s` on a machine with network access, then copy the produced tarball into the build tree's `dl/` directory, and fill in `PKG_MIRROR_HASH` in the `Makefile`.

---

## Install on the Device

```sh
scp packages/*/xfrpc_loader_*.ipk root@<DEVICE_IP>:/tmp/
opkg install /tmp/xfrpc_loader_*.ipk
opkg install libevent2 libcurl libjson-c libopenssl
```

---

## Minimal Configuration

```sh
# Point to the management server (at least one of server_name / server_ip)
uci set xfrpc_loader.main.server_name='dm.example.com'
uci set xfrpc_loader.main.server_port='6999'
uci set xfrpc_loader.main.protocol='https'
uci commit xfrpc_loader

/etc/init.d/xfrpc_loader enable
/etc/init.d/xfrpc_loader start
```

Verify:

```sh
logread | grep xfrpc_loader | tail -30
# Expect: join ok, session=... ; xfrpc started, pid=...
```

---

## Enable Centralized Auth (with frps_helper)

```sh
uci set xfrpc_loader.auth.enabled='1'
uci set xfrpc_loader.auth.remote_host='auth.example.com'
uci set xfrpc_loader.auth.remote_port='6999'
uci set xfrpc_loader.auth.remote_path='/api/v1/auth'
uci commit xfrpc_loader
/etc/init.d/xfrpc_loader restart
```

---

## Full Configuration

See `files/xfrpc_loader.uci`. Key options:

| Section | Field | Default | Description |
|---------|-------|---------|-------------|
| main | `server_name` / `server_ip` | empty | Management server; at least one required |
| main | `server_port` | 6999 | Management server port |
| main | `protocol` | https | `http` / `https` |
| main | `local_if` | br-lan | Local interface (for MAC/IP) |
| auth | `enabled` | 0 | Enable centralized auth service |
| auth | `remote_*` | — | Remote auth server address & path |
| auth | `modify_local_password` | 0 | 0 = lock user with default account; 1 = rotate local password |

---

## Related Repos

- [`xfrpc_loader`](https://github.com/monkfish-iot/xfrpc_loader) — the C daemon (source this package builds)
- [`xfrpc5`](https://github.com/monkfish-iot/xfrpc5) — prebuilt xfrpc client package (requires 5.x)
- `frps_helper` — companion cloud management + auth server

---

## License

Apache-2.0. See `LICENSE` in the xfrpc_loader repository.