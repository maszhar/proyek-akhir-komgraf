extends Node3D 

@export var speed: float = 5.0

const PROGRESS_LAMPU_HIJAU = 0
const PROGRESS_LAMPU_KUNING = 1
const PROGRESS_LAMPU_MERAH = 2
const PROGRESS_MENYEBRANG = 3
const PROGRESS_SELESAI = 4

const KONDISI_BELUM_MENYEBRANG = 0
const KONDISI_SEDANG_MENYEBRANG = 1
const KONDISI_TELAH_MENYEBRANG = 2

var menyebrang_pada = 0.0
var kondisi_menyebrang = KONDISI_BELUM_MENYEBRANG
var progress_menyebrang = PROGRESS_LAMPU_HIJAU
var kemajuan_waktu_menyebrang = 0
var objekLampuHijau: Node3D
var objekLampuKuning: Node3D
var objekLampuMerah: Node3D
var objekSiswa: Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menyebrang_pada = randf() * 1000 - 200
	print("Crossing at: " + str(menyebrang_pada))
	objekLampuHijau = get_parent().get_node("Lampu Hijau")
	objekLampuKuning = get_parent().get_node("Lampu Kuning")
	objekLampuMerah = get_parent().get_node("Lampu Merah")
	objekSiswa = get_parent().get_node("Siswa")

func cross(current_position: Vector3, delta_time):
	if(kondisi_menyebrang == KONDISI_TELAH_MENYEBRANG):
		return
	if(kondisi_menyebrang == KONDISI_BELUM_MENYEBRANG && current_position.z < menyebrang_pada):
		return
		
	kondisi_menyebrang = KONDISI_SEDANG_MENYEBRANG
	
	if(progress_menyebrang == PROGRESS_LAMPU_HIJAU):
		print("Crossing")
		# switch kuning
		objekLampuHijau.set_visible(false)
		objekLampuKuning.set_visible(true)
		progress_menyebrang = PROGRESS_LAMPU_KUNING;
		
	elif(progress_menyebrang == PROGRESS_LAMPU_KUNING && kemajuan_waktu_menyebrang > 3):
		objekLampuKuning.set_visible(false)
		objekLampuMerah.set_visible(true)
		progress_menyebrang = PROGRESS_LAMPU_MERAH;
		
	elif(progress_menyebrang == PROGRESS_LAMPU_MERAH && kemajuan_waktu_menyebrang > 4):
		var crossingSpeed = Vector3.ZERO
		crossingSpeed.z += 0.1
		objekSiswa.translate(crossingSpeed)
		if(objekSiswa.get_position().x < -450):
			progress_menyebrang = PROGRESS_MENYEBRANG;
			
	elif(progress_menyebrang == PROGRESS_MENYEBRANG && kemajuan_waktu_menyebrang > 10):
		objekLampuMerah.set_visible(false)
		objekLampuHijau.set_visible(true)
		progress_menyebrang = PROGRESS_SELESAI;
		kondisi_menyebrang = KONDISI_TELAH_MENYEBRANG;
		
	kemajuan_waktu_menyebrang += delta_time

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
