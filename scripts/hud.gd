## HUD — displays all UI elements for the gameplay screen
extends CanvasLayer

# Node references
@onready var p1_name_label: Label = $P1Panel/P1Name
@onready var p1_score_label: Label = $P1Panel/P1Score
@onready var p2_name_label: Label = $P2Panel/P2Name
@onready var p2_score_label: Label = $P2Panel/P2Score
@onready var timer_label: Label = $TimerPanel/TimerLabel
@onready var p1_medicine_icon: TextureRect = $P1MedicinePanel/MedicineIcon
@onready var p2_medicine_icon: TextureRect = $P2MedicinePanel/MedicineIcon
@onready var p1_medicine_ring: Panel = $P1MedicinePanel
@onready var p2_medicine_ring: Panel = $P2MedicinePanel
@onready var medicine_stock: Control = $MedicineStockPanel/StockContainer
@onready var p1_knowledge_box: Panel = $P1KnowledgePanel
@onready var p1_knowledge_label: Label = $P1KnowledgePanel/KnowledgeText
@onready var p2_knowledge_box: Panel = $P2KnowledgePanel
@onready var p2_knowledge_label: Label = $P2KnowledgePanel/KnowledgeText
@onready var p1_combo_label: Label = $P1Panel/P1Combo
@onready var p2_combo_label: Label = $P2Panel/P2Combo
@onready var p1_panel: Panel = $P1Panel
@onready var p2_panel: Panel = $P2Panel
@onready var timer_panel: Panel = $TimerPanel
@onready var p1_med_panel: Panel = $P1MedicinePanel
@onready var p2_med_panel: Panel = $P2MedicinePanel
@onready var med_stock_panel: Panel = $MedicineStockPanel
@onready var gameplay_bg: TextureRect = $GameplayBg

# Overlays
@onready var attract_panel: Control = $AttractPanel
@onready var start_button: TextureButton = $AttractPanel/StartButton
@onready var how_to_play_panel: Control = $HowToPlayPanel
@onready var play_button: TextureButton = $HowToPlayPanel/PlayButton
@onready var results_overlay: ColorRect = $ResultsOverlay
@onready var countdown_label: Label = $CountdownLabel

# Results sub-nodes
@onready var result_title: Label = $ResultsOverlay/ResultsPopup/ResultTitle
@onready var p1_score_result: Label = $ResultsOverlay/ResultsPopup/P1ResultArea/P1ScoreResult
@onready var p2_score_result: Label = $ResultsOverlay/ResultsPopup/P2ResultArea/P2ScoreResult
@onready var p1_crown: Label = $ResultsOverlay/ResultsPopup/P1ResultArea/P1Crown
@onready var p2_crown: Label = $ResultsOverlay/ResultsPopup/P2ResultArea/P2Crown
@onready var p1_stars: Label = $ResultsOverlay/ResultsPopup/P1ResultArea/P1Stars
@onready var p2_stars: Label = $ResultsOverlay/ResultsPopup/P2ResultArea/P2Stars
@onready var p1_name_result: Label = $ResultsOverlay/ResultsPopup/P1ResultArea/P1NameResult
@onready var p2_name_result: Label = $ResultsOverlay/ResultsPopup/P2ResultArea/P2NameResult
@onready var winner_label: Label = $ResultsOverlay/ResultsPopup/WinnerLabel
@onready var restart_button: Button = $ResultsOverlay/ResultsPopup/RestartButton
@onready var vs_label: Label = $ResultsOverlay/ResultsPopup/VsLabel

var _timer_flash := false
var _flash_timer := 0.0
var _attract_blink_timer := 0.0
var _restart_blink_timer := 0.0

# Medicine bottle buttons
var _medicine_buttons: Array[Button] = []

# Sound settings buttons (created in code)
var _bgm_toggle: Button
var _sfx_toggle: Button



func _ready() -> void:
    GameManager.score_changed.connect(_on_score_changed)
    GameManager.medicine_changed.connect(_on_medicine_changed)
    GameManager.timer_updated.connect(_on_timer_updated)
    GameManager.game_state_changed.connect(_on_state_changed)
    GameManager.game_over.connect(_on_game_over)
    GameManager.germ_killed.connect(_on_germ_killed)

    _setup_medicine_stock()
    _update_medicine_display(0)
    _update_medicine_display(1)
    start_button.pressed.connect(_on_start_button_pressed)
    play_button.pressed.connect(_on_play_button_pressed)
    _setup_sound_settings()
    _setup_controls_guide()
    _show_attract()
    # Play attract BGM on initial launch (state is already ATTRACT, no signal fires)
    SoundManager.play_bgm("attract")


func _process(delta: float) -> void:
    if _timer_flash:
        _flash_timer += delta
        timer_label.modulate.a = 0.5 + 0.5 * sin(_flash_timer * 8.0)

    # Attract mode — pulse start button
    if GameManager.current_state == GameManager.GameState.ATTRACT:
        _attract_blink_timer += delta
        if start_button:
            var pulse = 0.9 + 0.1 * sin(_attract_blink_timer * 3.0)
            start_button.scale = Vector2(pulse, pulse)
            start_button.pivot_offset = start_button.size / 2

    # Keep medicine bottles on their pedestals
    if med_stock_panel.visible:
        _layout_bottles_on_pedestals()

    # Results restart blink
    if GameManager.current_state == GameManager.GameState.RESULTS and restart_button.visible:
        _restart_blink_timer += delta
        restart_button.modulate.a = 0.5 + 0.5 * abs(sin(_restart_blink_timer * 2.0))


## Bottle texture paths
const BOTTLE_TEXTURES := {
    GameData.MedicineType.ANTIBIOTIC:    "res://assets/textures/bottle_antibiotic.png",
    GameData.MedicineType.VACCINE:       "res://assets/textures/bottle_vaccine.png",
    GameData.MedicineType.ANTIFUNGAL:    "res://assets/textures/bottle_antifungal.png",
    GameData.MedicineType.ANTIPARASITIC: "res://assets/textures/bottle_antiparasitic.png",
    GameData.MedicineType.SPECIFIC:      "res://assets/textures/bottle_specific.png",
}

# Bottles are pinned to the pedestals painted in the 3D gameplay background
# (bg_gameplay_full.jpeg, shown on Arena/BodySprite). Positions are in that image's
# pixel space and projected through the 3D camera every frame, so the bottles stay
# on their pedestals regardless of window size, aspect ratio, or stretch scale.
const BOTTLE_BG_SIZE := Vector2(78, 72)   # bottle box size, in background-image pixels
const BOTTLE_BG_CENTERS := {             # bottle box centers, in background-image pixels
    GameData.MedicineType.ANTIBIOTIC:    Vector2(393.8, 632.0),
    GameData.MedicineType.VACCINE:       Vector2(516.9, 648.2),
    GameData.MedicineType.ANTIFUNGAL:    Vector2(656.8, 654.2),
    GameData.MedicineType.ANTIPARASITIC: Vector2(796.1, 648.2),
    GameData.MedicineType.SPECIFIC:      Vector2(921.0, 632.0),
}
# Fallbacks matching arena.gd, used if Arena/BodySprite can't be found
const BG_FALLBACK_CENTER := Vector3(0, 1.2, -0.5)
const BG_FALLBACK_PIXEL_SIZE := 0.011
const BG_FALLBACK_TEX_SIZE := Vector2(1310, 816)

func _setup_medicine_stock() -> void:
    for med_type in GameData.MedicineType.values():
        var btn = Button.new()
        btn.text = ""
        # Transparent button — no box, no border
        var empty_style = StyleBoxEmpty.new()
        btn.add_theme_stylebox_override("normal", empty_style)
        btn.add_theme_stylebox_override("hover", empty_style)
        btn.add_theme_stylebox_override("pressed", empty_style)
        btn.add_theme_stylebox_override("focus", empty_style)
        btn.tooltip_text = GameData.MEDICINE_NAMES[med_type]

        var med = med_type
        btn.pressed.connect(func(): _on_medicine_bottle_clicked(med))

        var tex_rect = TextureRect.new()
        var tex = load(BOTTLE_TEXTURES[med_type])
        if tex:
            tex_rect.texture = tex
        tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(tex_rect)

        medicine_stock.add_child(btn)
        _medicine_buttons.append(btn)


## Background-image pixel → 3D world position on the background sprite
func _bg_px_to_world(px: Vector2) -> Vector3:
    var sprite := get_node_or_null("../Arena/BodySprite") as Sprite3D
    if sprite and sprite.texture:
        var tex_size := sprite.texture.get_size()
        var ps := sprite.pixel_size
        var local := Vector3((px.x - tex_size.x * 0.5) * ps, -(px.y - tex_size.y * 0.5) * ps, 0.0)
        return sprite.global_transform * local
    var fallback := Vector3((px.x - BG_FALLBACK_TEX_SIZE.x * 0.5) * BG_FALLBACK_PIXEL_SIZE,
        -(px.y - BG_FALLBACK_TEX_SIZE.y * 0.5) * BG_FALLBACK_PIXEL_SIZE, 0.0)
    return BG_FALLBACK_CENTER + fallback


func _layout_bottles_on_pedestals() -> void:
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return
    var half := BOTTLE_BG_SIZE * 0.5
    for i in range(_medicine_buttons.size()):
        var center: Vector2 = BOTTLE_BG_CENTERS[i as GameData.MedicineType]
        var top_left := cam.unproject_position(_bg_px_to_world(center - half))
        var bottom_right := cam.unproject_position(_bg_px_to_world(center + half))
        var btn := _medicine_buttons[i]
        var new_size := bottom_right - top_left
        btn.custom_minimum_size = new_size
        btn.size = new_size
        btn.global_position = top_left


func _on_medicine_bottle_clicked(med_type: GameData.MedicineType) -> void:
    # Button click = mouse = P1
    select_medicine_for_player(0, med_type)


func try_select_medicine_at(player_id: int, aim_pos: Vector2) -> bool:
    ## Check if aim_pos hits any medicine bottle button; if so, select it for the player
    for i in range(_medicine_buttons.size()):
        var btn: Button = _medicine_buttons[i]
        if btn.get_global_rect().has_point(aim_pos):
            var med_type = i as GameData.MedicineType
            select_medicine_for_player(player_id, med_type)
            return true
    return false


func select_medicine_for_player(player_id: int, med_type: GameData.MedicineType) -> void:
    SoundManager.play_sfx("medicine_select")
    GameManager.set_medicine(player_id, med_type)
    _update_knowledge_panel(player_id, med_type)


func _on_score_changed(player: int, new_score: int) -> void:
    if player == 1:
        p1_score_label.text = str(new_score)
        _pulse_label(p1_score_label)
    else:
        p2_score_label.text = str(new_score)
        _pulse_label(p2_score_label)


func _on_medicine_changed(player: int, _med_type: GameData.MedicineType) -> void:
    _update_medicine_display(player - 1)


func _update_medicine_display(player_idx: int) -> void:
    var med = GameManager.equipped_medicine[player_idx]
    var tex = load(BOTTLE_TEXTURES[med])
    if player_idx == 0 and p1_medicine_icon:
        p1_medicine_icon.texture = tex
    elif player_idx == 1 and p2_medicine_icon:
        p2_medicine_icon.texture = tex


func _on_timer_updated(time_left: float) -> void:
    var total_seconds := int(time_left)
    @warning_ignore("integer_division")
    var minutes := total_seconds / 60
    var seconds := total_seconds % 60
    timer_label.text = "%02d:%02d" % [minutes, seconds]

    if time_left <= GameData.LAST_SECONDS_WARNING:
        if not _timer_flash:
            _timer_flash = true
            timer_label.add_theme_color_override("font_color", Color.RED)
    else:
        _timer_flash = false
        timer_label.modulate.a = 1.0
        timer_label.add_theme_color_override("font_color", Color.WHITE)


func _on_germ_killed(_player: int, _germ_type: GameData.GermType, _points: int) -> void:
    pass


func _on_state_changed(new_state: GameManager.GameState) -> void:
    attract_panel.visible = (new_state == GameManager.GameState.ATTRACT)
    how_to_play_panel.visible = false
    results_overlay.visible = (new_state == GameManager.GameState.RESULTS)
    countdown_label.visible = (new_state == GameManager.GameState.COUNTDOWN)

    if new_state == GameManager.GameState.COUNTDOWN:
        SoundManager.fade_bgm(0.3)
        _reset_gameplay_hud()
        _do_countdown()
    elif new_state == GameManager.GameState.PLAYING:
        SoundManager.play_bgm("gameplay")
    elif new_state == GameManager.GameState.SUDDEN_DEATH:
        timer_label.text = "SUDDEN DEATH!"
        _timer_flash = true
    elif new_state == GameManager.GameState.ATTRACT:
        _show_attract()
        SoundManager.play_bgm("attract")


func _on_game_over(winner: int) -> void:
    SoundManager.stop_bgm()
    SoundManager.play_bgm("results")
    # Hide all gameplay UI — show only the results popup
    _set_gameplay_hud_visible(false)
    results_overlay.visible = true

    # Set scores
    p1_score_result.text = str(GameManager.scores[0])
    p2_score_result.text = str(GameManager.scores[1])

    # Reset winner decorations
    p1_crown.visible = false
    p2_crown.visible = false
    p1_stars.visible = false
    p2_stars.visible = false
    winner_label.text = ""
    restart_button.visible = false

    if winner == 0:
        # Draw
        winner_label.text = "เสมอ!"
        p1_score_result.add_theme_font_size_override("font_size", 80)
        p2_score_result.add_theme_font_size_override("font_size", 80)
        p1_score_result.add_theme_color_override("font_color", Color.WHITE)
        p2_score_result.add_theme_color_override("font_color", Color.WHITE)
        p1_name_result.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
        p2_name_result.add_theme_color_override("font_color", Color(1, 0.5, 0.4, 1))
    elif winner == 1:
        # P1 wins
        p1_crown.visible = true
        p1_stars.visible = true
        winner_label.text = "PLAYER 1\nคือผู้ชนะ!"
        SoundManager.play_sfx("winner")
        p1_score_result.add_theme_font_size_override("font_size", 96)
        p1_score_result.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
        p1_name_result.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
        p2_score_result.add_theme_font_size_override("font_size", 56)
        p2_score_result.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        p2_name_result.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        _animate_winner_stars(p1_stars)
    else:
        # P2 wins
        p2_crown.visible = true
        p2_stars.visible = true
        winner_label.text = "PLAYER 2\nคือผู้ชนะ!"
        SoundManager.play_sfx("winner")
        p2_score_result.add_theme_font_size_override("font_size", 96)
        p2_score_result.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
        p2_name_result.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
        p1_score_result.add_theme_font_size_override("font_size", 56)
        p1_score_result.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        p1_name_result.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        _animate_winner_stars(p2_stars)

    # Score reveal animation
    _animate_score_reveal()

    # After 3 seconds, show restart button
    var tween = create_tween()
    tween.tween_interval(3.0)
    tween.tween_callback(func():
        restart_button.visible = true
        GameManager.enable_restart()
    )


func _animate_score_reveal() -> void:
    # Scores pop in with scale animation
    for label in [p1_score_result, p2_score_result]:
        label.pivot_offset = label.size / 2
        label.scale = Vector2(0.0, 0.0)
    var tween = create_tween().set_parallel(true)
    tween.tween_property(p1_score_result, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.3)
    tween.tween_property(p2_score_result, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.6)


func _animate_winner_stars(stars_label: Label) -> void:
    # Stars pulse animation
    stars_label.pivot_offset = stars_label.size / 2
    var tween = create_tween().set_loops()
    tween.tween_property(stars_label, "scale", Vector2(1.15, 1.15), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    tween.tween_property(stars_label, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _do_countdown() -> void:
    countdown_label.visible = true
    countdown_label.text = "3"

    var colors := [Color(0.2, 0.8, 1.0), Color(1.0, 0.8, 0.0), Color(1.0, 0.3, 0.2), Color(0.2, 1.0, 0.4)]
    var tween = create_tween()

    SoundManager.play_bgm("countdown", false)

    # "3" — cyan
    tween.tween_callback(func():
        countdown_label.add_theme_color_override("font_color", colors[0])
        countdown_label.scale = Vector2(0.3, 0.3)
        countdown_label.pivot_offset = countdown_label.size / 2
        SoundManager.play_sfx("countdown_beep")
    )
    tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_interval(0.7)

    # "2" — yellow
    tween.tween_callback(func():
        countdown_label.text = "2"
        countdown_label.add_theme_color_override("font_color", colors[1])
        countdown_label.scale = Vector2(0.3, 0.3)
        SoundManager.play_sfx("countdown_beep")
    )
    tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_interval(0.7)

    # "1" — red
    tween.tween_callback(func():
        countdown_label.text = "1"
        countdown_label.add_theme_color_override("font_color", colors[2])
        countdown_label.scale = Vector2(0.3, 0.3)
        SoundManager.play_sfx("countdown_beep")
    )
    tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_interval(0.7)

    # "GO!" — green
    tween.tween_callback(func():
        countdown_label.text = "GO!"
        countdown_label.add_theme_color_override("font_color", colors[3])
        countdown_label.scale = Vector2(0.5, 0.5)
        SoundManager.play_sfx("countdown_go")
    )
    tween.tween_property(countdown_label, "scale", Vector2(1.4, 1.4), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_interval(0.3)
    tween.tween_property(countdown_label, "scale", Vector2(0.0, 0.0), 0.2)
    tween.tween_callback(func():
        countdown_label.visible = false
        countdown_label.scale = Vector2(1.0, 1.0)
        GameManager.begin_play()
    )


func _show_attract() -> void:
    attract_panel.visible = true
    how_to_play_panel.visible = false
    results_overlay.visible = false
    gameplay_bg.visible = false
    countdown_label.visible = false
    _set_gameplay_hud_visible(false)
    _attract_blink_timer = 0.0


func _reset_gameplay_hud() -> void:
    attract_panel.visible = false
    how_to_play_panel.visible = false
    results_overlay.visible = false
    gameplay_bg.visible = false
    countdown_label.visible = false
    _set_gameplay_hud_visible(true)
    timer_label.text = "00:30"
    timer_label.add_theme_color_override("font_color", Color.WHITE)
    timer_label.modulate.a = 1.0
    _timer_flash = false
    p1_score_label.text = "0"
    p2_score_label.text = "0"
    p1_combo_label.visible = false
    p2_combo_label.visible = false


func _on_start_button_pressed() -> void:
    attract_panel.visible = false
    how_to_play_panel.visible = true
    _set_gameplay_hud_visible(false)


func _on_play_button_pressed() -> void:
    how_to_play_panel.visible = false
    GameManager.start_game()


func handle_ui_shot(aim_pos: Vector2) -> void:
    # Check if shot hits the start button on Attract screen
    if attract_panel.visible and start_button:
        var btn_rect = start_button.get_global_rect()
        if btn_rect.has_point(aim_pos):
            _on_start_button_pressed()
            return
    # Check if shot hits the play button on How to Play screen
    if how_to_play_panel.visible and play_button:
        var btn_rect = play_button.get_global_rect()
        if btn_rect.has_point(aim_pos):
            _on_play_button_pressed()
            return
    # Check if shot hits restart button on Results screen
    if results_overlay.visible and restart_button.visible:
        var btn_rect = restart_button.get_global_rect()
        if btn_rect.has_point(aim_pos):
            _on_restart_pressed()
            return
    # Check if shot hits sound toggle buttons on Attract screen
    if attract_panel.visible:
        if _bgm_toggle.get_global_rect().has_point(aim_pos):
            _on_bgm_toggle()
            return
        if _sfx_toggle.get_global_rect().has_point(aim_pos):
            _on_sfx_toggle()
            return


func _on_restart_pressed() -> void:
    if GameManager.results_can_restart:
        SoundManager.play_sfx("button_click")
        GameManager.start_game()


func _set_gameplay_hud_visible(show: bool) -> void:
    gameplay_bg.visible = false  # Always hidden — 3D background in Arena handles this
    p1_panel.visible = show
    p2_panel.visible = show
    timer_panel.visible = show
    p1_med_panel.visible = show
    p2_med_panel.visible = show
    med_stock_panel.visible = show
    p1_knowledge_box.visible = show
    p2_knowledge_box.visible = show
    if show:
        # Show default medicine knowledge on game start
        _update_knowledge_panel(0, GameManager.equipped_medicine[0])
        _update_knowledge_panel(1, GameManager.equipped_medicine[1])


func _update_knowledge_panel(player_id: int, med_type: GameData.MedicineType) -> void:
    var text = GameData.MEDICINE_KNOWLEDGE[med_type]
    if player_id == 0:
        p1_knowledge_label.text = text
        p1_knowledge_box.visible = true
    else:
        p2_knowledge_label.text = text
        p2_knowledge_box.visible = true


func _pulse_label(label: Label) -> void:
    var tween = create_tween()
    tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)


# ---- Sound settings on Attract screen ----

func _make_sound_btn(text: String, y_pos: float) -> Button:
    var btn = Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(220, 50)
    btn.size = Vector2(220, 50)
    btn.position = Vector2(20, y_pos)
    btn.add_theme_font_size_override("font_size", 22)
    btn.add_theme_color_override("font_color", Color.WHITE)
    # Semi-transparent dark background
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.5)
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    style.content_margin_left = 10
    style.content_margin_right = 10
    btn.add_theme_stylebox_override("normal", style)
    var hover_style = style.duplicate()
    hover_style.bg_color = Color(0.2, 0.4, 0.8, 0.6)
    btn.add_theme_stylebox_override("hover", hover_style)
    var pressed_style = style.duplicate()
    pressed_style.bg_color = Color(0.1, 0.3, 0.6, 0.7)
    btn.add_theme_stylebox_override("pressed", pressed_style)
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    return btn


func _setup_sound_settings() -> void:
    _bgm_toggle = _make_sound_btn("BGM: ON", 20)
    _bgm_toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    attract_panel.add_child(_bgm_toggle)

    _sfx_toggle = _make_sound_btn("SFX: ON", 80)
    _sfx_toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    attract_panel.add_child(_sfx_toggle)


func _on_bgm_toggle() -> void:
    SoundManager.play_sfx("button_click")
    if SoundManager.bgm_volume > 0:
        SoundManager.set_bgm_volume(0.0)
        _bgm_toggle.text = "BGM: OFF"
    else:
        SoundManager.set_bgm_volume(0.7)
        _bgm_toggle.text = "BGM: ON"


func _on_sfx_toggle() -> void:
    if SoundManager.sfx_volume > 0:
        SoundManager.set_sfx_volume(0.0)
        _sfx_toggle.text = "SFX: OFF"
    else:
        SoundManager.set_sfx_volume(0.8)
        _sfx_toggle.text = "SFX: ON"
        SoundManager.play_sfx("button_click")


# ---- Controls guide (key mapping) on How to Play screen ----

const P1_COLOR := Color(0.2, 0.6, 1.0)   # Same as P1 crosshair
const P2_COLOR := Color(1.0, 0.3, 0.2)   # Same as P2 crosshair
const GUIDE_TOP := 335.0                 # Y inside ContentBox where cards start
const GUIDE_CARD_SIZE := Vector2(455, 225)
const GUIDE_MARGIN_X := 30.0


func _setup_controls_guide() -> void:
    var box: Control = $HowToPlayPanel/ContentBox

    # P1 — mouse aim, mouse fire
    var p1_fire := _action_key_names("p1_fire")
    var p1_card := _make_player_card("PLAYER 1", P1_COLOR, [
        [_make_key_row(["เมาส์"]), "เล็งเป้า"],
        [_make_key_row(p1_fire), "ยิง / เลือกยา"],
    ])
    p1_card.position = Vector2(GUIDE_MARGIN_X, GUIDE_TOP)
    box.add_child(p1_card)

    # P2 — keyboard aim (inverted-T cluster), keyboard fire
    var up := _first_key_name("p2_aim_up", "W")
    var left := _first_key_name("p2_aim_left", "A")
    var down := _first_key_name("p2_aim_down", "S")
    var right := _first_key_name("p2_aim_right", "D")
    var p2_card := _make_player_card("PLAYER 2", P2_COLOR, [
        [_make_dpad(up, left, down, right), "เล็งเป้า\n(ขึ้น/ซ้าย/ลง/ขวา)"],
        [_make_key_row(_action_key_names("p2_fire")), "ยิง / เลือกยา"],
    ])
    # Anchor to ContentBox's right edge (its size isn't resolved yet in _ready)
    p2_card.anchor_left = 1.0
    p2_card.anchor_right = 1.0
    p2_card.offset_left = -GUIDE_MARGIN_X - GUIDE_CARD_SIZE.x
    p2_card.offset_right = -GUIDE_MARGIN_X
    p2_card.offset_top = GUIDE_TOP
    p2_card.offset_bottom = GUIDE_TOP + GUIDE_CARD_SIZE.y
    box.add_child(p2_card)

    # Footer note — light gun overrides keyboard/mouse
    var note := Label.new()
    note.text = "🔫 มีปืน Light Gun? เล็งที่จอแล้วเหนี่ยวไกยิงได้เลย"
    note.add_theme_font_size_override("font_size", 22)
    note.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.anchor_right = 1.0
    note.offset_top = GUIDE_TOP + GUIDE_CARD_SIZE.y + 8
    note.offset_bottom = note.offset_top + 34
    note.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(note)


## Human-readable names of every keyboard/mouse binding of an action (reads the live InputMap)
func _action_key_names(action: String) -> Array[String]:
    var names: Array[String] = []
    if not InputMap.has_action(action):
        return names
    for ev in InputMap.action_get_events(action):
        if ev is InputEventKey:
            var code: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
            names.append(OS.get_keycode_string(code))
        elif ev is InputEventMouseButton:
            match ev.button_index:
                MOUSE_BUTTON_LEFT: names.append("คลิกซ้าย")
                MOUSE_BUTTON_RIGHT: names.append("คลิกขวา")
                MOUSE_BUTTON_MIDDLE: names.append("คลิกกลาง")
    return names


func _first_key_name(action: String, fallback: String) -> String:
    var names := _action_key_names(action)
    return names[0] if names.size() > 0 else fallback


func _make_player_card(title: String, color: Color, rows: Array) -> Panel:
    var card := Panel.new()
    card.size = GUIDE_CARD_SIZE
    card.custom_minimum_size = GUIDE_CARD_SIZE
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.85)
    style.border_color = color
    style.set_border_width_all(3)
    style.set_corner_radius_all(16)
    card.add_theme_stylebox_override("panel", style)

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 14)
    card.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(vbox)

    var title_label := Label.new()
    title_label.text = title
    title_label.add_theme_font_size_override("font_size", 30)
    title_label.add_theme_color_override("font_color", color.lightened(0.2))
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_label)

    for row in rows:
        var hbox := HBoxContainer.new()
        hbox.add_theme_constant_override("separation", 16)
        hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
        hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

        var keys_holder := CenterContainer.new()
        keys_holder.custom_minimum_size = Vector2(170, 0)
        keys_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
        keys_holder.add_child(row[0])
        hbox.add_child(keys_holder)

        var desc := Label.new()
        desc.text = row[1]
        desc.add_theme_font_size_override("font_size", 24)
        desc.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
        desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hbox.add_child(desc)
        vbox.add_child(hbox)
    return card


## A single keyboard-key "cap"
func _make_keycap(text: String) -> PanelContainer:
    var cap := PanelContainer.new()
    cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cap.custom_minimum_size = Vector2(44, 40)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.93, 0.95, 1.0)
    style.border_color = Color(0.55, 0.6, 0.7)
    style.border_width_bottom = 4   # gives a pressable "key" look
    style.set_corner_radius_all(8)
    style.content_margin_left = 10
    style.content_margin_right = 10
    cap.add_theme_stylebox_override("panel", style)
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cap.add_child(label)
    return cap


## Row of key caps, joined by "/" when an action has several bindings
func _make_key_row(names: Array) -> HBoxContainer:
    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 6)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in range(names.size()):
        if i > 0:
            var sep := Label.new()
            sep.text = "/"
            sep.add_theme_font_size_override("font_size", 22)
            hbox.add_child(sep)
        hbox.add_child(_make_keycap(names[i]))
    return hbox


## Inverted-T arrow cluster (e.g. W on top, A S D below)
func _make_dpad(up: String, left: String, down: String, right: String) -> GridContainer:
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var cells := ["", up, "", left, down, right]
    for c in cells:
        if c == "":
            var spacer := Control.new()
            spacer.custom_minimum_size = Vector2(44, 40)
            spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grid.add_child(spacer)
        else:
            grid.add_child(_make_keycap(c))
    return grid
