extends Node

# ── Category base gains (dB) ────────────────────────────────────────────────
var gain_waves: float      =  0.0
var gain_ambience: float   = -3.0
var gain_impairment: float =  0.0
var gain_surreal: float    = -4.0
var gain_stingers: float   =  0.0  # exception category — no random variation

# ── Audio library ───────────────────────────────────────────────────────────

const _WAVES_AMBIENCE:      AudioStream = preload("res://assets/audio/waves ambience.mp3")
const _WETWALKING:          AudioStream = preload("res://assets/audio/wetwalking.mp3")
const _ELEGY:               AudioStream = preload("res://assets/audio/elegy for a night swim.mp3")

const _WAVE_HIT_1:          AudioStream = preload("res://assets/audio/wave hit 1.mp3")
const _WAVE_HIT_UNDERWATER: AudioStream = preload("res://assets/audio/wave hit underwater.mp3")
const _WAVE_CRASH_BEHIND:   AudioStream = preload("res://assets/audio/wave crash behind.mp3")

const _GULLS_1:         AudioStream = preload("res://assets/audio/some gulls.mp3")
const _GULLS_2:         AudioStream = preload("res://assets/audio/some gulls2.mp3")
const _LIGHTHOUSE_GONG: AudioStream = preload("res://assets/audio/lighthouse gong.mp3")
const _BUOY_RINGS:      AudioStream = preload("res://assets/audio/the buoy rings.mp3")
const _DRONING:         AudioStream = preload("res://assets/audio/the droning begins.mp3")

const _SMACKEAR:     AudioStream = preload("res://assets/audio/smackear.mp3")
const _SMACKEAR_WET: AudioStream = preload("res://assets/audio/smackear wet.mp3")
const _RUB_EYES:     AudioStream = preload("res://assets/audio/rub eyes.mp3")

const _GURGLE:      AudioStream = preload("res://assets/audio/gurgle.mp3")
const _GURGLING:    AudioStream = preload("res://assets/audio/gurgling.mp3")
const _DEEP_BREATH: AudioStream = preload("res://assets/audio/deep breath.mp3")
const _PLUNGED_1:   AudioStream = preload("res://assets/audio/plunged.mp3")
const _PLUNGED_2:   AudioStream = preload("res://assets/audio/plunged2.mp3")

const _COFFIN_1:        AudioStream = preload("res://assets/audio/coffin.mp3")
const _COFFIN_2:        AudioStream = preload("res://assets/audio/coffin2.mp3")
const _COFFIN_3:        AudioStream = preload("res://assets/audio/coffin3.mp3")
const _WETCOFFIN_1:     AudioStream = preload("res://assets/audio/wetcoffin.mp3")
const _WETCOFFIN_2:     AudioStream = preload("res://assets/audio/wetcoffin2.mp3")
const _WETCOFFIN_3:     AudioStream = preload("res://assets/audio/wetcoffin3.mp3")
const _SOMEBODY:        AudioStream = preload("res://assets/audio/somebody in the depths.mp3")
const _WEIRD_SOUND:     AudioStream = preload("res://assets/audio/weirdsoundd.mp3")
const _STRANGE_RINGING:    AudioStream = preload("res://assets/audio/strange ringing.mp3")
const _STRANGE_MURMURING:  AudioStream = preload("res://assets/audio/strange murmuring.mp3")
const _STRANGE_CHANTING:   AudioStream = preload("res://assets/audio/strange chanting.mp3")

const _SOMETHING_GOOD:    AudioStream = preload("res://assets/audio/something good.mp3")
const _THINGS_ARENT_GOOD: AudioStream = preload("res://assets/audio/things arent good.mp3")
const _YOU_DARE_RETURN:   AudioStream = preload("res://assets/audio/you dare return.mp3")

# ── Grouped pools (populated in _ready to avoid 4.3 const-array issues) ────
var _gulls:     Array[AudioStream]
var _plunged:   Array[AudioStream]
var _coffin:    Array[AudioStream]
var _wetcoffin: Array[AudioStream]

var _knocked_down: bool = false  # mirrored from SignalBus to avoid cross-autoload ref
var _ambience_player: AudioStreamPlayer
var _elegy_player: AudioStreamPlayer = null

# ── Wet footstep loop ────────────────────────────────────────────────────────
var gain_wetwalking: float = -4.0
# Pitch slides from 1.0 at shore to 0.5 (−12 semitones) at 100m.
const _WETWALKING_PITCH_FAR: float = 0.5
const _WETWALKING_FADE_RATE: float = 20.0  # dB per second for volume fade
var _wetwalking_player: AudioStreamPlayer
var _wetwalking_vol: float = -80.0

# ── Drown gurgle loop ────────────────────────────────────────────────────────
const _GURGLING_GAIN_MAX: float = -4.0   # volume at drown = 1.0
const _GURGLING_FADE_RATE: float = 20.0  # dB per second
var _gurgling_player: AudioStreamPlayer
var _gurgling_vol: float = -80.0

# Ear clog — low-pass filter + panner on Master bus.
const _EAR_LP_CUTOFF: float = 400.0
var _ear_lp_idx: int = -1
var _ear_pan_idx: int = -1

# ── Wave crash behind — ambient timer near shore ────────────────────────────
const _CRASH_MAX_DIST: float      = 15.0
const _CRASH_INTERVAL_MIN: float  =  6.0
const _CRASH_INTERVAL_MAX: float  = 12.0
const _CRASH_BEHIND_GAIN: float   = -8.0  # offset from gain_waves — quieter than direct hits
var _crash_timer: float = 3.0

const _GURGLE_THRESHOLD: float   = 0.9
const _GURGLE_INTERVAL: float    = 2.5
var _gurgle_timer: float         = 0.0
var _prev_drown: float           = 0.0
var _was_high_drown: bool        = false

# ── Ambient stingers — gulls / lighthouse gong every 5-15 s ─────────────────
const _AMBIENT_INTERVAL_MIN: float = 15.0
const _AMBIENT_INTERVAL_MAX: float = 30.0
const _GULLS_GAIN_OFFSET: float    =  -4.4  # 40% quieter in amplitude
const _GULLS2_GAIN_OFFSET: float   = -14.4  # gulls2 additionally -10 dB
const _LP_CHANCE: float            = 0.5   # probability of low-pass per play
const _LP_FREQ_MIN: float          = 300.0
const _LP_FREQ_MAX: float          = 20000.0
var _ambient_timer: float = randf_range(_AMBIENT_INTERVAL_MIN, _AMBIENT_INTERVAL_MAX)

# ── Wave hit intensity ───────────────────────────────────────────────────────
# Normalisation ceiling for force * (eff_h / player_h).
# Waves at or above this product play at full gain_waves volume.
const _WAVE_MAX_INTENSITY: float = 1.5

func _ready() -> void:
	_gulls     = [_GULLS_1, _GULLS_2]
	_plunged   = [_PLUNGED_1, _PLUNGED_2]
	_coffin    = [_COFFIN_1, _COFFIN_2, _COFFIN_3]
	_wetcoffin = [_WETCOFFIN_1, _WETCOFFIN_2, _WETCOFFIN_3]
	SignalBus.wave_hit.connect(_on_wave_hit)
	SignalBus.knocked_down.connect(func() -> void: _knocked_down = true)
	SignalBus.stood_up.connect(func() -> void: _knocked_down = false)
	SignalBus.impairment_changed.connect(_on_impairment_changed)
	_setup_ear_filter()
	_start_waves_ambience()
	_start_wetwalking()
	_start_gurgling()

func _start_gurgling() -> void:
	(_GURGLING as AudioStreamMP3).loop = true
	_gurgling_player = AudioStreamPlayer.new()
	_gurgling_player.stream = _GURGLING
	_gurgling_player.volume_db = -80.0
	add_child(_gurgling_player)
	_gurgling_player.play()

func _start_wetwalking() -> void:
	(_WETWALKING as AudioStreamMP3).loop = true
	_wetwalking_player = AudioStreamPlayer.new()
	_wetwalking_player.stream = _WETWALKING
	_wetwalking_player.volume_db = -80.0
	add_child(_wetwalking_player)
	_wetwalking_player.play()

func _start_waves_ambience() -> void:
	(_WAVES_AMBIENCE as AudioStreamMP3).loop = true
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.stream = _WAVES_AMBIENCE
	_ambience_player.volume_db = gain_ambience
	add_child(_ambience_player)
	_ambience_player.play()

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return
	_crash_timer -= delta
	if _crash_timer <= 0.0:
		_crash_timer = randf_range(_CRASH_INTERVAL_MIN, _CRASH_INTERVAL_MAX)
		_try_crash_behind()
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = randf_range(_AMBIENT_INTERVAL_MIN, _AMBIENT_INTERVAL_MAX)
		_play_ambient_stinger()
	if DrownMeter.value >= _GURGLE_THRESHOLD:
		_gurgle_timer -= delta
		if _gurgle_timer <= 0.0:
			_gurgle_timer = _GURGLE_INTERVAL
			play_impairment_gurgle()
	else:
		_gurgle_timer = 0.0
	_update_wetwalking(delta)
	_update_gurgling(delta)
	var drown: float = DrownMeter.value
	if drown > 0.5:
		_was_high_drown = true
	if _prev_drown >= 0.8 and drown < 0.8:
		_play(_pick(_wetcoffin), gain_surreal + 10.0, true)
	if _prev_drown >= 0.6 and drown < 0.6:
		play_surreal_coffin()
	if _prev_drown > 0.0 and drown == 0.0:
		if _was_high_drown:
			play_impairment_breath()
		_was_high_drown = false
	_prev_drown = drown

# ── Public play methods ─────────────────────────────────────────────────────

func play_wave_hit(wave_data: WaveData) -> void:
	var player_h: float = 1.0 if _knocked_down else 2.0
	var eff_h: float    = wave_data.height + GameManager.water_level()
	var stream: AudioStream = _WAVE_HIT_UNDERWATER if eff_h >= player_h else _WAVE_HIT_1

	# Volume scales with force * relative height, floored at 0.
	# sqrt gives perceptual linearity: small waves are quiet but audible.
	var intensity: float    = clamp(wave_data.force * (eff_h / player_h) / _WAVE_MAX_INTENSITY, 0.0, 1.0)
	var volume_db: float    = gain_waves + linear_to_db(maxf(sqrt(intensity), 0.0001))
	_play(stream, volume_db, true)

func play_ambience_gulls() -> void:      _play(_pick(_gulls), gain_ambience, true)
func play_ambience_buoy() -> void:       _play(_BUOY_RINGS, gain_ambience, true)
func play_ambience_droning() -> void:    _play(_DRONING, gain_ambience, true)

# Rub eyes — fires when the player wipes their eyes.
func play_rub_eyes() -> void:            _play(_RUB_EYES, gain_impairment, false)

# Ear smack — fires when the player clears an ear. Wet variant if the ear was
# clogged. Left ear plays as-is; right ear is imaged to the right side.
func play_ear_smack(is_right_ear: bool, was_wet: bool) -> void:
	var stream: AudioStream = _SMACKEAR_WET if was_wet else _SMACKEAR
	if not is_right_ear:
		_play(stream, gain_impairment, false)
		return
	# Right ear: route through a temporary panned bus, freed when the sound ends.
	var bus_name := StringName("EarSmack_%d" % [randi()])
	AudioServer.add_bus()
	var bus_idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_idx, bus_name)
	AudioServer.set_bus_send(bus_idx, &"Master")
	var pan := AudioEffectPanner.new()
	pan.pan = 1.0
	AudioServer.add_bus_effect(bus_idx, pan)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = gain_impairment
	player.bus = bus_name
	player.finished.connect(func() -> void:
		AudioServer.remove_bus(AudioServer.get_bus_index(bus_name))
		player.queue_free()
	)
	add_child(player)
	player.play()

func play_impairment_gurgle() -> void:   _play(_GURGLE, gain_impairment + 5.0, true)
func play_impairment_plunged() -> void:  _play(_pick(_plunged), gain_impairment, true)
func play_impairment_breath() -> void:   _play(_DEEP_BREATH, gain_impairment + 5.0, true)

func play_surreal_coffin() -> void:      _play(_pick(_coffin), gain_surreal + 5.0, true)
func play_surreal_somebody() -> void:    _play(_SOMEBODY, gain_surreal, true)
func play_surreal_weird() -> void:       _play(_WEIRD_SOUND, gain_surreal, true)
func play_surreal_ringing() -> void:     _play(_STRANGE_RINGING, gain_surreal, true)

func play_stinger_good() -> void:        _play(_SOMETHING_GOOD, gain_stingers, false)
func play_stinger_bad() -> void:         _play(_THINGS_ARENT_GOOD, gain_stingers, false)
func play_you_dare_return() -> void:     _play(_YOU_DARE_RETURN, gain_stingers, false)

func play_elegy_loop() -> void:
	if _elegy_player and is_instance_valid(_elegy_player):
		_elegy_player.queue_free()
	(_ELEGY as AudioStreamMP3).loop = true
	_elegy_player = AudioStreamPlayer.new()
	_elegy_player.stream = _ELEGY
	_elegy_player.volume_db = gain_surreal
	add_child(_elegy_player)
	_elegy_player.play()

func fade_out_elegy(duration: float) -> void:
	if not _elegy_player or not is_instance_valid(_elegy_player):
		return
	var p: AudioStreamPlayer = _elegy_player
	_elegy_player = null
	var tween := create_tween()
	tween.tween_property(p, "volume_db", -80.0, duration)
	tween.tween_callback(p.queue_free)

func reset() -> void:
	_prev_drown       = 0.0
	_was_high_drown   = false
	_gurgle_timer     = 0.0
	_crash_timer      = randf_range(_CRASH_INTERVAL_MIN, _CRASH_INTERVAL_MAX)
	_ambient_timer    = randf_range(_AMBIENT_INTERVAL_MIN, _AMBIENT_INTERVAL_MAX)
	_wetwalking_vol   = -80.0
	if _wetwalking_player:
		_wetwalking_player.volume_db = -80.0
	_gurgling_vol = -80.0
	if _gurgling_player:
		_gurgling_player.volume_db = -80.0

# ── Signal handlers ─────────────────────────────────────────────────────────

func _on_wave_hit(wave_data: WaveData) -> void:
	play_wave_hit(wave_data)
	var player_h: float = 1.0 if _knocked_down else 2.0
	var eff_h: float    = wave_data.height + GameManager.water_level()
	if eff_h >= player_h:
		play_impairment_plunged()

# ── Internal ────────────────────────────────────────────────────────────────

const _VARIATION_MAX: float = 0.15

func _try_crash_behind() -> void:
	var dist: float = GameManager.distance
	if dist >= _CRASH_MAX_DIST:
		return
	# Linear fade: full volume at shore, silent at CRASH_MAX_DIST.
	var vol_linear: float = 1.0 - dist / _CRASH_MAX_DIST
	var volume_db: float  = gain_waves + _CRASH_BEHIND_GAIN + linear_to_db(maxf(vol_linear, 0.0001))
	_play(_WAVE_CRASH_BEHIND, volume_db, true)

func _play(stream: AudioStream, base_db: float, vary: bool) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	var variation_db: float = 0.0
	if vary:
		variation_db = linear_to_db(1.0 - randf() * _VARIATION_MAX)
	player.volume_db = base_db + variation_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

const _SURREAL_DIST_1: float = 70.0  # strange murmuring
const _SURREAL_DIST_2: float = 80.0  # strange ringing / somebody in the depths
const _SURREAL_DIST_3: float = 90.0  # strange chanting

func _play_ambient_stinger() -> void:
	var stream: AudioStream
	var base_db: float
	var dist: float = GameManager.distance
	if dist >= _SURREAL_DIST_3:
		stream = _STRANGE_CHANTING
		base_db = gain_surreal
	elif dist >= _SURREAL_DIST_2:
		base_db = gain_surreal
		match randi() % 2:
			0: stream = _STRANGE_RINGING
			1: stream = _SOMEBODY
	elif dist >= _SURREAL_DIST_1:
		stream = _STRANGE_MURMURING
		base_db = gain_surreal
	else:
		base_db = gain_ambience
		match randi() % 3:
			0: stream = _GULLS_1;        base_db += _GULLS_GAIN_OFFSET
			1: stream = _GULLS_2;        base_db += _GULLS2_GAIN_OFFSET
			2: stream = _LIGHTHOUSE_GONG

	var variation_db: float = linear_to_db(1.0 - randf() * _VARIATION_MAX)
	var volume_db: float    = base_db + variation_db

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db

	if randf() < _LP_CHANCE:
		# Spin up a temporary bus with a low-pass effect so the filter is
		# isolated to this one player and freed with it.
		var bus_name: StringName = "AmbLP_%d" % [randi()]
		AudioServer.add_bus()
		var bus_idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, bus_name)
		AudioServer.set_bus_send(bus_idx, &"Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = randf_range(_LP_FREQ_MIN, _LP_FREQ_MAX)
		AudioServer.add_bus_effect(bus_idx, lp)
		player.bus = bus_name
		player.finished.connect(func() -> void:
			AudioServer.remove_bus(AudioServer.get_bus_index(bus_name))
			player.queue_free()
		)
	else:
		player.finished.connect(player.queue_free)

	add_child(player)
	player.play()

func _update_gurgling(delta: float) -> void:
	var target_vol: float = lerpf(-80.0, _GURGLING_GAIN_MAX, DrownMeter.value) if DrownMeter.value > 0.001 else -80.0
	_gurgling_vol = move_toward(_gurgling_vol, target_vol, _GURGLING_FADE_RATE * delta)
	_gurgling_player.volume_db = _gurgling_vol

func _update_wetwalking(delta: float) -> void:
	var walking: bool = Input.is_action_pressed(&"walk_forward") and not _knocked_down
	var target_vol: float = gain_wetwalking if walking else -80.0
	if _wetwalking_vol < target_vol:
		_wetwalking_vol = minf(_wetwalking_vol + _WETWALKING_FADE_RATE * delta, target_vol)
	else:
		_wetwalking_vol = maxf(_wetwalking_vol - _WETWALKING_FADE_RATE * delta, target_vol)
	_wetwalking_player.volume_db = _wetwalking_vol
	_wetwalking_player.pitch_scale = lerpf(1.0, _WETWALKING_PITCH_FAR,
			clampf(GameManager.distance / 100.0, 0.0, 1.0))

func _setup_ear_filter() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = _EAR_LP_CUTOFF
	AudioServer.add_bus_effect(master, lp)
	_ear_lp_idx = AudioServer.get_bus_effect_count(master) - 1
	AudioServer.set_bus_effect_enabled(master, _ear_lp_idx, false)
	var pan := AudioEffectPanner.new()
	pan.pan = 0.0
	AudioServer.add_bus_effect(master, pan)
	_ear_pan_idx = AudioServer.get_bus_effect_count(master) - 1
	AudioServer.set_bus_effect_enabled(master, _ear_pan_idx, false)

func _on_impairment_changed(type: StringName, state: bool) -> void:
	if type == &"left_ear" or type == &"right_ear":
		_update_ear_filter()

func _update_ear_filter() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	var left: bool  = ImpairmentSystem.left_ear_impaired
	var right: bool = ImpairmentSystem.right_ear_impaired
	if left and right:
		# Both clogged: muffle everything, stay centered.
		AudioServer.set_bus_effect_enabled(master, _ear_lp_idx, true)
		AudioServer.set_bus_effect_enabled(master, _ear_pan_idx, false)
	elif left:
		# Left clogged, right clear: clear ear hears fine, silence the clogged side.
		AudioServer.set_bus_effect_enabled(master, _ear_lp_idx, false)
		AudioServer.set_bus_effect_enabled(master, _ear_pan_idx, true)
		(AudioServer.get_bus_effect(master, _ear_pan_idx) as AudioEffectPanner).pan = 1.0
	elif right:
		# Right clogged, left clear: clear ear hears fine, silence the clogged side.
		AudioServer.set_bus_effect_enabled(master, _ear_lp_idx, false)
		AudioServer.set_bus_effect_enabled(master, _ear_pan_idx, true)
		(AudioServer.get_bus_effect(master, _ear_pan_idx) as AudioEffectPanner).pan = -1.0
	else:
		AudioServer.set_bus_effect_enabled(master, _ear_lp_idx, false)
		AudioServer.set_bus_effect_enabled(master, _ear_pan_idx, false)

func _pick(pool: Array[AudioStream]) -> AudioStream:
	return pool[randi() % pool.size()]
