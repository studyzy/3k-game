# ==============================================================================
# 文件：test/cloud_save_validate.gd
# 说明：headless 下校验 Cloud_Save.gd 可加载，并断言槽位/UUID/时间比较三个纯函数。
# 用法：
#   Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl \
#       --script res://test/cloud_save_validate.gd
# ==============================================================================
extends SceneTree

func _init():
	var bad = 0
	var script = load("res://script/Cloud_Save.gd")
	if script == null:
		print("CLOUD_SAVE FAIL load")
		print("CLOUD_SAVE_RESULT=1")
		quit()
		return

	var inst = script.new()

	var slot_cases = [
		["0", false], ["1", true], ["2", false], ["3", true], ["51", true],
		["52", false], ["01", false], ["endless", false], ["", false],
	]
	for c in slot_cases:
		var got = inst.is_network_slot(c[0])
		if got != c[1]:
			print("CLOUD_SAVE FAIL slot ", c[0], " got=", got, " want=", c[1])
			bad += 1

	if not inst.is_valid_uuid("3f2b8c1e-9d4a-4b7f-8c21-5e6a0b9d7c31"):
		print("CLOUD_SAVE FAIL uuid 合法值被判非法")
		bad += 1
	for v in ["", "nope", "3f2b8c1e-9d4a-4b7f-8c21", "3f2b8c1e-9d4a-1b7f-8c21-5e6a0b9d7c31"]:
		if inst.is_valid_uuid(v):
			print("CLOUD_SAVE FAIL uuid 非法值被判合法: ", v)
			bad += 1

	if not inst.is_newer("2026-11-21 10:00:00", "2026-11-20 23:59:59"):
		print("CLOUD_SAVE FAIL is_newer 云端较新")
		bad += 1
	if inst.is_newer("2026-11-20 10:00:00", "2026-11-21 10:00:00"):
		print("CLOUD_SAVE FAIL is_newer 本地较新")
		bad += 1
	if not inst.is_newer("2026-11-21 10:00:00", ""):
		print("CLOUD_SAVE FAIL is_newer 本地为空")
		bad += 1
	if inst.is_newer("", "2026-11-21 10:00:00"):
		print("CLOUD_SAVE FAIL is_newer 云端为空")
		bad += 1

	# 兜底 UUID：必须是合法 v4（第 3 组首位 4、第 4 组首位 8/9/a/b），且不重复。
	var seen = {}
	var uuid_bad = 0
	for i in 200:
		var u = inst._fallback_uuid()
		if not inst.is_valid_uuid(u):
			uuid_bad += 1
			if uuid_bad <= 3:
				print("CLOUD_SAVE FAIL fallback uuid 非法: ", u)
			continue
		seen[u] = true
		var segs = u.split("-")
		if segs.size() != 5:
			uuid_bad += 1
			if uuid_bad <= 3:
				print("CLOUD_SAVE FAIL fallback uuid 段数: ", u)
			continue
		if segs[2].substr(0, 1) != "4":
			uuid_bad += 1
			if uuid_bad <= 3:
				print("CLOUD_SAVE FAIL fallback uuid 版本位不是 4: ", u)
		if "89ab".find(segs[3].substr(0, 1)) < 0:
			uuid_bad += 1
			if uuid_bad <= 3:
				print("CLOUD_SAVE FAIL fallback uuid 变体位非法: ", u)
	if uuid_bad > 0:
		bad += uuid_bad
	if seen.size() != 200:
		print("CLOUD_SAVE FAIL fallback uuid 重复: 唯一数=", seen.size())
		bad += 1

	inst.free()
	print("CLOUD_SAVE_RESULT=", bad)
	quit()