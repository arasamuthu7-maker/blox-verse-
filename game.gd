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
var animation_time := 0.0
var body_mesh: MeshInstance3D
var held := {}
var enemies: Array[Node3D] = []
var arena_size := 28.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_ui()
	_load_progress()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.82, 1.0)
	environment.ambient_light_energy = 0.9
	env.environment = environment
	add_child(env)

	# Natural island base, not a cube/block terrain.
	_make_box(Vector3(0, -0.6, 0), Vector3(arena_size, 1, arena_size), Color(0.12, 0.42, 0.23), true)
	_make_box(Vector3(0, -0.1, 0), Vector3(24, 0.25, 24), Color(0.22, 0.58, 0.29), false)
	_make_box(Vector3(0, -0.2, 13.2), Vector3(28, 0.35, 2.0), Color(0.85, 0.75, 0.49), false)
	_make_box(Vector3(0, -0.2, -13.2), Vector3(28, 0.35, 2.0), Color(0.85, 0.75, 0.49), false)
	_make_box(Vector3(13.2, -0.2, 0), Vector3(2.0, 0.35, 28), Color(0.85, 0.75, 0.49), false)
	_make_box(Vector3(-13.2, -0.2, 0), Vector3(2.0, 0.35, 28), Color(0.85, 0.75, 0.49), false)

	# Trees use cylinders and spheres for a more natural island silhouette.
	for i in range(14):
		var angle := float(i) * TAU / 14.0
		var px := cos(angle) * 10.0
		var pz := sin(angle) * 10.0
		_make_cylinder(Vector3(px, 0.65, pz), 0.22, 1.5, Color(0.34, 0.19, 0.09), true)
		_make_sphere(Vector3(px, 1.75, pz), Vector3(1.15, 1.35, 1.15), Color(0.08, 0.38 + float(i % 3) * 0.06, 0.16), false)

	# Low rocky hills and a central training platform.
	_make_sphere(Vector3(-8.5, 0.3, -5.5), Vector3(3.5, 1.3, 2.8), Color(0.35, 0.39, 0.31), false)
	_make_sphere(Vector3(8.5, 0.55, -6.5), Vector3(3.8, 1.8, 3.0), Color(0.42, 0.43, 0.37), false)
	_make_cylinder(Vector3(0, 0.05, -9.0), 2.5, 0.25, Color(0.22, 0.35, 0.55), false)
	_make_cylinder(Vector3(0, 0.22, -9.0), 1.7, 0.12, Color(0.15, 0.65, 1.0), false)

	for i in range(4):
		var e := _make_box(Vector3(-7 + i * 4, 1, -4), Vector3(1.1, 1.8, 1.1), Color(0.82, 0.16, 0.2), true)
		e.name = "Enemy"
		enemies.append(e)

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

func _make_cylinder(pos: Vector3, radius: float, height: float, color: Color, solid: bool) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	if solid:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		root.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	root.position = pos
	add_child(root)
	return root

func _make_sphere(pos: Vector3, scale_value: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	if solid:
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.0
		collision.shape = shape
		collision.scale = scale_value
		root.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh_instance.mesh = mesh
	mesh_instance.scale = scale_value
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	root.position = pos
	add_child(root)
	return root

func _add_character_part(parent: Node3D, part_name: String, local_pos: Vector3, part_scale: Vector3, color: Color, shape_kind: String) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	if shape_kind == "box":
		var mesh := BoxMesh.new()
		mesh.size = part_scale
		part.mesh = mesh
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		part.mesh = mesh
		part.scale = part_scale
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	part.material_override = mat
	part.position = local_pos
	parent.add_child(part)

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
	body_mesh = MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	body_mesh.mesh = capsule_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 1.0)
	body_mesh.material_override = mat
	body_mesh.position.y = 0.9
		player.add_child(body_mesh)
	# Anime-inspired head, hair, face, scarf, coat, arms, and boots.
	_add_character_part(player, "Head", Vector3(0, 1.95, 0), Vector3(0.66, 0.72, 0.62), Color(0.94, 0.72, 0.57), "sphere")
	_add_character_part(player, "Hair", Vector3(0, 2.28, -0.08), Vector3(0.72, 0.48, 0.68), Color(0.035, 0.045, 0.07), "sphere")
	_add_character_part(player, "Fringe", Vector3(0, 2.15, 0.43), Vector3(0.52, 0.22, 0.18), Color(0.025, 0.03, 0.05), "sphere")
	_add_character_part(player, "LeftEye", Vector3(-0.17, 1.99, 0.53), Vector3(0.10, 0.07, 0.045), Color(0.12, 0.78, 1.0), "sphere")
	_add_character_part(player, "RightEye", Vector3(0.17, 1.99, 0.53), Vector3(0.10, 0.07, 0.045), Color(0.12, 0.78, 1.0), "sphere")
	_add_character_part(player, "RedScarf", Vector3(0, 1.48, -0.12), Vector3(0.78, 0.25, 0.55), Color(0.86, 0.035, 0.08), "box")
	_add_character_part(player, "ScarfTail", Vector3(0.28, 1.35, -0.55), Vector3(0.22, 0.78, 0.12), Color(0.9, 0.025, 0.07), "box")
	_add_character_part(player, "CoatFront", Vector3(0, 0.95, 0.34), Vector3(0.78, 0.82, 0.16), Color(0.045, 0.055, 0.08), "box")
	_add_character_part(player, "LeftArm", Vector3(-0.57, 1.05, 0.02), Vector3(0.22, 0.72, 0.24), Color(0.06, 0.07, 0.1), "box")
	_add_character_part(player, "RightArm", Vector3(0.57, 1.05, 0.02), Vector3(0.22, 0.72, 0.24), Color(0.06, 0.07, 0.1), "box")
	_add_character_part(player, "LeftBoot", Vector3(-0.24, 0.16, 0.12), Vector3(0.34, 0.25, 0.48), Color(0.025, 0.03, 0.05), "box")
	_add_character_part(player, "RightBoot", Vector3(0.24, 0.16, 0.12), Vector3(0.34, 0.25, 0.48), Color(0.025, 0.03, 0.05), "box")
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
	_build_move_pad(layer)
	_add_button(layer, "JUMP", Vector2(-245, -160), "jump")
	_add_button(layer, "TRAIN", Vector2(-245, -105), "train")
	_add_button(layer, "ATTACK", Vector2(-245, -50), "attack")
	_add_button(layer, "SAVE", Vector2(-245, -215), "save")
	_add_button(layer, "LOAD", Vector2(-245, -270), "load")
	_refresh_hud()

func _build_move_pad(layer: CanvasLayer) -> void:
	# A compact D-pad on the lower-left, positioned with anchors so it stays on screen.
	_add_button(layer, "▲", Vector2(92, -174), "forward", false)
	_add_button(layer, "▼", Vector2(92, -62), "back", false)
	_add_button(layer, "◀", Vector2(36, -118), "left", false)
	_add_button(layer, "▶", Vector2(148, -118), "right", false)

func _add_button(layer: CanvasLayer, text_value: String, offset: Vector2, action: String, right_side: bool = true) -> void:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(76, 48)
	var use_right_side := right_side
	b.anchor_left = 1.0 if use_right_side else 0.0
	b.anchor_right = 1.0 if use_right_side else 0.0
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
	elif action == "save":
		b.pressed.connect(_save_progress)
	elif action == "load":
		b.pressed.connect(_load_progress)
	else:
		b.pressed.connect(_attack)

func _process(delta: float) -> void:
	if is_instance_valid(player):
		_update_player_animation(delta)
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

func _update_player_animation(delta: float) -> void:
	if not is_instance_valid(body_mesh) or not is_instance_valid(player):
		return
	animation_time += delta
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.25
	if not player.is_on_floor():
		body_mesh.position.y = 0.9 + sin(animation_time * 9.0) * 0.035
		body_mesh.rotation.x = -0.12
	elif moving:
		body_mesh.position.y = 0.9 + absf(sin(animation_time * 10.0)) * 0.16
		body_mesh.rotation.x = sin(animation_time * 10.0) * 0.08
		body_mesh.rotation.z = sin(animation_time * 5.0) * 0.06
	else:
		body_mesh.position.y = 0.9 + sin(animation_time * 2.2) * 0.025
		body_mesh.rotation.x = lerpf(body_mesh.rotation.x, 0.0, minf(delta * 8.0, 1.0))
		body_mesh.rotation.z = lerpf(body_mesh.rotation.z, 0.0, minf(delta * 8.0, 1.0))

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

func _save_progress() -> void:
	var data := {
		"level": level,
		"xp": xp,
		"power": power,
		"hp": hp,
		"player_x": player.position.x if is_instance_valid(player) else 0.0,
		"player_y": player.position.y if is_instance_valid(player) else 1.5,
		"player_z": player.position.z if is_instance_valid(player) else 5.0
	}
	if BlockVerseSave.save_game(data):
		status_label.text = "Progress saved on this device!"

func _load_progress() -> void:
	var data := BlockVerseSave.load_game()
	if data.is_empty():
		if is_instance_valid(status_label):
			status_label.text = "New adventure! Train and fight to grow."
		return
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	power = maxi(0, int(data.get("power", 0)))
	hp = clampi(int(data.get("hp", 100)), 1, 100)
	if is_instance_valid(player):
		player.position = Vector3(
			float(data.get("player_x", 0.0)),
			float(data.get("player_y", 1.5)),
			float(data.get("player_z", 5.0))
		)
	if is_instance_valid(status_label):
		status_label.text = "Progress loaded!"
	_refresh_hud()

func _refresh_hud() -> void:
	if is_instance_valid(hud):
		hud.text = "BLOCK VERSE   |   LVL %d   |   XP %d/%d   |   POWER %d   |   HP %d" % [level, xp, level * 10, power, hp]
