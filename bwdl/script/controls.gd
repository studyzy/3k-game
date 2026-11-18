extends Resource







func wait_for_choose_actor(backFlow: String, endOnBack: bool = false, disableStart: bool = false) -> bool:
	if Input.is_action_just_pressed("ANALOG_UP"):
		SceneManager.actorlist.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		SceneManager.actorlist.move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		SceneManager.actorlist.page_up()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		SceneManager.actorlist.page_down()
	if Input.is_action_just_pressed("EMU_SELECT"):
		SceneManager.actorlist.sort_toggle();
	if Input.is_action_just_pressed("EMU_START"):
		if disableStart:
			return true
		SceneManager.actorlist.move_to( - 1)

	if Global.is_action_pressed_BY():
		if not SceneManager.actorlist.is_msg_complete():
			return false
		FlowManager.add_flow(backFlow)
		if endOnBack:
			LoadControl.end_script()
		return false

	if not Global.is_action_pressed_AX():
		return false
	if not SceneManager.actorlist.is_msg_complete():
		SceneManager.actorlist.show_all_msg()
		return false
	return true


func wait_for_yesno(flowForYes: String, flowForNo: String, endOnNo: bool = false, backFlow: String = "") -> void :
	if backFlow == "":
		backFlow = flowForNo
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		SceneManager.actor_dialog.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		SceneManager.actor_dialog.move_right()
	if Global.is_action_pressed_BY():
		if not SceneManager.dialog_msg_complete(false):
			return
		FlowManager.add_flow(backFlow)
		return
	if not Global.is_action_pressed_AX():
		return
	if not SceneManager.dialog_msg_complete(true):
		return
	LoadControl.set_view_model( - 1)
	match SceneManager.actor_dialog.lsc.cursor_index:
		0:
			FlowManager.add_flow(flowForYes)
		1:
			if endOnNo:
				LoadControl.end_script()
			FlowManager.add_flow(flowForNo)
	return


func wait_for_confirmation(nextFlow: String = "city_enter_menu", prevFlow: String = "") -> bool:
	if prevFlow != "" and Global.is_action_pressed_BY():
		if not SceneManager.dialog_msg_complete():
			return false
		FlowManager.add_flow(prevFlow)
		return false
	if not Global.is_action_pressed_AX():
		return false
	if not SceneManager.dialog_msg_complete(true):
		return false
	LoadControl.set_view_model( - 1)
	if nextFlow != "":
		FlowManager.add_flow(nextFlow)
	return true



func wait_for_options(optionFlows: PoolStringArray, backFlow: String, endOnBack: bool = false, menu = null) -> bool:
	if menu == null:
		menu = SceneManager.lsc_menu
	var lsc = menu.get_node_or_null("lsc")
	if lsc == null:
		lsc = menu
	if Input.is_action_just_pressed("ANALOG_UP"):
		lsc.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		lsc.move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		lsc.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		lsc.move_right()
	DataManager.remember_lsc_index(lsc)
	if Global.is_action_pressed_BY():
		if not menu.is_msg_complete():
			return false
		FlowManager.add_flow(backFlow)
		if endOnBack:
			LoadControl.end_script()
		return false
	if not Global.is_action_pressed_AX():
		return false
	if not menu.is_msg_complete():
		menu.show_all_msg()
		return false
	var option = lsc.cursor_index
	if option >= 0 and option < lsc.items.size():
		DataManager.set_env("菜单选项", lsc.items[option])
	if option >= 0 and option < optionFlows.size():
		LoadControl.set_view_model( - 1)
		FlowManager.add_flow(optionFlows[option])
		return true
	return true


func wait_for_number_input(backFlow: String, allowZero: bool = false) -> bool:
	var conNumberInput = SceneManager.input_numbers.get_current_input_node()
	if Input.is_action_just_pressed("ANALOG_UP"):
		conNumberInput.cursor_number_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		conNumberInput.cursor_number_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		conNumberInput.cursor_move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		conNumberInput.cursor_move_right()
	if Input.is_action_just_pressed("EMU_SELECT"):
		conNumberInput.set_number(conNumberInput.min_number)
	if Input.is_action_just_pressed("EMU_START"):
		conNumberInput.set_number(conNumberInput.max_number)
	if Global.is_action_pressed_BY():
		if not SceneManager.input_numbers.is_msg_complete():
			return false
		if SceneManager.input_numbers.pre_input_index():
			var input = SceneManager.input_numbers.get_current_input_node();
			input.set_number(0, true)
			return false
		FlowManager.add_flow(backFlow)
		return false
	if not Global.is_action_pressed_AX():
		return false
	if not SceneManager.input_numbers.is_msg_complete():
		SceneManager.input_numbers.show_all_msg()
		return false
	var number = conNumberInput.get_number()
	if number == 0 and SceneManager.input_numbers.is_last_input() and not allowZero:
		return false
	return true


func wait_for_choose_city(delta: float, backFlow: String, quickChoices: PoolIntArray = []) -> int:
	var vstateId = int(DataManager.vstates_sort[DataManager.vstate_no]);
	if Input.is_action_pressed("ANALOG_UP"):
		SceneManager.current_scene().cursor_move_up(delta)
	if Input.is_action_pressed("ANALOG_DOWN"):
		SceneManager.current_scene().cursor_move_down(delta)
	if Input.is_action_pressed("ANALOG_LEFT"):
		SceneManager.current_scene().cursor_move_left(delta)
	if Input.is_action_pressed("ANALOG_RIGHT"):
		SceneManager.current_scene().cursor_move_right(delta)
	if Input.is_action_just_pressed("EMU_START"):
		if not quickChoices.empty():
			var cityId = SceneManager.current_scene().get_curosr_point_city();
			if cityId >= 0:
				var current = quickChoices.find(cityId)
				current = (current + 1) % quickChoices.size()
				SceneManager.current_scene().set_city_cursor_position(quickChoices[current])
			else:
				SceneManager.current_scene().set_city_cursor_position(quickChoices[0])
			SceneManager.dialog_msg_complete(true)
	if backFlow != "" and Global.is_action_pressed_BY():
		SceneManager.dialog_msg_complete(true)
		LoadControl.set_view_model( - 1)
		FlowManager.add_flow(backFlow)
		return - 1
	if not Global.is_action_pressed_AX():
		return - 1
	SceneManager.dialog_msg_complete(true)
	var cityId = SceneManager.current_scene().get_curosr_point_city()
	if cityId < 0:
		SceneManager.show_unconfirm_dialog("此处并没有城")
		return - 1
	
	clCity.city(cityId).fix_lord_position()
	return cityId

func bind_top_menu(items: PoolStringArray, values: Array, columns: int = 2) -> void :
	DataManager.set_env("列表值", values)
	SceneManager.lsc_menu_top.set_lsc()
	SceneManager.lsc_menu_top.lsc.columns = columns
	SceneManager.lsc_menu_top.lsc.items = items
	SceneManager.lsc_menu_top.lsc._set_data()
	SceneManager.lsc_menu_top.show()
	SceneManager.lsc_menu_top.lsc.cursor_index = 0
	return



func wait_for_choose_item(backFlow: String, endOnBack: bool = false) -> int:
	if Input.is_action_just_pressed("ANALOG_UP"):
		SceneManager.lsc_menu_top.lsc.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		SceneManager.lsc_menu_top.lsc.move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		SceneManager.lsc_menu_top.lsc.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		SceneManager.lsc_menu_top.lsc.move_right()
	if backFlow != "" and Global.is_action_pressed_BY():
		if not SceneManager.actor_dialog.is_msg_complete():
			return - 1
		if backFlow != "":
			FlowManager.add_flow(backFlow)
			if endOnBack:
				LoadControl.end_script()
		return - 1
	if not Global.is_action_pressed_AX():
		return - 1
	if not SceneManager.actor_dialog.is_msg_complete():
		SceneManager.actor_dialog.show_all_msg()
		return - 1
	var option = SceneManager.lsc_menu_top.lsc.cursor_index
	return option

func bind_bottom_menu(items: PoolStringArray, vals: Array, msg: String, columns: int = 1):
	DataManager.set_env("列表值", vals)
	SceneManager.lsc_menu.lsc.columns = columns
	SceneManager.lsc_menu.lsc.items = items
	SceneManager.lsc_menu.set_lsc()
	SceneManager.lsc_menu.lsc._set_data();
	SceneManager.lsc_menu.show_msg(msg)
	SceneManager.lsc_menu.show_orderbook(true)
	DataManager.cityInfo_type = 1
	SceneManager.show_cityInfo(true)
	SceneManager.lsc_menu.lsc.cursor_index = 0
	SceneManager.lsc_menu.show()
	return
