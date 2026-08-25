# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/pnlJoySet.gd
# 说明：摇杆设置面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

signal joy_set_quit;

var key_control: Control = null;


onready var hsSize = get_node("hsSize");
onready var hsA = get_node("hsA");
onready var hsX = get_node("hsX");
onready var hsY = get_node("hsY");

func set_control_ready(_key_control: Control):
	key_control = _key_control;
	hsSize.value = key_control.rect_scale.x * 100;
	hsA.value = key_control.modulate.a * 100;
	
	hsX.max_value = 1024 - key_control.rect_size.x;
	hsY.max_value = 600 - key_control.rect_size.y;
	
	hsX.value = key_control.rect_position.x;
	hsY.value = key_control.rect_position.y;
	


func _on_btnDefault_pressed() -> void :
	SceneManager.VirtualKey.restore_vkey_default()
	return

func get_drag_data(_position):
	var d = self.duplicate();
	var mydata = {"control": d, "type": "joyset"};
	set_drag_preview(d)
	d.rect_position -= _position;
	return mydata;
	
func can_drop_data(_position, data):
	return true
	
func drop_data(_position, data):
	var d = data["control"];
	self.rect_position = d.rect_position;
	return


func _on_hsSize_value_changed(value: float) -> void :
	var set_value = Vector2(value / 100, value / 100);
	if key_control != null:
		key_control.rect_scale = set_value;
	return


func _on_hsA_value_changed(value: float) -> void :
	var set_value = value / 100;
	if key_control != null:
		key_control.modulate.a = set_value;
	return


func _on_hsX_value_changed(value: float) -> void :
	var set_value = value;
	if key_control != null:
		key_control.rect_position.x = set_value;
	return


func _on_hsY_value_changed(value: float) -> void :
	var set_value = value;
	if key_control != null:
		key_control.rect_position.y = set_value;
	return


func _on_btnSave_pressed() -> void :
	SceneManager.VirtualKey.write_vkey_set();
	emit_signal("joy_set_quit");
	return


func _on_btnCancel_pressed() -> void :
	SceneManager.VirtualKey.read_vkey_set();
	emit_signal("joy_set_quit");
	return


func _on_btnAutoSize_pressed():
	var vk = SceneManager.VirtualKey.get_node("VirtualKey")
	var x = vk.get_node("con_btnemu_Y").rect_scale.x
	var btns = [
		"con_btnemu_A", 
		"con_btnemu_B", 
		"con_btnemu_X", 
		"con_btnemu_Y", 
	]
	for btn in btns:
		vk.get_node(btn).rect_scale.x = x
		vk.get_node(btn).rect_scale.y = x
	x = vk.get_node("con_btnemu_select").rect_scale.x
	btns = [
		"con_btnemu_select", 
		"con_btnemu_start", 
	]
	for btn in btns:
		vk.get_node(btn).rect_scale.x = x
		vk.get_node(btn).rect_scale.y = x
	return


func _on_btnAutoAlign_pressed():
	var vk = SceneManager.VirtualKey.get_node("VirtualKey")
	vk.get_node("con_btnemu_X").rect_position.y = vk.get_node("con_btnemu_Y").rect_position.y
	vk.get_node("con_btnemu_A").rect_position.y = vk.get_node("con_btnemu_B").rect_position.y
	vk.get_node("con_btnemu_B").rect_position.x = vk.get_node("con_btnemu_Y").rect_position.x
	vk.get_node("con_btnemu_A").rect_position.x = vk.get_node("con_btnemu_X").rect_position.x
	vk.get_node("con_btnemu_start").rect_position.y = vk.get_node("con_btnemu_select").rect_position.y
	return
