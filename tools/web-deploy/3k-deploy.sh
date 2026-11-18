#!/bin/bash
# 3k-game（霸王的大陆，Godot 3.6.3）→ https://124.221.164.209/3k/
# 流程：导出 WebAssembly → 拆核心包/资源包 → 预压缩 → 上传 COS → 外壳补丁 → 同步本机
# 用法：~/bin/3k-deploy.sh             # 重新导出并发布（大文件走 COS）
#      ~/bin/3k-deploy.sh --no-export  # 只把现有 build/web 同步上线
#      ~/bin/3k-deploy.sh --no-split   # 已有拆好的产物，只做补丁+上传+同步
#      ~/bin/3k-deploy.sh --local      # 不用 COS，全部放本机（回滚开关）
#
# 说明：wasm/pck 走 COS（pub-1256298121，ap-guangzhou），出口带宽只有 ~4Mbps 的本机
# 只负责 index.html / index.js / worklet 这些几百 KB 的文件。COS 的 CORS 与
# Content-Type: application/wasm 已配好（见 3k-patch.py 顶部说明）。
set -euo pipefail

# 支持从 ~/bin 软链调用
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SRC=$(cd "$HERE/../../bwdl" && pwd)
WEB=$SRC/build/web
DST=/var/www/3k
GODOT=~/godot-dl/Godot_v3.6.3-stable_x11.64
TEMPLATES=~/.local/share/godot/templates/3.6.3.stable
COSCMD=~/.venv-cos/bin/coscmd
COS_BUCKET=pub-1256298121
COS_PREFIX=3k
COS_ORIGIN=https://pub-1256298121.cos.ap-guangzhou.myqcloud.com

USE_COS=1
for arg in "$@"; do
  case $arg in
    --no-export) SKIP_EXPORT=1 ;;
    --no-split)  SKIP_EXPORT=1; SKIP_SPLIT=1 ;;
    --local) USE_COS=0 ;;
  esac
done
[ "${SKIP_EXPORT:-0}" = "1" ] || true

[ -x "$GODOT" ] || { echo "缺少 Godot 3.6.3: $GODOT"; exit 1; }
[ -f "$TEMPLATES/webassembly_release.zip" ] || { echo "缺少导出模板: $TEMPLATES"; exit 1; }

if [ "$USE_COS" = "1" ]; then
  COS_BASE="$COS_ORIGIN/$COS_PREFIX"
else
  COS_BASE=""
fi

if [ "${SKIP_EXPORT:-0}" != "1" ]; then
  echo "==> 导出 Web（首次/改动资源后要几十秒到数分钟）..."
  mkdir -p "$WEB"
  # 无显示器环境靠 xvfb；导出前若有新资源，Godot 会自动补导入
  xvfb-run -a "$GODOT" --no-window --path "$SRC" --export "Web" "$WEB/index.html" \
    > /tmp/godot_export.log 2>&1 || true
  if [ ! -s "$WEB/index.wasm" ]; then
    echo "导出失败，日志末尾："; tail -20 /tmp/godot_export.log; exit 1
  fi
fi
ls -lh "$WEB"/index.{html,js,wasm,pck}

if [ "${SKIP_SPLIT:-0}" != "1" ]; then
  echo "==> 拆包：核心 index.pck + 资源 assets.pck（音频/战斗大图后台加载）"
  mv "$WEB/index.pck" "$WEB/_full.pck"
  python3 "$HERE/3k-pck-split.py" "$WEB/_full.pck" "$WEB/index.pck" "$WEB/assets.pck"
  rm -f "$WEB/_full.pck"

  echo "==> 预压缩核心包（本机出口 ~4Mbps，Caddy 用 precompressed；COS 侧带 Content-Encoding: gzip）"
  gzip -6 -c "$WEB/index.pck" > "$WEB/index.pck.gz"
else
  echo "==> 跳过拆包/预压缩（--no-split）"
fi

echo "==> 外壳补丁：COS 地址 + 下载进度 + 资源包后台下载"
COS_BASE="$COS_BASE" python3 "$HERE/3k-patch.py" "$WEB/index.html"

if [ "$USE_COS" = "1" ]; then
  echo "==> 上传大文件到 COS（$COS_BUCKET/$COS_PREFIX）"
  # 密钥来自 coscmd 自己的配置（~/.cos.conf，600，由 `coscmd config` 生成）；
  # 不要在脚本里 source /etc/profile —— 那份文件在非交互 shell 下会把当前 shell 干掉。
  # 大文件文件名不带 hash，用 must-revalidate + ETag，改版后立刻生效且回访不重下
  CACHE='{"Cache-Control":"public,max-age=0,must-revalidate"}'
  WASM_HDR='{"Content-Type":"application/wasm","Cache-Control":"public,max-age=0,must-revalidate"}'
  PCK_HDR='{"Content-Type":"application/octet-stream","Content-Encoding":"gzip","Cache-Control":"public,max-age=0,must-revalidate"}'
  "$COSCMD" upload -H "$WASM_HDR" "$WEB/index.wasm" "$COS_PREFIX/index.wasm"
  "$COSCMD" upload -H "$PCK_HDR"  "$WEB/index.pck.gz" "$COS_PREFIX/index.pck"
  "$COSCMD" upload -H "$CACHE"    "$WEB/assets.pck" "$COS_PREFIX/assets.pck"

  echo "==> COS 自检（匿名 + 跨域 + MIME）"
  for f in index.wasm index.pck assets.pck; do
    curl -s -o /dev/null -D /tmp/cos-h.txt -H "Origin: https://124.221.164.209" \
      "$COS_BASE/$f" -w "  $f  %{http_code}  %{size_download}B  "
    grep -i "^content-type" /tmp/cos-h.txt | tr -d '\r' | sed 's/^/ /'
    grep -i "^access-control-allow-origin" /tmp/cos-h.txt | tr -d '\r' | sed 's/^/  /' || echo "  ! 缺少 CORS 头"
  done
fi

echo "==> 发布到 $DST（本机只放小文件，大文件仍保留一份作为回滚后备）"
sudo mkdir -p "$DST"
sudo rsync -a --delete "$WEB/" "$DST/"
sudo chown -R caddy:caddy "$DST"

echo "==> 自检"
curl -s -o /dev/null -w "index.html  %{http_code}\n" https://124.221.164.209/3k/
grep -o "executable\":\"[^\"]*" "$DST/index.html" | sed 's/^/  引擎入口: /'
echo "==> 完成: https://124.221.164.209/3k/"