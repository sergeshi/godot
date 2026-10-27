extends Node2D

## Narrative RPG vertical slice: exploration, dialogue, skill checks, inventory,
## journal, character sheet, interactables and JSON save/load.

const SAVE_PATH := "user://pale_district_save.json"
const WORLD_SIZE := Vector2(1440, 900)
const INTERACTION_RANGE := 92.0

@onready var player: RPGPlayer = $Player

var skills := {"Empathy": 3, "Logic": 2, "Rhetoric": 3, "Perception": 4, "Composure": 2, "Inland Empire": 3}
var money := 12
var inventory: Array[String] = ["Cracked notebook", "Cigarette packet"]
var journal: Array[String] = ["Find out why the waterfront is sealed."]
var flags: Dictionary = {}
var current_panel: String = ""
var current_dialogue: String = ""
var current_speaker: String = ""
var dialogue_lines: Array[String] = []
var dialogue_choices: Array[Dictionary] = []
var current_line := 0
var toast_text := ""
var toast_time := 0.0
var hovered_target := ""
var ui_layer: CanvasLayer
var panel: PanelContainer
var panel_content: VBoxContainer
var status_label: Label
var objective_label: Label
var interaction_hint: Label
var dialogue_active := false

var people := {
	"mara": {"name": "Mara Venn", "position": Vector2(770, 370), "color": Color("#c87960"), "description": "A dockworker with tired eyes and a careful voice."},
	"keeper": {"name": "The Kiosk Keeper", "position": Vector2(1080, 570), "color": Color("#91a58b"), "description": "A quiet person behind a rain-stained kiosk."},
	"witness": {"name": "Silent Witness", "position": Vector2(300, 310), "color": Color("#8b91b0"), "description": "Someone watching the empty street."}
}

func _ready() -> void:
	_build_ui()
	_refresh_hud()
	queue_redraw()
	show_toast("THE PALE DISTRICT  •  DEMO BUILD")
	_add_journal_once("Speak to Mara Venn by the waterfront.")
	set_process(true)

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0 and is_instance_valid(status_label):
			status_label.text = _status_text()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact_nearest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		_show_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_show_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character"):
		_show_character()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_game()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if current_panel != "" and event.button_index == MOUSE_BUTTON_LEFT:
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			player.set_destination(get_global_mouse_position().clamp(Vector2(40, 100), Vector2(1400, 860)))
		elif event.button_index == MOUSE_BUTTON_LEFT and not dialogue_active:
			var target := _target_at(get_global_mouse_position())
			if target != "":
				_try_interact(target)
			else:
				player.set_destination(get_global_mouse_position().clamp(Vector2(40, 100), Vector2(1400, 860)))

func _draw() -> void:
	# Hand-painted placeholder blockout: replace with authored tiles, props and lighting.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#252a2b"))
	draw_rect(Rect2(0, 95, 1440, 805), Color("#343a38"))
	# Wet street and waterfront
	draw_rect(Rect2(0, 95, 1440, 105), Color("#283e43"))
	for x in range(0, 1440, 70):
		draw_line(Vector2(x, 145), Vector2(x + 42, 145), Color("#597074", 0.28), 2.0)
	# Streets
	draw_rect(Rect2(0, 430, 1440, 150), Color("#4b4c45"))
	draw_rect(Rect2(0, 488, 1440, 3), Color("#b5a77e", 0.28), 2.0)
	# Buildings and facades
	_draw_building(Rect2(70, 230, 270, 165), Color("#67584f"), "OLD MUNICIPAL OFFICE")
	_draw_building(Rect2(420, 230, 245, 165), Color("#555d58"), "CLOSED HOTEL")
	_draw_building(Rect2(890, 250, 300, 140), Color("#756a58"), "FERRY ADMINISTRATION")
	_draw_building(Rect2(920, 640, 270, 140), Color("#57504a"), "KIOSK / 24H")
	# Pavement details
	for i in range(12):
		var px := 80.0 + i * 105.0
		draw_line(Vector2(px, 595), Vector2(px + 40, 595), Color("#d3c5a1", 0.12), 2.0)
	# Interaction markers
	for key in people:
		var person: Dictionary = people[key]
		var p: Vector2 = person["position"]
		draw_circle(p + Vector2(0, 7), 17, Color(0, 0, 0, 0.25))
		draw_circle(p, 13, person["color"])
		draw_circle(p + Vector2(0, -16), 8, Color("#c9b69d"))
		draw_arc(p + Vector2(0, -16), 8, PI, TAU, 16, Color("#27292a"), 4)
		draw_string(ThemeDB.fallback_font, p + Vector2(-58, -34), person["name"], HORIZONTAL_ALIGNMENT_CENTER, 116, 13, Color("#e6ddc9"))
		if key == hovered_target:
			draw_arc(p, 24, 0, TAU, 28, Color("#e3c28a"), 2.0)
	# Aim marker
	if player and player.destination.distance_to(player.global_position) > 18:
		draw_arc(player.destination, 8, 0, TAU, 18, Color("#d9c28f", 0.8), 2.0)

func _draw_building(rect: Rect2, color: Color, title: String) -> void:
	draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color(0, 0, 0, 0.25))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), color.lightened(0.13))
	for x in range(int(rect.position.x + 20), int(rect.end.x - 10), 48):
		draw_rect(Rect2(x, rect.position.y + 32, 24, 36), Color("#252e30"))
		draw_rect(Rect2(x + 3, rect.position.y + 35, 18, 30), Color("#7c958d", 0.5))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, rect.size.y - 14), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 12, Color("#e3d8c4"))

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 82
	top.add_theme_stylebox_override("panel", _style(Color("#191d20"), Color("#6e6b5b"), 1, 0))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	var title := Label.new()
	title.text = "THE PALE DISTRICT"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d7c59e"))
	top_row.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A NARRATIVE RPG TEMPLATE  /  DAY 01"
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_color_override("font_color", Color("#9da39a"))
	top_row.add_child(subtitle)
	var controls := Label.new()
	controls.text = "WASD move  •  LMB walk/interact  •  E talk  •  J journal  •  I inventory  •  C skills  •  F5 save"
	controls.add_theme_color_override("font_color", Color("#c6c3b7"))
	top_row.add_child(controls)

	objective_label = Label.new()
	objective_label.position = Vector2(28, 106)
	objective_label.text = "CURRENT TASK  /  Find Mara Venn"
	objective_label.add_theme_font_size_override("font_size", 16)
	objective_label.add_theme_color_override("font_color", Color("#e3c994"))
	root.add_child(objective_label)

	interaction_hint = Label.new()
	interaction_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	interaction_hint.position = Vector2(28, -48)
	interaction_hint.text = "Right-click to move • Approach a person and press E"
	interaction_hint.add_theme_color_override("font_color", Color("#e3ddcb"))
	root.add_child(interaction_hint)

	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	status_label.position = Vector2(-330, -45)
	status_label.size = Vector2(300, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_color_override("font_color", Color("#d6c7a5"))
	root.add_child(status_label)

	panel = PanelContainer.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(460, 480)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _style(Color("#202427"), Color("#a18b68"), 2, 8))
	root.add_child(panel)
	panel_content = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 12)
	panel.add_child(panel_content)

func _style(bg: Color, border: Color, border_size: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_size)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

func _refresh_hud() -> void:
	if is_instance_valid(status_label):
		status_label.text = _status_text()
	if is_instance_valid(objective_label):
		objective_label.text = "CURRENT TASK  /  " + ("Report what Mara told you" if flags.get("mara_truth", false) else "Find Mara Venn by the waterfront")

func _status_text() -> String:
	return "₡ %d   •   %d items   •   %d journal entries" % [money, inventory.size(), journal.size()]

func _target_at(pos: Vector2) -> String:
	var closest := ""
	var best := 42.0
	for key in people:
		var p: Vector2 = people[key]["position"]
		var d := p.distance_to(pos)
		if d < best:
			best = d
			closest = key
	return closest

func _nearest_target() -> String:
	var closest := ""
	var best := INTERACTION_RANGE
	for key in people:
		var d: float = player.global_position.distance_to(people[key]["position"])
		if d < best:
			best = d
			closest = key
	return closest

func _interact_nearest() -> void:
	var target := _nearest_target()
	if target == "":
		show_toast("Nobody close enough. Walk closer to a person.")
	else:
		_try_interact(target)

func _try_interact(target: String) -> void:
	var target_pos: Vector2 = people[target]["position"]
	if player.global_position.distance_to(target_pos) > INTERACTION_RANGE:
		player.set_destination(target_pos + Vector2(36, 28))
		show_toast("Moving closer to " + str(people[target]["name"]) + "…")
		return
	_start_dialogue(target)

func _start_dialogue(target: String) -> void:
	dialogue_active = true
	player.stop()
	player.movement_locked = true
	current_dialogue = target
	current_speaker = str(people[target]["name"])
	if target == "mara":
		if flags.get("mara_truth", false):
			_open_dialogue("Mara Venn", ["The ferry left before dawn. Someone wanted the pier empty.", "I told you what I know. The rest is in the ledger."], [
				{"text":"Ask about the ledger", "action":"ledger"},
				{"text":"Say goodbye", "action":"close"}
			])
		else:
			_open_dialogue("Mara Venn", ["You look like someone who woke up in the wrong life.", "The waterfront was sealed before sunrise. No notice, no explanation.", "I saw a clerk carrying a ledger into the old municipal office."], [
				{"text":"Read her expression  [Perception: 4]", "action":"perception"},
				{"text":"Ask who ordered the closure  [Rhetoric: 3]", "action":"rhetoric"},
				{"text":"Tell her about your strange dream  [Inland Empire: 3]", "action":"dream"},
				{"text":"Leave the conversation", "action":"close"}
			])
	elif target == "keeper":
		_open_dialogue("The Kiosk Keeper", ["Tea costs two coins. Rumours are free, if you look like you can keep one."], [
			{"text":"Buy a hot tea  [₡2]", "action":"buy_tea"},
			{"text":"Ask about the ferry", "action":"rumour"},
			{"text":"Leave", "action":"close"}
		])
	else:
		_open_dialogue("Silent Witness", ["Their eyes follow the empty road. For a moment, you feel the city thinking through you."], [
			{"text":"Listen to the silence  [Inland Empire: 3]", "action":"witness"},
			{"text":"Leave", "action":"close"}
		])

func _open_dialogue(speaker: String, lines: Array[String], choices: Array[Dictionary]) -> void:
	current_speaker = speaker
	dialogue_lines = lines
	current_line = 0
	dialogue_choices = choices
	_show_dialogue_panel()

func _show_dialogue_panel() -> void:
	_clear_panel()
	current_panel = "dialogue"
	panel.visible = true
	var speaker := Label.new()
	speaker.text = current_speaker.to_upper()
	speaker.add_theme_font_size_override("font_size", 22)
	speaker.add_theme_color_override("font_color", Color("#e3c994"))
	panel_content.add_child(speaker)
	var body := Label.new()
	body.text = "\n".join(dialogue_lines)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(400, 100)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color("#e1ded3"))
	panel_content.add_child(body)
	var separator := HSeparator.new()
	panel_content.add_child(separator)
	for choice in dialogue_choices:
		var b := Button.new()
		b.text = str(choice["text"])
		b.custom_minimum_size.y = 38
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color("#e3ddcb"))
		b.add_theme_stylebox_override("normal", _style(Color("#303638"), Color("#5e625c"), 1, 3))
		b.add_theme_stylebox_override("hover", _style(Color("#414640"), Color("#d0b783"), 1, 3))
		b.pressed.connect(_choose_dialogue.bind(str(choice["action"])))
		panel_content.add_child(b)
	var close_button := Button.new()
	close_button.text = "Close  [Esc]"
	close_button.pressed.connect(_close_panel)
	panel_content.add_child(close_button)

func _choose_dialogue(action: String) -> void:
	match action:
		"perception":
			var success := _skill_check("Perception", 4, 2)
			if success:
				_add_journal_once("Mara seemed frightened when she mentioned the municipal ledger.")
				show_toast("SUCCESS — you noticed fear beneath her composure.")
			else:
				show_toast("FAILURE — her expression gives nothing away.")
		"rhetoric":
			var success := _skill_check("Rhetoric", 3, 2)
			if success:
				flags["mara_truth"] = true
				_add_journal_once("Mara says a clerk took a ledger to the old municipal office.")
				_add_journal_once("The waterfront closure was ordered before sunrise.")
				if not inventory.has("Torn ferry receipt"):
					inventory.append("Torn ferry receipt")
				show_toast("SUCCESS — new clue added to your journal.")
			else:
				_add_journal_once("Mara refused to name the person who ordered the closure.")
				show_toast("FAILURE — you pushed too hard. Try another approach.")
		"dream":
			var success := _skill_check("Inland Empire", 3, 2)
			if success:
				_add_journal_once("A dream-image: a black bird above a locked door.")
				show_toast("SUCCESS — a strange intuition becomes a thought.")
			else:
				show_toast("FAILURE — the feeling dissolves before it becomes a clue.")
		"ledger":
			_add_journal_once("The municipal ledger may explain the waterfront closure.")
			show_toast("The old municipal office is now your next lead.")
		"buy_tea":
			if money >= 2:
				money -= 2
				inventory.append("Hot tea")
				show_toast("Bought hot tea. A little warmth in a cold city.")
			else:
				show_toast("Not enough coins.")
		"rumour":
			_add_journal_once("The kiosk keeper heard a ferry depart before its scheduled time.")
			show_toast("New rumour recorded.")
		"witness":
			if _skill_check("Inland Empire", 3, 2):
				_add_journal_once("The silent witness remembers a black car idling by the pier.")
				show_toast("SUCCESS — a memory that might not be yours.")
			else:
				show_toast("Only wind, water and the weight of the city.")
		"close":
			_close_panel()
			return
	_refresh_hud()
	_show_dialogue_panel()

func _skill_check(skill: String, difficulty: int, modifier: int) -> bool:
	var rank: int = int(skills.get(skill, 1))
	var roll := randi_range(1, 6) + randi_range(1, 6) + rank + modifier
	var passed := roll >= difficulty + 7
	show_toast("%s check: %d vs %d — %s" % [skill, roll, difficulty + 7, "SUCCESS" if passed else "FAILURE"])
	return passed

func _show_journal() -> void:
	_show_list_panel("CASE JOURNAL", journal, "No leads recorded yet.")

func _show_inventory() -> void:
	var entries: Array[String] = ["Money: ₡%d" % money]
	entries.append_array(inventory)
	_show_list_panel("INVENTORY", entries, "Your pockets are empty.")

func _show_character() -> void:
	var entries: Array[String] = []
	for key in skills:
		entries.append("%s     %d / 6" % [key, skills[key]])
	entries.append("")
	entries.append("Checks roll 2d6 + skill + situational modifier.")
	entries.append("A failed check can change the story, not end it.")
	_show_list_panel("CHARACTER / SKILLS", entries, "")

func _show_list_panel(title_text: String, entries: Array, empty_text: String) -> void:
	_clear_panel()
	current_panel = "list"
	panel.visible = true
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("#e3c994"))
	panel_content.add_child(heading)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_content.add_child(list)
	if entries.is_empty():
		entries = [empty_text]
	for entry in entries:
		var label := Label.new()
		label.text = "—  " + str(entry) if str(entry) != "" else ""
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color("#e1ded3"))
		list.add_child(label)
	var close_button := Button.new()
	close_button.text = "Close  [Esc]"
	close_button.pressed.connect(_close_panel)
	panel_content.add_child(close_button)

func _clear_panel() -> void:
	for child in panel_content.get_children():
		child.queue_free()

func _close_panel() -> void:
	panel.visible = false
	current_panel = ""
	dialogue_active = false
	player.movement_locked = false
	player.destination = player.global_position

func _add_journal_once(entry: String) -> void:
	if not journal.has(entry):
		journal.append(entry)
		_refresh_hud()

func show_toast(message: String) -> void:
	toast_text = message
	toast_time = 3.2
	if is_instance_valid(status_label):
		status_label.text = message

func save_game() -> void:
	var data := {
		"version": 1,
		"player_position": [player.global_position.x, player.global_position.y],
		"skills": skills,
		"money": money,
		"inventory": inventory,
		"journal": journal,
		"flags": flags
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		show_toast("SAVE FAILED: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	show_toast("GAME SAVED")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		show_toast("No save found. Press F5 to create one.")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		show_toast("Could not open save file.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		show_toast("Save file is invalid.")
		return
	var data: Dictionary = parsed
	var pos: Array = data.get("player_position", [540.0, 470.0])
	if pos.size() >= 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))
		player.destination = player.global_position
	skills = data.get("skills", skills)
	money = int(data.get("money", money))
	inventory.assign(data.get("inventory", inventory))
	journal.assign(data.get("journal", journal))
	flags = data.get("flags", flags)
	_refresh_hud()
	show_toast("GAME LOADED")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_panel != "":
		_close_panel()
