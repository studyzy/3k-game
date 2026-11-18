extends Control


onready var animationPlayer = get_node("AnimationPlayer");




func _ready() -> void :

	update_orderbook();
	pass
	
func update_orderbook():
	get_node("lblOrderbook").visible = true;
	get_node("lblOrderbook").text = str(DataManager.orderbook);


var orderbook_times: int = 0;
var flow: String;

func order_book_play(_flow: String):
	orderbook_times = 0;
	animationPlayer.play("orderbook");
	var parent = get_parent();
	var lsc = parent.get_node_or_null("lsc");
	if (is_instance_valid(lsc)):
		lsc.cursor.hide();

	flow = _flow;

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	if (anim_name == "orderbook"):
		orderbook_times += 1;
		update_orderbook();
		get_node("lblOrderbook").visible = true;
		match orderbook_times:
			1:
				animationPlayer.play("orderbook");
			2:
				FlowManager.flows_history_list.clear();
				FlowManager.add_flow(flow);
	return
