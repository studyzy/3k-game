# ==============================================================================
# 霸王的大陆 - 网页版渐进加载
# 文件：script/WebAssets.gd（自动加载）
#
# 网页版把 pck 拆成两个：
#   index.pck  核心包：脚本 / 场景 / 数据表 / 字体 / 界面纹理 —— 启动就要
#   assets.pck 资源包：音频 + 战斗大图 —— 引擎跑起来后由 index.html 后台下载
#
# 下载完成后挂载 assets.pck，并发 assets_ready（SoundManager 补播 BGM、SceneManager 放行）。
# 非 HTML5 平台直接视为已就绪，行为与原来完全一致。
#
# 注意：游戏在标题/署名页会把 SceneTree 暂停（Main.gd: get_tree().paused = true），
# 所以这里的轮询/定时器都必须是 PAUSE_MODE_PROCESS，否则永远不触发。
# ==============================================================================

extends Node

signal assets_ready

const PACK_NAME = "assets.pck"

var ready_mounted: bool = false
var _frame_count: int = 0
var _idle_ticks: int = 0
var _wait_layer: CanvasLayer = null
var _wait_label: Label = null
var _assets_deadline: float = 0.0


func is_ready() -> bool:
	return ready_mounted


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	print("[WebAssets] ready html5=", str(OS.has_feature("HTML5")), " os=", OS.get_name(), " paused=", str(get_tree().paused))
	if not OS.has_feature("HTML5"):
		ready_mounted = true
		return

	# 主路径：把 GDScript 回调交给 index.html，下载完成时由 JS 直接叫我们
	var cb = JavaScript.create_callback(self, "_on_js_assets_ready")
	var win = JavaScript.get_interface("window")
	if win != null:
		win.__godotAssetsReady = cb
		print("[WebAssets] callback registered")

	# 兜底路径：轮询 window.__assetsPckReady。
	# 注意不能用 _process：游戏在署名页把 SceneTree 暂停了，即使 pause_mode=PROCESS
	# 实测 _process 也只在第 1 帧跑过一次。SceneTree 的 idle_frame 信号不受暂停影响。
	_assets_deadline = OS.get_ticks_msec() + 60000
	get_tree().connect("idle_frame", self, "_on_idle_frame")
	print("[WebAssets] idle_frame hooked")


func _on_js_assets_ready(_args = null) -> void:
	print("[WebAssets] js callback fired")
	_mount_assets()


func _on_idle_frame() -> void:
	# 游戏开了 low_processor_mode，静止画面时主循环可能只有 1fps，
	# 所以每个 idle 帧都要查（JS eval 很便宜），不能按帧数取模。
	_idle_ticks += 1
	_poll_assets()


func _poll_assets() -> void:
	if ready_mounted:
		return
	# 必须用全局执行上下文，否则沙箱里拿不到 window（实测返回 null）
	var flag = String(JavaScript.eval("window.__assetsPckReady === true ? 'Y' : 'N'", true))
	if flag == "Y":
		_mount_assets()
	elif OS.get_ticks_msec() > _assets_deadline:
		print("[WebAssets] deadline, mount anyway")
		_mount_assets()



func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count <= 2 or _frame_count % 600 == 0:
		print("[WebAssets] tick#", _frame_count, " processing=", str(is_processing()), " ready=", str(ready_mounted))


func _mount_assets() -> void:
	if ready_mounted:
		return
	ready_mounted = true
	_hide_waiting()
	# 挂载顺序：先按相对路径，再试绝对路径
	var ok = ProjectSettings.load_resource_pack(PACK_NAME)
	if not ok:
		ok = ProjectSettings.load_resource_pack("/" + PACK_NAME)
	print("[WebAssets] mount %s -> %s" % [PACK_NAME, str(ok)])
	# 即便挂载失败也放行，免得玩家卡死（只是音频/战斗大图缺失）
	emit_signal("assets_ready")


# 换场景前用：先显示遮罩，调用方自己 while + yield 等 assets_ready
func show_waiting_overlay() -> void:
	_show_waiting()


func hide_waiting_overlay() -> void:
	_hide_waiting()


func _show_waiting() -> void:
	if _wait_layer == null:
		_wait_layer = CanvasLayer.new()
		_wait_layer.layer = 128
		add_child(_wait_layer)
		var bg = ColorRect.new()
		bg.color = Color(0, 0, 0, 0.8)
		bg.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		_wait_layer.add_child(bg)
		_wait_label = Label.new()
		_wait_label.text = "正在载入战斗资源…\n首次进入需要一点时间，请稍候"
		_wait_label.align = Label.ALIGN_CENTER
		_wait_label.valign = Label.VALIGN_CENTER
		_wait_label.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		_wait_label.add_color_override("font_color", Color(1, 1, 1, 1))
		_wait_layer.add_child(_wait_label)
	_wait_layer.visible = true


func _hide_waiting() -> void:
	if _wait_layer != null:
		_wait_layer.visible = false