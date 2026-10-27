extends Node3D

## 3D narrative RPG vertical slice: isometric exploration, dialogue, skill checks,
## inventory, journal and JSON save/load.

const SAVE_PATH := "user://pale_district_save.json"
const INTERACTION_RANGE := 3.2

@onready var player: RPGPlayer = $Player
var camera: Camera3D
var world_root: Node3D
var npc_nodes: Dictionary = {}

var skills := {"Empathy": 3, "Logic": 2, "Rhetoric": 3, "Perception": 4, "Composure": 2, "Inland Empire": 3}
var money := 12
var inventory: Array[String] = ["Cracked notebook", "Cigarette packet"]
var journal: Array[String] = ["Find out why the waterfront is sealed."]
var flags: Dictionary = {}
var current_panel := ""
var current_dialogue := ""
var current_speaker := ""
var dialogue_lines: Array[String] = []
var dialogue_choices: Array[Dictionary] = []
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
	"mara": {"name": "Mara Venn", "position": Vector3(-2.5, 0.0, -1.0), "color": Color("#c87960"), "description": "A dockworker with tired eyes and a careful voice."},
	"keeper": {"name": "The Kiosk Keeper", "position": Vector3(8.0, 0.0, 5.0), "color": Color("#91a58b"), "description": "A quiet person behind a rain-stained kiosk."},
	"witness": {"name": "Silent Witness", "position": Vector3(-8.0, 0.0, -5.0), "color": Color("#8b91b0"), "description": "Someone watching the empty street."}
}

func _ready() -> void:
	_build_world()
	_build_camera()
	_build_ui()
	_refresh_hud()
	show_toast("THE PALE DISTRICT  •  3D DEMO BUILD")
	_add_journal_once("Speak to Mara Venn by the waterfront.")

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0 and is_instance_valid(status_label):
			status_label.text = _status_text()
	if is_instance_valid(camera) and is_instance_valid(player):
		var focus := player.global_position + Vector3(0, 0.6, 0)
		camera.global_position = focus + Vector3(13.0, 17.0, 13.0)
		camera.look_at(focus, Vector3.UP)
	_update_hover()

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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_panel != "" or dialogue_active:
			return
		var target := _raycast_target(event.position)
		if target != "":
			_try_interact(target)
		else:
			var destination := _ground_point(event.position)
			if destination != Vector3.INF:
				player.set_destination(destination)

func _build_world() -> void:
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	_add_box("Ground", Vector3(0, -0.35, 0), Vector3(34, 0.6, 28), Color("#343a38"))
	_add_box("Waterfront", Vector3(0, -0.02, -11.2), Vector3(34, 0.12, 5.0), Color("#283e43"))
	_add_box("Wet Road", Vector3(0, 0.015, 2.0), Vector3(34, 0.08, 5.0), Color("#4b4c45"))
	_add_box("Pavement", Vector3(0, 0.02, 6.5), Vector3(34, 0.1, 2.2), Color("#55534b"))
	for i in range(15):
		_add_box("Road Mark %02d" % i, Vector3(-15.5 + i * 2.2, 0.07, 2.0), Vector3(1.0, 0.015, 0.045), Color("#b5a77e", 0.42))
	_add_building("OLD MUNICIPAL OFFICE", Vector3(-10, 1.4, -6.3), Vector3(5.0, 2.8, 4.0), Color("#67584f"))
	_add_building("CLOSED HOTEL", Vector3(-3.5, 1.8, -6.5), Vector3(5.2, 3.6, 4.0), Color("#555d58"))
	_add_building("FERRY ADMINISTRATION", Vector3(5.2, 1.5, -6.3), Vector3(6.0, 3.0, 4.2), Color("#756a58"))
	_add_building("KIOSK / 24H", Vector3(10.5, 1.0, 8.5), Vector3(4.2, 2.0, 3.0), Color("#57504a"))
	_add_box("Pier", Vector3(-1.5, 0.06, -9.0), Vector3(8.0, 0.15, 1.5), Color("#625747"))
	for key in people:
		var info: Dictionary = people[key]
		var npc := _make_npc(key, info)
		world_root.add_child(npc)
		npc_nodes[key] = npc
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#aab4b2")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Overcast Sun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("#e2d7bd")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	camera.current = true
	add_child(camera)

func _add_box(box_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	world_root.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _add_building(label: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := _add_box(label, pos, size, color)
	var roof := _add_box(label + " Roof", pos + Vector3(0, size.y / 2.0 + 0.08, 0), Vector3(size.x + 0.25, 0.16, size.z + 0.25), color.lightened(0.12))
	# Roof is intentionally a simple blockout mesh for easy replacement with authored art.
	for x in range(int(size.x / 1.4)):
		var wx := pos.x - size.x / 2.0 + 0.8 + x * 1.4
		_add_box(label + " Window %d" % x, Vector3(wx, pos.y + 0.1, pos.z + size.z / 2.0 + 0.012), Vector3(0.55, 0.75, 0.035), Color("#263235"))
		_add_box(label + " Window Glow %d" % x, Vector3(wx, pos.y + 0.1, pos.z + size.z / 2.0 + 0.035), Vector3(0.4, 0.58, 0.02), Color("#7c958d", 0.65))

func _make_npc(key: String, info: Dictionary) -> Node3D:
	var root := StaticBody3D.new()
	root.name = key
	root.position = info["position"]
	root.add_to_group("interactable")
	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.55
	capsule.mesh = mesh
	capsule.position.y = 0.78
	var material := StandardMaterial3D.new()
	material.albedo_color = info["color"]
	material.roughness = 0.92
	capsule.material_override = material
	root.add_child(capsule)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	root.add_child(collision)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position.y = 1.72
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color("#c9b69d")
	head.material_override = head_mat
	root.add_child(head)
	var name_tag := Label3D.new()
	name_tag.text = str(info["name"])
	name_tag.position.y = 2.25
	name_tag.font_size = 32
	name_tag.pixel_size = 0.006
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.modulate = Color("#e6ddc9")
	root.add_child(name_tag)
	return root

func _update_hover() -> void:
	var target := _raycast_target(get_viewport().get_mouse_position())
	if target != hovered_target:
		hovered_target = target
		for key in npc_nodes:
			var node: Node3D = npc_nodes[key]
			var mesh_instance: MeshInstance3D = node.get_child(0)
			var mat: StandardMaterial3D = mesh_instance.material_override
			mat.emission_enabled = key == hovered_target
			mat.emission = Color("#d0b783")
			mat.emission_energy_multiplier = 0.4

func _raycast_target(screen_pos: Vector2) -> String:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var collider: Object = hit.get("collider")
	if collider is Node:
		var node := collider as Node
		while node != null and node != world_root:
			if node.is_in_group("interactable"):
				return str(node.name)
			node = node.get_parent()
	return ""

func _ground_point(screen_pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return Vector3.INF
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector3.INF
	var point := origin + direction * distance
	point.x = clampf(point.x, -15.5, 15.5)
	point.z = clampf(point.z, -12.0, 12.0)
	return point

func _target_position(target: String) -> Vector3:
	return (npc_nodes[target] as Node3D).global_position

func _nearest_target() -> String:
	var closest := ""
	var best := INTERACTION_RANGE
	for key in people:
		var distance: float = player.global_position.distance_to(_target_position(key))
		if distance < best:
			best = distance
			closest = key
	return closest

func _interact_nearest() -> void:
	var target := _nearest_target()
	if target == "":
		show_toast("Nobody close enough. Walk closer to a person.")
	else:
		_try_interact(target)

func _try_interact(target: String) -> void:
	var target_pos := _target_position(target)
	if player.global_position.distance_to(target_pos) > INTERACTION_RANGE:
		var direction := player.global_position - target_pos
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			direction = Vector3.RIGHT
		player.set_destination(target_pos + direction.normalized() * 1.8)
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
	panel_content.add_child(HSeparator.new())
	for choice in dialogue_choices:
		var button := Button.new()
		button.text = str(choice["text"])
		button.custom_minimum_size.y = 38
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", Color("#e3ddcb"))
		button.add_theme_stylebox_override("normal", _style(Color("#303638"), Color("#5e625c"), 1, 3))
		button.add_theme_stylebox_override("hover", _style(Color("#414640"), Color("#d0b783"), 1, 3))
		button.pressed.connect(_choose_dialogue.bind(str(choice["action"])))
		panel_content.add_child(button)
	var close_button := Button.new()
	close_button.text = "Close  [Esc]"
	close_button.pressed.connect(_close_panel)
	panel_content.add_child(close_button)

func _choose_dialogue(action: String) -> void:
	match action:
		"perception":
			if _skill_check("Perception", 4, 2):
				_add_journal_once("Mara seemed frightened when she mentioned the municipal ledger.")
				show_toast("SUCCESS — you noticed fear beneath her composure.")
			else:
				show_toast("FAILURE — her expression gives nothing away.")
		"rhetoric":
			if _skill_check("Rhetoric", 3, 2):
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
			if _skill_check("Inland Empire", 3, 2):
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
	var pos := player.global_position
	var data := {"version": 2, "player_position": [pos.x, pos.y, pos.z], "skills": skills, "money": money, "inventory": inventory, "journal": journal, "flags": flags}
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
	var pos: Array = data.get("player_position", [0.0, 0.0, 4.0])
	if pos.size() >= 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		player.destination = player.global_position
	elif pos.size() >= 2:
		player.global_position = Vector3(float(pos[0]) / 45.0 - 16.0, 0.0, float(pos[1]) / 45.0 - 12.0)
		player.destination = player.global_position
	skills = data.get("skills", skills)
	money = int(data.get("money", money))
	inventory.assign(data.get("inventory", inventory))
	journal.assign(data.get("journal", journal))
	flags = data.get("flags", flags)
	_refresh_hud()
	show_toast("GAME LOADED")

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
	subtitle.text = "3D NARRATIVE RPG  /  DAY 01"
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_color_override("font_color", Color("#9da39a"))
	top_row.add_child(subtitle)
	var controls := Label.new()
	controls.text = "WASD move  •  LMB move/interact  •  E talk  •  J journal  •  I inventory  •  C skills  •  F5 save"
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
	interaction_hint.text = "Click ground to move • Click a person or approach and press E"
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
	panel.size = Vector2(460, 480)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _style(Color("#202427"), Color("#a18b68"), 2, 8))
	root.add_child(panel)
	panel_content = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 12)
	panel.add_child(panel_content)

func _style(bg: Color, border: Color, border_size: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_size)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _refresh_hud() -> void:
	if is_instance_valid(status_label):
		status_label.text = _status_text()
	if is_instance_valid(objective_label):
		objective_label.text = "CURRENT TASK  /  " + ("Report what Mara told you" if flags.get("mara_truth", false) else "Find Mara Venn by the waterfront")

func _status_text() -> String:
	return "₡ %d   •   %d items   •   %d journal entries" % [money, inventory.size(), journal.size()]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_panel != "":
		_close_panel()
