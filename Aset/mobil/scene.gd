extends Node3D

@export var speed: float = 5.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var velocity: Vector3 = Vector3.ZERO

	# Jika tombol dengan input action "move_up" ditekan
	if Input.is_action_pressed("move_up"):
		velocity.z += 1  # bergerak ke depan (arah -Z)
		
	if Input.is_action_pressed("move_down"):
		velocity.z += -1

	# Terapkan gerakan
	if velocity != Vector3.ZERO:
		velocity = velocity.normalized() * speed * delta
		translate(velocity)
