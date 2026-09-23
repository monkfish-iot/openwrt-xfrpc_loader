#!/bin/sh
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
# show_luci_passwd.sh - 显示当前 LuCI root 明文密码
#
# 通过 xfrpc_loader 本地认证服务(127.0.0.1) 的 /api/password 接口获取，
# 由服务端 C 代码负责 RSA 解密（避免 shell 依赖 openssl 命令行）。
#
# 用法：
#   show_luci_passwd.sh            # 输出明文密码
#   show_luci_passwd.sh -q         # 静默模式（出错时不打印错误信息）
#
# 依赖：curl（OpenWrt 上需安装 curl 包）

set -u

AUTH_BASE="http://127.0.0.1:${AUTH_PORT:-8888}"

QUIET=0
[ "${1:-}" = "-q" ] && QUIET=1

log_err() {
	[ "$QUIET" -eq 1 ] || echo "show_luci_passwd: $*" >&2
}

# 1. 检查 curl
if ! command -v curl >/dev/null 2>&1; then
	log_err "curl not found (install curl)"
	exit 1
fi

# 2. 调用认证服务接口获取明文密码
#    不使用 -f：-f 会在 4xx/5xx 时吞掉响应体，看不到服务端给出的具体原因
#    （404=未初始化，500=解密失败），只能笼统报 "is xfrpc_loader running?"。
#    用 -w 在 body 后追加一行 HTTP 状态码，自行判定并把服务端 JSON 原样带出。
RESP=$(curl -sS --connect-timeout 5 -m 10 \
	-w '
%{http_code}' "${AUTH_BASE}/api/password" 2>/dev/null)
RC=$?
if [ "$RC" -ne 0 ]; then
	# curl 退出码 7 = 连接被拒/连不上（进程确实没监听时）
	if [ "$RC" -eq 7 ]; then
		log_err "cannot connect ${AUTH_BASE}/api/password (is xfrpc_loader running?)"
	else
		# 28=超时（单线程事件循环被阻塞时也会出现：端口在 LISTEN 但无人应答）
		log_err "query ${AUTH_BASE}/api/password failed (curl exit $RC)"
	fi
	exit 1
fi

HTTP_CODE=$(printf '%s' "$RESP" | tail -n 1)
BODY=$(printf '%s' "$RESP" | sed '$d')

# 3. 优先提取服务端 error 字段（HTTP 404/500 或 200 带 error 的情况）
ERROR_MSG=$(printf '%s' "$BODY" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')

if [ -n "$ERROR_MSG" ]; then
	case "$ERROR_MSG" in
		*"not initialized"*)
			log_err "local password not initialized yet"
			log_err "  - device has not completed remote auth (first login)"
			log_err "  - use default root password until then"
			;;
		*)
			log_err "xfrpc_loader error: $ERROR_MSG"
			;;
	esac
	exit 1
fi

if [ "$HTTP_CODE" != "200" ]; then
	log_err "xfrpc_loader returned HTTP $HTTP_CODE${BODY:+: $BODY}"
	exit 1
fi

# 4. 解析 JSON 中的 password 字段（busybox 无 jq，用 sed 提取）
PASSWORD=$(printf '%s' "$BODY" | sed -n 's/.*"password":"\([^"]*\)".*/\1/p')

if [ -z "$PASSWORD" ]; then
	log_err "no password in response${BODY:+: $BODY}"
	exit 1
fi

# 5. 输出明文密码
echo "$PASSWORD"
exit 0
