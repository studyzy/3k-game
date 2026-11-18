// 3k 网页版：全屏按钮 / 首次手势自动全屏 / 竖屏提示
// 由 ~/bin/3k-postprocess.py 内联注入 index.html（不要直接改生成物）
// 版本标记 __fsVer，改动后请递增，注入脚本会替换旧块
(function () {
	if (window.__fsVer === 6) return;
	window.__fsVer = 6;

	var btn = document.getElementById('__fsBtn');
	if (!btn) return;

	function cur() {
		return document.fullscreenElement || document.webkitFullscreenElement ||
			document.mozFullScreenElement || null;
	}

	function lockLandscape() {
		try {
			if (screen.orientation && screen.orientation.lock) {
				screen.orientation.lock('landscape').catch(function () {});
			}
		} catch (e) {}
	}

	function update() {
		btn.textContent = cur() ? '退出全屏' : '全屏';
	}

	function enter() {
		var el = document.documentElement;
		var req = el.requestFullscreen || el.webkitRequestFullscreen ||
			el.mozRequestFullScreen || el.msRequestFullscreen;
		if (!req) {
			btn.textContent = '请用浏览器菜单全屏';
			return;
		}
		try {
			var r = req.call(el);
			if (r && r.then) { r.then(lockLandscape).catch(function () {}); }
			else { lockLandscape(); }
		} catch (e) {}
	}

	function exit() {
		var f = document.exitFullscreen || document.webkitExitFullscreen || document.mozCancelFullScreen;
		if (f) { try { f.call(document); } catch (e) {} }
	}

	btn.addEventListener('click', function (e) {
		e.stopPropagation();
		if (cur()) { exit(); } else { enter(); }
		setTimeout(update, 300);
	});

	['fullscreenchange', 'webkitfullscreenchange'].forEach(function (n) {
		document.addEventListener(n, update);
	});

	// 首次触摸 / 点击画面时自动尝试全屏（浏览器要求必须由用户手势触发）
	function once() {
		document.removeEventListener('pointerdown', once, true);
		if (!cur()) { enter(); }
	}
	document.addEventListener('pointerdown', once, true);

	// 竖屏提示：游戏画面是 1280x633 的横屏，竖着看会很小
	var rot = document.createElement('div');
	rot.id = '__rotHint';
	rot.textContent = '↻ 横屏体验更好（旋转手机，或点右上角全屏）';
	rot.style.position = 'fixed';
	rot.style.left = '0';
	rot.style.right = '0';
	rot.style.top = '44%';
	rot.style.zIndex = '100001';
	rot.style.textAlign = 'center';
	rot.style.color = '#fff';
	rot.style.font = "14px/1.6 -apple-system,'PingFang SC','Microsoft YaHei',sans-serif";
	rot.style.textShadow = '0 2px 6px #000';
	rot.style.pointerEvents = 'none';
	rot.style.transition = 'opacity .4s';
	rot.style.display = 'none';
	document.body.appendChild(rot);

	function rotCheck() {
		rot.style.display = (window.innerHeight > window.innerWidth) ? 'block' : 'none';
	}
	window.addEventListener('resize', rotCheck);
	window.addEventListener('orientationchange', function () { setTimeout(rotCheck, 200); });
	rotCheck();
	setTimeout(function () {
		rot.style.opacity = '0';
		setTimeout(function () {
			rot.style.display = 'none';
			window.removeEventListener('resize', rotCheck);
		}, 500);
	}, 20000);

	update();
})();