extends Control

var is_save = false;

var page_no: int = 0;
var cursor_index = 0

var common_save_path = ""

const AUTO_SAVE_NAMES = ["unused", "unused", "unused", "endless", "monthly", "annualy", "defence", "paused"]
const AUTO_SAVE_DESCS = ["<保留>", "<保留>", "<保留>", "无尽过关", "月度自动", "年度自动", "最近防御", "后台自动"]

onready var gv = $gc / list / items
onready var lblLocation = $gc / footer / lblLocation

onready var saveItems = gv.get_children()
onready var btnPrev = $gc / footer / gc / btnPrePage
onready var lblPage = $gc / footer / gc / lblPage
onready var btnNext = $gc / footer / gc / btnNextPage

var btnCopyLink: Button = null

func _ready() -> void :
	hide()
	OS.request_permissions();
	var osName = OS.get_name()
	common_save_path = DataManager.get_common_path() + "save/"

	var d: Directory = Directory.new();
	if not d.dir_exists(common_save_path):
		d.make_dir_recursive(common_save_path)
	lblLocation.text = "存档位置:" + common_save_path;
	if osName == "Android" and not "手机存储" in lblLocation.text:
		lblLocation.text = str(lblLocation.text).replacen("storage/emulated/0", "手机存储")

	for i in saveItems.size():
		var saveItem = saveItems[i]
		saveItem.add_user_signal("saved")
		saveItem.add_user_signal("selected")
		saveItem.connect("saved", self, "item_saved", [i])
		saveItem.connect("selected", self, "item_selected", [i])

	_setup_cloud_footer()
	init_data(StaticManager.saveIdx.page)
	return

func init_data(current: int):
	set_process(true);
	var total = SaveDataIndex.SAVE_PAGE_TOTAL
	var extra = int(AUTO_SAVE_NAMES.size() / 4)
	if is_save:
		$gc / header / notice.text = "请选择存档点";
	else:
		$gc / header / notice.text = "读取哪个存档？";
		total += extra
	if current > total:
		current = 0
	if current < 0:
		current = total
	page_no = current
	var settings = []
	if not is_save and current > SaveDataIndex.SAVE_PAGE_TOTAL:
		var offset = (current - SaveDataIndex.SAVE_PAGE_TOTAL - 1) * 4
		for i in saveItems.size():
			var idx = offset + i
			settings.append([AUTO_SAVE_NAMES[idx], AUTO_SAVE_DESCS[idx]])
	else:
		for i in saveItems.size():
			var save_item_no = int(current * 4 + i)
			settings.append([str(save_item_no), ""])
	for i in saveItems.size():
		var s = settings[i]
		var saveItem = saveItems[i].get_node_or_null("save_item")
		if saveItem == null:
			continue
		saveItem.init_data(s[0], common_save_path, is_save, s[1], self)
	lblPage.text = "第{0}/{1}页".format([current + 1, total + 1])
	cursor_change()
	return

func item_saved(i: int) -> void :
	cursor_index = i
	cursor_change()
	refresh_cloud_footer()
	return

func item_selected(i: int) -> void :
	cursor_index = i
	cursor_change()
	return

func cursor_change():
	for i in saveItems.size():
		var saveItem = saveItems[i].get_node_or_null("save_item")
		if saveItem == null:
			continue
		saveItem.set_is_cursor(i == cursor_index)

	if cursor_index == saveItems.size():
		btnPrev.self_modulate = Color("#00ff22")
	else:
		btnPrev.self_modulate = Color("#ffffff")
		
	if cursor_index == saveItems.size() + 1:
		btnNext.self_modulate = Color("#00ff22")
	else:
		btnNext.self_modulate = Color("#ffffff")
	return

func _process(delta: float) -> void :
	if not visible:
		set_process(false)
		return
	if SceneManager.process_popuped():
		return

	if Input.is_action_just_pressed("ANALOG_UP"):
		move_up()
		cursor_change()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		move_down()
		cursor_change()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		move_left()
		cursor_change()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		move_right()
		cursor_change()
	if Input.is_action_just_pressed("EMU_START"):
		init_data(page_no + 1)
		return
	if Input.is_action_just_pressed("EMU_SELECT"):
		init_data(page_no - 1)
		return
	if Input.is_action_just_pressed("EMU_B"):
		_on_btnBack_pressed()
		return
	if Input.is_action_just_pressed("EMU_A"):
		if cursor_index == saveItems.size():
			init_data(page_no - 1)
			return
		if cursor_index == saveItems.size() + 1:
			init_data(page_no + 1)
			return
		if cursor_index < 0 or cursor_index >= saveItems.size():
			return
		var saveItem = saveItems[cursor_index].get_node_or_null("save_item")
		if saveItem == null:
			return
		saveItem.emit_signal("pressed")
		SceneManager.over_animation.hide()
	return

func move_up():
	var cols = gv.columns
	var rows = int(saveItems.size() / cols)
	if cursor_index == saveItems.size():
		cursor_index = (rows - 1) * cols
		return
	if cursor_index > saveItems.size():
		cursor_index = rows * cols - 1
		return
	var y = cursor_index / cols
	var x = cursor_index % cols
	if y == 0:
		cursor_index = rows * cols + x
	else:
		cursor_index -= cols
	return

func move_down():
	var cols = gv.columns
	var rows = int(saveItems.size() / cols)
	if cursor_index == saveItems.size():
		cursor_index = 0
		return
	if cursor_index > saveItems.size():
		cursor_index = cols - 1
		return
	var y = cursor_index / cols
	var x = cursor_index % cols
	if y == rows - 1:
		cursor_index = rows * cols + x
	else:
		cursor_index += cols
	return

func move_left():
	var cols = gv.columns
	var rows = int(saveItems.size() / cols)
	if cursor_index == saveItems.size():
		cursor_index = saveItems.size() + 1
		return
	if cursor_index > saveItems.size():
		cursor_index = saveItems.size()
		return
	var y = cursor_index / cols
	var x = cursor_index % cols
	x = (x + cols - 1) % cols
	cursor_index = y * rows + x
	return

func move_right():
	var cols = gv.columns
	var rows = int(saveItems.size() / cols)
	if cursor_index == saveItems.size():
		cursor_index = saveItems.size() + 1
		return
	if cursor_index > saveItems.size():
		cursor_index = saveItems.size()
		return
	var y = cursor_index / cols
	var x = cursor_index % cols
	x = (x + 1) % cols
	cursor_index = y * rows + x
	return

func _on_btnBack_pressed() -> void :
	hide()
	return

func _on_btnNextPage_pressed() -> void :
	init_data(page_no + 1)
	return

func _on_btnPrePage_pressed() -> void :
	init_data(page_no - 1)
	return

func reset_layout_landscape() -> void :
	rect_position = Vector2(0, 0)
	rect_size = Vector2(1024, 600)
	$bg.rect_size = rect_size
	$gc / list.rect_min_size.y = 400
	gv.rect_scale = Vector2(1, 1)
	gv.columns = 2
	gv.rect_position.x = 176
	return

func reset_layout_portrait() -> void :
	rect_position = Vector2(0, 0)
	rect_size = Vector2(600, 1560)
	$bg.rect_size = rect_size
	$gc / list.rect_min_size.y = 1300
	gv.rect_scale = Vector2(1.7, 1.7)
	gv.columns = 1
	gv.rect_position.x = 240
	return

func _setup_cloud_footer() -> void :
	if not CloudSave.is_web():
		return
	btnCopyLink = Button.new()
	btnCopyLink.text = "复制链接"
	btnCopyLink.rect_position = Vector2(770, 58)
	btnCopyLink.rect_min_size = Vector2(160, 44)
	btnCopyLink.connect("pressed", self, "_on_btnCopyLink_pressed")
	$gc / footer.add_child(btnCopyLink)
	refresh_cloud_footer()
	return

func refresh_cloud_footer() -> void :
	if not CloudSave.is_web():
		return
	lblLocation.text = "云存档：已同步 {0} 个网络存档位".format([CloudSave.get_synced_count()])
	return

func _on_btnCopyLink_pressed() -> void :
	CloudSave.copy_link()
	return
