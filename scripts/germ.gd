## Germ — a single germ entity that follows a path toward an organ
extends Node3D

signal hit(player_id: int)
signal reached_organ(organ_name: String)

@export var germ_type: GameData.GermType = GameData.GermType.BACTERIA
@export var target_organ: String = "heart"
@export var speed_multiplier: float = 1.0

var alive := true
var _progress: float = 0.0
var _path_points: PackedVector3Array
var _path_length: float = 0.0
var _speed: float = 1.0
var _current_distance: float = 0.0
var _use_3d_model := false
var _anim_player: AnimationPlayer = null
var _model_node: Node3D = null

@onready var sprite: Sprite3D = $Sprite3D
@onready var area: Area3D = $Area3D

# Texture paths per germ type
const GERM_TEXTURES := {
	GameData.GermType.BACTERIA: "res://assets/textures/germ_bacteria.png",
	GameData.GermType.VIRUS:    "res://assets/textures/germ_virus.png",
	GameData.GermType.FUNGUS:   "res://assets/textures/germ_fungus.png",
	GameData.GermType.PARASITE: "res://assets/textures/germ_parasite.png",
	GameData.GermType.SUPERBUG: "res://assets/textures/germ_superbug.png",
}

# 3D rigged model paths (disabled — using sprite fallback)
const GERM_3D_MODELS := {}


func _ready() -> void:
	_speed = GameData.GERM_SPEED[germ_type] * speed_multiplier
	var scale_val = GameData.GERM_SCALE[germ_type]
	scale = Vector3(scale_val, scale_val, scale_val)
	_setup_appearance()
	area.collision_layer = 1
	area.collision_mask = 0


func setup_path(points: PackedVector3Array) -> void:
	_path_points = points
	_path_length = 0.0
	for i in range(points.size() - 1):
		_path_length += points[i].distance_to(points[i + 1])
	if points.size() > 0:
		global_position = points[0]
	# Orient 3D model: face camera, tilt 45° toward body, eyes toward body
	if _use_3d_model and _model_node and points.size() >= 2:
		# Face the camera (+Z direction) — rotate 180° around Y
		_model_node.rotation.y = PI
		# Tilt 45° forward: lean head toward direction of travel (Z-axis rotation)
		if points[0].x > 0:
			# Coming from right, moving left toward body
			_model_node.rotation.z = PI / 4.0
		else:
			# Coming from left, moving right toward body
			_model_node.rotation.z = -PI / 4.0
	elif sprite and points.size() >= 2:
		# Flip so the germ's face looks toward the body
		if germ_type == GameData.GermType.SUPERBUG:
			sprite.flip_h = (points[0].x < 0)
		else:
			sprite.flip_h = (points[0].x > 0)
		# Set initial rotation to point head toward travel direction
		var init_dir = (points[1] - points[0]).normalized()
		var dir_angle = atan2(init_dir.x, init_dir.y)
		sprite.rotation.z = dir_angle if sprite.flip_h else -dir_angle


## Shrink target when despawning. Never tween to exactly zero: a zero scale makes the
## transform non-invertible and Godot logs "Basis invert: det == 0" every frame.
const DESPAWN_SCALE := Vector3(0.001, 0.001, 0.001)


func _process(delta: float) -> void:
	if not alive or _path_points.size() < 2:
		return

	# Speed increases as germ gets closer to organ
	var proximity_boost = 1.0 + (_progress * 0.5)
	_current_distance += _speed * proximity_boost * delta
	_progress = clampf(_current_distance / _path_length, 0.0, 1.0)

	# Interpolate position along path
	var target_dist = _progress * _path_length
	var accumulated := 0.0
	var current_dir := Vector3.ZERO
	for i in range(_path_points.size() - 1):
		var seg_len = _path_points[i].distance_to(_path_points[i + 1])
		if accumulated + seg_len >= target_dist:
			var t = (target_dist - accumulated) / seg_len if seg_len > 0 else 0.0
			global_position = _path_points[i].lerp(_path_points[i + 1], t)
			current_dir = (_path_points[i + 1] - _path_points[i]).normalized()
			break
		accumulated += seg_len

	# Rotate sprite to face travel direction + wobble (Sprite3D germs only)
	if not _use_3d_model and sprite:
		var time_ms = Time.get_ticks_msec() * 0.001
		var id_offset = float(get_instance_id() % 1000) * 0.1
		# Point head toward travel direction
		if current_dir.length_squared() > 0.001:
			var dir_angle = atan2(current_dir.x, current_dir.y)
			sprite.rotation.z = dir_angle if sprite.flip_h else -dir_angle
		# Add small wobble on top
		sprite.rotation.z += sin(time_ms * 3.0 + id_offset) * 0.1
		# Bob up/down
		var bob = sin(time_ms * 5.0 + id_offset) * 0.05
		position.y += bob * delta * 10.0

	# Reached organ
	if _progress >= 1.0:
		_on_reached_organ()


func try_hit(player_id: int, medicine_type: GameData.MedicineType) -> bool:
	if not alive:
		return false
	var required_med = GameData.germ_to_medicine(germ_type)
	if medicine_type == required_med:
		alive = false
		hit.emit(player_id)
		_play_death_effect()
		return true
	else:
		_play_resist_effect()
		return false


func _on_reached_organ() -> void:
	alive = false
	reached_organ.emit(target_organ)
	GameManager.on_germ_reached(target_organ)
	SoundManager.play_sfx("germ_reach")
	var tween = create_tween()
	tween.tween_property(self, "scale", DESPAWN_SCALE, 0.3)
	tween.tween_callback(queue_free)


func _play_death_effect() -> void:
	if _use_3d_model and _anim_player:
		# Play the Death animation from the rigged model
		var death_name := _find_anim_name("Death")
		if death_name != "":
			_anim_player.play(death_name)
			_anim_player.animation_finished.connect(func(_anim): queue_free())
			# Score popup (2D label floating up)
			_spawn_score_popup()
			return
	# Fallback: Pop + flash white (for Sprite3D germs)
	if sprite:
		sprite.modulate = Color(2, 2, 2, 1)
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.5, 0.1)
	tween.tween_property(self, "scale", DESPAWN_SCALE, 0.15)
	tween.tween_callback(queue_free)
	_spawn_score_popup()


func _play_resist_effect() -> void:
	if _use_3d_model and _anim_player:
		# Play the Hurt animation then resume swimming
		var hurt_name := _find_anim_name("Hurt")
		if hurt_name != "":
			_anim_player.play(hurt_name)
			_anim_player.animation_finished.connect(func(_anim):
				var swim_name := _find_anim_name("Swim")
				if swim_name != "":
					_anim_player.play(swim_name)
			, CONNECT_ONE_SHOT)
		# Shake
		var tween = create_tween()
		var orig_pos = position
		tween.tween_property(self, "position", orig_pos + Vector3(0.1, 0, 0), 0.04)
		tween.tween_property(self, "position", orig_pos - Vector3(0.1, 0, 0), 0.04)
		tween.tween_property(self, "position", orig_pos, 0.04)
		return
	# Fallback: Shake + flash red tint (for Sprite3D germs)
	if sprite:
		var orig_mod = sprite.modulate
		sprite.modulate = Color(1.5, 0.5, 0.5, 1)
		var tween = create_tween()
		var orig_pos = position
		tween.tween_property(self, "position", orig_pos + Vector3(0.1, 0, 0), 0.04)
		tween.tween_property(self, "position", orig_pos - Vector3(0.1, 0, 0), 0.04)
		tween.tween_property(self, "position", orig_pos, 0.04)
		tween.tween_callback(func(): sprite.modulate = orig_mod)


func _spawn_score_popup() -> void:
	## Create a floating score label at the germ's screen position
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var screen_pos = camera.unproject_position(global_position)
	var points = GameData.GERM_POINTS.get(germ_type, 10)
	# Create a Label in the HUD layer
	var label = Label.new()
	label.text = "+" + str(points)
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1, 1, 0, 1))  # Yellow
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.position = screen_pos - Vector2(30, 20)
	label.z_index = 50
	# Add to root viewport so it overlays everything
	get_tree().root.add_child(label)
	# Animate: float up + fade out
	var tween = get_tree().create_tween()
	tween.tween_property(label, "position:y", label.position.y - 80, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)


func _setup_appearance() -> void:
	# Check if this germ type has a 3D rigged model
	var model_path = GERM_3D_MODELS.get(germ_type, "")
	if model_path != "" and ResourceLoader.exists(model_path):
		_use_3d_model = true
		# Hide the Sprite3D fallback
		if sprite:
			sprite.visible = false
		# Instantiate the 3D model
		var model_scene = load(model_path)
		if model_scene:
			_model_node = model_scene.instantiate()
			_model_node.name = "Model3D"
			add_child(_model_node)
			# Brighten the model materials (glb imports dark without scene lights)
			_brighten_model(_model_node)
			# Find AnimationPlayer in the instantiated model
			_anim_player = _find_animation_player(_model_node)
			if _anim_player:
				# Play swim animation loop
				var swim_name := _find_anim_name("Swim")
				if swim_name != "":
					_anim_player.play(swim_name)
		return

	# Fallback: use Sprite3D with texture
	if not sprite:
		return
	var tex_path = GERM_TEXTURES.get(germ_type, "")
	if tex_path != "":
		var tex = load(tex_path)
		if tex:
			sprite.texture = tex
			sprite.pixel_size = 0.003  # Adjust so 512px sprite ~ 1.5 units
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.transparent = true
			sprite.no_depth_test = false
			sprite.render_priority = 1


func _brighten_model(node: Node) -> void:
	## Make 3D model fully unshaded and boost albedo brightness
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in range(mesh_inst.get_surface_override_material_count()):
			var mat = mesh_inst.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var bright_mat = mat.duplicate() as StandardMaterial3D
				bright_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				# Boost albedo color brightness
				var c = bright_mat.albedo_color
				bright_mat.albedo_color = Color(
					minf(c.r * 1.8, 1.0),
					minf(c.g * 1.8, 1.0),
					minf(c.b * 1.8, 1.0),
					c.a
				)
				mesh_inst.set_surface_override_material(i, bright_mat)
	for child in node.get_children():
		_brighten_model(child)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null


func _find_anim_name(keyword: String) -> String:
	## Find animation name containing keyword (case-insensitive)
	if not _anim_player:
		return ""
	for anim_name in _anim_player.get_animation_list():
		if keyword.to_lower() in anim_name.to_lower():
			return anim_name
	return ""
