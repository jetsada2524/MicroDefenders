## GameManager — Autoload singleton managing game state
extends Node

signal game_state_changed(new_state: GameState)
signal score_changed(player_id: int, new_score: int)
signal medicine_changed(player_id: int, medicine_type: GameData.MedicineType)
signal timer_updated(time_left: float)
signal germ_killed(player_id: int, germ_type: GameData.GermType, points: int)
signal germ_reached_organ(organ_name: String)
signal game_over(winner_id: int)  # 0=draw, 1=P1, 2=P2
signal results_restart_ready  # Emitted after 5s delay in results

enum GameState { ATTRACT, COUNTDOWN, PLAYING, SUDDEN_DEATH, RESULTS }

var current_state: GameState = GameState.ATTRACT
var scores := [0, 0]  # P1, P2
var equipped_medicine := [
	GameData.MedicineType.ANTIBIOTIC,
	GameData.MedicineType.ANTIBIOTIC,
]
var combo_count := [0, 0]
var time_left: float = GameData.ROUND_TIME
var is_sudden_death := false
var results_can_restart := false  # True after 5s in RESULTS

var _timer_active := false

# Attract/idle timeout
var _idle_timer: float = 0.0
const IDLE_TIMEOUT: float = 30.0  # seconds of no input before returning to attract


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_state(GameState.ATTRACT)


func _process(delta: float) -> void:
	# Idle timeout — return to attract if no input in RESULTS (after restart is ready)
	if current_state == GameState.RESULTS and results_can_restart:
		_idle_timer += delta
		if _idle_timer >= IDLE_TIMEOUT:
			_idle_timer = 0.0
			go_to_attract()

	if not _timer_active:
		return
	time_left -= delta
	timer_updated.emit(time_left)
	if time_left <= 0.0:
		time_left = 0.0
		_timer_active = false
		_on_time_up()


func go_to_attract() -> void:
	_timer_active = false
	results_can_restart = false
	_set_state(GameState.ATTRACT)


func reset_idle() -> void:
	_idle_timer = 0.0


func start_game() -> void:
	scores = [0, 0]
	combo_count = [0, 0]
	equipped_medicine = [
		GameData.MedicineType.ANTIBIOTIC,
		GameData.MedicineType.ANTIBIOTIC,
	]
	time_left = GameData.ROUND_TIME
	is_sudden_death = false
	results_can_restart = false
	_set_state(GameState.COUNTDOWN)
	# Countdown handled by UI, then call begin_play()


func begin_play() -> void:
	_timer_active = true
	_set_state(GameState.PLAYING)


func start_sudden_death() -> void:
	is_sudden_death = true
	time_left = GameData.SUDDEN_DEATH_TIME
	_timer_active = true
	_set_state(GameState.SUDDEN_DEATH)


func add_score(player_id: int, points: int) -> void:
	scores[player_id] += points
	scores[player_id] = max(scores[player_id], 0)
	score_changed.emit(player_id + 1, scores[player_id])


func set_medicine(player_id: int, med_type: GameData.MedicineType) -> void:
	equipped_medicine[player_id] = med_type
	medicine_changed.emit(player_id + 1, med_type)


func get_medicine(player_id: int) -> GameData.MedicineType:
	return equipped_medicine[player_id]


func on_germ_hit(player_id: int, germ_type: GameData.GermType) -> bool:
	## Returns true if the medicine matches (germ dies)
	var required_med = GameData.germ_to_medicine(germ_type)
	var current_med = equipped_medicine[player_id]
	if current_med == required_med:
		var points = GameData.GERM_POINTS[germ_type]
		add_score(player_id, points)
		germ_killed.emit(player_id + 1, germ_type, points)
		return true
	else:
		add_score(player_id, GameData.SCORE_WRONG_MEDICINE_PENALTY)
		return false


func on_germ_reached(organ_name: String) -> void:
	germ_reached_organ.emit(organ_name)


func _on_time_up() -> void:
	if is_sudden_death:
		_determine_winner()
	elif scores[0] == scores[1]:
		start_sudden_death()
	else:
		_determine_winner()


func _determine_winner() -> void:
	_set_state(GameState.RESULTS)
	var winner: int
	if scores[0] > scores[1]:
		winner = 1
	elif scores[1] > scores[0]:
		winner = 2
	else:
		winner = 0
	game_over.emit(winner)


func enable_restart() -> void:
	results_can_restart = true
	_idle_timer = 0.0
	results_restart_ready.emit()


func _set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)
