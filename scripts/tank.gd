# The ASCII fish tank. Simulates and draws everything inside the glass
# on a character grid (positions are in cells, not pixels).
extends Control

signal money_earned(amount: float)
signal sell_requested(fish)

const Data = preload("res://scripts/data.gd")

const MIRROR := {
	"<": ">", ">": "<", "(": ")", ")": "(", "[": "]", "]": "[",
	"{": "}", "}": "{", "/": "\\", "\\": "/", "b": "d", "d": "b", "p": "q", "q": "p",
}
const SAND := ".,_.:',._,.;"
const SNAIL_RIGHT := "_@'"
const SNAIL_LEFT := "'@_"
const CASTLE := [
	"  |  ",
	" [~] ",
	"[o o]",
	"[_n_]",
]

const C_BG := Color("070b14")
const C_WATER_TOP := Color("0c2238")
const C_WATER_BOTTOM := Color("081627")
const C_GLASS := Color("3a6b8a")
const C_SURFACE := Color("5fb3d9")
const C_SAND := Color("c2a46b")
const C_WEED := Color("3fae6a")
const C_FOOD := Color("d98c4a")
const C_BUBBLE := Color(0.7, 0.9, 1.0, 0.7)
const C_SNAIL := Color("e0a96d")
const C_CASTLE := Color("8a8fa3")
const C_FEEDER := Color("9fb3c8")


class Fish extends RefCounted:
	var species: int
	var pos: Vector2          # top-left of the sprite, in cells
	var target: Vector2
	var facing := 1
	var speed := 3.0
	var hunger := 0.0
	var level := 0
	var xp := 0
	var coin_timer := 0.0
	var wander_timer := 0.0
	var phase := 0.0
	var w := 1
	var h := 1
	var anim := 0.0           # animation clock; advances faster while swimming fast
	var blink := 0.0          # >0 while the eyes are closed
	var next_blink := 3.0


var font: Font
var font_size := 16
var cell := Vector2(9, 18)
var cols := 80
var rows := 24
var origin := Vector2.ZERO
var ascent := 14.0

var fishes: Array = []
var foods: Array = []     # {pos, rest}
var coins: Array = []     # {pos, value, landed, life}
var bubbles: Array = []   # {pos, speed, seed}
var popups: Array = []    # {text, pos, life, color}
var snails: Array = []    # {x, dir, speed}
var weeds: Array = []     # {xf, h, phase}
var motes: Array = []     # {pos, vel}

var coin_mult := 1.0
var feeder_level := 0
var has_castle := false

var hovered: Fish = null
var mouse_cell := Vector2(-100, -100)
var time := 0.0
var _feeder_timer := 0.0
var _bubble_timer := 0.0
var _sprites := {}        # species -> {"r": frames, "l": frames, "mr": mask, "ml": mask}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in Data.SPECIES.size():
		_sprites[i] = _build_sprite(Data.SPECIES[i])
	for i in 18:
		motes.append({
			"pos": Vector2(randf() * cols, randf() * rows),
			"vel": Vector2(randf_range(-0.3, 0.3), randf_range(-0.15, 0.15)),
		})
	_recalc_grid()
	resized.connect(_recalc_grid)


# ---------------------------------------------------------------- grid helpers

func _recalc_grid() -> void:
	if font == null:
		return
	cell = Vector2(font.get_char_size(ord("M"), font_size).x, font.get_height(font_size))
	cell.x = max(cell.x, 4.0)
	cell.y = max(cell.y, 8.0)
	ascent = font.get_ascent(font_size)
	cols = max(30, int(size.x / cell.x))
	rows = max(12, int(size.y / cell.y))
	origin = ((size - Vector2(cols, rows) * cell) * 0.5).floor()
	for f in fishes:
		f.pos = _clamp_fish(f, f.pos)
		f.target = _clamp_fish(f, f.target)
	for c in coins:
		c.pos.x = clamp(c.pos.x, 1.0, cols - 2.0)
		c.pos.y = min(c.pos.y, floor_y())
	for fd in foods:
		fd.pos.x = clamp(fd.pos.x, 1.0, cols - 2.0)
		fd.pos.y = min(fd.pos.y, floor_y())
	for s in snails:
		s.x = clamp(s.x, 1.0, cols - 4.0)


func sand_row() -> int:
	return rows - 2


func floor_y() -> float:
	return float(sand_row() - 1)


func _clamp_fish(f: Fish, p: Vector2) -> Vector2:
	return Vector2(
		clamp(p.x, 1.0, max(1.0, cols - 1.0 - f.w)),
		clamp(p.y, 2.0, max(2.0, float(sand_row() - f.h))))


func _random_spot(f: Fish) -> Vector2:
	return _clamp_fish(f, Vector2(randf_range(1, cols - 1 - f.w), randf_range(2, sand_row() - f.h)))


# Trims trailing spaces from every frame, then pads all frames and the mask
# to one shared width so mirroring keeps everything lined up.
static func _build_sprite(sp: Dictionary) -> Dictionary:
	var frames: Array = []
	var w := 0
	for fr in sp.frames:
		var rows_: Array = []
		for r in fr:
			var t := String(r).rstrip(" ")
			rows_.append(t)
			w = max(w, t.length())
		frames.append(rows_)
	var h: int = frames[0].size()
	var right: Array = []
	for fr in frames:
		right.append(_pad(fr, w, h))
	var mask: Array = _pad(sp.get("mask", []), w, h)
	var left: Array = []
	if sp.has("left"):
		for fr in sp.left:
			left.append(_pad(fr, w, h))
	else:
		for fr in right:
			left.append(_mirror(fr))
	var mask_l: Array = []
	for r in mask:
		mask_l.append(String(r).reverse())
	return {"r": right, "l": left, "mr": mask, "ml": mask_l, "w": w, "h": h}


static func _pad(src: Array, w: int, h: int) -> Array:
	var out := []
	for i in h:
		var r := String(src[i]) if i < src.size() else ""
		out.append(r.rpad(w))
	return out


static func _mirror(src: Array) -> Array:
	var out := []
	for r in src:
		var s := String(r)
		var m := ""
		for i in range(s.length() - 1, -1, -1):
			var ch := s[i]
			m += String(MIRROR.get(ch, ch))
		out.append(m)
	return out


# ---------------------------------------------------------------- public API

func add_fish(species: int, level := 0, xp := 0, hunger := 0.2, splash := false) -> Fish:
	var f := Fish.new()
	f.species = species
	f.level = level
	f.xp = xp
	f.hunger = hunger
	var sp: Dictionary = Data.SPECIES[species]
	f.speed = float(sp.speed) * randf_range(0.8, 1.2)
	f.phase = randf() * TAU
	f.coin_timer = randf() * float(sp.interval)
	f.w = _sprites[species].w
	f.h = _sprites[species].h
	f.anim = randf() * 4.0
	f.next_blink = randf_range(1.0, 6.0)
	f.facing = 1 if randf() < 0.5 else -1
	if splash:
		f.pos = _clamp_fish(f, Vector2(randf_range(2, cols - 2 - f.w), 2))
		_popup("*splash*", f.pos + Vector2(f.w * 0.5, -0.5), C_SURFACE)
	else:
		f.pos = _random_spot(f)
	f.target = _random_spot(f)
	fishes.append(f)
	return f


func remove_fish(f: Fish) -> void:
	fishes.erase(f)
	if hovered == f:
		hovered = null


func fish_value(f: Fish) -> float:
	var sp: Dictionary = Data.SPECIES[f.species]
	return max(1.0, round(float(sp.value) * (1.0 + 0.5 * f.level) * coin_mult))


func estimate_rate() -> float:
	var r := 0.0
	for f in fishes:
		if f.hunger < 1.0:
			r += fish_value(f) / float(Data.SPECIES[f.species].interval)
	return r


func set_snails(n: int) -> void:
	while snails.size() < n:
		snails.append({"x": randf_range(2, cols - 5), "dir": 1, "speed": 3.0})
	while snails.size() > n:
		snails.pop_back()


func set_weeds(n: int) -> void:
	weeds.clear()
	for i in n:
		weeds.append({
			"xf": fmod(0.17 + i * 0.377, 0.86) + 0.06,
			"h": 3 + (i * 7) % 5,
			"phase": float(i) * 1.3,
		})


func serialize_fish() -> Array:
	var out := []
	for f in fishes:
		out.append({"s": f.species, "lv": f.level, "xp": f.xp, "hg": snappedf(f.hunger, 0.001)})
	return out


func drop_food(p: Vector2) -> void:
	if foods.size() >= 24:
		return
	foods.append({"pos": Vector2(clamp(p.x, 1.0, cols - 2.0), max(p.y, 2.0)), "rest": 0.0})


# ---------------------------------------------------------------- simulation

func _process(dt: float) -> void:
	time += dt
	_update_fish(dt)
	_update_food(dt)
	_update_coins(dt)
	_update_snails(dt)
	_update_bubbles(dt)
	_update_feeder(dt)
	_update_misc(dt)
	_update_hover()
	queue_redraw()


func _update_fish(dt: float) -> void:
	for f: Fish in fishes:
		var sp: Dictionary = Data.SPECIES[f.species]
		f.hunger = min(1.0, f.hunger + dt / Data.HUNGER_TIME)
		var spd := f.speed
		var chasing := false

		# Hungry fish chase the nearest food.
		if f.hunger > 0.35 and not foods.is_empty():
			var center := f.pos + Vector2(f.w, f.h) * 0.5
			var best = null
			var best_d := INF
			for fd in foods:
				var d: float = center.distance_squared_to(fd.pos)
				if d < best_d:
					best_d = d
					best = fd
			if best != null:
				f.target = _clamp_fish(f, best.pos - Vector2(f.w, f.h) * 0.5)
				spd *= 1.7
				chasing = true

		f.wander_timer -= dt
		f.anim += dt * 0.6                      # slow idle wag even when still
		f.blink -= dt
		f.next_blink -= dt
		if f.next_blink <= 0.0:
			f.blink = 0.15
			f.next_blink = randf_range(2.5, 7.0)
		if not chasing and (f.pos.distance_to(f.target) < 0.5 or f.wander_timer <= 0.0):
			f.target = _random_spot(f)
			f.wander_timer = randf_range(3.0, 9.0)

		var dir := f.target - f.pos
		var dist := dir.length()
		if dist > 0.01:
			# Fish move mostly sideways; vertical movement is slower.
			var step: Vector2 = dir / dist * minf(dist, spd * dt)
			step.y *= 0.6
			f.pos += step
			f.anim += step.length() * 0.9     # tail wags with distance swum
			if abs(dir.x) > 0.3:
				f.facing = 1 if dir.x > 0 else -1

		# Eat food touching the sprite.
		var rect := Rect2(f.pos - Vector2(0.6, 0.6), Vector2(f.w, f.h) + Vector2(1.2, 1.2))
		for i in range(foods.size() - 1, -1, -1):
			if f.hunger > 0.05 and rect.has_point(foods[i].pos):
				foods.remove_at(i)
				_eat(f)
				break

		# Drop coins while not starving.
		if f.hunger < 1.0:
			f.coin_timer += dt
			if f.coin_timer >= float(sp.interval):
				f.coin_timer = 0.0
				coins.append({
					"pos": f.pos + Vector2(f.w * 0.5, f.h * 0.5),
					"value": fish_value(f), "landed": false, "life": 90.0,
				})


func _eat(f: Fish) -> void:
	f.hunger = max(0.0, f.hunger - Data.FOOD_VALUE)
	if f.level >= Data.MAX_LEVEL:
		return
	f.xp += 1
	if f.xp >= Data.xp_needed(f.level):
		f.xp = 0
		f.level += 1
		_popup("LVL %d!" % f.level, f.pos + Vector2(f.w * 0.5, -0.6), Color("9dff9d"))


func _update_food(dt: float) -> void:
	for i in range(foods.size() - 1, -1, -1):
		var fd: Dictionary = foods[i]
		if fd.pos.y < floor_y():
			fd.pos.y = min(floor_y(), fd.pos.y + 1.6 * dt)
			fd.pos.x += sin(time * 3.0 + fd.pos.y) * 0.4 * dt
		else:
			fd.rest += dt
			if fd.rest > 25.0:
				foods.remove_at(i)


func _update_coins(dt: float) -> void:
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		if not c.landed:
			c.pos.y += 3.0 * dt
			if c.pos.y >= floor_y():
				c.pos.y = floor_y()
				c.landed = true
		else:
			c.life -= dt
			if c.life <= 0.0:
				coins.remove_at(i)


func _update_snails(dt: float) -> void:
	var claimed := []   # each snail goes after a different coin
	for s in snails:
		var target_x := -1.0
		var target = null
		var best := INF
		for c in coins:
			if (c.landed or c.pos.y > floor_y() - 1.5) and not claimed.has(c):
				var d: float = abs(c.pos.x - (s.x + 1.0))
				if d < best:
					best = d
					target_x = c.pos.x
					target = c
		if target != null:
			claimed.append(target)
		if target_x >= 0.0:
			s.dir = 1 if target_x > s.x + 1.0 else -1
		elif s.x <= 1.5:
			s.dir = 1
		elif s.x >= cols - 5.0:
			s.dir = -1
		s.x = clamp(s.x + s.dir * s.speed * dt, 1.0, cols - 4.0)
		# Collect anything under the snail.
		for i in range(coins.size() - 1, -1, -1):
			var c: Dictionary = coins[i]
			if c.pos.y > floor_y() - 1.5 and abs(c.pos.x - (s.x + 1.0)) < 1.6:
				_collect(i)


func _update_bubbles(dt: float) -> void:
	_bubble_timer -= dt
	if _bubble_timer <= 0.0:
		_bubble_timer = randf_range(0.3, 1.1)
		var bx := float(max(2, int(cols * 0.07)))
		bubbles.append({"pos": Vector2(bx + randf_range(-0.4, 0.4), floor_y()),
			"speed": randf_range(2.0, 3.5), "seed": randf() * TAU})
		# Occasionally a fish burps a bubble.
		if not fishes.is_empty() and randf() < 0.25:
			var f: Fish = fishes.pick_random()
			var mouth_x: float = f.pos.x + (f.w if f.facing > 0 else -1.0)
			bubbles.append({"pos": Vector2(mouth_x, f.pos.y), "speed": randf_range(1.5, 2.5), "seed": randf() * TAU})
	for i in range(bubbles.size() - 1, -1, -1):
		var b: Dictionary = bubbles[i]
		b.pos.y -= b.speed * dt
		b.pos.x += sin(time * 4.0 + b.seed) * 0.5 * dt
		if b.pos.y < 1.6:
			bubbles.remove_at(i)


func _update_feeder(dt: float) -> void:
	if feeder_level <= 0:
		return
	_feeder_timer += dt
	var interval: float = Data.FEEDER_INTERVAL[min(feeder_level, Data.FEEDER_INTERVAL.size() - 1)]
	if _feeder_timer < interval:
		return
	var anyone_hungry := false
	for f in fishes:
		if f.hunger > 0.4:
			anyone_hungry = true
			break
	if anyone_hungry:
		_feeder_timer = 0.0
		var fx := _feeder_x() + 1.5
		for k in 2:
			drop_food(Vector2(fx + randf_range(-1.0, 1.0), 2.0))


func _feeder_x() -> float:
	return floor(cols * 0.82)


func _update_misc(dt: float) -> void:
	for i in range(popups.size() - 1, -1, -1):
		var p: Dictionary = popups[i]
		p.life -= dt
		p.pos.y -= 1.2 * dt
		if p.life <= 0.0:
			popups.remove_at(i)
	for m in motes:
		m.pos += m.vel * dt
		if m.pos.x < 1: m.pos.x = cols - 2
		if m.pos.x > cols - 2: m.pos.x = 1
		if m.pos.y < 2: m.pos.y = sand_row() - 1
		if m.pos.y > sand_row() - 1: m.pos.y = 2


func _update_hover() -> void:
	hovered = _fish_at(mouse_cell)


func _fish_at(p: Vector2) -> Fish:
	for i in range(fishes.size() - 1, -1, -1):
		var f: Fish = fishes[i]
		if Rect2(f.pos - Vector2(0.3, 0.3), Vector2(f.w, f.h) + Vector2(0.6, 0.6)).has_point(p):
			return f
	return null


func _collect(i: int) -> void:
	var c: Dictionary = coins[i]
	coins.remove_at(i)
	money_earned.emit(c.value)
	_popup("+$" + Data.fmt(c.value), c.pos + Vector2(0, -0.6), Color("ffd84d"))


func _popup(text: String, p: Vector2, color: Color) -> void:
	popups.append({"text": text, "pos": p, "life": 1.2, "color": color})


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mouse_cell = (event.position - origin) / cell
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_collect_near(mouse_cell)   # drag over coins to scoop them up
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _collect_near(mouse_cell) == 0:
				if mouse_cell.y > 1.5 and mouse_cell.y < sand_row() and mouse_cell.x > 1 and mouse_cell.x < cols - 1:
					drop_food(mouse_cell - Vector2(0.5, 0.5))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var f := _fish_at(mouse_cell)
			if f != null:
				sell_requested.emit(f)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse_cell = Vector2(-100, -100)


func _collect_near(p: Vector2) -> int:
	var n := 0
	for i in range(coins.size() - 1, -1, -1):
		if (coins[i].pos + Vector2(0.5, 0.5)).distance_to(p) < 1.6:
			_collect(i)
			n += 1
	return n


# ---------------------------------------------------------------- drawing

func _put(x: float, y: float, text: String, color: Color) -> void:
	# One glyph per grid cell: keeps everything aligned and avoids font ligatures.
	var base := origin + Vector2(x * cell.x, y * cell.y + ascent)
	for i in text.length():
		var ch := text[i]
		if ch != " ":
			draw_char(font, base + Vector2(i * cell.x, 0).round(), ch, font_size, color)


func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	# Water, a little darker toward the bottom.
	var water_rows := sand_row() - 1
	for r in water_rows:
		var t: float = float(r) / maxf(1.0, water_rows - 1.0)
		draw_rect(Rect2(origin + Vector2(cell.x, (r + 1) * cell.y), Vector2((cols - 2) * cell.x, cell.y)),
			C_WATER_TOP.lerp(C_WATER_BOTTOM, t))

	# Drifting specks in the water.
	for m in motes:
		_put(m.pos.x, m.pos.y, ".", Color(0.6, 0.8, 1.0, 0.18))

	# Glass.
	var inner := cols - 2
	_put(0, 0, "+" + "-".repeat(inner) + "+", C_GLASS)
	_put(0, rows - 1, "+" + "-".repeat(inner) + "+", C_GLASS)
	for r in range(1, rows - 1):
		_put(0, r, "|", C_GLASS)
		_put(cols - 1, r, "|", C_GLASS)

	# Water surface.
	var surf := ""
	var shift := int(time * 3.0)
	for i in inner:
		var fx := int(_feeder_x()) - 1
		if feeder_level > 0 and i >= fx and i < fx + 4:
			surf += " "   # leave a gap for the feeder
		else:
			surf += "~" if (i + shift) % 5 < 3 else "-"
	_put(1, 1, surf, C_SURFACE)

	# Sand.
	var sand := ""
	for i in inner:
		sand += SAND[(i * 7 + i * i * 3) % SAND.length()]
	_put(1, sand_row(), sand, C_SAND)

	# Seaweed.
	for wd in weeds:
		var x: float = clamp(floor(wd.xf * cols), 2.0, cols - 3.0)
		var h: int = min(int(wd.h), sand_row() - 3)
		for k in h:
			var ch := "(" if (k + int(time * 1.5 + wd.phase)) % 2 == 0 else ")"
			_put(x, sand_row() - 1 - k, ch, C_WEED.lerp(Color("8be0a4"), float(k) / max(1, h)))

	# Castle.
	if has_castle:
		var cx: float = floor(cols * 0.62)
		for k in CASTLE.size():
			_put(cx, sand_row() - CASTLE.size() + k, CASTLE[k], C_CASTLE)
		_put(cx + 3, sand_row() - CASTLE.size(), ">" if int(time * 2.0) % 2 == 0 else "}", Color("ff6f6f"))

	# Auto-feeder hanging at the surface.
	if feeder_level > 0:
		_put(_feeder_x(), 1, "[::]", C_FEEDER)

	for fd in foods:
		_put(fd.pos.x, fd.pos.y, "*", C_FOOD)

	for b in bubbles:
		var prog: float = 1.0 - (b.pos.y - 2.0) / max(1.0, floor_y() - 2.0)
		var ch := "." if prog < 0.3 else ("o" if prog < 0.75 else "O")
		_put(b.pos.x, b.pos.y, ch, C_BUBBLE)

	for c in coins:
		if c.landed and c.life < 15.0 and fmod(time, 0.5) < 0.2:
			continue
		var v: float = c.value
		if v >= 1000.0:
			_put(c.pos.x, c.pos.y, "<>", Color("7ff9ff"))
		else:
			var col := Color("c87533") if v < 10.0 else (Color("d8dde6") if v < 100.0 else Color("ffd84d"))
			_put(c.pos.x, c.pos.y, "$", col)

	for s in snails:
		_put(s.x, floor_y(), SNAIL_RIGHT if s.dir > 0 else SNAIL_LEFT, C_SNAIL)

	for f: Fish in fishes:
		_draw_fish(f)

	for p in popups:
		var a: float = clamp(p.life / 0.6, 0.0, 1.0)
		var col: Color = p.color
		col.a = a
		_put(p.pos.x - String(p.text).length() * 0.5, p.pos.y, p.text, col)


func _draw_fish(f: Fish) -> void:
	var sp: Dictionary = Data.SPECIES[f.species]
	var spr_data: Dictionary = _sprites[f.species]
	var frames: Array = spr_data.r if f.facing > 0 else spr_data.l
	var spr: Array = frames[int(f.anim) % frames.size()]
	var mask: Array = spr_data.mr if f.facing > 0 else spr_data.ml

	var body: Color = sp.color
	var accent: Color = sp.get("accent", body)
	var eye := Color("ffffff")
	var dim := 0.0
	if f.hunger >= 1.0:
		dim = 0.7
	elif f.hunger > 0.7:
		dim = 0.3
	var gray := Color("555c66")
	var palette := {
		" ": body, "a": accent, "d": body.darkened(0.4), "l": body.lightened(0.35), "e": eye,
	}
	for key in palette:
		var c: Color = palette[key]
		c = c.lerp(gray, dim)
		if f == hovered:
			c = c.lightened(0.3)
		palette[key] = c

	var bob := sin(time * 2.0 + f.phase) * 0.12
	var blinking := f.blink > 0.0 or f.hunger >= 1.0
	for k in spr.size():
		var row: String = spr[k]
		var mrow: String = mask[k]
		var base := origin + Vector2(f.pos.x * cell.x, (f.pos.y + k + bob) * cell.y + ascent)
		for i in row.length():
			var ch := row[i]
			if ch == " ":
				continue
			var m := mrow[i]
			if m == "e" and blinking:
				ch = "-"
			draw_char(font, base + Vector2(i * cell.x, 0).round(), ch, font_size, palette.get(m, palette[" "]))

	# Hunger / starving marker above the head.
	var head_x := f.pos.x + (f.w - 1 if f.facing > 0 else 0)
	if f.hunger >= 1.0:
		_put(head_x, f.pos.y - 1 + bob, "!", Color("ff5c5c"))
	elif f.hunger > 0.7:
		_put(head_x, f.pos.y - 1 + bob, "?", Color("ffcf5c"))
	if f == hovered and f.level > 0:
		_put(f.pos.x, f.pos.y + spr.size() + bob, "*".repeat(f.level), Color("9dff9d"))
