# Grime on the tank glass: a coarse grid of how dirty each spot is (0..1).
# The grid is stretched over the water, so it survives window resizes.
#
# Growth spreads like algae: new grime mostly appears next to existing grime,
# a fixed random texture makes some spots grow faster than others, and the
# bottom, the sides and the waterline get dirty first. Every tank gets
# dirty differently.
#
# Old grime gets "hard" and takes more scrubbing to remove.
extends RefCounted

const W := 72
const H := 28
const FULL_SECONDS := 6000.0       # spotless -> fully covered: about 1.7 h of play
const HARDEN_SECONDS := 1500.0     # how long grime takes to become fully stubborn

var d := PackedFloat32Array()      # dirt per cell, 0..1
var hard := PackedFloat32Array()   # stubbornness per cell, 0..1
var level := 0.0                   # average dirt over the whole glass
var rate_mult := 1.0               # <1 with filters, >1 with dead fish in the tank
var _w0 := PackedFloat32Array()    # where grime likes to grow (position x texture)
var _wbuf := PackedFloat32Array()


func _init() -> void:
	d.resize(W * H)
	hard.resize(W * H)
	_wbuf.resize(W * H)
	_make_texture()


# A new random layout for where grime grows fastest.
func _make_texture() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	_w0.resize(W * H)
	for y in H:
		for x in W:
			var n := noise.get_noise_2d(x, y * 1.8) * 0.5 + 0.5          # 0..1
			_w0[y * W + x] = _bias(x, y) * (0.15 + 1.85 * n * n)


# Bottom, sides and the waterline get dirty first.
func _bias(x: int, y: int) -> float:
	var u := float(x) / (W - 1)
	var v := float(y) / (H - 1)
	var edge := 1.0 - minf(u, 1.0 - u) * 2.0
	var b := 0.45 + 1.3 * v * v + 0.9 * edge * edge * edge
	if y <= 1:
		b += 0.8
	return b


func clear() -> void:
	d.fill(0.0)
	hard.fill(0.0)
	level = 0.0
	_make_texture()


# Add grime for dt seconds. Stops once the average reaches cap.
func grow(dt: float, cap := 1.0) -> void:
	if dt <= 0.0 or level >= cap:
		return
	var total := 0.0
	for y in H:
		for x in W:
			var i := y * W + x
			var v := d[i]
			if v >= 1.0:
				_wbuf[i] = 0.0
				continue
			var nb := 0.0
			if x > 0: nb += d[i - 1]
			if x < W - 1: nb += d[i + 1]
			if y > 0: nb += d[i - W]
			if y < H - 1: nb += d[i + W]
			var w := _w0[i] * (0.06 + nb * 0.45 + v * 0.4) * (1.0 - v * 0.7)
			_wbuf[i] = w
			total += w
	if total <= 0.0:
		return
	var k := dt / FULL_SECONDS * rate_mult * float(W * H) / total
	var sum := 0.0
	var harden := dt / HARDEN_SECONDS
	for i in W * H:
		var v := minf(1.0, d[i] + _wbuf[i] * k)
		d[i] = v
		sum += v
		if v > 0.45:
			hard[i] = minf(1.0, hard[i] + harden)
	level = sum / float(W * H)
	# Now and then a fresh spore lands somewhere and starts its own patch.
	if randf() < dt * 0.04:
		_spore()


func _spore() -> void:
	# Pick a few random spots and keep the one that grows best.
	var best := 0
	var best_w := -1.0
	for t in 6:
		var i := randi() % (W * H)
		if _w0[i] > best_w:
			best_w = _w0[i]
			best = i
	var cx := best % W
	var cy := best / W
	for y in range(maxi(0, cy - 2), mini(H, cy + 3)):
		for x in range(maxi(0, cx - 3), mini(W, cx + 4)):
			var f := 1.0 - (Vector2(x - cx, (y - cy) * 1.5).length() / 3.6)
			if f > 0.0:
				var i := y * W + x
				d[i] = minf(1.0, d[i] + 0.3 * f)


# While the game was closed: grow in big steps, but never past cap.
func grow_offline(secs: float, cap: float) -> void:
	var step := 120.0
	while secs > 0.0 and level < cap:
		grow(minf(step, secs), cap)
		secs -= step


# Dirt at a point given in 0..1 across / down the glass (smoothly blended).
func sample(u: float, v: float) -> float:
	var fx := clampf(u * W - 0.5, 0.0, W - 1.0)
	var fy := clampf(v * H - 0.5, 0.0, H - 1.0)
	var x0 := int(fx)
	var y0 := int(fy)
	var x1 := mini(x0 + 1, W - 1)
	var y1 := mini(y0 + 1, H - 1)
	var tx := fx - x0
	var ty := fy - y0
	var a := lerpf(d[y0 * W + x0], d[y0 * W + x1], tx)
	var b := lerpf(d[y1 * W + x0], d[y1 * W + x1], tx)
	return lerpf(a, b, ty)


# Scrub along a stroke from a to b (0..1 coordinates). r is the sponge's
# radius (0..1 across / down). power: how much of the grime one pass takes
# at the sponge's center. smear: share of what comes off that gets pushed
# ahead of the stroke instead of into the sponge. Returns how much dirt
# ended up in the sponge.
func wipe(a: Vector2, b: Vector2, r: Vector2, power: float, smear: float) -> float:
	var ga := Vector2(a.x * W, a.y * H)
	var gb := Vector2(b.x * W, b.y * H)
	var gr := Vector2(maxf(0.8, r.x * W), maxf(0.8, r.y * H))
	var dir := gb - ga
	var length := dir.length()
	dir = dir / length if length > 0.001 else Vector2.ZERO
	var steps := maxi(1, int(ceil(length / (minf(gr.x, gr.y) * 0.6))))
	var taken := 0.0
	for s in steps:
		var p := ga.lerp(gb, float(s + 1) / steps)
		var pushed := 0.0
		for y in range(maxi(0, int(p.y - gr.y)), mini(H, int(p.y + gr.y) + 1)):
			for x in range(maxi(0, int(p.x - gr.x)), mini(W, int(p.x + gr.x) + 1)):
				var q := Vector2((x + 0.5 - p.x) / gr.x, (y + 0.5 - p.y) / gr.y).length_squared()
				if q >= 1.0:
					continue
				var f := 1.0 - q * q            # flat in the middle, soft at the rim
				var i := y * W + x
				var take := d[i] * power / float(steps) * f / (1.0 + 1.2 * hard[i])
				d[i] -= take
				taken += take
				pushed += take * smear
				if d[i] < 0.03:
					hard[i] = 0.0
		# The smeared part lands just past the front edge of the sponge.
		if pushed > 0.0 and dir != Vector2.ZERO:
			_deposit(p + dir * gr * 1.3, gr * 0.7, pushed)
	_recount()
	return taken * (1.0 - smear)


# A plain scrub at one spot (algae eaters).
func nibble(at: Vector2, r: Vector2, power: float) -> void:
	wipe(at, at, r, power, 0.0)


func _deposit(p: Vector2, r: Vector2, amount: float) -> void:
	var cells := []
	var weight := 0.0
	for y in range(maxi(0, int(p.y - r.y)), mini(H, int(p.y + r.y) + 1)):
		for x in range(maxi(0, int(p.x - r.x)), mini(W, int(p.x + r.x) + 1)):
			var f := 1.0 - Vector2((x + 0.5 - p.x) / r.x, (y + 0.5 - p.y) / r.y).length_squared()
			if f > 0.0:
				cells.append([y * W + x, f])
				weight += f
	for c in cells:
		var i: int = c[0]
		d[i] = minf(1.0, d[i] + amount * c[1] / weight)


func _recount() -> void:
	var sum := 0.0
	for v in d:
		sum += v
	level = sum / float(W * H)


func serialize() -> Dictionary:
	var a := PackedByteArray()
	a.resize(W * H * 2)
	for i in W * H:
		a[i] = int(round(clampf(d[i], 0.0, 1.0) * 255.0))
		a[W * H + i] = int(round(clampf(hard[i], 0.0, 1.0) * 255.0))
	return {"w": W, "h": H, "data": Marshalls.raw_to_base64(a)}


func load_from(saved) -> void:
	clear()
	if typeof(saved) != TYPE_DICTIONARY or int(saved.get("w", 0)) != W or int(saved.get("h", 0)) != H:
		return
	var a := Marshalls.base64_to_raw(String(saved.get("data", "")))
	if a.size() != W * H * 2:
		return
	for i in W * H:
		d[i] = a[i] / 255.0
		hard[i] = a[W * H + i] / 255.0
	_recount()
