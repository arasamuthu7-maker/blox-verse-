extends CharacterBody3D
class_name BlockVerseEnemy

@export var max_hp: int = 30
@export var move_speed: float = 2.2
@export var detection_range: float = 8.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 5

var hp: int
var target: Node3D
var attack_cooldown: float = 0.0

func _ready() -> void:
	hp = max_hp

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if not is_instance_valid(target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= detection_range and distance > attack_range:
		var direction := offset.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if distance <= attack_range and attack_cooldown <= 0.0 and target.has_method("take_damage"):
		target.take_damage(attack_damage)
		attack_cooldown = 1.2

func take_damage(amount: int) -> bool:
	hp = maxi(hp - amount, 0)
	return hp <= 0
