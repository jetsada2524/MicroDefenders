## SoundManager — Autoload singleton for BGM + SFX
extends Node

# --- BGM players ---
var _bgm_player: AudioStreamPlayer
var _current_bgm: String = ""

# --- SFX pool (multiple simultaneous sounds) ---
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

# --- Preloaded audio ---
var _audio_cache: Dictionary = {}

# --- Volume settings (linear 0..1) ---
var bgm_volume: float = 1.0
var sfx_volume: float = 0.8

# Audio file paths
const AUDIO_DIR := "res://assets/audio/"

const BGM := {
    "attract": "bgm_attract.wav",
    "gameplay": "bgm_gameplay.wav",
    "results": "bgm_results.wav",
    "countdown": "bgm_countdown.wav",
}

const SFX := {
    "shoot": "sfx_shoot.wav",
    "hit_correct": "sfx_hit_correct.wav",
    "hit_wrong": "sfx_hit_wrong.wav",
    "medicine_select": "sfx_medicine_select.wav",
    "countdown_beep": "sfx_countdown_beep.wav",
    "countdown_go": "sfx_countdown_go.wav",

    "winner": "sfx_winner.wav",
    "button_click": "sfx_button_click.wav",
    "germ_spawn": "sfx_germ_spawn.wav",
    "germ_reach": "sfx_germ_reach.wav",
}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

    # Create BGM player
    _bgm_player = AudioStreamPlayer.new()
    _bgm_player.bus = "Master"
    _bgm_player.volume_db = _to_db(bgm_volume)
    add_child(_bgm_player)

    # Create SFX player pool
    for i in range(SFX_POOL_SIZE):
        var p = AudioStreamPlayer.new()
        p.bus = "Master"
        p.volume_db = _to_db(sfx_volume)
        add_child(p)
        _sfx_players.append(p)

    # Preload all audio
    _preload_all()


func _preload_all() -> void:
    for key in BGM:
        var path = AUDIO_DIR + BGM[key]
        var stream = _load_audio(path)
        if stream:
            _audio_cache[BGM[key]] = stream
            print("SoundManager: Loaded BGM '%s' OK" % key)
        else:
            push_warning("SoundManager: BGM not found — %s" % path)

    for key in SFX:
        var path = AUDIO_DIR + SFX[key]
        var stream = _load_audio(path)
        if stream:
            _audio_cache[SFX[key]] = stream
            print("SoundManager: Loaded SFX '%s' OK" % key)
        else:
            push_warning("SoundManager: SFX not found — %s" % path)


func _load_audio(path: String) -> AudioStream:
    ## Load through Godot's import system. This is the only path that works in exported
    ## builds (macOS / Windows / Web): exports contain the imported .sample resources,
    ## not the original .wav files, so FileAccess on the .wav fails there.
    if ResourceLoader.exists(path):
        var res = load(path)
        if res is AudioStream:
            return res
    # Editor-only fallback: parse the raw .wav if it hasn't been imported yet
    if OS.has_feature("editor"):
        return _load_wav_direct(path)
    return null


func _load_wav_direct(path: String) -> AudioStreamWAV:
    ## Load a PCM 16-bit WAV file directly via FileAccess, bypassing Godot import cache
    var exists = FileAccess.file_exists(path)
    print("SoundManager: _load_wav_direct('%s') exists=%s" % [path, exists])
    if not exists:
        # Try globalized path as fallback
        var global_path = ProjectSettings.globalize_path(path)
        print("SoundManager: Trying global path: %s" % global_path)
        if not FileAccess.file_exists(global_path):
            print("SoundManager: File not found at either path")
            return null
        path = global_path

    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        print("SoundManager: Cannot open %s — error %d" % [path, FileAccess.get_open_error()])
        return null

    var file_len = file.get_length()
    print("SoundManager: Opened %s — %d bytes" % [path, file_len])

    # Read RIFF header
    var riff = file.get_buffer(4).get_string_from_ascii()
    if riff != "RIFF":
        print("SoundManager: Not a RIFF file — %s (got '%s')" % [path, riff])
        file.close()
        return null

    var _file_size = file.get_32()
    var wave = file.get_buffer(4).get_string_from_ascii()
    if wave != "WAVE":
        print("SoundManager: Not a WAVE file — %s" % path)
        file.close()
        return null

    var format_found := false
    var channels := 1
    var sample_rate := 44100
    var bits_per_sample := 16
    var audio_data := PackedByteArray()

    # Parse chunks
    while file.get_position() < file_len - 8:
        var chunk_id = file.get_buffer(4).get_string_from_ascii()
        var chunk_size = file.get_32()

        if chunk_id == "fmt ":
            var audio_format = file.get_16()  # 1 = PCM
            channels = file.get_16()
            sample_rate = file.get_32()
            var _byte_rate = file.get_32()
            var _block_align = file.get_16()
            bits_per_sample = file.get_16()
            format_found = true
            print("SoundManager: fmt — format=%d ch=%d rate=%d bits=%d" % [audio_format, channels, sample_rate, bits_per_sample])
            # Skip any extra fmt data
            var fmt_extra = chunk_size - 16
            if fmt_extra > 0:
                file.get_buffer(fmt_extra)
        elif chunk_id == "data":
            audio_data = file.get_buffer(chunk_size)
            print("SoundManager: data chunk — %d bytes loaded" % audio_data.size())
        else:
            # Skip unknown chunks (LIST, fact, etc.)
            print("SoundManager: Skipping chunk '%s' size=%d" % [chunk_id, chunk_size])
            if chunk_size > 0:
                file.get_buffer(chunk_size)

    file.close()

    if not format_found or audio_data.size() == 0:
        print("SoundManager: Invalid WAV — format_found=%s data_size=%d" % [format_found, audio_data.size()])
        return null

    var stream = AudioStreamWAV.new()
    stream.data = audio_data
    stream.mix_rate = sample_rate
    stream.stereo = (channels == 2)
    if bits_per_sample == 16:
        stream.format = AudioStreamWAV.FORMAT_16_BITS
    else:
        stream.format = AudioStreamWAV.FORMAT_8_BITS

    print("SoundManager: Created AudioStreamWAV — rate=%d stereo=%s duration=%.1fs" % [
        sample_rate, stream.stereo, float(audio_data.size()) / (sample_rate * channels * (bits_per_sample / 8))
    ])
    return stream


# ---- BGM ----

func play_bgm(name: String, loop: bool = true) -> void:
    print("SoundManager: play_bgm('%s') called — cache has %d items, bgm_volume=%.2f" % [name, _audio_cache.size(), bgm_volume])
    if name not in BGM:
        print("SoundManager: Unknown BGM '%s'" % name)
        return

    var file = BGM[name]
    if _current_bgm == file and _bgm_player.playing:
        print("SoundManager: BGM '%s' already playing, skip" % name)
        return

    if file not in _audio_cache:
        print("SoundManager: BGM file '%s' not in cache!" % file)
        return

    var stream: AudioStream = _audio_cache[file]
    # Set loop mode for WAV
    if stream is AudioStreamWAV:
        var wav_stream := stream as AudioStreamWAV
        if loop:
            wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            wav_stream.loop_begin = 0
            # Loop end in frames — works for every WAV format (PCM, IMA-ADPCM, QOA)
            wav_stream.loop_end = int(wav_stream.get_length() * wav_stream.mix_rate)
        else:
            wav_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED

    _bgm_player.stream = stream
    _bgm_player.volume_db = _to_db(bgm_volume)
    _bgm_player.play()
    _current_bgm = file
    print("SoundManager: BGM playing='%s' volume_db=%.1f is_playing=%s is_inside_tree=%s" % [
        name, _bgm_player.volume_db, _bgm_player.playing, _bgm_player.is_inside_tree()
    ])


func stop_bgm() -> void:
    _bgm_player.stop()
    _current_bgm = ""


func fade_bgm(duration: float = 0.5) -> void:
    if not _bgm_player.playing:
        return
    if _bgm_player.volume_db <= -40.0:
        # Already silent (BGM muted) — nothing to fade, just stop
        _bgm_player.stop()
        _current_bgm = ""
        return
    var tween = create_tween()
    tween.tween_property(_bgm_player, "volume_db", -40.0, duration)
    tween.tween_callback(func():
        _bgm_player.stop()
        _bgm_player.volume_db = _to_db(bgm_volume)
        _current_bgm = ""
    )


# ---- SFX ----

func play_sfx(name: String, volume_scale: float = 1.0) -> void:
    if sfx_volume <= 0.0:
        return  # SFX muted
    if name not in SFX:
        push_warning("SoundManager: Unknown SFX '%s'" % name)
        return

    var file = SFX[name]
    if file not in _audio_cache:
        return

    # Find a free player
    var player: AudioStreamPlayer = null
    for p in _sfx_players:
        if not p.playing:
            player = p
            break

    if player == null:
        # All busy — steal the oldest
        player = _sfx_players[0]

    player.stream = _audio_cache[file]
    player.volume_db = _to_db(sfx_volume * volume_scale)
    player.play()


# ---- Helpers ----

## Volume 0..1 → dB. linear_to_db(0) returns -INF, and tweening from -INF
## (e.g. fade_bgm while BGM is muted) produces NaN, so clamp to a silent floor instead.
const SILENT_DB := -80.0

func _to_db(linear: float) -> float:
    if linear <= 0.0001:
        return SILENT_DB
    return linear_to_db(linear)


func set_bgm_volume(vol: float) -> void:
    bgm_volume = clampf(vol, 0.0, 1.0)
    _bgm_player.volume_db = _to_db(bgm_volume)


func set_sfx_volume(vol: float) -> void:
    sfx_volume = clampf(vol, 0.0, 1.0)
