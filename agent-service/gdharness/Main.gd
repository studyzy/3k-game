extends Node

signal http_done

var _http_done = false
# 必须持有引用：Resource 局部变量在函数返回后会被释放，信号连接随之失效
var _client = null

func _ready():
    var Info = load("res://stubs/FakeActorInfo.gd")
    var Actor = load("res://stubs/FakeActor.gd")
    var WF = load("res://stubs/FakeWarFight.gd")
    var WV = load("res://stubs/FakeVState.gd")
    var Map = load("res://stubs/FakeMap.gd")
    var Scene = load("res://stubs/FakeScene.gd")

    var scene = Scene.new()
    scene.war_map = Map.new()
    SceneManager.fake_scene = scene

    var wa1 = Actor.new()
    wa1.actorId = 12; wa1.wvId = 2; wa1.position = Vector2(8, 14); wa1._info = Info.new()
    wa1._info.name = "张飞"
    var wa2 = Actor.new()
    wa2.actorId = 31; wa2.wvId = 1; wa2.position = Vector2(9, 15); wa2._info = Info.new()
    wa2._info.name = "曹操"

    var wf = WF.new()
    wf.actors = [wa1, wa2]
    DataManager.current_war_fight = wf
    var wv = WV.new()
    wv.side = "防守方"
    var enemy = WV.new()
    enemy.id = 1
    enemy.rice = 310
    enemy.money = 900
    enemy.main_actorId = 31
    enemy.side = "攻击方"
    wv.enemy_wv = enemy
    enemy.enemy_wv = wv
    wa1.vstate = wv
    wa2.vstate = enemy

    # 计策投影：给受控方武将配一个 6 点消耗的计，目标为敌方主将
    var Scheme = load("res://stubs/FakeScheme.gd")
    var scheme = Scheme.new()
    scheme.targets = [31]
    wa1._stratagems = [scheme]

    var proj = load("res://ai/StateProjection.gd").new()
    var payload = proj.build(wv)
    print("AI_PAYLOAD=", to_json(payload))
    var tool_res = proj.build_tool_result(wv, true, "契约测试")
    print("AI_TOOL_RESULT=", to_json(tool_res))

    var val = load("res://ai/ActionValidator.gd").new()
    var legal = payload["legal_actions"]
    # 逐步交互：校验单个动作（含 history 去重）
    var good_action = {"id": legal[0]["id"]}
    var accepted = val.accept_action(good_action, payload, [])
    print("AI_ACCEPT_GOOD=", not accepted.empty())
    print("AI_REJECT_BAD=", val.accept_action({"id":"__bogus__"}, payload, []).empty())
    # 已在 history 中成功执行过的动作应被拒绝
    var dup_history = [{"id": legal[0]["id"], "ok": true}]
    print("AI_REJECT_DUP=", val.accept_action(good_action, payload, dup_history).empty())
    print("AI_NORMALIZED=", to_json(accepted))

    # 真实 GDScript HTTP 客户端 → 真实 Agent 服务
    var url = OS.get_environment("AI_HTTP_URL")
    if url == "":
        print("AI_HTTP_SKIP=True")
        get_tree().quit()
        return
    _client = load("res://ai/AIHttpClient.gd").new()
    var ok = _client.post(url, to_json(payload), self, "_on_session_opened", 5)
    print("AI_HTTP_START=", ok)
    var timer = Timer.new()
    timer.wait_time = 10
    timer.one_shot = true
    add_child(timer)
    timer.connect("timeout", self, "_on_timeout")
    timer.start()
    return

func _on_session_opened(result, response_code, body):
    print("AI_HTTP_RESULT=", result, "_", response_code)
    print("AI_HTTP_BODY=", body.get_string_from_utf8())
    if result != 0 or response_code != 200:
        _http_done = true
        get_tree().quit()
        return
    var reply = parse_json(body.get_string_from_utf8())
    if typeof(reply) != TYPE_DICTIONARY or not reply.has("session_id"):
        _http_done = true
        get_tree().quit()
        return
    # 长轮询取下一个动作（真实调用 /ai/turn/:id/pending）
    var pending_url = "%s/%s/pending?wait_ms=2000" % [OS.get_environment("AI_HTTP_BASE"), reply["session_id"]]
    _client.get_url(pending_url, self, "_on_polled", 5)
    return

func _on_polled(result, response_code, body):
    print("AI_POLL_RESULT=", result, "_", response_code)
    print("AI_POLL_BODY=", body.get_string_from_utf8())
    _http_done = true
    get_tree().quit()
    return

func _on_timeout():
    if not _http_done:
        print("AI_HTTP_RESULT=timeout")
    get_tree().quit()
    return
