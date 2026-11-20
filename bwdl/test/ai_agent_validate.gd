# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：test/ai_agent_validate.gd
# 说明：Godot 3.6.3 headless 下强制 load() 全部 AI Agent 相关脚本，
#       用于验证 GDScript 1.0 语法与继承链。配合 agent-service 的
#       test/godot3-parse.test.ts 解析日志中的 Parse Error。
# 用法：
#   Godot_v3.6.3-stable_linux_headless.64 --no-window --path bwdl \
#       --script res://test/ai_agent_validate.gd
# ==============================================================================
extends SceneTree

func _init():
	var paths = [
		"res://packed/sgz_script/war/AI/AIHttpClient.gd",
		"res://packed/sgz_script/war/AI/StateProjection.gd",
		"res://packed/sgz_script/war/AI/ActionValidator.gd",
		"res://packed/sgz_script/war/AI/War_AI_behavior_llm.gd",
		"res://packed/sgz_script/war/AI_control.gd",
		# 白兵战 Agent 接入
		"res://packed/sgz_script/battle/AI/BattleProjection.gd",
		"res://packed/sgz_script/battle/AI/BattleAgent.gd",
		"res://packed/sgz_script/battle/Battle_Auto_Run.gd",
		# 云存档
		"res://script/Cloud_Save.gd",
	]
	var bad = 0
	for p in paths:
		var s = load(p)
		if s == null:
			print("AI_VALIDATE FAIL ", p)
			bad += 1
		else:
			print("AI_VALIDATE OK   ", p)
	print("AI_VALIDATE_RESULT=", bad)
	quit()
