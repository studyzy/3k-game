extends Node

class Item:
	
	var id: int
	var name: String
	var desc: String
	var effects: Dictionary
	var canTransfer: bool = true
	
	func _init(itemInfo: Dictionary):
		id = int(itemInfo["ID"])
		name = str(itemInfo["name"])
		desc = str(itemInfo["desc"])
		effects = Dictionary(itemInfo["effect"])
		if itemInfo.has("transfer") and int(itemInfo["transfer"]) == 0:
			canTransfer = false

	func getCount(actorId: int):
		var actor = ActorHelper.actor(actorId)
		var items = actor.get_items()
		if not items.has(str(id)):
			return 0
		return int(items[str(id)])

	func decCount(actorId: int, cnt: int = 1) -> bool:
		var had = getCount(actorId)
		if had < cnt:
			return false
		var actor = ActorHelper.actor(actorId)
		actor.set_item_count(id, had - cnt)
		return true

	func incCount(actorId: int, cnt: int = 1) -> void :
		var actor = ActorHelper.actor(actorId)
		actor.set_item_count(id, getCount(actorId) + cnt)
		return

	func transfer(actorId: int, targetId: int, cnt: int = 1) -> bool:
		if not decCount(actorId, cnt):
			return false
		incCount(targetId, cnt)
		return true

	func use(actorId: int) -> PoolStringArray:
		var msgs = []
		var actor = ActorHelper.actor(actorId)
		if effects.empty():
			msgs.append("[{0}] 无法使用".format([name]))
			return msgs
		for key in effects:
			match key:
				"hp":
					if not actor.is_injured():
						msgs.append("体力充沛，无须使用{0}".format([name]))
						return msgs
					if not decCount(actorId):
						return msgs
					actor.recover_hp(int(effects[key]))
					msgs.append("体力回复至{0}".format([int(actor.get_hp())]))
		return msgs

var __items: Array = []

func _ready():
	for itemInfo in StaticManager.items_static:
		var item = Item.new(itemInfo)
		__items.append(item)
	return

func getItem(id: int) -> Item:
	if id < 0 or id >= __items.size():
		return null
	return __items[id]

func getActorItems(actorId: int) -> Array:
	var actor = ActorHelper.actor(actorId)
	var ret = []
	var actorItems = actor.get_items()
	for key in actorItems:
		var id = int(key)
		if id < 0 or id >= __items.size():
			continue
		var cnt = int(actorItems[key])
		ret.append([__items[id], cnt])
	return ret
