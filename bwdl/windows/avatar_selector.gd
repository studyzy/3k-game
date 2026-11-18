extends WindowDialog

const FACE_RES_PATH = "res://packed/images/actor/face/"
const ORIGINAL_AVATAR_COUNT = 4
const ORIGINAL_PER_IMAGE = 60
const ORIGINAL_PER_HEIGHT = 40

var lastAvatarTab: int = - 1
var largeAvatarMode: bool = false
var actorId: int = - 1
var loadedTabs: Dictionary = {}

onready var avatarBtn = $avatar
onready var tc = $avatars / tc

signal avatar

func _ready() -> void :
	lastAvatarTab = - 1
	loadedTabs = {}
	switch_large_avatar_mode(false)
	return

func switch_large_avatar_mode(flag: bool):
	largeAvatarMode = flag
	$avatars / head / small.disabled = not flag
	$avatars / head / large.disabled = flag
	
	var cur = tc.current_tab
	if cur in loadedTabs:
		loadedTabs.erase(cur)
		_load_tab(cur)
	return

func start_for(targetId: int) -> void :
	actorId = targetId
	var actor = ActorHelper.actor(targetId)
	if lastAvatarTab == - 1:
		match actor.get_gender():
			"男":
				tc.current_tab = 0
			"女":
				tc.current_tab = 1
			_:
				tc.current_tab = 2
	_load_tab(tc.current_tab)
	popup_exclusive = true
	popup_centered()
	return

func tab_changed(tab):
	lastAvatarTab = tab
	_load_tab(tab)
	return

func _load_tab(tabIdx: int) -> void :
	if tabIdx in loadedTabs:
		return
	loadedTabs[tabIdx] = true
	var tabNode = tc.get_child(tabIdx)
	if tabNode == null:
		return
	var tabName = tabNode.name
	match tabName:
		"男":
			_load_diy_tab(tabNode, "diy/male/", "男")
		"女":
			_load_diy_tab(tabNode, "diy/female/", "女")
		"无性":
			_load_diy_tab(tabNode, "diy/genderless/", "无性")
		"自定义":
			_load_custom_tab(tabNode)
		"原版":
			_load_original_tab(tabNode)
	return

func _load_diy_tab(tab: ScrollContainer, subPath: String, groupName: String) -> void :
	var lst: GridContainer = tab.get_node("avatars")
	lst.columns = 4 if largeAvatarMode else 2
	Global.clearNode(lst)
	var modAvatarPath = DataManager.get_common_path() + "mod/avatars/"
	
	var modAvatars = []
	if Global.dir_exists(modAvatarPath + subPath):
		for file in Global.scan_all_files(modAvatarPath + subPath, false):
			var filename = file.get_file()
			var extname = filename.get_extension()
			if not extname in ["jpg", "jpeg", "png", "webp"]:
				continue
			modAvatars.append(filename)
	modAvatars.sort()
	for avatar in modAvatars:
		var fullPath = modAvatarPath + subPath + avatar
		if Global.get_file_size(fullPath) > StaticManager.MAX_AVATAR_IMAGE_SIZE:
			continue
		var texture = Global.load_pic_with_cache(fullPath)
		var btn = create_avatar_button(texture)
		var label = "mod/" + groupName + avatar
		var path = "mod/" + subPath + avatar
		btn.hint_tooltip = label
		btn.connect("pressed", self, "set_avatar", [label, path])
		lst.add_child(btn)
	
	var avatars = []
	for file in Global.scan_all_files(FACE_RES_PATH + subPath, false):
		var filename = file.get_file()
		var extname = filename.get_extension()
		if not extname in ["jpg", "jpeg", "png", "webp"]:
			continue
		avatars.append(filename)
	avatars.sort()
	for avatar in avatars:
		var texture = load(FACE_RES_PATH + subPath + avatar)
		var btn = create_avatar_button(texture)
		var idx = avatar.replace(".png", "")
		var label = groupName + idx
		var path = subPath + idx
		btn.hint_tooltip = label
		btn.connect("pressed", self, "set_avatar", [label, path])
		lst.add_child(btn)
	return

func _load_custom_tab(tab) -> void :
	var lst = tab.get_node("avatars")
	lst.columns = 4 if largeAvatarMode else 2
	Global.clearNode(lst)
	for k in StaticManager.extra_avatars:
		var btn = create_avatar_button(StaticManager.extra_avatars[k])
		var label = "自定义/" + k
		var path = "自定义/" + k
		btn.hint_tooltip = label
		btn.connect("pressed", self, "set_avatar", [label, path])
		lst.add_child(btn)
	return

func _load_original_tab(tab) -> void :
	var lst = tab.get_node("avatars")
	lst.columns = 4 if largeAvatarMode else 2
	Global.clearNode(lst)
	var globalIdx = 0
	for imgIdx in ORIGINAL_AVATAR_COUNT:
		var path = "res://resource/images/actor/face/original_%d.png" % (imgIdx + 1)
		var texture = Global.load_pic_with_cache(path)
		if texture == null:
			continue
		var width = texture.get_width()
		var height = texture.get_height()
		var count = int(height / ORIGINAL_PER_HEIGHT)
		for i in count:
			var rect = Rect2(0, i * ORIGINAL_PER_HEIGHT, width, ORIGINAL_PER_HEIGHT)
			var btn = create_avatar_button(texture, rect)
			var label = "原版/" + str(globalIdx)
			var avatarPath = "原版/" + str(globalIdx)
			btn.hint_tooltip = label
			btn.connect("pressed", self, "set_avatar", [label, avatarPath])
			lst.add_child(btn)
			globalIdx += 1
	return

func create_avatar_button(texture: Texture, rect: Rect2 = Rect2(0, 0, 0, 0)) -> TextureButton:
	var singleFrame = false
	var btn = avatarBtn.duplicate()
	var sp = Sprite.new()
	sp.texture = texture
	sp.centered = false
	var width = rect.size.x
	if width <= 0:
		width = texture.get_width()
	var height = rect.size.y
	if height <= 0:
		height = texture.get_height()
	sp.position = Vector2.ZERO
	var ratio = int(width * 50 / height)
	if ratio >= 36 and ratio <= 44:
		singleFrame = true
	if largeAvatarMode:
		sp.region_enabled = true
		var xFrames = 1 if singleFrame else 8
		if rect.size.x == 0:
			rect.size = Vector2(width / xFrames, height)
		else:
			rect.size.x = rect.size.x / xFrames
		sp.region_rect = rect
		sp.scale = Vector2(32.0 * xFrames / width * 4, 40.0 / height * 4)
		btn.rect_min_size = Vector2(128, 160)
		btn.rect_size = Vector2(128, 160)
	else:
		if rect.size.x > 0 and rect.size.y > 0:
			sp.region_enabled = true
			sp.region_rect = rect
		sp.scale = Vector2(256.0 / width, 40.0 / height)
		btn.rect_min_size = Vector2(256, 40)
		btn.rect_size = Vector2(256, 40)
		if singleFrame:
			sp.scale = Vector2(32.0 / width, 40.0 / height)
			btn.rect_min_size = Vector2(32, 40)
			btn.rect_size = Vector2(32, 40)
	btn.add_child(sp)
	btn.show()
	return btn

func set_avatar(name: String, avatar: String) -> void :
	hide()
	var actor = ActorHelper.actor(actorId)
	actor.set_avatar(avatar)
	actor._set_attr_int("头像切换", 0)
	emit_signal("avatar", name, avatar)
	return
