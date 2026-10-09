## ShootManager — handles raycasting from screen to 3D world for shooting
extends Node

@export var camera: Camera3D
@export var germ_container: Node3D

var _ray_length := 100.0


func shoot(player_id: int, screen_pos: Vector2) -> void:
	if not camera or not germ_container:
		return

	# Raycast from camera through screen position
	var from = camera.project_ray_origin(screen_pos)
	var _to = from + camera.project_ray_normal(screen_pos) * _ray_length

	# Check all germs — find closest hit
	var closest_germ: Node3D = null
	var closest_dist: float = INF
	var medicine = GameManager.get_medicine(player_id)

	for child in germ_container.get_children():
		if child is Node3D and child.has_method("try_hit"):
			if not child.alive:
				continue
			# Simple sphere collision check (approximation)
			var germ_pos = child.global_position
			var germ_screen = camera.unproject_position(germ_pos)
			var dist = screen_pos.distance_to(germ_screen)
			var hit_radius = 40.0 * child.scale.x / 0.4  # Scale hit area with germ size

			if dist < hit_radius and dist < closest_dist:
				closest_dist = dist
				closest_germ = child

	if closest_germ:
		var success = GameManager.on_germ_hit(player_id, closest_germ.germ_type)
		if success:
			closest_germ.try_hit(player_id, medicine)
			SoundManager.play_sfx("hit_correct")
		else:
			closest_germ._play_resist_effect()
			SoundManager.play_sfx("hit_wrong")
	else:
		# Check if clicking on medicine bottles (handled by HUD)
		pass


func check_medicine_click(_player_id: int, _screen_pos: Vector2) -> bool:
	## Check if clicking on a medicine bottle in HUD. Returns true if handled.
	# This is handled by the HUD's _gui_input, not 3D raycast
	return false
