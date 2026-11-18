#!/usr/bin/env python3
"""给 Godot 3.6 Web 导出的 index.html 打补丁（幂等，可反复执行）。

1) 底部下载进度面板（JS 在 3k-panel.js）：自己拦 fetch/XHR 数已下载字节，
   显示「核心 X / Y MB · 后台资源 A / B MB」+ 百分比，下完自动淡出
2) 手机端全屏按钮 + 首次手势自动全屏 + 竖屏提示（JS 在 3k-fullscreen.js）
3) 渐进加载：核心包起来后后台下载 assets.pck 写入虚拟 FS，置 __assetsPckReady
4) 大文件地址指向 COS（COS_BASE 为空则退回全站本机发布）

用法：COS_BASE=https://xxx.cos.ap-guangzhou.myqcloud.com/3k python3 3k-patch.py index.html
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PANEL_VER = "8"      # 与 3k-panel.js 里的 __dlPanelVer 保持一致
FS_VER = "6"         # 与 3k-fullscreen.js 里的 __fsVer 保持一致

path = sys.argv[1]
COS_BASE = os.environ.get("COS_BASE", "").rstrip("/")
html = open(path, encoding="utf-8").read()


def inline_js(fname):
    src = open(os.path.join(HERE, fname), encoding="utf-8").read()
    return "<script type='text/javascript'>//<![CDATA[\n" + src + "\n//]]></script>"


def drop_block(html, start_marker, end_marker="//]]></script>"):
    i = html.find(start_marker)
    if i < 0:
        return html
    j = html.find(end_marker, i)
    if j < 0:
        return html
    return html[:i] + html[j + len(end_marker):]


# ---------------------------------------------------------------- 0) COS 地址
if COS_BASE:
    html, n1 = re.subn(r'"executable":"[^"]*"', '"executable":"%s/index"' % COS_BASE, html, count=1)
    html, n2 = re.subn(r'var ASSETS_PCK_URL = "[^"]*";', 'var ASSETS_PCK_URL = "%s/assets.pck";' % COS_BASE, html, count=1)
    print("executable/assets ->", COS_BASE, "(命中 %d/%d)" % (n1, n2))
else:
    html, n1 = re.subn(r'"executable":"https?://[^"]*"', '"executable":"index"', html, count=1)
    html, n2 = re.subn(r'var ASSETS_PCK_URL = "https?://[^"]*";', 'var ASSETS_PCK_URL = "assets.pck";', html, count=1)
    if n1 or n2:
        print("executable/assets -> 本机相对路径 (命中 %d/%d)" % (n1, n2))

# ------------------------------------------------------- 1) 底部下载进度面板
PANEL_BOX = """<div id="__dlp" style="position:fixed;left:0;right:0;bottom:0;z-index:99999;display:none;opacity:1;
\tbackground:rgba(12,12,14,.82);color:#e6e6e6;padding:10px 14px 12px;
\tfont:13px/1.5 -apple-system,'PingFang SC','Microsoft YaHei',sans-serif;
\tbackdrop-filter:blur(6px);border-top:1px solid rgba(255,255,255,.12)">
\t<div style="display:flex;justify-content:space-between;margin-bottom:4px">
\t\t<span id="__dlp_l">正在加载游戏资源…</span><span id="__dlp_p">0%</span>
\t</div>
\t<div style="height:6px;background:rgba(255,255,255,.14);border-radius:3px;overflow:hidden">
\t\t<div id="__dlp_b" style="height:100%;width:0;background:linear-gradient(90deg,#39c5bb,#4a90e2);transition:width .25s ease-out"></div>
\t</div>
\t<div id="__dlp_s" style="margin-top:5px;color:#9aa0a6;font-size:12px"></div>
</div>
"""
SEL = "<script type='text/javascript' src='index.js'></script>"

if "__dlPanelVer === %s" % PANEL_VER not in html:
    html = drop_block(html, '<div id="__dlp"')
    assert SEL in html, "找不到 index.js script 标签"
    html = html.replace(SEL, SEL + "\n\t" + PANEL_BOX + "\t" + inline_js("3k-panel.js"), 1)
    print("进度面板已注入")
else:
    print("进度面板已是最新")

# ------------------------------------------------- 1b) 全屏 / 竖屏提示
FS_BTN = """<div id="__fsBtn" style="position:fixed;top:calc(env(safe-area-inset-top,0px) + 8px);right:8px;z-index:100000;
\tpadding:6px 12px;border-radius:16px;background:rgba(0,0,0,.55);color:#fff;
\tfont:13px/1.2 -apple-system,'PingFang SC','Microsoft YaHei',sans-serif;
\t-webkit-user-select:none;user-select:none;cursor:pointer;backdrop-filter:blur(4px);
\tborder:1px solid rgba(255,255,255,.25)">全屏</div>
"""
if "__fsVer === %s" % FS_VER not in html:
    html = drop_block(html, '<div id="__fsBtn"')
    assert SEL in html, "找不到 index.js script 标签"
    html = html.replace(SEL, SEL + "\n\t" + FS_BTN + "\t" + inline_js("3k-fullscreen.js"), 1)
    print("全屏按钮已注入")
else:
    print("全屏按钮已是最新")

# 视口铺满（只插一次）
if "100dvh" not in html and "#canvas:focus {" in html:
    css = """html, body {
\t\tmargin: 0; padding: 0;
\t\theight: 100vh; height: 100dvh;
\t\toverflow: hidden;
\t\toverscroll-behavior: none;
\t\ttouch-action: manipulation;
\t\tbackground: #000;
\t\t-webkit-user-select: none; user-select: none;
\t\t-webkit-touch-callout: none;
\t}
\t#canvas { width: 100%; height: 100%; display: block; }
\t"""
    html = html.replace("#canvas:focus {", css + "#canvas:focus {", 1)
    print("视口铺满样式已插入")

# 移动端 meta（添加到主屏幕后独立全屏运行）
if "mobile-web-app-capable" not in html and "</head>" in html:
    html = html.replace("</head>", """\t<meta name="mobile-web-app-capable" content="yes">
\t<meta name="apple-mobile-web-app-capable" content="yes">
\t<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
\t<meta name="theme-color" content="#000000">
\t<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
</head>""", 1)
    print("移动端 meta 已插入")

# --------------------------------------------- 2) 资源包后台下载 + 渐进挂载
if "copyToFS" not in html:
    engine_anchor = "var engine = new Engine(GODOT_CONFIG);"
    assert engine_anchor in html, "找不到 engine 构造"
    assets_js = engine_anchor + """

\t\t\t// 渐进加载：核心包(index.pck)跑起来后，后台拉资源包(音频 + 战斗大图)
\t\t\twindow.__assetsPckReady = false;
\t\t\tvar ASSETS_PCK_URL = "__COS_BASE__/assets.pck";
\t\t\tif (ASSETS_PCK_URL.indexOf("http") !== 0) ASSETS_PCK_URL = 'assets.pck';
\t\t\twindow.__assetsPckStarted = false;
\t\t\tfunction startAssetsPackDownload() {
\t\t\t\tif (window.__assetsPckStarted) return;
\t\t\t\twindow.__assetsPckStarted = true;
\t\t\t\t// 注意：preloadFile 只是入队，真正的写 FS 发生在 engine.init() 之前，
\t\t\t\t// 引擎已经在跑的时候必须自己下载再 copyToFS，否则 GDScript 挂载不到。
\t\t\t\t// 用 XHR 而不是 fetch，是为了能拿到 progress 事件更新进度面板。
\t\t\t\tvar xhr = new XMLHttpRequest();
\t\t\t\txhr.open('GET', ASSETS_PCK_URL);
\t\t\t\txhr.responseType = 'arraybuffer';
\t\t\t\txhr.onprogress = function (e) {
\t\t\t\t\tif (window.__dl) window.__dl('assets', 'assets.pck', e.loaded, e.lengthComputable ? e.total : 0);
\t\t\t\t};
\t\t\t\txhr.onload = function () {
\t\t\t\t\tif (xhr.status >= 400) {
\t\t\t\t\t\tconsole.error('[3k] assets.pck HTTP ' + xhr.status);
\t\t\t\t\t\twindow.__assetsPckReady = true;
\t\t\t\t\t\treturn;
\t\t\t\t\t}
\t\t\t\t\ttry {
\t\t\t\t\t\tvar buf = new Uint8Array(xhr.response);
\t\t\t\t\t\tif (window.__dl) window.__dl('assets', 'assets.pck', buf.length, buf.length);
\t\t\t\t\t\tengine.copyToFS('assets.pck', buf);
\t\t\t\t\t\twindow.__assetsPckReady = true;
\t\t\t\t\t\tconsole.log('[3k] assets.pck 已写入虚拟文件系统');
\t\t\t\t\t\tif (typeof window.__godotAssetsReady === 'function') {
\t\t\t\t\t\t\ttry { window.__godotAssetsReady(); } catch (e) { console.error(e); }
\t\t\t\t\t\t}
\t\t\t\t\t} catch (err) {
\t\t\t\t\t\tconsole.error('[3k] assets.pck 写入失败', err);
\t\t\t\t\t\twindow.__assetsPckReady = true;
\t\t\t\t\t}
\t\t\t\t};
\t\t\t\txhr.onerror = function () {
\t\t\t\t\tconsole.error('[3k] assets.pck 下载失败');
\t\t\t\t\twindow.__assetsPckReady = true; // 失败也放行，避免卡死在等待
\t\t\t\t};
\t\t\t\txhr.send();
\t\t\t}"""
    assets_js = assets_js.replace("__COS_BASE__", COS_BASE)
    html = html.replace(engine_anchor, assets_js, 1)
    print("资源包下载补丁已注入")

    old = "\t\t\t\t}).then(() => {\n\t\t\t\t\tsetStatusMode('hidden');"
    assert old in html, "找不到 startGame 成功回调"
    html = html.replace(
        old,
        "\t\t\t\t}).then(() => {\n"
        "\t\t\t\t\tstartAssetsPackDownload();\n"
        "\t\t\t\t\tsetStatusMode('hidden');\n", 1)
else:
    print("资源包补丁已存在")

open(path, "w", encoding="utf-8").write(html)
print("patched", path)