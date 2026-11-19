# ==============================================================================
# 新增：AI Agent 接入——服务地址解析校验
# 文件：test/ai_agent_url_validate.gd
# 说明：独立复刻 resolve_ai_agent_url 的规则做校验（headless --script 不加载 autoload）。
#       规则本身来自 DataManager.resolve_ai_agent_url，二者须保持一致。
# ==============================================================================
extends SceneTree

var failed = 0

# 与 DataManager.resolve_ai_agent_url 同规则
func resolve(configured: String, path: String) -> String:
	var base = configured
	if base == "":
		if OS.has_feature("HTML5"):
			var origin = String(JavaScript.eval("window.location.origin", true))
			if origin != "" and origin != "null":
				base = origin
		if base == "":
			base = "http://127.0.0.1:8060"
	base = base.strip_edges()
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base + path

func check(label: String, actual: String, expect: String):
	if actual == expect:
		print("URL_OK   ", label, " = ", actual)
	else:
		print("URL_FAIL ", label, " 期望 ", expect, " 实际 ", actual)
		failed += 1
	return

func _init():
	check("带尾斜杠", resolve("http://10.0.0.5:9000/", "/ai/battle"), "http://10.0.0.5:9000/ai/battle")
	check("无尾斜杠", resolve("https://example.com/agent", "/ai/turn"), "https://example.com/agent/ai/turn")
	check("空配置默认", resolve("", "/ai/turn"), "http://127.0.0.1:8060/ai/turn")
	check("含空格", resolve("  http://h:1  ", "/ai/battle"), "http://h:1/ai/battle")
	print("URL_VALIDATE_RESULT=", failed)
	quit()
