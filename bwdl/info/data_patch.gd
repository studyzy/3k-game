extends "basiclist.gd"

class ActorPatchSorter extends Reference:

	func actor(a, b) -> bool:
		return a.actorId < b.actorId

	func desc_actor(a, b) -> bool:
		return a.actorId > b.actorId

	func hp(a, b) -> bool:
		var key = "体"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_hp(a, b) -> bool:
		var key = "体"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func power(a, b) -> bool:
		var key = "武"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_power(a, b) -> bool:
		var key = "武"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func wisdom(a, b) -> bool:
		var key = "知"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_wisdom(a, b) -> bool:
		var key = "知"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func leadership(a, b) -> bool:
		var key = "统"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_leadership(a, b) -> bool:
		var key = "统"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func politics(a, b) -> bool:
		var key = "政"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_politics(a, b) -> bool:
		var key = "政"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func moral(a, b) -> bool:
		var key = "德"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_moral(a, b) -> bool:
		var key = "德"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func courage(a, b) -> bool:
		var key = "胆"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_courage(a, b) -> bool:
		var key = "胆"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

func init() -> void :
	for btn in header.get_children():
		if not btn is Button:
			continue
		Global.clear_signals(btn, ["pressed"])
		btn.connect("pressed", self, "attr_sorting", [btn])
	sorter = ActorPatchSorter.new()
	return

func reload_data() -> Array:
	var ret = []
	var set = {}
	
	if keyword != "":
		for actor in ActorHelper.search_actors(keyword):
			ret.append(actor)
			set[actor.actorId] = 1
	
	for key in StaticManager.actor_patches:
		var actorId = int(key)
		if actorId < 0 or actorId >= StaticManager.actors.size():
			continue
		if actorId in set:
			continue
		ret.append(ActorHelper.actor(actorId))
	return ret

func create_row(item: Object, idList: PoolIntArray) -> HBoxContainer:
	if not item is ActorHelper.ActorInfo:
		return null
	var actor: ActorHelper.ActorInfo = item
	var created = row.duplicate()
	created.get_node("武将").text = StaticManager.actors[actor.actorId]["姓名"]
	for attr in StaticManager.PATCH_ATTRS:
		var field = created.get_node(attr)
		if not field is Button:
			continue
		var val = int(StaticManager.actors[actor.actorId][attr])
		var original = val
		var originalAttr = "原" + attr
		if originalAttr in StaticManager.actors[actor.actorId]:
			original = int(StaticManager.actors[actor.actorId][originalAttr])
		field.text = str(int(val))
		if original == val:
			field.modulate = Color(0.3, 0.3, 0.3, 0.3)
		field.connect("pressed", self, "field_patch", [actor.actorId, attr])
	var btn = created.get_node("operation/btn")
	btn.connect("pressed", self, "remove_patch", [actor.actorId])
	return created

func attr_sorting(btn):
	sorting(btn.editor_description)
	return

func remove_patch(actorId: int) -> void :
	var dialog = ConfirmationDialog.new()
	dialog.window_title = "请确认"
	dialog.dialog_text = "\n确定要删除{0}的数据补丁吗？".format([
		ActorHelper.actor(actorId).get_name(), 
	])
	dialog.rect_size = Vector2(350, 150)
	dialog.get_ok().text = "删！"
	dialog.get_cancel().text = "再想想"
	add_child(dialog)
	dialog.connect("confirmed", self, "remove_patch_confirmed", [actorId])
	dialog.popup_exclusive = true
	dialog.popup_centered()
	return

func remove_patch_confirmed(actorId: int) -> void :
	StaticManager.remove_actor_patches(actorId)
	nav.get_node("keyword").text = ""
	reload_list("", page)
	return

func field_patch(actorId: int, attr: String) -> void :
	var data = StaticManager.actors[actorId]
	var patch = Global.dic_val(StaticManager.actor_patches, str(actorId), {})
	var original = int(data[attr])
	var originalAttr = "原" + attr
	if originalAttr in data:
		original = int(data[originalAttr])
	var patched = Global.dic_val(patch, attr, original)
	detail.get_node("title").text = data["姓名"] + "：" + attr
	detail.get_node("title").editor_description = "{0}|{1}".format([actorId, attr])
	detail.get_node("value").text = str(original)
	detail.get_node("patch").text = str(patched)
	detail.popup_centered()
	detail.popup_exclusive = true
	return

func save_patch():
	var pieces = detail.get_node("title").editor_description.split("|")
	var actorId = int(pieces[0])
	var key = str(actorId)
	var attr = pieces[1]
	var patched = int(detail.get_node("patch").text)
	if patched <= 0 or patched > 99:
		return
	if not key in StaticManager.actor_patches:
		StaticManager.actor_patches[key] = {}
	StaticManager.actor_patches[key][attr] = patched
	StaticManager.save_actor_patches()
	reload_list(keyword, page)
	return

func close_patch():
	detail.hide()
	return

func reset_layout_landscape() -> void :
	pageSize = 6
	return

func reset_layout_portrait() -> void :
	pageSize = 15
	return
