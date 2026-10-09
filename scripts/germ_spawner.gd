## GermSpawner — spawns germs at intervals, increasing frequency over time
extends Node3D

const GERM_SCENE_PATH = "res://scenes/Germ.tscn"

@export var spawn_container: Node3D
@export var body_center: Vector3 = Vector3(0, 0, 0)
@export var camera: Camera3D

var _germ_scene: PackedScene
var _spawn_timer: float = 0.0
var _active := false

# Body bounding box in world space (approximate from Sprite3D: 1024x2048 * 0.004)
const BODY_X_MIN := -2.0
const BODY_X_MAX := 2.0
const BODY_Y_MIN := -1.0  # body position.y=1.0 minus half height ~2.0
const BODY_Y_MAX := 5.1   # body position.y=1.0 plus half height ~4.1
const MIN_SCREEN_DISTANCE := 300.0  # minimum pixels from body edge

# Organ positions (relative to body center) — will be set from Arena
var organ_positions := {
	"brain":     Vector3(0, 3.4, 0),
	"heart":     Vector3(-0.2, 1.8, 0),
	"lungs":     Vector3(0, 2.0, 0),
	"liver":     Vector3(-0.35, 1.2, 0),
	"stomach":   Vector3(0.15, 1.0, 0),
	"intestine": Vector3(0, 0.3, 0),
	"kidney":    Vector3(0.4, 1.0, 0),
}

# Spawn points around the body (outside the body silhouette)
var _spawn_positions: Array[Vector3] = []


func _ready() -> void:
	_germ_scene = load(GERM_SCENE_PATH)
	# Generate spawn positions around the body
	_generate_spawn_positions()
	GameManager.game_state_changed.connect(_on_state_changed)


func _generate_spawn_positions() -> void:
	# Spawn from LEFT, RIGHT, and TOP edges of the screen only
	# Not from directly above/below the body (too close to organs)

	# LEFT side spawn points (x = -6 to -5, spread vertically)
	for i in range(5):
		var y = lerpf(-0.5, 4.0, float(i) / 4.0)
		_spawn_positions.append(Vector3(randf_range(-6.5, -5.5), y, 0))

	# RIGHT side spawn points (x = 5 to 6, spread vertically)
	for i in range(5):
		var y = lerpf(-0.5, 4.0, float(i) / 4.0)
		_spawn_positions.append(Vector3(randf_range(5.5, 6.5), y, 0))

	# TOP spawn points (above the body, y > 4.5, spread horizontally)
	for i in range(4):
		var x = lerpf(-4.0, 4.0, float(i) / 3.0)
		_spawn_positions.append(Vector3(x, randf_range(5.0, 6.0), 0))


func _process(delta: float) -> void:
	if not _active:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_germ()
		# Interval decreases as time goes on
		var progress = 1.0 - (GameManager.time_left / GameData.ROUND_TIME)
		var interval = lerpf(GameData.SPAWN_INTERVAL_START, GameData.SPAWN_INTERVAL_END, progress)
		_spawn_timer = interval


func _is_too_close_to_body(world_pos: Vector3) -> bool:
	## Check if a world position is within MIN_SCREEN_DISTANCE pixels of the body
	if not camera:
		# Fallback: world-space check (~1.5 units ≈ 300px)
		var closest_x = clampf(world_pos.x, BODY_X_MIN, BODY_X_MAX)
		var closest_y = clampf(world_pos.y, BODY_Y_MIN, BODY_Y_MAX)
		var dist = Vector2(world_pos.x - closest_x, world_pos.y - closest_y).length()
		return dist < 1.5

	# Screen-space check: project spawn pos and body edges, measure distance
	var screen_pos = camera.unproject_position(world_pos)
	# Project the 4 corners of the body bounding box
	var body_corners := [
		camera.unproject_position(Vector3(BODY_X_MIN, BODY_Y_MIN, 0)),
		camera.unproject_position(Vector3(BODY_X_MAX, BODY_Y_MIN, 0)),
		camera.unproject_position(Vector3(BODY_X_MIN, BODY_Y_MAX, 0)),
		camera.unproject_position(Vector3(BODY_X_MAX, BODY_Y_MAX, 0)),
	]
	# Find screen-space bounding rect of the body
	var body_screen_min: Vector2 = body_corners[0]
	var body_screen_max: Vector2 = body_corners[0]
	for corner in body_corners:
		body_screen_min.x = minf(body_screen_min.x, corner.x)
		body_screen_min.y = minf(body_screen_min.y, corner.y)
		body_screen_max.x = maxf(body_screen_max.x, corner.x)
		body_screen_max.y = maxf(body_screen_max.y, corner.y)

	# Distance from point to rect
	var closest := Vector2(
		clampf(screen_pos.x, body_screen_min.x, body_screen_max.x),
		clampf(screen_pos.y, body_screen_min.y, body_screen_max.y)
	)
	return screen_pos.distance_to(closest) < MIN_SCREEN_DISTANCE


func _get_valid_spawn_pos() -> Vector3:
	## Pick a random spawn position that is at least 300px from the body
	for _attempt in range(20):
		var pos = _spawn_positions[randi() % _spawn_positions.size()]
		# Add slight randomness to each pick
		pos += Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), 0)
		if not _is_too_close_to_body(pos):
			return pos
	# Fallback: use far edges
	var side = [-7.0, 7.0][randi() % 2]
	return Vector3(side, randf_range(0.0, 3.5), 0)


func _spawn_germ() -> void:
	if not _germ_scene or not spawn_container:
		return

	var germ = _germ_scene.instantiate()

	var germ_type = _pick_germ_type()
	germ.germ_type = germ_type

	var organ_keys = organ_positions.keys()
	var target_organ = organ_keys[randi() % organ_keys.size()]
	germ.target_organ = target_organ

	var time_progress = 1.0 - (GameManager.time_left / GameData.ROUND_TIME)
	germ.speed_multiplier = 1.0 + (time_progress * 0.5)

	# Get a valid spawn position (>300px from body)
	var spawn_pos = _get_valid_spawn_pos()
	var organ_pos = body_center + organ_positions[target_organ]

	# Midpoint for curved path — also ensure it's not too close to body
	var mid = (spawn_pos + organ_pos) * 0.5
	mid += Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), 0)

	var path_points = PackedVector3Array([spawn_pos, mid, organ_pos])

	spawn_container.add_child(germ)
	germ.setup_path(path_points)


func _pick_germ_type() -> GameData.GermType:
	var roll = randf()
	if roll < 0.05:
		return GameData.GermType.SUPERBUG
	elif roll < 0.25:
		return GameData.GermType.PARASITE
	elif roll < 0.45:
		return GameData.GermType.FUNGUS
	elif roll < 0.70:
		return GameData.GermType.VIRUS
	else:
		return GameData.GermType.BACTERIA


func _on_state_changed(new_state: GameManager.GameState) -> void:
	_active = (new_state == GameManager.GameState.PLAYING or
			   new_state == GameManager.GameState.SUDDEN_DEATH)
	if _active:
		_spawn_timer = 0.5  # Start spawning quickly
	elif new_state == GameManager.GameState.RESULTS or new_state == GameManager.GameState.ATTRACT:
		_clear_all_germs()


func _clear_all_germs() -> void:
	if not spawn_container:
		return
	for child in spawn_container.get_children():
		child.queue_free()
