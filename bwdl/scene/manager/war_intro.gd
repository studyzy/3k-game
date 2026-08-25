# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/manager/war_intro.gd
# 说明：战争开场动画脚本。播放进入战争前的开场演出。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

var tween: Tween
var shader_material: ShaderMaterial
var current_callback_flow: String = ""


const DISSOLVE_IN_TIME = 0.4
const DISSOLVE_OUT_TIME = 0.6
const TEXT_SCALE_IN_TIME = 0.3
const TEXT_FADE_IN_TIME = 0.2
const DESCRIPTION_FADE_IN_TIME = 0.2
const TEXT_FADE_OUT_TIME = 0.5
const TITLE_DELAY = 0.2
const DESCRIPTION_DELAY = 0.5
const DISPLAY_DURATION = 1.5
const STAY_AFTER_FADE = 0.1

func _ready() -> void :
	tween = $Tween
	visible = false

	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.1;
uniform vec4 edge_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// 创建噪声图案
	float noise = rand(UV * 10.0);

	// 从两边向中间的溶解效果
	float dist_from_edge = min(UV.x, 1.0 - UV.x) * 2.0;
	float threshold = dissolve_amount * 2.0;

	if (dist_from_edge < threshold - edge_width) {
		// 完全透明
		COLOR = vec4(0.0);
	} else if (dist_from_edge < threshold) {
		// 边缘发光
		float edge_factor = (dist_from_edge - (threshold - edge_width)) / edge_width;
		COLOR = mix(edge_color, tex_color, edge_factor);
		COLOR.a *= edge_factor;
	} else {
		// 正常显示
		COLOR = tex_color;
	}
}
"""

	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material

	return


func show_war_intro(wf: WarFight, callback_flow: String = "") -> void :
	current_callback_flow = callback_flow

	if wf == null:
		if callback_flow != "":
			FlowManager.add_flow(callback_flow)
		return

	
	var fromCity = wf.from_city()
	var targetCity = wf.target_city()
	var attackerLeader = null
	var defenderLeader = null

	if wf.attackerWV != null:
		attackerLeader = wf.attackerWV.get_leader()
	if wf.defenderWV != null:
		defenderLeader = wf.defenderWV.get_leader()

	
	var warTitle = ""
	if targetCity != null:
		warTitle = targetCity.get_name() + "之战"
	$Content / title.text = warTitle

	
	var descriptionText = ""
	if attackerLeader != null and defenderLeader != null:
		descriptionText = "{0}军 {1} vs {2}军 {3}".format([
			wf.from_vstate().get_dynasty_title_or_lord_name(), 
			attackerLeader.get_name(), 
			wf.target_vstate().get_dynasty_title_or_lord_name(), 
			defenderLeader.get_name(), 
		])
	elif attackerLeader != null and targetCity != null:
		descriptionText = "{0} 攻打 {1}".format([
			attackerLeader.get_name(), 
			targetCity.get_name(), 
		])
	elif targetCity != null:
		descriptionText = "进攻 " + targetCity.get_name()
	$Content / description.text = descriptionText

	
	visible = true
	modulate = Color(1, 1, 1, 1)
	$Content.modulate = Color(1, 1, 1, 1)

	
	shader_material.set_shader_param("dissolve_amount", 1.0)

	
	tween.interpolate_method(
		self, "_set_dissolve", 
		1.0, 0.0, 
		DISSOLVE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_CUBIC, 
		Tween.EASE_OUT
	)

	
	$Content / title.rect_scale = Vector2(0.7, 0.7)
	$Content / title.rect_pivot_offset = $Content / title.rect_size / 2
	$Content / title.modulate = Color(1, 1, 1, 0)

	tween.interpolate_property(
		$Content / title, "rect_scale", 
		Vector2(0.7, 0.7), Vector2(1.0, 1.0), 
		TEXT_SCALE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_BACK, 
		Tween.EASE_OUT, 
		TITLE_DELAY * Engine.time_scale
	)

	tween.interpolate_property(
		$Content / title, "modulate:a", 
		0.0, 1.0, 
		TEXT_FADE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT, 
		TITLE_DELAY * Engine.time_scale
	)

	
	$Content / description.rect_scale = Vector2(1.3, 1.3)
	$Content / description.rect_pivot_offset = $Content / description.rect_size / 2
	$Content / description.modulate = Color(1, 1, 1, 0)

	tween.interpolate_property(
		$Content / description, "rect_scale", 
		Vector2(1.3, 1.3), Vector2(1.0, 1.0), 
		TEXT_SCALE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_BACK, 
		Tween.EASE_OUT, 
		DESCRIPTION_DELAY * Engine.time_scale
	)

	tween.interpolate_property(
		$Content / description, "modulate:a", 
		0.0, 1.0, 
		DESCRIPTION_FADE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT, 
		DESCRIPTION_DELAY * Engine.time_scale
	)

	
	tween.interpolate_callback(self, DISPLAY_DURATION * Engine.time_scale, "_start_hide_animation")

	tween.start()
	return


func show_basic_info(info: String, description: String = "") -> void :
	current_callback_flow = ""

	$Content / title.text = info

	$Content / description.text = description

	
	visible = true
	modulate = Color(1, 1, 1, 1)
	$Content.modulate = Color(1, 1, 1, 1)

	
	shader_material.set_shader_param("dissolve_amount", 1.0)

	
	tween.interpolate_method(
		self, "_set_dissolve", 
		1.0, 0.0, 
		DISSOLVE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_CUBIC, 
		Tween.EASE_OUT
	)

	
	$Content / title.rect_scale = Vector2(0.7, 0.7)
	$Content / title.rect_pivot_offset = $Content / title.rect_size / 2
	$Content / title.modulate = Color(1, 1, 1, 0)

	tween.interpolate_property(
		$Content / title, "rect_scale", 
		Vector2(0.7, 0.7), Vector2(1.0, 1.0), 
		TEXT_SCALE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_BACK, 
		Tween.EASE_OUT, 
		TITLE_DELAY * Engine.time_scale
	)

	tween.interpolate_property(
		$Content / title, "modulate:a", 
		0.0, 1.0, 
		TEXT_FADE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT, 
		TITLE_DELAY * Engine.time_scale
	)

	
	$Content / description.rect_scale = Vector2(1.3, 1.3)
	$Content / description.rect_pivot_offset = $Content / description.rect_size / 2
	$Content / description.modulate = Color(1, 1, 1, 0)

	tween.interpolate_property(
		$Content / description, "rect_scale", 
		Vector2(1.3, 1.3), Vector2(1.0, 1.0), 
		TEXT_SCALE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_BACK, 
		Tween.EASE_OUT, 
		DESCRIPTION_DELAY * Engine.time_scale
	)

	tween.interpolate_property(
		$Content / description, "modulate:a", 
		0.0, 1.0, 
		DESCRIPTION_FADE_IN_TIME * Engine.time_scale, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT, 
		DESCRIPTION_DELAY * Engine.time_scale
	)

	
	tween.interpolate_callback(self, DISPLAY_DURATION * Engine.time_scale, "_start_hide_animation")

	tween.start()
	return


func _set_dissolve(value: float) -> void :
	if shader_material:
		shader_material.set_shader_param("dissolve_amount", value)


func _start_hide_animation() -> void :
	
	tween.interpolate_method(
		self, "_set_dissolve", 
		0.0, 1.0, 
		DISSOLVE_OUT_TIME * Engine.time_scale, 
		Tween.TRANS_CUBIC, 
		Tween.EASE_IN
	)

	
	tween.interpolate_property(
		$Content, "modulate:a", 
		1.0, 0.0, 
		TEXT_FADE_OUT_TIME * Engine.time_scale, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN
	)

	
	tween.interpolate_callback(self, (DISSOLVE_OUT_TIME + STAY_AFTER_FADE) * Engine.time_scale, "_on_animation_complete")

	tween.start()
	return

func _on_animation_complete() -> void :
	visible = false
	
	SceneManager.black.hide()
	if current_callback_flow != "":
		FlowManager.add_flow(current_callback_flow)
	current_callback_flow = ""
	return

func cleanup() -> void :
	tween.stop_all()
	tween.remove_all()
	return


func hide_immediately() -> void :
	cleanup()
	visible = false
	SceneManager.black.hide()
	
	if current_callback_flow != "":
		FlowManager.add_flow(current_callback_flow)
	current_callback_flow = ""
	return


func _input(event: InputEvent) -> void :
	if not visible:
		return

	if event.is_action_pressed("EMU_A") or event.is_action_pressed("EMU_B") or event.is_action_pressed("EMU_START"):
		
		if tween.is_active():
			hide_immediately()
