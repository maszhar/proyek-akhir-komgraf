extends Node3D

@export var RED_DURATION: float = 4.0
@export var YELLOW_DELAY_AFTER_TRIGGER: float = 0.5
@export var RED_DELAY_AFTER_YELLOW: float = 2.0
@export var SISWA_MOVE_DELAY: float = 5.0
@export var SISWA_MOVE_AMOUNT_X: float = 9.0 # move left by -9 -> subtract this from current X

# Node references 
var lamp_green: MeshInstance3D
var lamp_yellow: MeshInstance3D
var lamp_red: MeshInstance3D
var collision_area: Area3D
var over_collision_area: Area3D

# State tracking
var state: String = "green" # Default State
var trigger_active: bool = false
var timer: float = 0.0
var siswa: Node3D = null
var siswa_pending: bool = false
var siswa_timer: float = 0.0
var siswa_moving: bool = false
var siswa_moved: bool = false
var pelanggaran: bool = false

@onready var mesh = $"."
var warning_label : Label = null
@export var lamp_sound: AudioStream

var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	# Resolve nodes (robust search — safe if structure differs slightly)
	call_deferred("_init_nodes")

func _init_nodes() -> void:
	print("[Tetot2] Initializing nodes and collision handler...")
	
	warning_label = get_tree().root.get_node("Node3D/Tetot2/CenterContainer/WarningLabel")
	if warning_label == null:
		_log("[Warning Label] : not found")
	
	# Prefer finding lamp nodes inside this Tetot2 subtree first (handles names like LampuHijau / Lampu Hijau / Lampu_Hijau)
	lamp_green = _search_local_lamp("hijau") as MeshInstance3D
	lamp_yellow = _search_local_lamp("kuning") as MeshInstance3D
	lamp_red = _search_local_lamp("merah") as MeshInstance3D

	# If we still don't have lamps, fallback to global search and warn
	if lamp_green == null:
		lamp_green = _search_global_lamp_variants("hijau") as MeshInstance3D
		if lamp_green != null:
			_log("Warning: Using global 'Hijau' node (%s) — consider renaming local lamps so they're found locally" % lamp_green.get_path())
	if lamp_yellow == null:
		lamp_yellow = _search_global_lamp_variants("kuning") as MeshInstance3D
		if lamp_yellow != null:
			_log("Warning: Using global 'Kuning' node (%s) — consider renaming local lamps so they're found locally" % lamp_yellow.get_path())
	if lamp_red == null:
		lamp_red = _search_global_lamp_variants("merah") as MeshInstance3D
		if lamp_red != null:
			_log("Warning: Using global 'Merah' node (%s) — consider renaming local lamps so they're found locally" % lamp_red.get_path())

	print("[Tetot2] Found lamps -> green:", lamp_green != null, "yellow:", lamp_yellow != null, "red:", lamp_red != null)
	if lamp_green: _log("Green lamp path: %s" % lamp_green.get_path())
	if lamp_yellow: _log("Yellow lamp path: %s" % lamp_yellow.get_path())
	if lamp_red: _log("Red lamp path: %s" % lamp_red.get_path())

	# Locate the collision area (trigger lampu merah)
	collision_area = _find_node_by_name("tetotcollition")
	if not collision_area.area_entered.is_connected(_on_area_entered):
		collision_area.area_entered.connect(_on_area_entered)
		print("[Tetot2] Connected collision signal from:", collision_area.name)
	
	# Locate the OVER collision area (pelanggaran lampu merah)
	over_collision_area = _find_node_by_name("redcollition")
	if not over_collision_area.area_entered.is_connected(_on_red_area_entered):
		over_collision_area.area_entered.connect(_on_red_area_entered)
		print("[Tetot2] Connected RED COLLISION signal from:", over_collision_area.name)
	
	_set_state("green", true)
	siswa = _find_node_by_name("Siswa") as Node3D
	if siswa != null:
		_log("Siswa found for Tetot2 -> %s" % siswa.get_path())
	else:
		_log("No Siswa node found inside Tetot2 (searching for child named 'Siswa')")

func _process(delta: float) -> void:
	# First, handle any pending Siswa movement (runs independently of light timeline)
	if siswa_pending and not siswa_moving:
		siswa_timer -= delta
		if siswa_timer <= 0.0:
			# Start actual movement
			_start_move_siswa()

	# If trigger active we run the timeline via timer for lights
	if not trigger_active:
		return

	timer -= delta
	
	if state == "green" and pelanggaran == true:
		pelanggaran == false
		_log("green pelanggaran true")
	if state == "pre_yellow" and timer <= 0.0:
		warning_label.modulate = Color(0.9, 0.9, 0.0)
		warning_label.visible = true
		warning_label.text = "Kurangi Kecepatan !"
		_log("PRE_YELLOW elapsed -> switching to YELLOW")
		_set_state("yellow")
		timer = RED_DELAY_AFTER_YELLOW
	elif state == "yellow" and timer <= 0.0 and pelanggaran == false :
		warning_label.modulate = Color(0.9, 0.0, 0.0)
		warning_label.text = "Berhenti Sebelum Lampu Merah !!"
		_log("YELLOW -> switching to RED now")
		_set_state("red")
		timer = RED_DURATION
		
	elif state == "red" and timer <= 0.0 and pelanggaran == false:
		warning_label.modulate = Color(0.0, 0.8, 0.0)
		warning_label.text = "Silahkan Jalan Kembali"
		_log("RED duration finished -> switching back to GREEN")
		_set_state("end_tetot")
		timer = 1.0
		
	elif state == "end_tetot" and timer <= 0.0 and pelanggaran == false:
		_log("End Event")
		warning_label.visible = false
		trigger_active = false
		_set_state("green")
		timer = 0.0
		
	if state == "end_tetot" and pelanggaran == true:
		pelanggaran == false
	elif trigger_active and state == "red" and pelanggaran == true:
		_log("Red Light Violation find")
		if warning_label != null:
			warning_label.modulate = Color(1.0, 0.0, 0.0) #
			warning_label.text = "PELANGGARAN !!!"
		_log("Red Light Violation")
		trigger_active = false
		pelanggaran == false
		_set_state("green")
	elif trigger_active and state == "yellow" and pelanggaran == true:
		_log("Mobil masuk area Merah saat lampu Kuning. Perlu peringatan?")
		if warning_label != null:
			warning_label.modulate = Color(1.0, 0.7, 0.0)
			warning_label.text = "Peringatan: Hampir Melanggar!"
		timer = 1.0
		_log("Warning Yellow Light")
		pelanggaran = false
		_set_state("end_tetot")

func _on_area_entered(area: Area3D) -> void:
	# Called when something enters Tetot2's collision area
	_log("Collision area entered firs trigger: %s (type=%s)" % [area.name, area.get_class()])

	# Identify vehicle by name containing 'Mobil' or group 'mobil_collision'
	var is_car = false
	if "Mobil" in area.name:
		is_car = true
	if area.is_in_group("mobil_collision"):
		is_car = true

	if not is_car:
		_log("Collision ignored: object is not a Mobil (name/group mismatch)")
		return

	_log("Mobil collision detected -> activating light sequence")

	# Immediately disable green (per spec) and start timeline
	_log("Trigger: turning GREEN OFF immediately, waiting %.2fs for YELLOW" % YELLOW_DELAY_AFTER_TRIGGER)
	_set_lamps(false, false, false)

	trigger_active = true
	state = "pre_yellow"
	# After a 0.5s delay we will switch to YELLOW in _process
	timer = YELLOW_DELAY_AFTER_TRIGGER
	_log("Sequence timeline started: 0.5s -> YELLOW, +1.0s -> RED, RED duration: %s s" % RED_DURATION)
	# Schedule Siswa movement if applicable
	if siswa != null:
		if siswa_pending or siswa_moving or siswa_moved:
			_log("Siswa movement already pending or performed; skipping scheduling")
		else:
			siswa_pending = true
			siswa_timer = SISWA_MOVE_DELAY
			# compute target x now (relative to current) so repeated moves don't stack unexpectedly
			var target_x = siswa.position.x - SISWA_MOVE_AMOUNT_X
			_log("SISWA: Scheduled to walk to X=%.2f (current=%.2f) in %.2f seconds" % [target_x, siswa.position.x, SISWA_MOVE_DELAY])
			# store target on the node for safety
			siswa.set_meta("_tetot_siswa_target_x", target_x)
	else:
		_log("No Siswa node to schedule movement for")
		
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "tototot"
	add_child(audio_player)
	# Export lamp_sound from asset if get_node don't find the audio
	if lamp_sound != null:
		audio_player.stream = lamp_sound
	else:
		var default_path := "res://Aset/audio/tototot.wav"
		if FileAccess.file_exists(default_path):
			var loaded = load(default_path)
			if loaded:
				audio_player.stream = loaded
				print("[Tetot] Using default engine audio: %s" % default_path)
			else:
				print("[Mobil] Default engine audio exists but failed to load: %s" % default_path)
		else:
			print("[Mobil] No engine sound assigned and default file not found: %s" % default_path)
	audio_player.play()
	
# Fungsi baru yang merespons tabrakan dengan Area "redcollition"
func _on_red_area_entered(area: Area3D) -> void:
	# 1. Identifikasi apakah objek yang bertabrakan adalah Mobil
	_log("Collision area entered: %s (type=%s)" % [area.name, area.get_class()])
	if state == "green" or state == "end_tetot":
		return
	var is_car = false
	if "Mobil" in area.name:
		is_car = true
	if area.is_in_group("mobil_collision"):
		is_car = true
	if not is_car:
		_log("Red Collision ignored: object is not a Mobil")
		return
		
	pelanggaran = true
	
func _set_state(new_state: String, force_show: bool=false) -> void:
	# Update internal state and visual lamp nodes as requested
	state = new_state

	# Update visibility of lamps
	if  new_state == "end_tetot":
		_set_lamps(true, false, false)
	elif new_state == "green":
		_set_lamps(true, false, false)
	elif new_state == "yellow":
		_set_lamps(false, true, false)
	elif new_state == "red":
		_set_lamps(false, false, true)
	elif new_state == "pre_yellow":
		_set_lamps(false, false, false)

	_log("State changed -> %s" % new_state.to_upper())

func _log(msg: String) -> void:
	# Consistent logging helper
	print("[Tetot2] %s" % msg)

func _find_node_by_name(name: String) -> Node:
	# Helper: search current node and subtree by name
	var n = get_node_or_null(name)
	if n:
		return n
	for c in get_children():
		var found = _find_in_tree_recursive(c, name)
		if found:
			return found
	return null

func _find_in_tree_recursive(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var f = _find_in_tree_recursive(child, name)
		if f:
			return f
	return null

func _find_node_in_tree(root: Node, name: String) -> Node:
	# Search only inside root subtree
	if root.name == name:
		return root
	for child in root.get_children():
		var found = _find_in_tree_recursive(child, name)
		if found:
			return found
	return null

func _get_collision_area() -> Area3D:
	# Look for common names used in the project (both from Tetot2 and Mobil)
	var candidates = ["tetotcollition"]
	for name in candidates:
		var n = _find_node_by_name(name)
		if n and n is Area3D:
			return n

	# Sometimes Tetot2 may have a direct child named "tetotcollition"
	var direct = get_node_or_null("tetotcollition")
	if direct and direct is Area3D:
		return direct

	# Not found
	return null

func _search_local_lamp(color_keyword: String) -> MeshInstance3D:
	# Search only inside this node for a MeshInstance3D whose name contains the color keyword
	for child in get_children():
		var found = _search_child_for_lamp(child, color_keyword)
		if found:
			return found
	return null

func _search_child_for_lamp(node: Node, color_keyword: String) -> MeshInstance3D:
	# case-insensitive contains check
	if node is MeshInstance3D and node.name.to_lower().findn(color_keyword) >= 0:
		return node as MeshInstance3D
	for c in node.get_children():
		var f = _search_child_for_lamp(c, color_keyword)
		if f:
			return f
	return null

func _search_global_lamp_variants(color_keyword: String) -> MeshInstance3D:
	# Try several naming variants globally (spaces, no-spaces, underscores)
	var variants = ["Lampu %s" % color_keyword.capitalize(), "Lampu%s" % color_keyword.capitalize(), "Lampu_%s" % color_keyword.capitalize(), "%s" % color_keyword.capitalize()]
	for v in variants:
		var n = _find_node_by_name(v)
		if n and n is MeshInstance3D:
			return n as MeshInstance3D
	# fallback: look for any MeshInstance3D in scene that contains keyword
	for n in get_tree().get_nodes_in_group(""):
		if n is MeshInstance3D and n.name.to_lower().findn(color_keyword) >= 0:
			return n as MeshInstance3D
	return null

func _set_lamps(green_on: bool, yellow_on: bool, red_on: bool) -> void:
	if lamp_green != null:
		lamp_green.visible = green_on
	if lamp_yellow != null:
		lamp_yellow.visible = yellow_on
	if lamp_red != null:
		lamp_red.visible = red_on

func _start_move_siswa() -> void:
	if siswa == null:
		_log("_start_move_siswa called but no siswa node available")
		siswa_pending = false
		return
	if siswa_moving:
		_log("Siswa is already moving — skipping start")
		return

	# read target from meta, fallback to current - SISWA_MOVE_AMOUNT_X
	var target_x = siswa.get_meta("_tetot_siswa_target_x") if siswa.has_meta("_tetot_siswa_target_x") else (siswa.position.x - SISWA_MOVE_AMOUNT_X)

	siswa_pending = false
	siswa_moving = true
	_log("SISWA: Starting movement to X=%.2f (current=%.2f)" % [target_x, siswa.position.x])

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(siswa, "position:x", target_x, 0.8)

	# Wait for tween to finish and mark as moved
	await tween.finished

	siswa_moving = false
	siswa_moved = true
	siswa.set_meta("_tetot_siswa_target_x", null)
	_log("SISWA: Movement complete — new position x=%.2f" % siswa.position.x)
