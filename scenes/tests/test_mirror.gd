extends GdUnitTestSuite
## Mirror 只读镜像的单元测试（纯逻辑，无网络）。
## 用脚本路径 preload 实例化独立副本（autoload 单例 Mirror 不可 new）。

const MirrorScript := preload("res://scripts/net/mirror.gd")


func _new_mirror() -> Node:
	var node := Node.new()
	node.set_script(MirrorScript)
	return node


func test_apply_delta_merges_generals_cities() -> void:
	var mirror: Node = auto_free(_new_mirror())
	var delta := {
		"changed": {
			"generals": {"1": {"name": "刘备", "loyalty": 95}},
			"cities": {"10": {"name": "成都", "population": 50000}},
		},
		"gameInfo": {"playerOrderNum": 2, "years": 251, "month": 1},
	}
	mirror.apply_delta(delta)

	var g: Dictionary = mirror.get_general(1)
	assert_that(g.get("name", "")).is_equal("刘备")
	assert_that(int(g.get("loyalty", 0))).is_equal(95)
	assert_that(int(mirror.get_city(10).get("population", 0))).is_equal(50000)
	assert_that(mirror.player_order_num()).is_equal(2)
	assert_that(mirror.years()).is_equal(251)
	assert_that(mirror.month()).is_equal(1)


func test_apply_delta_overwrites_same_id_fields() -> void:
	var mirror: Node = auto_free(_new_mirror())
	mirror.apply_delta({"changed": {"generals": {"1": {"loyalty": 90}}}})
	mirror.apply_delta({"changed": {"generals": {"1": {"loyalty": 88, "name": "关羽"}}}})
	var g: Dictionary = mirror.get_general(1)
	assert_that(int(g.get("loyalty", 0))).is_equal(88)
	assert_that(g.get("name", "")).is_equal("关羽")


func test_player_country_id_default_zero() -> void:
	var mirror: Node = auto_free(_new_mirror())
	assert_that(mirror.player_country_id()).is_equal(0)


func test_apply_war_replaces_state() -> void:
	var mirror: Node = auto_free(_new_mirror())
	mirror.apply_war({"foo": "bar"})
	assert_that(mirror.war.get("foo", "")).is_equal("bar")
	mirror.apply_war({"foo": "baz", "extra": 1})
	assert_that(mirror.war.get("foo", "")).is_equal("baz")
	assert_that(mirror.war.size()).is_equal(2)