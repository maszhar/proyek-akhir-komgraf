extends Node3D

# ======= KONFIGURASI KENDARAAN =======
@export var max_forward_speed : float = 20.0
@export var max_backward_speed : float = 4.0
@export var acceleration : float = 0.5
@export var brake_force : float = 1.0
@export var friction : float = 17.0
@export var steering_sensitivity : float = 5.0
@export var max_steering_angle : float = 15.0
@export var steering_responsiveness : float = 0.25  # smooth steering
@export var engine_inertia : float = 0.01  # smooth acceleration

# ======= VARIABEL FISIKA =======
var velocity : Vector3 = Vector3.ZERO
var current_speed : float = 0.0
var current_steering_angle : float = 0.0
var target_steering_angle : float = 0.0
var is_moving_forward : bool = false
var wheel_ground_contact : bool = true
var speed_kmh : float = 0.0

# ======= REFERENSI NODE =======
@onready var mesh = $"."  # atau sesuaikan dengan nama node mesh Anda
var speed_label : Label = null
var kmh_label : Label = null
@export var engine_sound: AudioStream
@export var engine_base_pitch: float = 1.0
@export var engine_max_pitch: float = 2.0
@export var engine_idle_volume_db: float = 3.0
@export var engine_max_volume_db: float = 24.0

var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	# Ambil referensi ke speed label dari scene utama
	speed_label = get_tree().root.get_node("Node3D/SpeedUI/SpeedLabel")
	kmh_label = get_tree().root.get_node("Node3D/SpeedUI/KmhLabel")
	
	# Setup collision area untuk tabrakan dengan Tetot2
	_setup_collision_area()


	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "AudioMobil"
	add_child(audio_player)
	# Assign stream: prefer exported engine_sound, fallback to default asset
	if engine_sound != null:
		audio_player.stream = engine_sound
	else:
		var default_path := "res://Aset/audio/car-engine-idling-76891.mp3"
		if FileAccess.file_exists(default_path):
			var loaded = load(default_path)
			if loaded:
				audio_player.stream = loaded
				print("[Mobil] Using default engine audio: %s" % default_path)
			else:
				print("[Mobil] Default engine audio exists but failed to load: %s" % default_path)
		else:
			print("[Mobil] No engine sound assigned and default file not found: %s" % default_path)

	# Start playing if stream is available
	if audio_player.stream != null:
		audio_player.play()
		audio_player.pitch_scale = engine_base_pitch
		audio_player.volume_db = engine_idle_volume_db

func _setup_collision_area() -> void:
	# Buat Area3D untuk collision detection
	var collision_area = Area3D.new()
	collision_area.name = "MobilCollisionArea"
	add_child(collision_area)
	
	# Buat collision shape (box)
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2, 1, 3.8)  # Ukuran mobil
	collision_shape.shape = box_shape
	collision_area.add_child(collision_shape)
	
	# Set collision layer dan mask
	collision_area.collision_layer = 0
	collision_area.collision_mask = 1
	collision_area.add_to_group("mobil_collision")


func _physics_process(delta: float) -> void:
	# ===============================
	# 1. Input handling
	# ===============================
	var input_acceleration : float = 0.0
	var input_steering : float = 0.0
	var is_braking : bool = false
	var target_speed : float = 0.0
	
	# Check if space is pressed for braking
	if Input.is_action_pressed("ui_accept"):  # ui_accept adalah Space
		is_braking = true
	elif Input.is_action_pressed("move_down"):
		# Jika sedang bergerak maju, ini adalah rem biasa (brake)
		# Jika sedang diam atau mundur, ini adalah akselerasi mundur
		if is_moving_forward == true && speed_kmh > 1:  # Sedang bergerak maju
			is_braking = true
		else:  # Diam atau mundur
			input_acceleration = 1.0  # Akselerasi mundur
			is_moving_forward = false
	elif Input.is_action_pressed("move_up"):
		input_acceleration = -1.0  # Akselerasi maju
		is_moving_forward = true
	else:
		input_acceleration = 0.0
	
	if Input.is_action_pressed("ui_left"):
		input_steering = 1.0
	elif Input.is_action_pressed("ui_right"):
		input_steering = -1.0
	else:
		input_steering = 0.0
	
	# ===============================
	# 2. Engine & Speed calculation
	# ===============================
	
	if is_braking:
		# Ketika sedang maju dan menekan down, rem perlahan (bukan emergency)
		target_speed = 0.0
		current_speed = lerp(current_speed, target_speed, brake_force * delta)
	elif input_acceleration > 0.0:
		# Akselerasi mundur dengan kecepatan sama seperti maju
		target_speed = max_backward_speed * input_acceleration
		current_speed = lerp(current_speed, target_speed, engine_inertia)
	elif input_acceleration < 0.0:
		# Akselerasi maju
		target_speed = -max_forward_speed * abs(input_acceleration)
		current_speed = lerp(current_speed, target_speed, engine_inertia)
	else:
		# Saat gas dilepas, maintain current speed dan kurangi secara bertahap
		target_speed = current_speed * (1.0 - friction * delta)
		current_speed = lerp(current_speed, target_speed, engine_inertia)
	
	# ===============================
	# 3. Steering dengan smoothing
	# ===============================
	if current_speed != 0.0:
		target_steering_angle = input_steering * max_steering_angle
	else:
		target_steering_angle = 0.0
	
	# Smooth steering untuk gerak natural
	current_steering_angle = lerp(current_steering_angle, target_steering_angle, steering_responsiveness)
	
	# Apply steering rotation
	rotation.y += deg_to_rad(current_steering_angle * steering_sensitivity * delta)
	
	# ===============================
	# 4. Movement dengan Ackermann steering
	# ===============================
	if abs(current_speed) > 0.1:
		var forward_dir = -transform.basis.z.normalized()
		var movement = forward_dir * current_speed * delta
		position += movement
		
		# Tilting effect untuk realism (lean saat belok)
		var target_tilt = -current_steering_angle * 0.3
		rotation.z = lerp(rotation.z, deg_to_rad(target_tilt), 0.1)
	else:
		# Reset tilt saat berhenti
		rotation.z = lerp(rotation.z, 0.0, 0.1)
	
	# ===============================
	# 5. Visual feedback (opsional)
	# ===============================
	_update_engine_sound_pitch(delta)
	_update_speed_ui()

func _update_speed_ui() -> void:
	if speed_label != null:
		# Konversi speed ke km/h (asumsi current_speed dalam unit/detik)
		speed_kmh = abs(current_speed) * 3.6
		speed_label.text = "%.0f"  % speed_kmh


func _update_engine_sound_pitch(delta: float) -> void:
	# Update engine audio (pitch & volume) according to current speed
	if audio_player == null or audio_player.stream == null:
		return

	var speed_abs = abs(current_speed)
	var max_speed = max(abs(max_forward_speed), abs(max_backward_speed))
	var normalized = 0.0
	if max_speed > 0.0:
		normalized = clamp(speed_abs / max_speed, 0.0, 1.0)

	# Calculate target pitch & volume
	var target_pitch = lerp(engine_base_pitch, engine_max_pitch, normalized)
	var target_volume = lerp(engine_idle_volume_db, engine_max_volume_db, normalized)

	# Smooth transitions
	audio_player.pitch_scale = lerp(audio_player.pitch_scale, target_pitch, 0.12)
	audio_player.volume_db = lerp(audio_player.volume_db, target_volume, 0.1)

	# Ensure playing
	if not audio_player.playing:
		audio_player.play()
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
