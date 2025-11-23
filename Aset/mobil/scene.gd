extends Node3D 

@export var speed: float = 5.0

var crossing_at = 0.0
var crossing_done = 0
var crossing_progress = 0
var crossing_elapsed = 0
var objekLampuHijau: Node3D
var objekLampuKuning: Node3D
var objekLampuMerah: Node3D
var objekSiswa: Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	crossing_at = randf() * 1000 - 200
	print("Crossing at: " + str(crossing_at))
	objekLampuHijau = get_parent().get_node("Lampu Hijau")
	objekLampuKuning = get_parent().get_node("Lampu Kuning")
	objekLampuMerah = get_parent().get_node("Lampu Merah")
	objekSiswa = get_parent().get_node("Siswa")

func cross(current_position: Vector3, delta_time):
	if(crossing_done == 2):
		return
	if(crossing_done == 0 && current_position.z < crossing_at):
		return
		
	crossing_done = 1
	
	if(crossing_progress == 0):
		print("Crossing")
		# switch kuning
		objekLampuHijau.set_visible(false)
		objekLampuKuning.set_visible(true)
		crossing_progress = 1;
		
	elif(crossing_progress == 1 && crossing_elapsed > 3):
		objekLampuKuning.set_visible(false)
		objekLampuMerah.set_visible(true)
		crossing_progress = 2;
		
	elif(crossing_progress == 2 && crossing_elapsed > 4):
		var crossingSpeed = Vector3.ZERO
		crossingSpeed.z += 0.1
		objekSiswa.translate(crossingSpeed)
		if(objekSiswa.get_position().x < -450):
			crossing_progress = 3;
			
	elif(crossing_progress == 3 && crossing_elapsed > 10):
		objekLampuMerah.set_visible(false)
		objekLampuHijau.set_visible(true)
		crossing_progress = 4;
		crossing_done = 2;
		
	crossing_elapsed += delta_time

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var current_position = get_position()
	var velocity: Vector3 = Vector3.ZERO

	# Jika tombol dengan input action "move_up" ditekan
	if Input.is_action_pressed("move_up") && current_position.z < 3000:
		velocity.z += 1  # bergerak ke depan (arah -Z)
		
	if Input.is_action_pressed("move_down") && current_position.z > -450:
		velocity.z += -1

	cross(current_position, delta)

	# Terapkan gerakan
	if velocity != Vector3.ZERO:
		velocity = velocity.normalized() * speed * delta
		translate(velocity)
