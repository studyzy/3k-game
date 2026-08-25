#!/usr/bin/env bash
# 运行 Godot 客户端单元测试（gdUnit4）。
# 流程：起一个 MockServer（回放预设 HTTP + WS）→ 注入地址 → 跑 gdUnit4 CLI → 清理。
#
# 注意：gdUnit4 的 CI 入口必须在 Game 模式（非 `--headless`、非 `-s`）下运行，
# 否则 HTTPRequest 无法工作、且触发 headless 检查。--remote-debug tcp://127.0.0.1:0
# 用于禁用本地交互式 CLI 调试器，防止脚本解析错误时的 'debug>' 死循环。

set -euo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
MOCK_BIN="server/bin/3k-mockserver"
CASE_FILE="server/cmd/mockserver/testdata/case_netclient.json"

# MockServer 端口：优先用环境变量，否则随机高位端口
PORT="${K3G_MOCK_PORT:-$(python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1]);s.close()')}"
MOCK_URL="http://127.0.0.1:${PORT}"
MOCK_WS="ws://127.0.0.1:${PORT}/game/ws"

# 启动 MockServer
if [ ! -x "$MOCK_BIN" ]; then
  echo "缺少 $MOCK_BIN，请先执行: make build-mock" >&2
  exit 1
fi

"$MOCK_BIN" -port "$PORT" -case "$CASE_FILE" &
MOCK_PID=$!
cleanup() {
  kill "$MOCK_PID" 2>/dev/null || true
  wait "$MOCK_PID" 2>/dev/null || true
}
trap cleanup EXIT

# 等待 MockServer 就绪
for i in $(seq 1 50); do
  if curl -sf "$MOCK_URL/auth/login" -X POST -d playerId=probe >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

echo "MockServer 就绪: $MOCK_URL"

# 注入 server 地址后跑 gdUnit4 CLI（headless）。
# CI 是无显示服务器，必须 --headless；HTTP/WS 在 --headless + --ignoreHeadlessMode 下仍可用（已本地验证）。
K3G_SERVER_URL="$MOCK_URL" K3G_WS_URL="$MOCK_WS" \
  "$GODOT" --headless --path . -s --remote-debug tcp://127.0.0.1:0 \
    addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode \
    --add res://scenes/tests \
    --continue \
    --report-directory reports