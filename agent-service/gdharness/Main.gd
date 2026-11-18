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
    var wa2 = Actor.new()
    wa2.actorId = 31; wa2.wvId = 1; wa2.position = Vector2(9, 15); wa2._info = Info.new()

    var wf = WF.new()
    wf.actors = [wa1, wa2]
    DataManager.current_war_fight = wf
    var wv = WV.new()

    var proj = load("res://ai/StateProjection.gd").new()
    var payload = proj.build(wv)
    print("AI_PAYLOAD=", to_json(payload))

    var val = load("res://ai/ActionValidator.gd").new()
    var legal = payload["legal_actions"]
    var good = [{"id": legal[0]["id"], "order": 1}]
    print("AI_ACCEPT_GOOD=", val.accept_all(good, payload))
    print("AI_REJECT_BAD=", not val.accept_all([{"id":"__bogus__","order":1}], payload))
    print("AI_NORMALIZED=", to_json(val.normalize(good, payload)))

    # 真实 GDScript HTTP 客户端 → 真实 Agent 服务
    var url = OS.get_environment("AI_HTTP_URL")
    if url == "":
        print("AI_HTTP_SKIP=True")
        get_tree().quit()
        return
    _client = load("res://ai/AIHttpClient.gd").new()
    var ok = _client.post(url, to_json(payload), self, "_on_http_done", 5)
    print("AI_HTTP_START=", ok)
    var timer = Timer.new()
    timer.wait_time = 10
    timer.one_shot = true
    add_child(timer)
    timer.connect("timeout", self, "_on_timeout")
    timer.start()
    return

func _on_http_done(result, response_code, body):
    print("AI_HTTP_RESULT=", result, "_", response_code)
    print("AI_HTTP_BODY=", body.get_string_from_utf8())
    _http_done = true
    get_tree().quit()
    return

func _on_timeout():
    if not _http_done:
        print("AI_HTTP_RESULT=timeout")
    get_tree().quit()
    return
