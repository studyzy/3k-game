extends Panel


class SimulatedMapCursor:
	var position

	func show():
		return

	func hide():
		return

var cell_columns = 32
var cell_rows = 20
var blocks = {}
var cursor = SimulatedMapCursor.new()
var next_shrink_actors

func require_camer_move(wa):
	return false

func is_valid_position(pos: Vector2) -> bool:
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x > cell_columns - 1 or pos.y > cell_rows - 2:
		return false
	return true

func get_blockEN_by_CN(terrian: String) -> String:
	for en in StaticManager.BLOCKS_EN_CN:
		if StaticManager.BLOCKS_EN_CN[en] == terrian:
			return en
	return "unknown"

func get_blockCN_by_position(pos: Vector2):
	if blocks.has(pos):
		return blocks[pos]
	return "未知"


func set_blockCN_by_position(pos: Vector2, block):
	blocks[pos] = block
	return

func set_cursor_location(pos: Vector2, update: bool):
	cursor.position = pos
	return


func show_can_choose_actors(actorIds: PoolIntArray, fromId: int = - 1, disabledTargets: PoolIntArray = []):
	return


func camer_to_actorId(actorId: int, nextFlow: String):
	return


func show_color_block_by_position(positions: PoolVector2Array):
	return


func update_ap(actorId: int = - 1):
	return

func clear_can_choose_actors() -> void :
	return
