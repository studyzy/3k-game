extends Node

var _client = null
var _agent = null
var _bf = null
var _done = false

func _ready():
    var BF = load("res://stubs/FakeBattleFight.gd")
    var WA = load("res://stubs/FakeWarActor.gd")
    var Info = load("res://stubs/FakeActorInfo.gd")

    _bf = BF.new()
    var mine = WA.new(); mine.actorId = 12; mine._info = Info.new()
    var foe = WA.new(); foe.actorId = 31; foe._info = Info.new(); foe._enemy = mine
    mine._enemy = foe

    DataManager.battle = _bf
    DataManager.war_actor = mine
    Global.iTactic = load("res://stubs/ITacticStub.gd").new()

    var proj = load("res://BattleProjection.gd").new()
    var payload = proj.build(_bf, 12)
    print("BATTLE_PAYLOAD=", to_json(payload))

    _agent = load("res://BattleAgent.gd").new()
    var ok = _agent.open(12)
    print("BATTLE_OPEN=", ok)
    if not ok:
        _done = true
        get_tree().quit()
        return
    var timer = Timer.new()
    timer.wait_time = 15
    timer.one_shot = true
    add_child(timer)
    timer.connect("timeout", self, "_on_timeout")
    timer.start()
    return

func _on_timeout():
    if not _done:
        print("BATTLE_RESULT=timeout")
        get_tree().quit()
    return
