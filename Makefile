#
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Monkfish
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# open-xfrpc_loader - 面向 OpenWrt 的 xfrpc_loader 包
#
# 源码从独立 Git 仓库克隆：
#   GitHub: https://github.com/monkfish-iot/xfrpc_loader
#   源码位于仓库根目录（C 源码），files/（配置脚本）随本包分发
#
# 首次下载后请记录实际的提交哈希，并填到 PKG_SOURCE_VERSION，
# 同时用 "make package/xfrpc_loader/download V=s" 得到 PKG_MIRROR_HASH 填上。
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xfrpc_loader
PKG_VERSION:=0.0.1
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Monkfish <5747844@qq.com>

# ---- Git 源码来源 ----
# PKG_SOURCE_PROTO:=git 时，OpenWrt 会按 PKG_SOURCE_VERSION 克隆整个 xfrpc_loader 仓库，
# 克隆后整个仓库放在 $(PKG_BUILD_DIR)。
# 源码在仓库内的 src/ 子目录，需通过 Build/Prepare 复制到构建根目录。
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/monkfish-iot/xfrpc_loader.git
PKG_SOURCE_VERSION:=main
PKG_SOURCE_DATE:=2026-08-26
PKG_MIRROR_HASH:=

PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

# LOCAL_SKEY=1（默认）：从本地文件读取密钥，不依赖 libskey
# LOCAL_SKEY=0：使用 libskey 静态库
LOCAL_SKEY ?= 1

# INSTALL_PASSWD_SH=1（默认）：安装 show_luci_passwd.sh（解密显示 LuCI 明文密码）
# INSTALL_PASSWD_SH=0：不安装
INSTALL_PASSWD_SH ?= 1

ifeq ($(LOCAL_SKEY),1)
    SKEY_PKG_DEPS:=
    SKEY_LINK_LIBS:=-lcrypto
else
    SKEY_PKG_DEPS:=+skey
    SKEY_LINK_LIBS:=-lskey -lcrypto
endif

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=Monkfish
  CATEGORY:=Monkfish Softwares
  DEPENDS:=+libevent2 +libcurl +libjson-c $(SKEY_PKG_DEPS) +libopenssl
  TITLE:=xfrpc loader daemon (built from git)
  URL:=https://github.com/monkfish-iot/xfrpc_loader
endef

define Package/$(PKG_NAME)/description
  xfrpc_loader OpenWrt daemon.
  Source is fetched from the xfrpc_loader git repository (src/).
endef

# 源码从独立 git 仓库克隆后，C 源码位于仓库根目录，
# 解包后的 $(PKG_BUILD_DIR) 即仓库根，无需额外复制。
define Build/Prepare
	$(call Build/Prepare/Default)
endef

TARGET_CFLAGS += -Wall -Wextra
ifeq ($(LOCAL_SKEY),1)
    TARGET_CFLAGS += -DLOCAL_SKEY
endif

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-o $(PKG_BUILD_DIR)/xfrpc_loader \
		$(PKG_BUILD_DIR)/*.c \
		-levent -lcurl -ljson-c $(SKEY_LINK_LIBS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/xfrpc_loader $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/xfrpc_loader.init $(1)/etc/init.d/xfrpc_loader
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/xfrpc_loader.uci $(1)/etc/config/xfrpc_loader
ifeq ($(LOCAL_SKEY),1)
	$(INSTALL_BIN) ./files/skey_gen.sh $(1)/usr/bin/skey_gen.sh
endif
ifeq ($(INSTALL_PASSWD_SH),1)
	$(INSTALL_BIN) ./files/show_luci_passwd.sh $(1)/usr/bin/show_luci_passwd.sh
endif
	$(INSTALL_DIR) $(1)/etc/nginx/conf.d
	$(INSTALL_DATA) ./files/etc/nginx/conf.d/luci.conf $(1)/etc/nginx/conf.d/luci.conf
endef

$(eval $(call BuildPackage,$(PKG_NAME)))