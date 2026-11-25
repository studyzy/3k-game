# 假 StaticManager：TACTICS 可注入，buff 只关心场景名。
extends Node

# 可变：orders 场景用空表，tactic / queue_ttl 场景由 Main.gd 注入「强弩」
var TACTICS = {}

func get_buff(_name):
	return BuffInfo.new()

class BuffInfo:
	func get_scene(): return "小战场"
