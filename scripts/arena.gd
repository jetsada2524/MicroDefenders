## Arena — the main gameplay area with x-ray body sprite, organs, and spawn points
extends Node3D

@onready var body_sprite: Sprite3D = $BodySprite
@onready var germ_container: Node3D = $GermContainer
@onready var organ_markers: Node3D = $OrganMarkers

# Organ visual nodes
var _organ_meshes := {}


func _ready() -> void:
    _setup_body_sprite()
    _setup_organs()
    GameManager.germ_reached_organ.connect(_on_germ_reached_organ)
    GameManager.game_state_changed.connect(_on_game_state_changed)
    # Start hidden — only show during gameplay states
    if body_sprite:
        body_sprite.visible = false


func _setup_body_sprite() -> void:
    # Combined room+body background as 3D backdrop (behind germs, in front of nothing)
    # Camera is at (0, 1.2, 8) with FOV 50°. At z=-0.5 (distance 8.5 from camera):
    #   visible height ≈ 7.93 units, width ≈ 14.1 units (16:9)
    # bg_gameplay_full.jpeg is 1310x816px, pixel_size=0.011 → 14.4 x 8.98 units (fills screen)
    var tex = load("res://assets/textures/bg_gameplay_full.jpeg")
    if tex and body_sprite:
        body_sprite.texture = tex
        body_sprite.pixel_size = 0.011
        body_sprite.position = Vector3(0, 1.2, -0.5)  # Center on camera view, behind germs
        body_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        body_sprite.transparent = false
        body_sprite.render_priority = -1
        body_sprite.modulate = Color(1, 1, 1, 1)


func _setup_organs() -> void:
    # Organ positions matched to the body_xray.png proportions
    var organs := {
        "brain":     {"pos": Vector3(0, 3.4, 0.05), "size": 0.25, "color": Color(1.0, 0.8, 0.9, 0.0)},
        "heart":     {"pos": Vector3(-0.2, 1.8, 0.05), "size": 0.2, "color": Color(0.9, 0.2, 0.2, 0.0)},
        "lungs":     {"pos": Vector3(0, 2.0, 0.05), "size": 0.4, "color": Color(0.5, 0.8, 0.9, 0.0)},
        "liver":     {"pos": Vector3(-0.35, 1.2, 0.05), "size": 0.22, "color": Color(0.6, 0.3, 0.2, 0.0)},
        "stomach":   {"pos": Vector3(0.15, 1.0, 0.05), "size": 0.2, "color": Color(0.9, 0.7, 0.4, 0.0)},
        "intestine": {"pos": Vector3(0, 0.3, 0.05), "size": 0.35, "color": Color(0.9, 0.6, 0.5, 0.0)},
        "kidney":    {"pos": Vector3(0.4, 1.0, 0.05), "size": 0.15, "color": Color(0.7, 0.3, 0.3, 0.0)},
    }

    for organ_name in organs:
        var data = organs[organ_name]
        # Invisible collision area for organ (germs target these positions)
        var mesh_inst = MeshInstance3D.new()
        mesh_inst.name = organ_name

        var sphere = SphereMesh.new()
        sphere.radius = data.size
        sphere.height = data.size * 2
        mesh_inst.mesh = sphere

        # Start invisible — only flash on hit
        var mat = StandardMaterial3D.new()
        mat.albedo_color = data.color
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.emission_enabled = true
        mat.emission = Color(data.color.r, data.color.g, data.color.b)
        mat.emission_energy_multiplier = 0.0
        mat.no_depth_test = true
        mesh_inst.material_override = mat

        mesh_inst.position = data.pos
        organ_markers.add_child(mesh_inst)
        _organ_meshes[organ_name] = mesh_inst


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
    # Show 3D background only during gameplay/countdown states
    var show_bg = (new_state == GameManager.GameState.COUNTDOWN or
                   new_state == GameManager.GameState.PLAYING or
                   new_state == GameManager.GameState.SUDDEN_DEATH)
    if body_sprite:
        body_sprite.visible = show_bg


func _on_germ_reached_organ(organ_name: String) -> void:
    if organ_name in _organ_meshes:
        var mesh = _organ_meshes[organ_name]
        var mat = mesh.material_override
        if mat:
            # Flash red when infected
            var tween = create_tween()
            tween.tween_property(mat, "albedo_color", Color(1, 0.1, 0.1, 0.5), 0.1)
            tween.tween_property(mat, "emission_energy_multiplier", 2.0, 0.1)
            tween.tween_property(mat, "albedo_color", Color(1, 0.1, 0.1, 0.0), 0.6)
            tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.6)
