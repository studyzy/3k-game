extends Panel

var key_node_name = {
	"ANALOG_UP": "directions/txtUp", 
	"ANALOG_DOWN": "directions/txtDown", 
	"ANALOG_LEFT": "directions/txtLeft", 
	"ANALOG_RIGHT": "directions/txtRight", 
	"EMU_SELECT": "specials/txtSelect", 
	"EMU_START": "specials/txtStart", 
	"EMU_A": "actions/txtA", 
	"EMU_B": "actions/txtB", 
	"EMU_X": "actions/txtX", 
	"EMU_Y": "actions/txtY", 
	"EMU_MENU": "conMenu/txtValue", 
	"EMU_LAYOUT": "conLayout/txtValue", 
	"EMU_SPEED_UP": "conSpeedUp/txtValue", 
	"EMU_SPEED_DOWN": "conSpeedDown/txtValue", 
}

var key_set: Dictionary = {}
var cursor_speed_setting = {
	"默认": 18, 
	"稍慢": 12, 
	"贼慢": 6, 
}

func _ready() -> void :
	hide()
	reload()
	return

func reload() -> void :
	$settings / btnGroup.text = "#1"
	$settings / btnGroup.editor_description = "1"
	switch_keyset_group()
	$settings / btnCursorSpeed.text = "默认"
	for k in cursor_speed_setting:
		if SceneManager.cursor_speed == cursor_speed_setting[k]:
			$settings / btnCursorSpeed.text = k
	return

func init_set():
	var key_set_str = Global.get_file_text(StaticManager.KEY_SETTING_PATH);
	if key_set_str != "":
		key_set = parse_json(key_set_str)
	var hkSetting = StaticManager.get_hide_key_setting()
	if "隐藏虚拟键" in hkSetting:
		if Global.boolval(hkSetting["隐藏虚拟键"]):
			$settings / btnHideKey.text = "隐藏"
	if "光标速度" in hkSetting:
		SceneManager.cursor_speed = Global.intval(hkSetting["光标速度"], 18)
	reload()
	return


func _on_btnSaveKey_pressed() -> void :
	
	SceneManager.VirtualKey.keyboard = key_set;
	Global.save_file_text(StaticManager.KEY_SETTING_PATH, to_json(key_set));

	
	var text = $settings / btnHideKey.text
	var hide: bool = text == "隐藏"
	var hkSetting = {}
	hkSetting["隐藏虚拟键"] = hide
	SceneManager.VirtualKey.get_node("VirtualKey").visible = not hide;

	
	if not $settings / btnCursorSpeed.text in cursor_speed_setting:
		$settings / btnCursorSpeed.text = "默认"
	SceneManager.cursor_speed = cursor_speed_setting[$settings / btnCursorSpeed.text]
	hkSetting["光标速度"] = SceneManager.cursor_speed
	Global.save_file_text(StaticManager.HIDE_KEY_SETTING_PATH, JSON.print(hkSetting))
	hide()
	return

func _on_txtUp_gui_input(event: InputEvent) -> void :
	_update_key_setting("directions/txtUp", event)

func _on_txtDown_gui_input(event: InputEvent) -> void :
	_update_key_setting("directions/txtDown", event)

func _on_txtLeft_gui_input(event: InputEvent) -> void :
	_update_key_setting("directions/txtLeft", event)

func _on_txtRight_gui_input(event: InputEvent) -> void :
	_update_key_setting("directions/txtRight", event)

func _on_txtSelect_gui_input(event: InputEvent) -> void :
	_update_key_setting("specials/txtSelect", event)

func _on_txtStart_gui_input(event: InputEvent) -> void :
	_update_key_setting("specials/txtStart", event)

func _on_txtA_gui_input(event: InputEvent) -> void :
	_update_key_setting("actions/txtA", event)

func _on_txtB_gui_input(event: InputEvent) -> void :
	_update_key_setting("actions/txtB", event)

func _on_txtX_gui_input(event: InputEvent) -> void :
	_update_key_setting("actions/txtX", event)

func _on_txtY_gui_input(event: InputEvent) -> void :
	_update_key_setting("actions/txtY", event)

func _on_txtMenuValue_gui_input(event: InputEvent) -> void :
	_update_key_setting("conMenu/txtValue", event)

func _on_txtLayoutValue_gui_input(event: InputEvent) -> void :
	_update_key_setting("conLayout/txtValue", event)

func _on_txtSpeedUpValue_gui_input(event: InputEvent) -> void :
	_update_key_setting("conSpeedUp/txtValue", event)

func _on_txtSpeedDownValue_gui_input(event: InputEvent) -> void :
	_update_key_setting("conSpeedDown/txtValue", event)

func _on_btnHideKey_pressed() -> void :
	var text = $settings / btnHideKey.text;
	if text == "显示":
		text = "隐藏"
	else:
		text = "显示"
	var hide: bool = text == "隐藏"
	$settings / btnHideKey.text = text;
	SceneManager.VirtualKey.get_node("VirtualKey").visible = not hide
	return

func _on_btnBack_pressed() -> void :
	hide()
	return

func _update_key_setting(nodeName, event) -> bool:
	var key: String = ""
	for k in key_node_name.keys():
		if key_node_name[k] == nodeName:
			key = k
			break
	if key == "":
		return false
	var node = get_node(nodeName)
	if event is InputEventKey and event.pressed:
		var code = str(event.physical_scancode)
		_update_key_mapping(key, code)
		node.text = OS.get_scancode_string(event.physical_scancode)
		node.release_focus()
		return true
	if event is InputEventJoypadButton and event.pressed:
		var code = StaticManager.JOY_BUTTON_PREFIX + str(event.button_index)
		_update_key_mapping(key, code)
		node.text = code.replace(StaticManager.JOY_BUTTON_PREFIX, "J_")
		node.release_focus()
		return true
	return false

func _get_setting_codes(key: String) -> Array:
	if not key_set.has(key):
		return []
	var code = str(key_set[key])
	if code.begins_with("|"):
		code = code.right(1)
	if code.ends_with("|"):
		code = code.left(code.length() - 1)
	var codes = code.split("|")
	if codes.size() >= 2:
		return [codes[0], codes[1]]
	return [code, ""]

func _update_key_mapping(key: String, code: String):
	if not key_set.has(key):
		key_set[key] = code
		return
	var codes = _get_setting_codes(key)
	if codes.size() != 2:
		key_set[key] = code
	var idx = get_key_setting_group_idx()
	codes[idx] = code
	key_set[key] = "|{0}|{1}|".format(codes)

func _on_btnGroup_pressed():
	var current = get_key_setting_group_idx()
	current = 1 - current
	$settings / btnGroup.text = "#" + str(current + 1)
	$settings / btnGroup.editor_description = str(current + 1)
	switch_keyset_group()
	return

func switch_keyset_group():
	var idx = get_key_setting_group_idx()
	for key in key_set:
		var codes = _get_setting_codes(key)
		var scan_code = ""
		if codes.size() == 2:
			scan_code = codes[idx]
		var node_path = key_node_name[key]
		if StaticManager.JOY_BUTTON_PREFIX in scan_code:
			get_node(node_path).text = scan_code.replace(StaticManager.JOY_BUTTON_PREFIX, "J_")
		elif scan_code == "":
			get_node(node_path).text = "--"
		else:
			get_node(node_path).text = OS.get_scancode_string(int(scan_code))
	return

func _on_btnEditVkey_pressed() -> void :
	SceneManager.VirtualKey.change_set_mode(true);
	_on_btnBack_pressed();
	get_parent()._on_btnBackToGame_pressed();
	return

func _on_btnClearKey_pressed():
	for key in key_set:
		_update_key_mapping(key, "")
	switch_keyset_group()
	return

func _on_btnCursorSpeed_pressed():
	var text = $settings / btnCursorSpeed.text
	if not text in cursor_speed_setting:
		text = "默认"
	else:
		var speed = cursor_speed_setting[text]
		var speeds = cursor_speed_setting.values()
		speeds.sort()
		var idx = speeds.find(speed)
		idx = (idx + speeds.size() - 1) % speeds.size()
		speed = speeds[idx]
		for k in cursor_speed_setting:
			if cursor_speed_setting[k] == speed:
				text = k
				break
	$settings / btnCursorSpeed.text = text
	return

func get_key_setting_group_idx() -> int:
	return Global.intval($settings / btnGroup.editor_description, 1) - 1

func reset_layout_landscape() -> void :
	rect_size = Vector2(1024, 600)
	$conMenu.rect_position = Vector2(60, 50)
	$conMenu.rect_scale = Vector2(1, 1)
	$conLayout.rect_position = Vector2(280, 50)
	$conLayout.rect_scale = Vector2(1, 1)
	$conSpeedUp.rect_position = Vector2(580, 50)
	$conSpeedUp.rect_scale = Vector2(1, 1)
	$conSpeedDown.rect_position = Vector2(800, 50)
	$conSpeedDown.rect_scale = Vector2(1, 1)
	$directions.rect_position = Vector2(60, 120)
	$directions.rect_scale = Vector2(1, 1)
	$actions.rect_position = Vector2(720, 110)
	$actions.rect_scale = Vector2(1, 1)
	$specials.rect_position = Vector2(340, 300)
	$specials.rect_scale = Vector2(1, 1)
	$settings.rect_position = Vector2(100, 450)
	$settings.rect_scale = Vector2(1, 1)
	$system.rect_position = Vector2(160, 520)
	$system.rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait() -> void :
	rect_size = Vector2(600, 1560)
	$conMenu.rect_position = Vector2(60, 100)
	$conMenu.rect_scale = Vector2(1.5, 1.5)
	$conLayout.rect_position = Vector2(420, 100)
	$conLayout.rect_scale = Vector2(1.5, 1.5)
	$conSpeedUp.rect_position = Vector2(60, 210)
	$conSpeedUp.rect_scale = Vector2(1.5, 1.5)
	$conSpeedDown.rect_position = Vector2(420, 210)
	$conSpeedDown.rect_scale = Vector2(1.5, 1.5)
	$directions.rect_position = Vector2(60, 320)
	$directions.rect_scale = Vector2(1.5, 1.5)
	$actions.rect_position = Vector2(540, 310)
	$actions.rect_scale = Vector2(1.5, 1.5)
	$specials.rect_position = Vector2(240, 700)
	$specials.rect_scale = Vector2(1.5, 1.5)
	$settings.rect_position = Vector2(0, 1000)
	$settings.rect_scale = Vector2(1.2, 1.2)
	$system.rect_position = Vector2(0, 1100)
	$system.rect_scale = Vector2(1.3, 1.3)
	return
