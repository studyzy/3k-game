# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_battle/focus_mask.gd
# 说明：战斗聚焦遮罩脚本。控制战斗场景的聚焦高亮。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends ColorRect


var focus_center: Vector2 = Vector2.ZERO

var focus_size: Vector2 = Vector2(100, 100)

func _ready():
	
	hide()

	
	material.set_shader_param("feather_amount", 0.02)
	material.set_shader_param("focus_center", Vector2(0.5, 0.5))
	material.set_shader_param("focus_size", Vector2(0.3, 0.3))
	material.set_shader_param("feather_amount", 0.02)
	return


func show_mask(center: Vector2, size: Vector2):
	focus_center = center
	focus_size = size
	update_shader_parameters()
	show()
	return


func hide_mask():
	hide()


func update_shader_parameters():
	if not material:
		return

	
	var scale_offset = Vector2(
		(self.rect_size.x * (1.0 - self.rect_scale.x)) * 0.5, 
		(self.rect_size.y * (1.0 - self.rect_scale.y)) * 0.5
	)
	
	
	var adjusted_center = focus_center + scale_offset

	
	var focus_center_normalized = Vector2(
		adjusted_center.x / self.rect_size.x, 
		adjusted_center.y / self.rect_size.y
	)
	
	
	var focus_size_normalized = Vector2(
		focus_size.x / (self.rect_size.x * self.rect_scale.x), 
		focus_size.y / (self.rect_size.y * self.rect_scale.y)
	)
	
	material.set_shader_param("focus_center", focus_center_normalized)
	material.set_shader_param("focus_size", focus_size_normalized)

	update()
	return



func update_focus_position(new_center: Vector2):
	focus_center = new_center
	update_shader_parameters()
	return

func update_focus_size(new_size: Vector2):
	focus_size = new_size
	update_shader_parameters()
	return
