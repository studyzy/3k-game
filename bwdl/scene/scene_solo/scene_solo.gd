extends Control

const SCENE_ID = 40000

onready var solo_menu = get_node("solo_menu");
onready var solo_tactic_menu = get_node("solo_tactic_menu");
var solo_auto_run;


var bgm = true;


const NAME_LABEL_SIZES = [80, 80, 80, 110, 140, 166]

func _ready() -> void :
	solo_auto_run = Global.load_script(DataManager.mod_path + "sgz_script/solo/solo_auto_run.gd")

	SceneManager.load_scene_complete = true;
	SoundManager.play_bgm();
	
	init_data();
	return

func init_data():
	var sf = DataManager.get_current_solo_fight()
	if not sf.running():
		return
	solo_menu.hide()
	solo_tactic_menu.hide()
	update_actor_info()
	return

func update_actor_info():
	var sf = DataManager.get_current_solo_fight()
	var left = get_node("stage/left-actor")
	var right = get_node("stage/right-actor")

	var groupings = [
		[left, sf.leftId, false], 
		[right, sf.rightId, true]
	]
	for grp in groupings:
		var ctrl = grp[0]
		var wa = DataManager.get_war_actor(grp[1])
		if wa == null or wa.disabled:
			continue
		var isRightSide = grp[2]
		var name = wa.get_name()
		if name.length() >= 5:
			name = name.left(5)
		var lbl: Label = ctrl.get_node("lblName")
		lbl.rect_size.x = NAME_LABEL_SIZES[name.length()]
		lbl.text = name
		if isRightSide:
			lbl.rect_position.x = 456 + 78 - lbl.rect_size.x
		if wa.get_controlNo() >= 0:
			ctrl.get_node("lblRole").text = "1P"
		else:
			ctrl.get_node("lblRole").text = "AI"

		var actorNode = ctrl.get_node("solo_actor")
		if wa.is_attacker():
			actorNode.color1 = Color("#c50e0e")
			actorNode.color2 = Color("#ffd1d1")
		else:
			actorNode.color1 = Color("#ffffff")
			actorNode.color2 = Color("#ffd1d1")
		actorNode.init_data(wa.actorId)
		update_hp()
	return

func _process(delta: float) -> void :
	var sf = DataManager.get_current_solo_fight()
	if not sf.running():
		return
	if not is_instance_valid(solo_auto_run):
		return
	solo_auto_run._process(delta)
	return


func get_actor_node(actorId: int) -> Control:
	var sf = DataManager.get_current_solo_fight()
	var conPart = null
	if sf.leftId == actorId:
		conPart = get_node_or_null("stage/left-actor")
	if sf.rightId == actorId:
		conPart = get_node_or_null("stage/right-actor")
	if conPart == null:
		return null
	return conPart.get_node_or_null("solo_actor")

func update_hp():
	var sf = DataManager.get_current_solo_fight()
	var left = get_node("stage/left-actor")
	var right = get_node("stage/right-actor")
	var groupings = [
		[left, sf.leftId, false], 
		[right, sf.rightId, true]
	]

	for grp in groupings:
		var con = grp[0]
		var actorId = grp[1]
		var isRightSide = grp[2]
		var wa = DataManager.get_war_actor(actorId)
		var actor = wa.actor()
		
		var hp = min(96, int(actor.get_hp()))
		if actor.is_status_dead() or actor.is_status_captured():
			hp = 0
		
		var hpBars = min(20, ceil(hp / 4.8));
		var bloodBars: ColorRect = con.get_node("blood/red")
		var hpLength = hpBars * 9.8
		bloodBars.rect_size.x = hpLength
		if isRightSide:
			bloodBars.rect_position.x = 216 - hpLength
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.70666, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 0)
	rect_scale = Vector2(1, 1)
	return
