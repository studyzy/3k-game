# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/children/btn_city.gd
# 说明：城市按钮子控件。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var Icon = $Icon
onready var cityname = $cityname
onready var inspection = $inspection

export (int) var cityId = 2


func _ready() -> void :
	Icon.material = Icon.material.duplicate()
	return


func _process(delta: float) -> void :
	update_vstate()
	return


func update_vstate():
	var sceneId = DataManager.get_current_scene_id()
	if sceneId != 10000:
		return
	var scene = SceneManager.current_scene()
	var city = clCity.city(cityId)
	var vstateId = city.get_vstate_id()
	if vstateId < 0:
		_set_city_color(["#ffffff", "#ffffff"])
	else:
		var vstate = clVState.vstate(vstateId)
		_set_city_color(vstate.get_color(), city.is_delegated())
	rect_position = city.get_location()
	Icon.scale = Vector2(1.5, 1.5)
	cityname.text = ""
	cityname.set("custom_colors/font_color", Color("FFFFFF"))
	cityname.rect_scale = Vector2(0.35, 0.35)
	cityname.rect_position = Vector2( - 7, 16)
	cityname.hide()
	inspection.hide()
	if scene == null or scene.con_citys_lines == null:
		return
	if scene.inspecting:
		var vstate_controlNo = DataManager.get_current_control_sort()
		var currentVstateId = DataManager.vstates_sort[DataManager.vstate_no]
		var left = city.inspection_left(currentVstateId)
		if left > 0:
			inspection.text = str(left)
			inspection.show()
	if not scene.con_citys_lines.visible:
		return
	match scene.city_line_mode:
		0:
			var vstate_controlNo = DataManager.get_current_control_sort()
			var currentVstateId = DataManager.vstates_sort[DataManager.vstate_no]
			var left = city.inspection_left(currentVstateId)
			if left > 0:
				inspection.text = str(left)
				inspection.show()
		1:
			cityname.text = city.get_name()
			if city.has_feature("大"):
				cityname.set("custom_colors/font_color", Color("FFFF00"))
			Icon.scale = Vector2(1, 1)
			cityname.rect_size = Vector2(112, 47)
			cityname.rect_scale = Vector2(0.45, 0.45)
			cityname.rect_position = Vector2( - 14, 16)
			cityname.show()
		2:
			cityname.text = city.get_leader_name()
			Icon.scale = Vector2(1, 1)
			if cityname.text == "":
				cityname.hide()
			else:
				cityname.rect_size = Vector2(112, 47)
				cityname.rect_scale = Vector2(0.35, 0.35)
				cityname.rect_position = Vector2( - 8, 4)
				if city.get_leader_id() == city.get_lord_id():
					cityname.rect_scale = Vector2(0.45, 0.45)
					cityname.rect_position = Vector2( - 14, 2)
					cityname.set("custom_colors/font_color", Color("FFFF00"))
				cityname.show()
		3:
			Icon.scale = Vector2(1, 1)
			cityname.rect_size = Vector2(220, 47)
			cityname.rect_scale = Vector2(0.45, 0.45)
			cityname.rect_position = Vector2( - 33, 16)
			cityname.show()
			var names = []
			var specials = city.get_special_equips()
			for key in specials:
				for equip in specials[key]:
					if equip.remaining() == 0:
						continue
					var suffix = ""
					if key == "外":
						suffix = "(战)"
					names.append(equip.name() + suffix)
			if names.empty():
				cityname.text = ""
				cityname.hide()
			else:
				cityname.text = "\n".join(names)
	return

func set_icon_visible(b: bool):
	Icon.visible = b
	return

func _set_city_color(array: Array, delegated: bool = false):
	var outColor = Color(str(array[0]))
	var inColor = Color(str(array[1]))
	var sh_material: ShaderMaterial = Icon.material
	var alpha = 0.5 if delegated else 1.0
	var dic_new = {
		"outline_color_rgb": Vector3(outColor.r, outColor.g, outColor.b), 
		"inside_color_rgb": Vector3(inColor.r, inColor.g, inColor.b), 
		"alpha": alpha, 
	};
	for key in dic_new:
		sh_material.set_shader_param(key, dic_new[key])
	return
