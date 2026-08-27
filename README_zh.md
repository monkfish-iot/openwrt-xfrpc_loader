# openwrt-xfrpc_loader

**[English](README.md)** / **中文**

> 这是 [`xfrpc_loader`](https://github.com/monkfish-iot/xfrpc_loader) 的 **OpenWrt 包（feed）**。xfrpc_loader 是批量化、安全地让 OpenWrt 设备接入 frps 并提供集中 Web 登录鉴权的非侵入式辅助系统。系统整体设计、架构与原理详见 xfrpc_loader 的 README。

本仓库包含 OpenWrt 包的定义（`Makefile`）和打包的运行时文件（`files/` 目录）。C 源码**不在此处**——构建时会从独立的 `xfrpc_loader` git 仓库拉取。

---

## 本包包含

| 路径 | 作用 |
|------|------|
| `Makefile` | OpenWrt 包定义；构建时从 git 克隆 C 源码 |
| `files/xfrpc_loader.uci` | 默认 UCI 配置（管理 + 鉴权段） |
| `files/xfrpc_loader.init` | procd 启动脚本；由 UCI 生成 `/tmp/xfrpc_loader.json` 并拉起守护进程 |
| `files/skey_gen.sh` | 生成本地 RSA 密钥与 device_id（`LOCAL_SKEY=1` 模式） |
| `files/show_luci_passwd.sh` | 解密并显示当前 LuCI root 明文密码 |
| `files/etc/nginx/conf.d/luci.conf` | nginx 反向代理 + `auth_request` 集中鉴权配置 |

---

## 环境要求

- OpenWrt 构建树（SDK / 源码树）。
- 设备上：**xfrpc 5.x** 二进制；若启用鉴权链路还需 `nginx` + `luci-mod-rpc`。
- 运行库：`libevent2`、`libcurl`、`libjson-c`、`libopenssl`。

---

## 构建

```sh
cp -r openwrt-xfrpc_loader openwrt/package/xfrpc_loader/
cd openwrt
make menuconfig          # Network 下启用 xfrpc_loader
make -j$(nproc) V=s package/xfrpc_loader/compile
```

> 构建时包会从 `https://github.com/monkfish-iot/xfrpc_loader.git` `git clone` C 源码。构建机需能访问 GitHub（或预置 `dl/`）。

可选构建参数：

```sh
LOCAL_SKEY=1             # 默认：使用本地 OpenSSL 密钥（device_id 存 /etc/config/skey/）
LOCAL_SKEY=0             # 使用厂商 libskey
INSTALL_PASSWD_SH=0      # 不安装 show_luci_passwd.sh
```

### 离线构建

若构建机无法访问 GitHub：在一台有网的机器上执行 `make package/xfrpc_loader/download V=s`，把生成的 tarball 拷入构建树的 `dl/` 目录，并在 `Makefile` 中填入 `PKG_MIRROR_HASH`。

---

## 安装到设备

```sh
scp packages/*/xfrpc_loader_*.ipk root@<设备IP>:/tmp/
opkg install /tmp/xfrpc_loader_*.ipk
opkg install libevent2 libcurl libjson-c libopenssl
```

---

## 最小配置

```sh
# 配置管理服务器（server_name 与 server_ip 至少填一个）
uci set xfrpc_loader.main.server_name='dm.example.com'
uci set xfrpc_loader.main.server_port='6999'
uci set xfrpc_loader.main.protocol='https'
uci commit xfrpc_loader

/etc/init.d/xfrpc_loader enable
/etc/init.d/xfrpc_loader start
```

验证：

```sh
logread | grep xfrpc_loader | tail -30
# 期望看到：join ok, session=... ; xfrpc started, pid=...
```

---

## 启用集中鉴权（配合 frps_helper）

```sh
uci set xfrpc_loader.auth.enabled='1'
uci set xfrpc_loader.auth.remote_host='auth.example.com'
uci set xfrpc_loader.auth.remote_port='6999'
uci set xfrpc_loader.auth.remote_path='/api/v1/auth'
uci commit xfrpc_loader
/etc/init.d/xfrpc_loader restart
```

---

## 完整配置

见 `files/xfrpc_loader.uci`。关键项：

| 段 | 字段 | 默认 | 说明 |
|----|------|------|------|
| main | `server_name` / `server_ip` | 空 | 管理服务器，至少一个非空 |
| main | `server_port` | 6999 | 管理服务器端口 |
| main | `protocol` | https | `http` / `https` |
| main | `local_if` | br-lan | 本机接口（取 MAC/IP） |
| auth | `enabled` | 0 | 是否启用集中鉴权服务 |
| auth | `remote_*` | — | 远程认证服务器地址与路径 |
| auth | `modify_local_password` | 0 | 关闭时用默认账号密码锁用户；开启时随机轮换本机密码 |

---

## 相关仓库

- [`xfrpc_loader`](https://github.com/monkfish-iot/xfrpc_loader) — C 守护进程（本包构建的源码）
- [`xfrpc5`](https://github.com/monkfish-iot/xfrpc5) — 预编译 xfrpc 客户端包（需 5.x）
- `frps_helper` — 配套云端管理 + 鉴权服务器

---

## 许可

Apache-2.0。见 xfrpc_loader 仓库的 `LICENSE`。