// 3k 网页版：底部加载进度面板
// 由 ~/bin/3k-postprocess.py 内联注入 index.html（不要直接改生成物）
// 版本标记 __dlPanelVer，改动后请递增，注入脚本会替换旧块
(function () {
	if (window.__dlPanelVer === 8) return;
	window.__dlPanelVer = 8;

	var G = {core: {files: {}, t: 0, d: 0}, assets: {files: {}, t: 0, d: 0}};
	var box = null, bar = null, lbl = null, pct = null, sub = null;

	function ensure() {
		if (!box) {
			box = document.getElementById('__dlp');
			bar = document.getElementById('__dlp_b');
			lbl = document.getElementById('__dlp_l');
			pct = document.getElementById('__dlp_p');
			sub = document.getElementById('__dlp_s');
		}
		return !!box;
	}

	function human(b) { return (b / 1048576).toFixed(1); }

	function render() {
		if (!ensure()) return;
		if (window.__dlHidden) return;   // 已经收尾，别再弹出来
		var coreDone = G.core.t > 0 && G.core.d >= G.core.t;
		// 核心包下完后切换到「后台资源」的百分比，避免百分比往回跳
		var ratio;
		if (coreDone && G.assets.t > 0) {
			ratio = Math.min(1, G.assets.d / G.assets.t);
		} else {
			ratio = G.core.t > 0 ? Math.min(1, G.core.d / G.core.t) : 0;
		}
		var allDone = coreDone && (G.assets.t === 0 || G.assets.d >= G.assets.t);

		box.style.display = 'block';
		box.style.opacity = '1';
		bar.style.width = (ratio * 100).toFixed(1) + '%';
		var pctTxt = (G.core.t > 0 || G.assets.t > 0) ? (ratio * 100).toFixed(0) + '%' : '…';
		// 后台阶段单独标注，避免用户看到百分比从 100% 掉回来
		if (coreDone && G.assets.t > 0 && G.assets.d < G.assets.t) pctTxt = '后台 ' + pctTxt;
		pct.textContent = pctTxt;

		lbl.textContent = coreDone
			? '核心资源已就绪，正在后台加载音频与战斗大图…'
			: '正在加载游戏资源…';

		var parts = [];
		if (G.core.t > 0) parts.push('核心 ' + human(G.core.d) + ' / ' + human(G.core.t) + ' MB');
		if (G.assets.t > 0) parts.push('后台资源 ' + human(G.assets.d) + ' / ' + human(G.assets.t) + ' MB');
		sub.textContent = parts.length ? parts.join('\u3000\u00b7\u3000') : '（等待服务器返回文件大小）';

		// 全部下完就淡出，别一直挡着画面
		if (allDone) {
			window.__dlHidden = true;
			setTimeout(function () {
				if (!box) return;
				box.style.transition = 'opacity .4s';
				box.style.opacity = '0';
				setTimeout(function () { if (box) box.style.display = 'none'; }, 450);
			}, 1500);
		}
	}

	// kind: 'core' | 'assets'；file 用来区分同组内的多个文件
	window.__dl = function (kind, file, loaded, total) {
		var g = G[kind];
		if (!g) return;
		var f = g.files[file] || (g.files[file] = {loaded: 0, total: 0});
		if (total > 0) f.total = total;
		if (loaded > f.loaded) f.loaded = loaded;
		if (f.total > 0 && f.loaded > f.total) f.loaded = f.total;
		var t = 0, d = 0;
		for (var k in g.files) { t += g.files[k].total; d += g.files[k].loaded; }
		g.t = t;
		g.d = d;
		render();
	};

	// Godot 3.6 用 fetch + response.body.getReader() 读 wasm/pck，
	// 这里劫持 fetch，克隆一份流来计数（原响应仍交给引擎）。
	var _fetch = window.fetch;
	if (_fetch) {
		window.fetch = function (input) {
			var url = (typeof input === 'string') ? input : ((input && input.url) || '');
			var m = /(assets[.]pck|index[.]pck|index[.]wasm)/.exec(String(url));
			var p = _fetch.apply(this, arguments);
			if (!m) return p;
			var kind = (m[1] === 'assets.pck') ? 'assets' : 'core';
			return p.then(function (resp) {
				var total = parseInt(resp.headers.get('content-length') || '0', 10) || 0;
				if (!total || !resp.body || !resp.clone) {
					window.__dl(kind, m[1], 0, 0);
					return resp;
				}
				try {
					var reader = resp.clone().body.getReader();
					var loaded = 0, step = 0;
					(function pump() {
						reader.read().then(function (r) {
							if (r.done) { window.__dl(kind, m[1], total, total); return; }
							loaded += r.value.length;
							if (++step % 8 === 0) window.__dl(kind, m[1], loaded, total);
							pump();
						}).catch(function () {});
					})();
				} catch (e) {}
				return resp;
			});
		};
	}

	// 兜底：自己下载 assets.pck 时用的是 XHR
	var _open = XMLHttpRequest.prototype.open;
	var _send = XMLHttpRequest.prototype.send;
	XMLHttpRequest.prototype.open = function (m, u) {
		this.__dlurl = u;
		return _open.apply(this, arguments);
	};
	XMLHttpRequest.prototype.send = function () {
		var self = this;
		var mm = /(assets[.]pck|index[.]pck|index[.]wasm)/.exec(String(self.__dlurl || ''));
		if (mm) {
			var kind = (mm[1] === 'assets.pck') ? 'assets' : 'core';
			self.addEventListener('progress', function (e) {
				window.__dl(kind, mm[1], e.loaded, e.lengthComputable ? e.total : 0);
			});
			self.addEventListener('load', function () {
				var n = 0;
				try { n = self.response ? (self.response.byteLength || 0) : 0; } catch (e) {}
				if (n > 0) window.__dl(kind, mm[1], n, n);
			});
		}
		return _send.apply(this, arguments);
	};
})();