## Main — root scene orchestrating game flow
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var arena: Node3D = $Arena
@onready var germ_container: Node3D = $Arena/GermContainer
@onready var germ_spawner: Node3D = $Arena/GermSpawner
@onready var hud: CanvasLayer = $HUD
@onready var crosshair_layer: CanvasLayer = $CrosshairLayer
@onready var p1_crosshair: Node2D = $CrosshairLayer/P1Crosshair
@onready var p2_crosshair: Node2D = $CrosshairLayer/P2Crosshair
@onready var shoot_manager: Node = $ShootManager



func _ready() -> void:
    shoot_manager.camera = camera
    shoot_manager.germ_container = germ_container
    germ_spawner.spawn_container = germ_container
    germ_spawner.camera = camera

    p1_crosshair.shot_fired.connect(_on_shot_fired)
    p2_crosshair.shot_fired.connect(_on_shot_fired)
    p1_crosshair.ui_shot_fired.connect(_on_ui_shot_fired)
    p2_crosshair.ui_shot_fired.connect(_on_ui_shot_fired)

    GameManager.game_state_changed.connect(_on_state_changed)


func _input(event: InputEvent) -> void:
    # Any input resets idle timer
    if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
        GameManager.reset_idle()

    # Results state — restart only via the restart button (handled by ui_shot)


func _on_shot_fired(player_id: int, aim_pos: Vector2) -> void:
    # Check if shot hits a medicine bottle — let HUD handle hit detection
    if hud.try_select_medicine_at(player_id, aim_pos):
        return

    # Otherwise, shoot at germs
    shoot_manager.shoot(player_id, aim_pos)


func _on_ui_shot_fired(_player_id: int, aim_pos: Vector2) -> void:
    # Forward UI shots to HUD for button hit detection
    hud.handle_ui_shot(aim_pos)


func _on_state_changed(new_state: GameManager.GameState) -> void:
    # Crosshairs always visible
    crosshair_layer.visible = true

    if new_state == GameManager.GameState.PLAYING:
        for child in germ_container.get_children():
            child.queue_free()
    elif new_state == GameManager.GameState.ATTRACT:
        for child in germ_container.get_children():
            child.queue_free()
