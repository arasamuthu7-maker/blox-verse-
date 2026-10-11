extends Node3D

const MOVE_SPEED := 7.0
const JUMP_SPEED := 7.0

var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var status_label: Label
var level := 1
var xp := 0
var power := 0
var hp := 100
var training := false
var attacking := false
var held := {}
var enemies: Array[Node3D] = []
var arena_size := 28.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.9)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)
	_make_box(Vector3(0, -0.6, 0), Vector3(arena_size, 1, arena_size), Color(0.18, 0.58, 0.28), true)
	for x in range(-12, 13, 4):
		for z in range(-12, 13, 4):
			if abs(x) < 4 and abs(z) < 4:
				continue
			_make_box(Vector3(x, 0.15, z), Vector3(1.1, 1.1, 1.1), Color(0.25, 0.55, 0.85), false)
	for i in range(4):
		var e := _make_box(Vector3(-7 + i * 4, 1, -7), Vector3(1.5, 2, 1.5), Color(0.9, 0.18, 0.2), true)
		e.name = "Enemy"
		enemies.append(e)
	_make_box(Vector3(0, 0.08, -10), Vector3(5, 0.15, 3), Color(0.95, 0.7, 0.15), false)

func _make_box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		root = body
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	else:
		root = Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.08
	mat.roughness = 0.7
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	root.position = pos
	add_child(root)
	return root

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.5, 5)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)
	var body_mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	body_mesh.mesh = capsule_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 1.0)
	body_mesh.material_override = mat
	body_mesh.position.y = 0.9
	player.add_child(body_mesh)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 75
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18, 14)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(hud)
	status_label = Label.new()
	status_label.position = Vector2(18, 88)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(1, 0.95, 0.55))
	layer.add_child(status_label)
	_add_button(layer, "↑", Vector2(105, -155), "forward")
	_add_button(layer, "↓", Vector2(105, -65), "back")
	_add_button(layer, "←", Vector2(15, -110), "left")
	_add_button(layer, "→", Vector2(195, -110), "right")
	_add_button(layer, "JUMP", Vector2(-245, -160), "jump")
	_add_button(layer, "TRAIN", Vector2(-245, -105), "train")
	_add_button(layer, "ATTACK", Vector2(-245, -50), "attack")
	_refresh_hud()

func _add_button(layer: CanvasLayer, text_value: String, offset: Vector2, action: String) -> void:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(76, 48)
	b.anchor_left = 1.0 if offset.x < 0 else 0.0
	b.anchor_right = 1.0 if offset.x < 0 else 0.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.position = offset
	b.add_theme_font_size_override("font_size", 17)
	layer.add_child(b)
	if action in ["forward", "back", "left", "right", "jump"]:
		b.button_down.connect(func(): held[action] = true)
		b.button_up.connect(func(): held[action] = false)
	elif action == "train":
		b.pressed.connect(_train)
	else:
		b.pressed.connect(_attack)

func _process(delta: float) -> void:
	if is_instance_valid(player):
		var target := player.global_position + Vector3(0, 4.5, 8.5)
		camera.global_position = camera.global_position.lerp(target, min(delta * 5.0, 1.0))
		camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	if training:
		xp += 1
		if xp >= level * 10:
			xp = 0
			level += 1
			power += 2
			status_label.text = "LEVEL UP! Power +2"
		_refresh_hud()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var input_dir := Vector2.ZERO
	input_dir.y -= float(held.get("forward", false)) + float(Input.is_key_pressed(KEY_W)) + float(Input.is_key_pressed(KEY_UP))
	input_dir.y += float(held.get("back", false)) + float(Input.is_key_pressed(KEY_S)) + float(Input.is_key_pressed(KEY_DOWN))
	input_dir.x -= float(held.get("left", false)) + float(Input.is_key_pressed(KEY_A)) + float(Input.is_key_pressed(KEY_LEFT))
	input_dir.x += float(held.get("right", false)) + float(Input.is_key_pressed(KEY_D)) + float(Input.is_key_pressed(KEY_RIGHT))
	input_dir = input_dir.limit_length()
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	player.velocity.x = direction.x * MOVE_SPEED
	player.velocity.z = direction.z * MOVE_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	elif held.get("jump", false) or Input.is_key_pressed(KEY_SPACE):
		player.velocity.y = JUMP_SPEED
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -13.0, 13.0)
	player.position.z = clampf(player.position.z, -13.0, 13.0)

func _train() -> void:
	training = not training
	status_label.text = "Training ON — gain XP!" if training else "Training OFF"
	_refresh_hud()

func _attack() -> void:
	var hit_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 5.0:
			enemy.queue_free()
			hit_count += 1
	if hit_count > 0:
		xp += hit_count * 5
		power += hit_count
		status_label.text = "POWER HIT! +%d power" % hit_count
	else:
		status_label.text = "Get closer to a red enemy!"
	_refresh_hud()

func _refresh_hud() -> void:
	if is_instance_valid(hud):
		hud.text = "BLOCK VERSE   |   LVL %d   |   XP %d/%d   |   POWER %d   |   HP %d" % [level, xp, level * 10, power, hp]
