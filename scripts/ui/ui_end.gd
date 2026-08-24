extends Control
## 游戏结算（对应 Unity UIEnd）

var _win: bool = false


func _ready() -> void:
	DataManager.ensure_loaded()
	_win = GameInfo.playingState == GameInfo.GameState.GAME_WIN
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title_text := "霸 业 已 成" if _win else "国 家 灭 亡"
	var title := UIFactory.make_label(title_text, 56, Color(0.95, 0.85, 0.4) if _win else Color(0.8, 0.2, 0.2))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200, 60)
	title.size = Vector2(400, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var body := UIFactory.make_label("", 22, Color.WHITE)
	body.position = Vector2(240, 200)
	body.size = Vector2(600, 300)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(body)

	if _win:
		body.text = _win_text()
	else:
		body.text = TextLibrary.GAME_FAIL

	var back := UIFactory.make_button("返回主菜单", Vector2(220, 60), 26)
	back.position = Vector2(370, 560)
	back.pressed.connect(func(): get_tree().quit())
	add_child(back)


func _win_text() -> String:
	var king := GeneralListCache.get_general(CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).countryKingId)
	var king_name := king.generalName if king != null else "您"
	var score := _calculate_total_score()
	return "历经 %d 年 %d 个月的征战，%s 终于一统天下！\n\n最终评分：%d 分" % [
		GameInfo.years - 251, GameInfo.month, king_name, score]


func _calculate_total_score() -> int:
	var score := 0
	var country := CountryListCache.get_country_by_country_id(GameInfo.playerCountryId)
	if country == null:
		return 0
	for city_id in country.cityIDs:
		var city := CityListCache.get_city_by_city_id(city_id)
		score += city.agriculture / 50 + city.commerce / 50 + city.rule + city.prevention
	score += country.get_country_soldier_num() / 1000
	return score
