# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/menu/pnlSoundSet.gd
# 说明：声音设置面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

const BUSES = ["Music", "SE"]

onready var chkSoundSpeed = $gc / sound / chkSoundSpeed
onready var chkSoundEffect = $gc / sound / chkSoundEffect
onready var hsMusicVolume = $gc / sound / hsMusicVolume
onready var hsSEVolume = $gc / sound / hsSEVolume
onready var lblMusicPctg = $gc / sound / lblMusicPctg
onready var lblSEPctg = $gc / sound / lblSEPctg

onready var chkExpandLandscape = $gc / view / chkExpandLandscape
onready var chkOriginalSprite = $gc / view / chkOriginalSprite
onready var chkExtraAvatars = $gc / view / chkExtraAvatars

func _ready() -> void :
	hide()
	return

func init():
	var musicIdx = AudioServer.get_bus_index("Music")
	var musicDb = AudioServer.get_bus_volume_db(musicIdx)
	hsMusicVolume.value = db2linear(musicDb)
	var seIdx = AudioServer.get_bus_index("SE")
	var seDb = AudioServer.get_bus_volume_db(seIdx)
	hsSEVolume.value = db2linear(seDb)
	chkSoundSpeed.pressed = SoundManager.sound_speed_not_change
	chkSoundEffect.pressed = SoundManager.sound_effect_disabled
	chkExpandLandscape = SoundManager.layout_landscape_extend
	chkOriginalSprite.pressed = SoundManager.traditional_soldier_image
	chkExtraAvatars.pressed = SoundManager.custom_avatar_prefered
	show_label()
	return

func _on_hsMusicVolume_drag_ended(value_changed: bool) -> void :
	var val = float(hsMusicVolume.value)
	var dic = SoundManager.get_sound_set()
	dic["音乐音量"] = val
	SoundManager.set_sound_set(dic)
	SoundManager.update_volume()
	return

func _on_hsSEVolume_drag_ended(value_changed: bool) -> void :
	var val = float(hsSEVolume.value)
	var dic = SoundManager.get_sound_set()
	dic["音效音量"] = val
	SoundManager.set_sound_set(dic)
	SoundManager.update_volume()
	
	SoundManager.play_se2("res://resource/sounds/se/ding.ogg")
	return

func show_label():
	SoundManager.pause(false)
	if true:
		var val = float(hsMusicVolume.value)
		var maxval = float(hsMusicVolume.max_value)
		var minval = float(hsMusicVolume.min_value)
		var pctg = (val - minval) / (maxval - minval)
		lblMusicPctg.text = "{0}%".format([int(pctg * 100.0)])
	if true:
		var val = float(hsSEVolume.value)
		var maxval = float(hsSEVolume.max_value)
		var minval = float(hsSEVolume.min_value)
		var pctg = (val - minval) / (maxval - minval)
		lblSEPctg.text = "{0}%".format([int(pctg * 100.0)])
	return

func _on_btnBack_pressed() -> void :
	SoundManager.pause(true)
	hide()
	return

func _on_hsMusicVolume_value_changed(value: float) -> void :
	show_label()
	return

func _on_hsSEVolume_value_changed(value: float) -> void :
	show_label()
	return


func _on_ChkSoundSpeed_toggled(button_pressed: bool) -> void :
	var dic = SoundManager.get_sound_set();
	dic["不加速"] = button_pressed
	SoundManager.set_sound_set(dic)
	return


func _on_ChkSoundEffect_toggled(button_pressed: bool) -> void :
	var dic = SoundManager.get_sound_set()
	dic["关闭音效"] = button_pressed
	SoundManager.set_sound_set(dic)
	return

func _on_ChkOriginalSprite_toggled(button_pressed: bool) -> void :
	var dic = SoundManager.get_sound_set()
	dic["传统兵模"] = button_pressed
	SoundManager.set_sound_set(dic)
	
	if DataManager.get_current_scene_id() == 30000:
		for bu in DataManager.battle_units:
			if bu == null:
				continue
			bu.requires_update = true
	return

func _on_ChkExtraAvatars_toggled(button_pressed: bool) -> void :
	var dic = SoundManager.get_sound_set()
	dic["自定义头像"] = button_pressed
	SoundManager.set_sound_set(dic)
	return

func _on_btnSwitchLayout_pressed():
	SceneManager.switch_layout()
	return

func _on_ChkLandscapeExtend_toggled(button_pressed: bool):
	var dic = SoundManager.get_sound_set()
	dic["横屏扩展"] = button_pressed
	SoundManager.set_sound_set(dic)
	return

func reset_layout_landscape() -> void :
	rect_size = Vector2(1024, 600)
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1, 1)
	$gc.columns = 2
	$btnBack.rect_position = Vector2(432, 470)
	return

func reset_layout_portrait() -> void :
	rect_size = Vector2(600, 1560)
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.5, 1.5)
	$gc.columns = 1
	$btnBack.rect_position = Vector2(240, 800)
	return

func _process(delta: float) -> void :
	if not visible:
		return
	if SceneManager.popuped:
		return
	if Input.is_action_just_pressed("EMU_B"):
		_on_btnBack_pressed()
		return
	return
