extends Control

onready var sp_color1 = get_node("color-1");
onready var sp_color2 = get_node("color-2");
onready var tween = get_node("Tween");
onready var animation_player = get_node("AnimationPlayer");

export (Color) var color1 = Color("#ffd1d1");

export (Color) var color2 = Color("#ffffff");

var temp_times = 0;



export (bool) var default_flip = false;
var flip = false;

export (int) var actorId = - 1;

export (Vector2) var actor_position;

var next_flow = "";


var push_actions = [];


func _ready() -> void :
	init_data(actorId);
	pass


func _process(delta: float) -> void :
	if (Engine.editor_hint):
		return ;
	if ( not check_next() and next_flow != ""):
		FlowManager.add_flow(next_flow);
		next_flow = "";
	var start_position = Vector2(0, 0);
	var move_position = actor_position;
	if (flip):
		start_position = Vector2(80, 0);
		move_position = - actor_position;
	rect_position = start_position + move_position;
	sp_color1.flip_h = flip;
	sp_color2.flip_h = flip;
	$AudioStreamPlayer.pitch_scale = Engine.time_scale;
	return


func init_data(_actorId: int):
	actor_position = Vector2(0, 0);
	actorId = _actorId;
	var weapon = ActorHelper.actor(actorId).get_weapon()
	if weapon.disabled:
		sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Sword_1.png");
		sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/Sword_2.png");
	else:
		match weapon.id:
			StaticManager.WEAPON_ID_HUAJI:
				sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Spear_1.png");
				sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/fangtianhuaji_2.png");
			StaticManager.WEAPON_ID_YANYUE:
				sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Knife_1.png");
				sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/qinglongyanyuedao_2.png");
			StaticManager.WEAPON_ID_SHEMAO:
				sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Spear_1.png");
				sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/zhangbashemao_2.png");
			_:
				match weapon.subtype():
					"剑":
						sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Sword_1.png");
						sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/Sword_2.png");
					"刀":
						sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Knife_1.png");
						sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/Knife_2.png");
					"枪":
						sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Spear_1.png");
						sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/Spear_2.png");
					"锤":
						sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/Hammer_1.png");
						sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/Hammer_2.png");
					"斧":
						sp_color1.texture = Global.load_pic("res://resource/images/solo/Weapon/axe_1.png");
						sp_color2.texture = Global.load_pic("res://resource/images/solo/Weapon/axe_2.png");
	sp_color1.self_modulate = color1;
	sp_color2.self_modulate = color2;
	sp_color1.frame = 0;
	sp_color2.frame = 0;
	
	animation_player.play("stand");
	
	flip = default_flip;
	sp_color1.flip_h = flip;
	sp_color2.flip_h = flip;
	var start_position = Vector2(0, 0);
	var move_position = actor_position;
	if (flip):
		start_position = Vector2(80, 0);
		move_position = - actor_position;
	rect_position = start_position + move_position;
	






func _on_Tween_tween_completed(object: Object, key: NodePath) -> void :
	pass


func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	pass

func go():
	tween.interpolate_property(self, "temp_times", 0, 1, 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	tween.start();


func check_next() -> bool:
	var current_animation: String = animation_player.current_animation;
	if (animation_player.is_playing()):
		if (animation_player.has_animation(current_animation)):
			var animation: Animation = animation_player.get_animation(current_animation);
			if (animation != null and not animation.loop):
				return true;
	if (tween.is_active()):
		return true;
	$AudioStreamPlayer.stop();
	if (push_actions.size() == 0):
		return false;
	var dic: Dictionary = push_actions[0];
	push_actions.remove(0);
	dic["object"].callv(dic["method"], dic["binds"]);
	return true;
	



func _action_run(to_distance: float):
	flip = default_flip;
	var to = actor_position + Vector2(to_distance, 0);
	animation_player.play("run");
	var total_time = abs(actor_position.x - to.x) / 150.0;
	tween.interpolate_property(self, "actor_position", actor_position, to, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.15);
	tween.start();
	pass
	

func _action_flip_run(to_distance: float):
	flip = not default_flip;
	actor_position = Vector2(360, 0) - actor_position;
	var to = actor_position + Vector2(to_distance, 0);
	animation_player.play("run");
	var total_time = abs(actor_position.x - to.x) / 150.0;
	tween.interpolate_property(self, "actor_position", actor_position, to, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.2);
	tween.start();
	pass


func _action_attack():
	animation_player.play("attack");
	go();

func _action_light_attack():
	animation_player.play("light_attack");
	go();

func _action_crazy_attack(to_distance: float):
	var to = actor_position + Vector2(to_distance, 0);
	animation_player.play("crazy_attack");
	var total_time = abs(actor_position.x - to.x) / 150.0;
	tween.interpolate_property(self, "actor_position", actor_position, to, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.15);
	tween.start();

func _action_surrender():
	flip = default_flip;
	actor_position = Vector2(0, 0);
	animation_player.play("surrender");
	SoundManager.play_anim_bgm("res://resource/sounds/bgm/solo_surrend.ogg");
	go();

func _action_defence():
	flip = default_flip;
	actor_position = Vector2(0, 0);
	animation_player.play("defence");

func _action_stand():
	flip = default_flip;
	actor_position = Vector2(0, 0);
	animation_player.play("stand");
	
func _action_dead():
	flip = default_flip;
	actor_position = Vector2(0, 0);
	animation_player.play("dead");
	SoundManager.play_anim_bgm("res://resource/sounds/bgm/solo_dead.ogg");
	

func get_enemy_actor_node() -> Control:
	var sf = DataManager.get_current_solo_fight()
	var scene = SceneManager.current_scene()
	return scene.get_actor_node(sf.opponent(actorId).actorId)


func action_attack(_next_flow: String):
	next_flow = _next_flow;
	var con_enemy = get_enemy_actor_node();
	
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_run", "binds": [200]});
	push_actions.append({"object": con_enemy, "method": "_action_defence", "binds": []});
	push_actions.append({"object": self, "method": "_action_attack", "binds": []});
	push_actions.append({"object": con_enemy, "method": "_action_stand", "binds": []});
	push_actions.append({"object": self, "method": "_action_flip_run", "binds": [200]});
	push_actions.append({"object": self, "method": "_action_stand", "binds": []});
	go();
	return


func action_light_attack(_next_flow: String):
	next_flow = _next_flow;
	var con_enemy = get_enemy_actor_node();
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_run", "binds": [200]});
	push_actions.append({"object": con_enemy, "method": "_action_defence", "binds": []});
	push_actions.append({"object": self, "method": "_action_light_attack", "binds": []});
	push_actions.append({"object": con_enemy, "method": "_action_stand", "binds": []});
	push_actions.append({"object": self, "method": "_action_flip_run", "binds": [200]});
	push_actions.append({"object": self, "method": "_action_stand", "binds": []});
	go();
	return


func action_crazy_attack(_next_flow: String):
	next_flow = _next_flow;
	var con_enemy = get_enemy_actor_node();
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_run", "binds": [170]});
	push_actions.append({"object": con_enemy, "method": "_action_defence", "binds": []});
	push_actions.append({"object": self, "method": "_action_crazy_attack", "binds": [30]});
	push_actions.append({"object": con_enemy, "method": "_action_stand", "binds": []});
	push_actions.append({"object": self, "method": "_action_flip_run", "binds": [170]});
	push_actions.append({"object": self, "method": "_action_stand", "binds": []});
	go();
	return


func action_surrender(_next_flow: String):
	next_flow = _next_flow;
	var con_enemy = get_enemy_actor_node();
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_surrender", "binds": []});
	go();
	return


func action_dead(_next_flow: String):
	next_flow = _next_flow;
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_dead", "binds": []});
	go();
	return


func action_retreat(_next_flow: String):
	next_flow = _next_flow;
	var con_enemy = get_enemy_actor_node();
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_flip_run", "binds": [250]});
	go();
	return



func action_chase(_next_flow: String):
	next_flow = _next_flow;
	var con_enemy = get_enemy_actor_node();
	push_actions = [];
	push_actions.append({"object": self, "method": "_action_run", "binds": [600]});
	go();
	return

