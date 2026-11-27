# Sound effects, synthesized when the game starts, so there are no audio
# files to ship. Call play("coin") etc.
extends Node

const RATE := 22050
const VOICES := 8

var volume := 0.6                 # 0..1, set from settings
var _streams := {}
var _players: Array = []
var _last_ms := {}                # name -> last time played, to avoid spam


func _ready() -> void:
	# Coin: a bright two-note "plink".
	_streams["coin"] = _wav(_concat([
		_sweep(1568.0, 1568.0, 0.05, 0.35, 4.0, 0.25),
		_sweep(2093.0, 2093.0, 0.16, 0.35, 7.0, 0.25),
	]))
	# Food pellet: a short rising "bloop".
	_streams["food"] = _wav(_sweep(320.0, 760.0, 0.09, 0.4, 5.0, 0.0))
	# Splash: soft noise burst plus a falling bloop.
	_streams["splash"] = _wav(_mix(_noise(0.45, 0.35, 7.0, 0.18), _sweep(620.0, 180.0, 0.22, 0.3, 6.0, 0.0)))
	# Level up: a quick happy arpeggio.
	_streams["level"] = _wav(_concat([
		_sweep(523.0, 523.0, 0.07, 0.3, 3.0, 0.3),
		_sweep(659.0, 659.0, 0.07, 0.3, 3.0, 0.3),
		_sweep(784.0, 784.0, 0.07, 0.3, 3.0, 0.3),
		_sweep(1047.0, 1047.0, 0.25, 0.3, 5.0, 0.3),
	]))
	# Buy: two rising notes. Sell: two falling notes.
	_streams["buy"] = _wav(_concat([
		_sweep(659.0, 659.0, 0.07, 0.3, 3.0, 0.2),
		_sweep(988.0, 988.0, 0.18, 0.3, 6.0, 0.2),
	]))
	_streams["sell"] = _wav(_concat([
		_sweep(784.0, 784.0, 0.07, 0.3, 3.0, 0.2),
		_sweep(523.0, 523.0, 0.18, 0.3, 6.0, 0.2),
	]))
	# Squeak: a short wobbly high chirp, like a sponge on glass.
	_streams["squeak"] = _wav(_mix(_sweep(1900.0, 2600.0, 0.06, 0.18, 4.0, 0.4), _sweep(2600.0, 2100.0, 0.05, 0.12, 6.0, 0.3)))
	# Flush: a long whooshing swirl that drains away.
	_streams["flush"] = _wav(_mix(_noise(1.1, 0.4, 2.5, 0.08), _sweep(420.0, 90.0, 1.0, 0.18, 2.5, 0.2)))
	# Death: a slow sad falling tone.
	_streams["death"] = _wav(_concat([
		_sweep(392.0, 392.0, 0.18, 0.3, 2.0, 0.3),
		_sweep(370.0, 370.0, 0.18, 0.3, 2.0, 0.3),
		_sweep(349.0, 262.0, 0.6, 0.3, 3.0, 0.3),
	]))
	# Sparkle: a twinkly run up.
	_streams["sparkle"] = _wav(_concat([
		_sweep(1319.0, 1319.0, 0.06, 0.25, 4.0, 0.1),
		_sweep(1568.0, 1568.0, 0.06, 0.25, 4.0, 0.1),
		_sweep(1976.0, 1976.0, 0.06, 0.25, 4.0, 0.1),
		_sweep(2637.0, 2637.0, 0.3, 0.25, 6.0, 0.1),
	]))
	# Pat: a soft little "boop boop".
	_streams["pat"] = _wav(_concat([
		_sweep(880.0, 990.0, 0.05, 0.18, 5.0, 0.0),
		_sweep(1175.0, 1320.0, 0.08, 0.16, 6.0, 0.0),
	]))
	# Chomp: a quick crunchy snap.
	_streams["chomp"] = _wav(_mix(_noise(0.12, 0.45, 9.0, 0.3), _sweep(240.0, 90.0, 0.12, 0.35, 8.0, 0.1)))
	# Warning: two low beeps.
	_streams["warn"] = _wav(_concat([
		_sweep(330.0, 330.0, 0.12, 0.3, 2.0, 0.5),
		_sweep(0.0, 0.0, 0.06, 0.0, 1.0, 0.0),
		_sweep(330.0, 330.0, 0.16, 0.3, 3.0, 0.5),
	]))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


# gain: 0..1 relative loudness. min_gap_ms: ignore repeats closer than this.
func play(sound: String, gain := 1.0, min_gap_ms := 45) -> void:
	if volume <= 0.001 or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < min_gap_ms:
		return
	_last_ms[sound] = now
	var p: AudioStreamPlayer = _players[0]
	for q in _players:
		if not q.playing:
			p = q
			break
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(0.0001, volume * gain))
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()


# ---------------------------------------------------------------- synthesis

func _sweep(f0: float, f1: float, dur: float, amp: float, decay: float, harmonic: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / RATE
		var attack := minf(1.0, i / (RATE * 0.004))
		var env := exp(-decay * t) * attack
		out[i] = amp * env * (sin(phase) + harmonic * sin(2.0 * phase))
	return out


func _noise(dur: float, amp: float, decay: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y += (randf_range(-1.0, 1.0) - y) * smooth      # one-pole low-pass
		out[i] = amp * exp(-decay * float(i) / n) * y * 3.0
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
