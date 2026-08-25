# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/children/actor_face.gd
# 说明：武将头像子控件。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var nprFace = get_node("nprFace");

var actorId: int = - 1;
var mood: int = 2;
var mouth: bool = false;
var sort_index: int = 0;
var has_face = false;

const WIDTH = 32
const HEIGHT = 40

var avatarWidth: int = - 1
var avatarHeight: int = - 1


func set_actor(_actorId: int, _mood: int = 2):
	has_face = true;
	actorId = _actorId;
	mood = _mood;
	if DataManager.secret_mood != - 1:
		mood = DataManager.secret_mood
	mouth = false;
	
	if actorId == - 1:
		sort_index = 0
		has_face = false
		load_face_img(StaticManager.special_avatars["random"])
		nprFace.region_rect = Rect2()
	elif actorId == StaticManager.ACTOR_ID_SLIME_GOD:
		sort_index = 0
		load_face_img(StaticManager.special_avatars["god"])
	elif actorId < 0:
		has_face = false
		nprFace.hide()
		return
	else:
		var actor = ActorHelper.actor(actorId)
		var setting = actor.get_avatar_setting()
		sort_index = setting[0]
		load_face_img(setting[1])
	update_mouth()
	nprFace.show()
	return

func set_mood(_mood: int) -> void :
	mood = _mood
	return

func set_mouth(_mouth: int) -> void :
	mouth = _mouth
	return

var next_face_displayed = true

func next_face() -> void :
	if not next_face_displayed:
		return
	if not mouth:
		mouth = true
	else:
		mouth = false
		mood = (mood + 1) % 4
	next_face_displayed = false
	return

func _process(delta: float) -> void :
	update_mouth()
	return

func update_mouth():
	if actorId < 0 and actorId != StaticManager.ACTOR_ID_SLIME_GOD:
		return
	var mouthFlag = 1 if mouth else 0

	var width = WIDTH
	var height = HEIGHT

	var ratio = int(avatarWidth * 50 / avatarHeight)
	var xFrames = 8
	if ratio >= 36 and ratio <= 44:
		xFrames = 1
	if avatarWidth != WIDTH * 8:
		
		width = int(avatarWidth / xFrames)
		height = avatarHeight

	if xFrames == 1:
		nprFace.region_rect = Rect2(0, 0, width, height)
	else:
		nprFace.region_rect = Rect2(
			mood * 2 * width + mouthFlag * width, height * int(sort_index), 
			width, height
		)
	next_face_displayed = true
	return

func load_face_img(img):
	avatarWidth = img.get_width()
	avatarHeight = img.get_height()
	nprFace.texture = img
	return
