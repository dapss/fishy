# The ASCII fish tank. Simulates and draws everything inside the glass
# on a character grid (positions are in cells, not pixels).
extends Control

signal money_earned(amount: float, coins: int, by_snail: bool)
signal fish_opened(fish)              # right-clicked or double-clicked a fish
signal sfx(sound: String, gain: float)
signal fish_died(fish)                # dirty water killed a fish
signal spotless                       # scrubbed a dirty tank completely clean
signal fish_eaten(prey, hunter)       # a shark ate a guppy
signal food_out(kind)                 # wanted to drop a food that's sold out

const Data = preload("res://scripts/data.gd")
const Dirt = preload("res://scripts/dirt.gd")

const MIRROR := {
	"<": ">", ">": "<", "(": ")", ")": "(", "[": "]", "]": "[",
	"{": "}", "}": "{", "/": "\\", "\\": "/", "b": "d", "d": "b", "p": "q", "q": "p",
}
const SAND := ".,_.:',._,.;"
const MIN_ROWS := 12
const MIN_COLS := 34
const MIN_FONT := 9
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
const C_SAND := Color("8a7550")
const C_WEED := Color("2a6b48")
const C_WEED_TIP := Color("4a9168")
const C_FOOD := Color("d98c4a")
const C_BUBBLE := Color(0.7, 0.9, 1.0, 0.4)
const C_SNAIL := Color("ff9f6b")
const C_CASTLE := Color("5d6377")
const C_COPPER := Color("d08a4a")
const C_SILVER := Color("dfe6f0")
const C_GOLD := Color("ffd84d")
const C_GEM := Color("7ff9ff")
const C_FEEDER := Color("9fb3c8")
const C_ALGAE := Color("6b8a3a")
const C_GRIME := Color("4a4128")
const C_SICK := Color("8fd16b")
const C_DEAD := Color("6c7480")
const C_BONE := Color("d8d2c0")
const C_CHOMP := Color("ff6b6b")
const HUNT_AT := 0.5              # sharks hunt once this hungry: about a guppy a minute
# Algae eaters: how much glass they scrape (cells), how hard, and how much
# the grime they eat fills them up.
const GRAZE_RADIUS := Vector2(2.2, 1.5)
const GRAZE_POWER := 0.5
const GRAZE_FOOD := 0.06
const GRAZE_DONE := 0.08          # grime thinner than this isn't worth staying for
const FULL_ENOUGH := 0.05         # a Dawa this close to fully happy counts as full
const GRIME := [".", ".,", ":;", ";%", "%&", "#&%", "#@&"]
# Sponge physics. Speeds are in cells per second.
const SPONGE_POWER := 0.75        # share of the grime one slow pass takes
const SPONGE_FAST := 45.0         # strokes faster than this mostly skim
const SPONGE_LOAD_PER_DIRT := 1.0 / 350.0
const SPONGE_RADIUS := Vector2(1.9, 1.25)
const SPOTLESS_BELOW := 0.03       # scrub below this and the rest wipes off: sparkling!


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
	var nickname := ""
	var sick := false
	var drain := 0.0          # time spent sick in filthy water (level loss)
	var dead := false
	var revive_left := 0.0    # seconds left to revive (counts only while running)
	var skeleton := false     # too late to revive; can only be flushed
	var weak := 0.0           # just revived: no coins for a while
	var pat_dist := 0.0       # Dawa: how far the mouse has stroked it since the last pat
	var pats := 0
	var overload := 0         # pats in a row while already fully happy
	var last_pat := -99.0
	var super_time := 0.0     # super happy: coins twice as often
	var super_cd := 0.0       # until it can get super happy again
	var grazed: Array = []    # algae eater: spots it just finished, {p, t}, to skip for a while
	var graze_face := 0       # algae eater: which way to face at its target (mouth to the grime)


var font: Font
var base_font_size := 16      # wanted size; font_size may shrink to fit
var font_size := 16
var cell := Vector2(9, 18)
var cols := 80
var rows := 24
var origin := Vector2.ZERO
var ascent := 14.0

var fishes: Array = []
var foods: Array = []     # {pos, rest, kind}
var food_stock := {}      # paid food kind -> pieces in stock (the main scene saves it)
var food_choice := "auto" # what a click drops: "auto" (what nearby fish need) or a kind
var gourmet_time := 0.0   # treat: double XP
var golden_time := 0.0    # treat: coins worth more
var _out_warned := {}     # kind -> time of the last "sold out" warning
var sparks: Array = []    # fireworks: {pos, vel, life, glyph, color} (+ drag, grav, sway, hue)
var rockets: Array = []   # super happy fireworks on their way up: {pos, vel, fuse, hue}
var confetti_time := 0.0  # super happy: confetti rains down over the tank while > 0
var _confetti_acc := 0.0
var flashes: Array = []   # {pos (cells), life}
var _mood_sprites := {}   # species -> mood -> sprite (the droopy Dawa)
var coins: Array = []     # {pos, value, landed, life}
var bubbles: Array = []   # {pos, speed, seed}
var popups: Array = []    # {text, pos, life, color}
var snails: Array = []    # {x, dir, speed}
var weeds: Array = []     # {xf, h, phase}
var motes: Array = []     # {pos, vel}

var coin_mult := 1.0
var feeder_level := 0
var has_castle := false
var transparent_outside := false   # don't paint the area around the glass
var player_food := 0               # pellets the player dropped (read and reset by stats)

var dirt := Dirt.new()
var dirt_enabled := true
var deaths_enabled := true
var dirt_rate_mult := 1.0          # filters and the UV lamp make this smaller
var clean_mode := false
var sponge_load := 0.0             # 0 clean .. 1 so full of grime it barely cleans
var boost_time := 0.0              # spotless bonus
var full_time := 0.0               # how long the tank has been fully covered
var _dirt_t := 0.0
var _dirt_peak := 0.0              # dirtiest it got since the last spotless clean
var _scrubbing := false
var sponge_level := 0             # Big sponge upgrade
var _sponge_shown := Vector4i(-1, -1, -1, -1)
var _sponge_cursors := {}         # Vector4i(load bucket, cell w, cell h, level) -> ImageTexture

# Grime is drawn on its own layer, which is only redrawn when the grime
# changes: thousands of cells every frame made dirty tanks slow. Things that
# must show above the grime go on the top layer, redrawn every frame.
var _dirt_layer: Control
var _top_layer: Control
var _ci: CanvasItem = self          # where _put draws
var _dirt_sig := []
var _dirt_wait := 0.0
var _glyphs := {}                   # grime char -> [texture, uv, offset, size]
var _glyphs_for := Vector2i(-1, -1)
var _tint_img: Image
var _tint_tex: ImageTexture

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
		var moods: Dictionary = Data.SPECIES[i].get("moods", {})
		if not moods.is_empty():
			_mood_sprites[i] = {}
			for m in moods:
				_mood_sprites[i][m] = _build_sprite(moods[m])
	for i in 18:
		motes.append({
			"pos": Vector2(randf() * cols, randf() * rows),
			"vel": Vector2(randf_range(-0.3, 0.3), randf_range(-0.15, 0.15)),
		})
	_dirt_layer = _make_layer(_draw_dirt_layer)
	_top_layer = _make_layer(_draw_top)
	_recalc_grid()
	resized.connect(_recalc_grid)


func _make_layer(painter: Callable) -> Control:
	var l := Control.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.draw.connect(painter)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	return l


# ---------------------------------------------------------------- grid helpers

func _recalc_grid() -> void:
	if font == null:
		return
	# Use the wanted size, but step down until the tank fits a minimum grid,
	# so small widget windows don't cut off the sand.
	font_size = base_font_size
	while font_size > MIN_FONT and (size.y < MIN_ROWS * font.get_height(font_size) \
			or size.x < MIN_COLS * font.get_char_size(ord("M"), font_size).x):
		font_size -= 1
	cell = Vector2(font.get_char_size(ord("M"), font_size).x, font.get_height(font_size))
	cell.x = max(cell.x, 4.0)
	cell.y = max(cell.y, 8.0)
	ascent = font.get_ascent(font_size)
	cols = max(MIN_COLS, int(size.x / cell.x))
	rows = max(MIN_ROWS, int(size.y / cell.y))
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
	for i in snails.size():
		var lane := _snail_lane(i)
		snails[i].x = clamp(snails[i].x, max(1.0, lane.x - 1.0), min(cols - 4.0, max(lane.x - 1.0, lane.y - 2.0)))
		snails[i].target = null


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
		sfx.emit("splash", 1.0)
	else:
		f.pos = _random_spot(f)
	f.target = _random_spot(f)
	fishes.append(f)
	return f


# Empties the tank (used when the player resets their save).
func reset() -> void:
	dirt.clear()
	full_time = 0.0
	boost_time = 0.0
	gourmet_time = 0.0
	golden_time = 0.0
	for k in food_stock:
		food_stock[k] = 0
	food_choice = "auto"
	sponge_load = 0.0
	_dirt_peak = 0.0
	fishes.clear()
	foods.clear()
	coins.clear()
	popups.clear()
	sparks.clear()
	flashes.clear()
	rockets.clear()
	confetti_time = 0.0
	snails.clear()
	hovered = null


func remove_fish(f: Fish) -> void:
	fishes.erase(f)
	if hovered == f:
		hovered = null


func fish_value(f: Fish) -> float:
	var sp: Dictionary = Data.SPECIES[f.species]
	return max(1.0, round(float(sp.value) * (1.0 + 0.5 * f.level) * coin_mult * water_mult()))


# Dirty water earns less; a freshly scrubbed tank earns a bit more.
func water_mult() -> float:
	var m := Data.dirt_penalty(dirt.level) if dirt_enabled else 1.0
	if boost_time > 0.0:
		m *= Data.SPARKLE_BONUS
	if golden_time > 0.0:
		m *= Data.GOLDEN_BONUS
	return m


func estimate_rate() -> float:
	var r := 0.0
	for f in fishes:
		if f.hunger < 1.0 and not f.dead and f.weak <= 0.0:
			r += fish_value(f) / coin_interval(f)
	return r


func living() -> int:
	var n := 0
	for f in fishes:
		if not f.dead:
			n += 1
	return n


func dirt_level() -> float:
	return dirt.level if dirt_enabled else 0.0


# Seconds until the next fish dies, or -1 if nothing is about to die.
func death_countdown() -> float:
	if not deaths_enabled or full_time <= 0.0 or not _someone_can_die():
		return -1.0
	return maxf(0.0, Data.DEATH_AFTER - full_time)


func _someone_can_die() -> bool:
	return living() > 1


func kill(f: Fish) -> void:
	f.dead = true
	f.sick = false
	f.revive_left = Data.REVIVE_WINDOW
	f.target = Vector2(f.pos.x, 2.0)
	_popup("x_x", f.pos + Vector2(f.w * 0.5, -0.6), C_DEAD)
	sfx.emit("death", 1.0)
	fish_died.emit(f)


func revive(f: Fish) -> void:
	f.dead = false
	f.skeleton = false
	f.sick = false
	f.level = maxi(0, f.level - 1)
	f.xp = 0
	f.hunger = 0.3
	f.weak = Data.REVIVE_WEAK
	f.target = _random_spot(f)
	_popup("revived!", f.pos + Vector2(f.w * 0.5, -0.6), Color("9dff9d"))
	sfx.emit("level", 1.0)


func cure(f: Fish) -> void:
	f.sick = false
	f.drain = 0.0
	_popup("cured!", f.pos + Vector2(f.w * 0.5, -0.6), Color("9dff9d"))


func set_clean_mode(on: bool) -> void:
	clean_mode = on
	_scrubbing = false
	_update_cursor()


func set_snails(n: int) -> void:
	while snails.size() > n:
		snails.pop_back()
	while snails.size() < n:
		snails.append({"x": 2.0, "dir": 1, "speed": 4.0, "target": null,
			"rest": 0.0, "idle_x": 2.0, "moving": false})
	# Lanes changed: start every snail in the middle of its lane.
	for i in snails.size():
		var lane := _snail_lane(i)
		snails[i].x = clamp((lane.x + lane.y) * 0.5 - 1.0, 1.0, cols - 4.0)
		snails[i].target = null
		snails[i].rest = 0.0


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
		var e := {"s": f.species, "lv": f.level, "xp": f.xp, "hg": snappedf(f.hunger, 0.001), "n": f.nickname}
		if f.sick:
			e["sick"] = true
		if f.dead:
			e["dead"] = snappedf(f.revive_left, 0.1)
			e["bones"] = f.skeleton
		out.append(e)
	return out


# Drops one piece of food; paid food comes out of the stock. False when
# there's none left (or the water is full of food already).
func drop_food(p: Vector2, kind := "flakes") -> bool:
	if not Data.FOODS.has(kind) or foods.size() >= 24:
		return false
	if kind != "flakes":
		if int(food_stock.get(kind, 0)) <= 0:
			_warn_out(kind)
			return false
		food_stock[kind] = int(food_stock[kind]) - 1
	foods.append({"pos": Vector2(clamp(p.x, 1.0, cols - 2.0), max(p.y, 2.0)), "rest": 0.0, "kind": kind})
	return true


func _warn_out(kind: String) -> void:
	if time - float(_out_warned.get(kind, -999.0)) > 30.0:
		_out_warned[kind] = time
		food_out.emit(kind)


# The food this fish eats if it's something you drop, else "".
static func drop_food_of(f) -> String:
	var k := Data.food_of(f.species)
	return k if Data.FOODS.has(k) else ""


# What a click at p drops: the chosen food, or what the hungriest fish
# nearby eats.
func food_for_click(p: Vector2) -> String:
	if food_choice != "auto":
		return food_choice
	var best := ""
	var best_score := INF
	for f: Fish in fishes:
		var k := drop_food_of(f)
		if f.dead or k == "":
			continue
		var d := p.distance_to(f.pos + Vector2(f.w, f.h) * 0.5)
		var score := d - f.hunger * 25.0      # hungry fish count as much closer
		if score < best_score:
			best_score = score
			best = k
	return best if best != "" else "flakes"


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
	_update_dirt(dt)
	_update_hover()
	queue_redraw()
	_top_layer.queue_redraw()
	_refresh_dirt_layer(dt)


# Redraw the grime only when it changed (or the tank was resized), and not
# more often than needed: fast while scrubbing, slowly for growth and the
# algae eaters' nibbling.
func _refresh_dirt_layer(dt: float) -> void:
	_dirt_wait -= dt
	var sig := [dirt.get_instance_id(), dirt.version, dirt_enabled, cols, rows, cell, origin, font_size]
	if sig == _dirt_sig:
		return
	var layout_same: bool = _dirt_sig.size() == sig.size() and sig.slice(2) == _dirt_sig.slice(2) \
		and sig[0] == _dirt_sig[0]
	if layout_same and _dirt_wait > 0.0:
		return
	_dirt_sig = sig
	_dirt_wait = 0.05 if _scrubbing else 0.4
	_dirt_layer.queue_redraw()


func _update_fish(dt: float) -> void:
	# Hungry sharks on the hunt, so their prey can try to get away.
	var hunters := []
	for f: Fish in fishes:
		if not f.dead and is_hunter(f) and f.hunger > HUNT_AT:
			hunters.append(f)
	var eaten := []
	for f: Fish in fishes:
		var sp: Dictionary = Data.SPECIES[f.species]
		if f.dead or eaten.has(f):
			if f.dead:
				_update_dead(f, dt)
			continue
		f.hunger = min(1.0, f.hunger + dt / Data.HUNGER_TIME)
		f.weak = maxf(0.0, f.weak - dt)
		var spd := f.speed * (0.5 if f.sick else 1.0)
		f.super_time = maxf(0.0, f.super_time - dt)
		f.super_cd = maxf(0.0, f.super_cd - dt)
		if f.super_time > 0.0:
			# A rainbow trail behind it, and hearts now and then.
			if randf() < dt * 14.0:
				var tail := f.pos + Vector2(-0.3 if f.facing > 0 else f.w - 0.7, f.h * 0.5)
				sparks.append({"pos": tail, "vel": Vector2(-1.5 * f.facing, randf_range(-0.4, 0.4)),
					"life": 0.8, "max": 0.8, "glyph": "~-*."[randi() % 4],
					"hue": fmod(time * 0.6, 1.0), "rainbow": true, "drag": 0.3, "grav": 0.0})
			if randf() < dt * 1.5:
				_popup("\u2665", f.pos + Vector2(f.w * 0.5 + randf_range(-1.5, 1.5), -0.6), Color("ff8fc8"))
		var mope := mood(f)
		if mope != "":
			spd *= 0.45 if mope == "sadder" else 0.65   # mopes around near the bottom
		var chasing := false
		var center := f.pos + Vector2(f.w, f.h) * 0.5
		var hunter := is_hunter(f)
		var prey: Fish = null

		if hunter:
			# Sharks ignore pellets and go after the nearest guppy instead.
			if f.hunger > HUNT_AT:
				prey = _nearest_prey(f, eaten)
				if prey != null:
					f.target = _clamp_fish(f, prey.pos + Vector2(prey.w, prey.h) * 0.5 - Vector2(f.w, f.h) * 0.5)
					spd *= 1.6
					chasing = true
		elif _is_prey(f) and not hunters.is_empty():
			# Prey darts away from a hunting shark that gets close.
			for h: Fish in hunters:
				var away: Vector2 = center - (h.pos + Vector2(h.w, h.h) * 0.5)
				if away.length() < 9.0:
					f.target = _clamp_fish(f, f.pos + away.normalized() * 6.0)
					spd *= 1.5
					chasing = true
					break
		elif _is_cleaner(f):
			if not dirt_enabled:
				# No grime with dirt turned off: there's always some algae about.
				f.hunger = maxf(0.0, f.hunger - dt * 2.0 / Data.HUNGER_TIME)
			else:
				# Grime is its food: what its mouth scrapes off the glass feeds it.
				# Close to its spot it turns its mouth to the grime.
				if f.graze_face != 0 and f.pos.distance_to(f.target) < 1.5:
					f.facing = f.graze_face
				var mouth := _mouth(f, f.pos, f.facing)
				var got := dirt.wipe(_glass_uv(mouth), _glass_uv(mouth), GRAZE_RADIUS / Vector2(cols, maxf(1.0, sand_row())),
					GRAZE_POWER * (0.5 if f.sick else 1.0) * dt, 0.0)
				f.hunger = maxf(0.0, f.hunger - minf(got * GRAZE_FOOD, dt * 3.0 / Data.HUNGER_TIME))
				# Crawl slowly over grime, swim normally between patches.
				var here := _graze_value(mouth)
				if here > 0.12:
					spd *= 0.35
				elif here < GRAZE_DONE and f.pos.distance_to(f.target) < 1.0:
					# Eaten clean (or nothing it can reach): remember the spot
					# so it doesn't come straight back, and find the next patch.
					f.grazed.append({"p": mouth, "t": time})
					f.wander_timer = 0.0

		# Hungry fish chase the nearest food of their own kind.
		var my_food := drop_food_of(f)
		if not chasing and my_food != "" and f.hunger > 0.35 and not foods.is_empty():
			var best = null
			var best_d := INF
			for fd in foods:
				if fd.kind != my_food:
					continue
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
			f.target = _graze_spot(f) if _is_cleaner(f) else _random_spot(f)
			if mope != "":
				f.target.y = randf_range(floor_y() - 5.0, floor_y() - 3.0)
			f.wander_timer = randf_range(1.5, 3.0) if _is_cleaner(f) else randf_range(3.0, 9.0)

		var dir := f.target - f.pos
		var dist := dir.length()
		if sp.get("drifter", false):
			_drift(f, dir, spd, dt)
		elif dist > 0.01:
			# Fish move mostly sideways; vertical movement is slower.
			var step: Vector2 = dir / dist * minf(dist, spd * dt)
			step.y *= 0.6
			f.pos += step
			f.anim += step.length() * 0.9     # tail wags with distance swum
			if abs(dir.x) > 0.3:
				f.facing = 1 if dir.x > 0 else -1

		# Eat food touching the sprite.
		var rect := Rect2(f.pos - Vector2(0.6, 0.6), Vector2(f.w, f.h) + Vector2(1.2, 1.2))
		if hunter:
			if prey != null and rect.has_point(prey.pos + Vector2(prey.w, prey.h) * 0.5):
				eaten.append(prey)
				_devour(f, prey)
		elif my_food != "":
			for i in range(foods.size() - 1, -1, -1):
				if f.hunger > 0.05 and foods[i].kind == my_food and rect.has_point(foods[i].pos):
					foods.remove_at(i)
					_eat(f)
					break

		# Drop coins while not starving (and not still weak from being revived).
		if f.hunger < 1.0 and f.weak <= 0.0:
			f.coin_timer += dt
			if f.coin_timer >= coin_interval(f):
				f.coin_timer = 0.0
				coins.append({
					"pos": f.pos + Vector2(f.w * 0.5, f.h * 0.5),
					"value": fish_value(f), "landed": false, "life": COIN_LIFE, "count": 1,
				})


	for p: Fish in eaten:
		remove_fish(p)


# Jellyfish: a quick squeeze up, then a slow sink, about every two seconds.
# How hard it squeezes decides whether it rises or sinks overall, so it can
# still get to where it wants to be. Sideways it just drifts.
func _drift(f: Fish, dir: Vector2, spd: float, dt: float) -> void:
	var cycle := fmod(time * 0.5 + f.phase, 1.0)
	var squeeze := cycle < 0.22
	var vy: float
	if dir.y < -0.3:
		vy = -6.0 if squeeze else 0.6        # wants to go up: strong pulses
	elif dir.y > 0.3:
		vy = -1.0 if squeeze else 1.4        # wants to go down: weak ones
	else:
		vy = -2.6 if squeeze else 0.75       # about right: bob in place
	var vx := clampf(dir.x, -1.0, 1.0) * 1.2
	f.pos = _clamp_fish(f, f.pos + Vector2(vx, vy) * spd * dt)
	f.anim = 0.0 if squeeze else 1.0          # tentacles tuck in on the squeeze
	if abs(dir.x) > 0.3:
		f.facing = 1 if dir.x > 0 else -1


# Seconds between coins; a super happy Dawa drops them twice as often.
static func coin_interval(f) -> float:
	var i := float(Data.SPECIES[f.species].interval)
	return i * 0.5 if f.super_time > 0.0 else i


# "" (fine), "sad" or "sadder": how much a lonely Dawa droops.
static func mood(f) -> String:
	if f.dead or Data.food_of(f.species) != "pat" or f.super_time > 0.0:
		return ""
	if f.hunger >= 1.0:
		return "sadder"
	if f.hunger > 0.7:
		return "sad"
	return ""


static func is_hunter(f) -> bool:
	return Data.SPECIES[f.species].has("prey")


func _is_prey(f: Fish) -> bool:
	for h: Fish in fishes:
		if not h.dead and is_hunter(h) and int(Data.SPECIES[h.species].prey) == f.species:
			return true
	return false


static func _is_cleaner(f) -> bool:
	return Data.SPECIES[f.species].get("cleaner", false)


# The closest guppy a shark may eat. Named guppies are pets: they're safe.
func _nearest_prey(h: Fish, skip: Array) -> Fish:
	var kind := int(Data.SPECIES[h.species].prey)
	var c := h.pos + Vector2(h.w, h.h) * 0.5
	var best: Fish = null
	var best_d := INF
	for f: Fish in fishes:
		if f.species != kind or f.dead or f.nickname != "" or skip.has(f):
			continue
		var d := c.distance_squared_to(f.pos + Vector2(f.w, f.h) * 0.5)
		if d < best_d:
			best_d = d
			best = f
	return best


func _devour(h: Fish, prey: Fish) -> void:
	_eat(h)
	_eat(h)            # a whole guppy is worth two pellets
	_popup("chomp!", prey.pos + Vector2(prey.w * 0.5, -0.5), C_CHOMP)
	sfx.emit("chomp", 1.0)
	for k in 3:
		bubbles.append({"pos": prey.pos + Vector2(randf() * prey.w, 0), "speed": randf_range(2.0, 3.5), "seed": randf() * TAU})
	fish_eaten.emit(prey, h)


# Algae eaters head for the dirtiest of a few random spots on the glass.
# Algae eaters look over the whole glass for the best patch to eat next:
# thick grime scores high, far away scores lower (so they work along a
# patch instead of zig-zagging), and a patch another algae eater is
# already heading for scores lower too, so they spread out.
func _graze_spot(f: Fish) -> Vector2:
	if not dirt_enabled or dirt.level < 0.005:
		f.graze_face = 0
		return _random_spot(f)
	var here := _mouth(f, f.pos, f.facing)
	for k in range(f.grazed.size() - 1, -1, -1):
		if time - float(f.grazed[k].t) > 25.0:
			f.grazed.remove_at(k)
	var others := []
	for o: Fish in fishes:
		if o != f and not o.dead and _is_cleaner(o):
			others.append(o.target + Vector2(o.w, o.h) * 0.5)
	var W: int = Dirt.W
	var H: int = Dirt.H
	var gw := float(cols - 2)
	var gh := float(sand_row() - 1)
	var best := Vector2(-1, -1)
	var best_score := -INF
	# Look at every other grid cell. It grazes with its mouth, at the front,
	# so it heads there mouth first: that way it can press right up to the
	# side walls. Judge each spot by what the mouth can reach from as close
	# as the fish can get.
	for gy in range(0, H - 1, 2):
		for gx in range(0, W - 1, 2):
			var i := gy * W + gx
			if (dirt.d[i] + dirt.d[i + 1] + dirt.d[i + W] + dirt.d[i + W + 1]) * 0.25 < GRAZE_DONE:
				continue
			var p := Vector2(0.5 + (gx + 1.0) / W * gw, 0.5 + (gy + 1.0) / H * gh)
			var face := 1 if p.x >= here.x else -1
			var pos := _clamp_fish(f, p - (_mouth(f, Vector2.ZERO, face)))
			var q := _mouth(f, pos, face)
			var v := _graze_value(q)
			if v < GRAZE_DONE:
				continue
			var done := false
			for g in f.grazed:
				if (g.p as Vector2).distance_to(q) < 3.0:
					done = true
					break
			if done:
				continue
			var d := Vector2(q.x - here.x, (q.y - here.y) * 2.0).length()   # rows are tall
			var score := v - d * 0.006
			for o: Vector2 in others:
				if o.distance_to(q) < 8.0:
					score -= 0.35
			if score > best_score:
				best_score = score
				best = pos
				f.graze_face = face
	if best.x < 0.0:
		f.graze_face = 0
		return _random_spot(f)
	return best


# How much grime a mouth at p can scrape: the average over the same patch
# of glass that grazing wipes (a few points across it).
func _graze_value(p: Vector2) -> float:
	var r := GRAZE_RADIUS * 0.55
	var s := 0.0
	for o in [Vector2.ZERO, Vector2(r.x, 0), Vector2(-r.x, 0), Vector2(0, r.y), Vector2(0, -r.y)]:
		var uv := _glass_uv(p + o)
		s += dirt.sample(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	return s / 5.0


# Where an algae eater's mouth is (the o at its front) for a fish at pos.
# Up at the waterline it reaches up, down by the sand it reaches down, so
# it can scrape the very top and bottom of the glass too.
func _mouth(f: Fish, pos: Vector2, facing: int) -> Vector2:
	var lo := 2.0
	var hi := maxf(lo + 0.01, float(sand_row() - f.h))
	var t := clampf((pos.y - lo) / (hi - lo), 0.0, 1.0)
	return pos + Vector2(f.w - 1.0 if facing > 0 else 1.0, lerpf(0.0, f.h - 0.4, t))


# Dead fish float up to the surface and bob there. The revive window only
# runs while the game is open.
func _update_dead(f: Fish, dt: float) -> void:
	if not f.skeleton:
		f.revive_left -= dt
		if f.revive_left <= 0.0:
			f.skeleton = true
			_popup("too late...", f.pos + Vector2(f.w * 0.5, -0.6), C_DEAD)
	var goal := Vector2(f.pos.x + sin(time * 0.3 + f.phase) * 0.2, 2.0)
	f.pos = f.pos.move_toward(_clamp_fish(f, goal), 0.8 * dt)


func _eat(f: Fish) -> void:
	# Sick fish only get half the good out of food, and learn nothing.
	f.hunger = max(0.0, f.hunger - Data.FOOD_VALUE * (0.5 if f.sick else 1.0))
	_gain_xp(f)


# The Dawa doesn't eat: a pat cheers it up, and every few pats teach it.
func pat(f: Fish) -> void:
	# Happiness drains a little every frame, so "full" means nearly full.
	var was_full := f.hunger < FULL_ENOUGH
	if mood(f) != "":
		f.pos.y = maxf(2.0, f.pos.y - 0.8)       # perks up with a little hop
	f.hunger = maxf(0.0, f.hunger - Data.PAT_VALUE)
	f.pats += 1
	if time - f.last_pat > 3.0:
		f.overload = 0                          # the patting has to keep going
	f.last_pat = time
	var heart := "<3"
	if was_full:
		if f.super_time <= 0.0 and f.super_cd <= 0.0:
			f.overload += 1
			if f.overload >= Data.OVERLOAD_PATS:
				_super_happy(f)
				return
			# The heart meter above it shows the charge; just a heart now and then.
			heart = "<3" if f.overload % 4 == 0 else ""
		else:
			heart = "<3<3"                      # can't get any happier right now
	else:
		f.overload = 0
	if heart != "":
		# Above the heart meter while charging, so it doesn't cover it.
		_popup(heart, f.pos + Vector2(f.w * 0.5, -1.6 if f.overload > 0 else -0.6), Color("ff8fc8"))
	sfx.emit("pat", 0.8)
	if f.pats % Data.PATS_PER_XP == 0:
		_gain_xp(f)


# Happiness overload: a white flash, fireworks, and coins twice as often.
# The reward for all that patting: a white flash, a ring of light, a burst
# of sparks, three fireworks going up and popping, and a few seconds of
# rainbow confetti raining over the whole tank.
func _super_happy(f: Fish) -> void:
	f.overload = 0
	f.super_time = Data.SUPER_TIME
	f.super_cd = Data.SUPER_TIME + Data.SUPER_COOLDOWN   # the 5 minutes start once it's back to normal
	var c := f.pos + Vector2(f.w * 0.5, f.h * 0.5)
	flashes.append({"pos": c, "life": 0.7, "max": 0.7, "size": 8.0})
	# A clean ring of light racing outward.
	for k in 32:
		var a := TAU * k / 32.0
		sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a) * 0.5) * 16.0, "life": 0.9, "max": 0.9,
			"glyph": "o" if k % 2 == 0 else "*", "color": Color("ffffff"), "drag": 0.08, "grav": 0.0})
	# A messy burst in every color.
	for k in 40:
		var a := randf() * TAU
		var sp := randf_range(4.0, 14.0)
		sparks.append({"pos": c, "vel": Vector2(cos(a) * sp, sin(a) * sp * 0.55), "life": randf_range(0.8, 1.8),
			"glyph": "*+.',"[randi() % 5], "hue": randf(), "rainbow": true})
	# Three fireworks.
	for k in 3:
		rockets.append({"pos": c + Vector2(randf_range(-2.0, 2.0), 0.0),
			"vel": Vector2(randf_range(-7.0, 7.0), randf_range(-11.0, -8.0)),
			"fuse": 0.45 + 0.3 * k, "hue": randf()})
	confetti_time = 4.5
	var p := _popup("SUPER HAPPY!", c + Vector2(0, -1.5), Color("fff3a0"))
	p.life = 3.0
	p["rainbow"] = true
	sfx.emit("sparkle", 1.0)
	sfx.emit("level", 0.7)
	_gain_xp(f)


func _explode(at: Vector2, hue: float) -> void:
	flashes.append({"pos": at, "life": 0.35, "max": 0.35, "size": 3.5})
	for k in 26:
		var a := randf() * TAU
		var sp := randf_range(3.0, 9.0)
		sparks.append({"pos": at, "vel": Vector2(cos(a) * sp, sin(a) * sp * 0.55), "life": randf_range(0.7, 1.5),
			"glyph": "*+.'"[randi() % 4], "hue": fmod(hue + randf_range(-0.07, 0.07) + 1.0, 1.0), "rainbow": true})
	sfx.emit("coin", 0.45)


func _gain_xp(f: Fish) -> void:
	if f.level >= Data.MAX_LEVEL or f.sick:
		return
	f.xp += 2 if gourmet_time > 0.0 else 1
	if f.xp >= Data.xp_needed(f.level):
		f.xp = 0
		f.level += 1
		_popup("LVL %d!" % f.level, f.pos + Vector2(f.w * 0.5, -0.6), Color("9dff9d"))
		sfx.emit("level", 1.0)


func _update_food(dt: float) -> void:
	for i in range(foods.size() - 1, -1, -1):
		var fd: Dictionary = foods[i]
		if fd.pos.y < floor_y():
			fd.pos.y = min(floor_y(), fd.pos.y + float(Data.FOODS[fd.kind].sink) * dt)
			fd.pos.x += sin(time * 3.0 + fd.pos.y) * 0.4 * dt
		else:
			fd.rest += dt
			# In dirty water, food that lands in grime is lost quickly.
			var lost := dirt_level() >= Data.DIRTY_AT and dirt_at(fd.pos) > 0.5
			if fd.rest > (3.0 if lost else 25.0):
				foods.remove_at(i)


const COIN_LIFE := 90.0


func _has_coin(target) -> bool:
	for c in coins:
		if is_same(c, target):
			return true
	return false


func _update_coins(dt: float) -> void:
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		if not c.landed:
			c.pos.y += 3.0 * dt
			if c.pos.y >= floor_y():
				c.pos.y = floor_y()
				c.landed = true
				# Land on a nearby pile instead of making a new coin.
				for other in coins:
					if not is_same(other, c) and other.landed and abs(other.pos.x - c.pos.x) < 2.0:
						other.value += c.value
						other.count += c.count
						other.life = COIN_LIFE
						coins.remove_at(i)
						break
		else:
			c.life -= dt
			if c.life <= 0.0:
				coins.remove_at(i)


# The sand is split into one lane per snail. Each snail only looks after
# its own lane, so they spread out instead of bunching up, and it keeps
# its current target until it reaches it, so it doesn't flip-flop.
func _snail_lane(i: int) -> Vector2:
	var n: int = max(1, snails.size())
	var width := float(cols - 2) / n
	return Vector2(1.0 + i * width, 1.0 + (i + 1) * width)   # [from, to) in cells


func _update_snails(dt: float) -> void:
	for i in snails.size():
		var s: Dictionary = snails[i]
		var lane := _snail_lane(i)
		var center: float = s.x + 1.0
		# Drop the target if it was collected or faded.
		if s.target != null and not _has_coin(s.target):
			s.target = null
		if s.target == null:
			var best := INF
			for c in coins:
				if c.landed and c.pos.x >= lane.x and c.pos.x < lane.y and not _buried(c):
					var d: float = abs(c.pos.x - center)
					if d < best:
						best = d
						s.target = c
		var goal := -1.0
		if s.target != null:
			goal = s.target.pos.x
		else:
			# Nothing to do: rest, then amble to a new spot in the lane.
			s.rest -= dt
			if s.rest <= 0.0:
				s.rest = randf_range(3.0, 8.0)
				s.idle_x = randf_range(lane.x + 1.0, max(lane.x + 1.0, lane.y - 2.0))
			goal = s.idle_x
		var dx: float = goal - center
		var spd: float = s.speed if s.target != null else s.speed * 0.4
		if dirt_level() >= Data.SICK_AT:
			spd *= 0.5
		s.moving = abs(dx) > 0.3
		if s.moving:
			s.dir = 1 if dx > 0.0 else -1
			s.x += sign(dx) * min(abs(dx), spd * dt)
		s.x = clamp(s.x, lane.x - 1.0, max(lane.x - 1.0, lane.y - 2.0))
		s.x = clamp(s.x, 1.0, cols - 4.0)
		# Collect any landed coin under the snail.
		for j in range(coins.size() - 1, -1, -1):
			var c: Dictionary = coins[j]
			if c.landed and abs(c.pos.x - (s.x + 1.0)) < 1.6 and not _buried(c):
				_collect(j, true)


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
			if not f.dead:
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
	var wanted := {}
	for f in fishes:
		var k := drop_food_of(f)
		if f.hunger > 0.4 and not f.dead and k != "":
			wanted[k] = true
	var dropped := 0
	var fx := _feeder_x() + 1.5
	for k in wanted:
		for n in 2:
			if drop_food(Vector2(fx + randf_range(-1.0, 1.0), 2.0), k):
				dropped += 1
	if dropped > 0:
		_feeder_timer = 0.0
		sfx.emit("food", 0.25)


func _feeder_x() -> float:
	return floor(cols * 0.82)


func _update_misc(dt: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s.life -= dt
		s.vel *= pow(float(s.get("drag", 0.25)), dt)   # water slows them down
		s.vel.y += float(s.get("grav", 5.0)) * dt        # then they drift down
		s.pos += s.vel * dt
		if s.has("sway"):
			s.pos.x += sin(time * 2.5 + float(s.sway)) * 0.8 * dt
		if s.life <= 0.0 or s.pos.y > floor_y() + 0.5:
			sparks.remove_at(i)
	for i in range(rockets.size() - 1, -1, -1):
		var r: Dictionary = rockets[i]
		r.fuse -= dt
		r.vel.y += 6.0 * dt
		r.pos += r.vel * dt
		r.pos.y = maxf(r.pos.y, 1.5)
		sparks.append({"pos": r.pos, "vel": Vector2.ZERO, "life": 0.35, "max": 0.35, "glyph": ".",
			"color": Color.from_hsv(r.hue, 0.3, 1.0), "grav": 0.0})
		if r.fuse <= 0.0:
			_explode(r.pos, r.hue)
			rockets.remove_at(i)
	if confetti_time > 0.0:
		confetti_time -= dt
		_confetti_acc += dt * 30.0
		while _confetti_acc >= 1.0 and sparks.size() < 500:
			_confetti_acc -= 1.0
			sparks.append({"pos": Vector2(randf_range(1.5, cols - 2.5), 1.5),
				"vel": Vector2(randf_range(-0.8, 0.8), randf_range(2.0, 4.0)), "life": randf_range(3.5, 6.0),
				"glyph": "*'.,`~"[randi() % 6], "hue": randf(), "rainbow": true,
				"drag": 1.0, "grav": 0.2, "sway": randf() * TAU})
	for i in range(flashes.size() - 1, -1, -1):
		flashes[i].life -= dt
		if flashes[i].life <= 0.0:
			flashes.remove_at(i)
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


# ---------------------------------------------------------------- dirt

# Cell coordinates -> 0..1 across the glass (the water, waterline included).
func _glass_uv(p: Vector2) -> Vector2:
	return Vector2((p.x - 1.0) / maxf(1.0, cols - 2.0), (p.y - 1.0) / maxf(1.0, sand_row() - 1.0))


func dirt_at(p: Vector2) -> float:
	if not dirt_enabled:
		return 0.0
	return dirt.sample((p.x - 0.5) / maxf(1.0, cols - 2.0), (p.y - 0.5) / maxf(1.0, sand_row() - 1.0))


func _buried(c: Dictionary) -> bool:
	return dirt_level() >= Data.DIRTY_AT and dirt_at(c.pos) > 0.6


func _update_dirt(dt: float) -> void:
	boost_time = maxf(0.0, boost_time - dt)
	gourmet_time = maxf(0.0, gourmet_time - dt)
	golden_time = maxf(0.0, golden_time - dt)
	if not dirt_enabled:
		full_time = 0.0
		for f in fishes:
			f.sick = false
		return
	_dirt_t += dt
	if _dirt_t >= 0.5:
		# Dead fish left in the tank foul the water.
		var mult := dirt_rate_mult
		for f in fishes:
			if f.dead:
				mult += 0.3 if f.skeleton else 0.15
		dirt.rate_mult = mult
		dirt.grow(_dirt_t)
		_dirt_t = 0.0
	_dirt_peak = maxf(_dirt_peak, dirt.level)
	# Rinse the sponge by taking it out of the water for a moment.
	if clean_mode and not in_water(mouse_cell) and sponge_load > 0.0:
		sponge_load = maxf(0.0, sponge_load - dt * 0.9)
	if clean_mode:
		_update_sponge_cursor()

	var lv := dirt.level
	for f in fishes:
		if f.dead:
			continue
		if lv >= Data.SICK_AT:
			if not f.sick and randf() < dt / 40.0:
				f.sick = true
				_popup("sick", f.pos + Vector2(f.w * 0.5, -0.6), C_SICK)
		elif f.sick:
			# Clean water cures sickness right away.
			cure(f)
		if f.sick and lv >= Data.FILTHY_AT:
			f.drain += dt
			if f.drain >= Data.LEVEL_DRAIN:
				f.drain = 0.0
				if f.level > 0:
					f.level -= 1
					f.xp = 0
					_popup("lvl -1", f.pos + Vector2(f.w * 0.5, -0.6), Color("ff8a8a"))
					sfx.emit("sell", 0.6)

	# A fully covered tank starts killing fish, one at a time, never the last one.
	if lv >= Data.FULL_AT and deaths_enabled:
		full_time += dt
		if full_time >= Data.DEATH_AFTER and _someone_can_die():
			var victim: Fish = null
			for f in fishes:
				if not f.dead and (victim == null or (f.sick and not victim.sick)
						or (f.sick == victim.sick and fish_value(f) < fish_value(victim))):
					victim = f
			if victim != null:
				kill(victim)
			full_time = Data.DEATH_AFTER - Data.DEATH_EVERY
	elif lv < Data.FILTHY_AT:
		full_time = 0.0


# One stroke of the sponge from a to b (cells). Slow, steady strokes clean
# best; flicks skim; a grimy sponge cleans worse and smears more.
func _scrub(a: Vector2, b: Vector2, velocity_px: Vector2) -> void:
	if not dirt_enabled:
		return
	var speed := (velocity_px / cell).length()
	var speed_eff := clampf(1.25 - speed / SPONGE_FAST, 0.2, 1.0)
	var power := SPONGE_POWER * (1.0 + Data.SPONGE_POWER_PER_LV * sponge_level) * speed_eff * (1.0 - 0.8 * sponge_load)
	var smear := clampf(0.04 + 0.45 * (1.0 - speed_eff) + 0.3 * sponge_load, 0.0, 0.8)
	var reach := sponge_radius()
	var r := Vector2(reach.x / maxf(1.0, cols - 2.0), reach.y / maxf(1.0, sand_row() - 1.0))
	var got := dirt.wipe(_glass_uv(a), _glass_uv(b), r, power, smear)
	sponge_load = minf(1.0, sponge_load + got * SPONGE_LOAD_PER_DIRT / (1.0 + Data.SPONGE_HOLD_PER_LV * sponge_level))
	if got > 0.05:
		sfx.emit("squeak", clampf(got * 0.4, 0.15, 0.5))
		if randf() < 0.3:
			bubbles.append({"pos": b, "speed": randf_range(1.5, 3.0), "seed": randf() * TAU})
	if _dirt_peak > 0.15 and dirt.level < SPOTLESS_BELOW:
		_dirt_peak = 0.0
		boost_time = Data.SPARKLE_TIME
		dirt.clear()
		_popup("* sparkling! +25% coins *", Vector2(cols * 0.5, rows * 0.4), C_GEM)
		sfx.emit("sparkle", 1.0)
		spotless.emit()


func rinse() -> void:
	if sponge_load > 0.02:
		sponge_load = 0.0
		sfx.emit("splash", 0.4)
		_popup("rinsed", mouse_cell + Vector2(0, -1.0), C_SURFACE)


# The sponge cursor gets browner as it fills with grime. Its reach (the
# area one stroke covers) is drawn into the cursor image itself: the OS moves
# the cursor at full speed, while anything the game draws only moves at the
# game's frame rate and trails behind the pointer.
func _update_sponge_cursor() -> void:
	var bucket := int(sponge_load * 4.0 + 0.5)
	var key := Vector4i(bucket, int(cell.x), int(cell.y), sponge_level)
	if key == _sponge_shown:
		return
	_sponge_shown = key
	if not _sponge_cursors.has(key):
		if _sponge_cursors.size() > 20:
			_sponge_cursors.clear()      # window resized many times
		_sponge_cursors[key] = _make_sponge(float(bucket) / 4.0, cell, sponge_radius())
	var tex: ImageTexture = _sponge_cursors[key]
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_CAN_DROP, (tex.get_size() / 2.0).floor())


# Half the size of what one stroke covers, in cells.
func sponge_radius() -> Vector2:
	return SPONGE_RADIUS * (1.0 + Data.SPONGE_REACH_PER_LV * sponge_level)


static func _make_sponge(load_: float, cell_px: Vector2, radius: Vector2) -> ImageTexture:
	# Cursors can be at most 256 x 256 px.
	var reach := (radius * 2.0 * cell_px).round()
	var w := clampi(int(reach.x) + 1, 23, 255)
	var h := clampi(int(reach.y) + 1, 17, 255)
	w += 1 - w % 2      # odd sizes keep the hotspot dead centre
	h += 1 - h % 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var hx := int(w / 2.0)
	var hy := int(h / 2.0)
	# Reach outline.
	var rx := mini(int(reach.x / 2.0), hx)
	var ry := mini(int(reach.y / 2.0), hy)
	var line := Color(1, 0.9, 0.5, 0.3)
	for x in range(hx - rx, hx + rx + 1):
		img.set_pixel(x, hy - ry, line)
		img.set_pixel(x, hy + ry, line)
	for y in range(hy - ry, hy + ry + 1):
		img.set_pixel(hx - rx, y, line)
		img.set_pixel(hx + rx, y, line)
	# The sponge, centred on the hotspot.
	var body := Color("f2d25c").lerp(Color("6b5a2a"), load_)
	var ox := hx - 11
	var oy := hy - 8
	for y in 16:
		for x in 22:
			var c := body
			if x == 0 or x == 21 or y == 0 or y == 15:
				c = Color("1a140a")
			elif (x * 7 + y * 13) % 11 == 0:
				c = body.darkened(0.35)     # sponge holes
			elif y < 4:
				c = Color("3fae6a").lerp(Color("2a4a2a"), load_)   # scrub side
			img.set_pixel(ox + x, oy + y, c)
	return ImageTexture.create_from_image(img)


func _update_hover() -> void:
	hovered = _fish_at(mouse_cell)


func _fish_at(p: Vector2) -> Fish:
	for i in range(fishes.size() - 1, -1, -1):
		var f: Fish = fishes[i]
		if Rect2(f.pos - Vector2(0.3, 0.3), Vector2(f.w, f.h) + Vector2(0.6, 0.6)).has_point(p):
			return f
	return null


func _collect(i: int, by_snail := false) -> void:
	var c: Dictionary = coins[i]
	coins.remove_at(i)
	money_earned.emit(c.value, int(c.get("count", 1)), by_snail)
	sfx.emit("coin", 0.3 if by_snail else 1.0)
	# Collections close together in time and space add up into one popup.
	for p in popups:
		if p.has("amount") and p.life > 0.7 and abs(p.pos.x - c.pos.x) < 8.0 and abs(p.pos.y - c.pos.y) < 3.0:
			p.amount += c.value
			p.text = "+$" + Data.fmt(p.amount)
			p.life = 1.2
			return
	var np := _popup("+$" + Data.fmt(c.value), c.pos + Vector2(0, -0.8), Color("ffd84d"))
	np["amount"] = c.value


func _popup(text: String, p: Vector2, color: Color) -> Dictionary:
	# Nudge upward so new popups don't print on top of existing ones.
	for other in popups:
		if abs(other.pos.y - p.y) < 0.9 and abs(other.pos.x - p.x) < (String(other.text).length() + text.length()) * 0.5 + 1.0:
			p.y = other.pos.y - 1.0
	var d := {"text": text, "pos": p, "life": 1.2, "color": color}
	popups.append(d)
	return d


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	var prev := mouse_cell
	if event is InputEventMouse:
		mouse_cell = (event.position - origin) / cell
	if clean_mode:
		_clean_input(event, prev)
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_collect_near(mouse_cell)   # drag over coins to scoop them up
		_stroke(event.relative)
		_update_cursor()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				var fd := _fish_at(mouse_cell)
				if fd != null:
					fish_opened.emit(fd)
					accept_event()
					return
			if _collect_near(mouse_cell) == 0 and in_water(mouse_cell):
				if drop_food(mouse_cell - Vector2(0.5, 0.5), food_for_click(mouse_cell)):
					sfx.emit("food", 1.0)
					player_food += 1
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var f := _fish_at(mouse_cell)
			if f != null:
				fish_opened.emit(f)
			accept_event()


# Moving the mouse back and forth over a Dawa pats it.
func _stroke(rel: Vector2) -> void:
	# The Dawa under the mouse, even if another fish swims in front of it.
	var f: Fish = null
	for i in range(fishes.size() - 1, -1, -1):
		var c: Fish = fishes[i]
		if not c.dead and Data.food_of(c.species) == "pat" \
				and Rect2(c.pos - Vector2(0.3, 0.3), Vector2(c.w, c.h) + Vector2(0.6, 0.6)).has_point(mouse_cell):
			f = c
			break
	if f == null:
		return
	f.pat_dist += absf(rel.x) / cell.x + absf(rel.y) / cell.y * 0.5
	if f.pat_dist >= Data.PAT_STROKE:
		f.pat_dist = 0.0
		pat(f)


# Clean mode: hold left and drag to scrub, right-click to rinse the sponge.
func _clean_input(event: InputEvent, prev: Vector2) -> void:
	if event is InputEventMouseMotion:
		if _scrubbing and event.button_mask & MOUSE_BUTTON_MASK_LEFT and _on_glass(mouse_cell):
			_scrub(prev if _on_glass(prev) else mouse_cell, mouse_cell, event.velocity)
		_update_cursor()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_scrubbing = event.pressed
			if event.pressed and _on_glass(mouse_cell):
				_scrub(mouse_cell, mouse_cell, Vector2.ZERO)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			rinse()
	accept_event()


func _on_glass(p: Vector2) -> bool:
	return p.y > 0.5 and p.y < sand_row() and p.x > 0.5 and p.x < cols - 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse_cell = Vector2(-100, -100)


func in_water(p: Vector2) -> bool:
	return p.y > 1.5 and p.y < sand_row() and p.x > 1 and p.x < cols - 1


func _coin_near(p: Vector2) -> bool:
	for c in coins:
		if (c.pos + Vector2(0.5, 0.5)).distance_to(p) < 1.6:
			return true
	return false


# Hand over coins (click collects), food pellet over water (click feeds).
func _update_cursor() -> void:
	var shape := Control.CURSOR_ARROW
	if clean_mode:
		if _on_glass(mouse_cell):
			shape = Control.CURSOR_CAN_DROP
	elif _coin_near(mouse_cell):
		shape = Control.CURSOR_POINTING_HAND
	elif in_water(mouse_cell):
		shape = Control.CURSOR_CROSS
	if shape != mouse_default_cursor_shape:
		mouse_default_cursor_shape = shape


func collect_all() -> int:
	var n := coins.size()
	for i in range(coins.size() - 1, -1, -1):
		_collect(i)
	return n


func mouse_in_tank() -> bool:
	return in_water(mouse_cell)


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
			_ci.draw_char(font, base + Vector2(i * cell.x, 0).round(), ch, font_size, color)


func _water_color(y: float) -> Color:
	var water_rows := sand_row() - 1
	var t: float = clampf((floor(y) - 1.0) / maxf(1.0, water_rows - 1.0), 0.0, 1.0)
	return C_WATER_TOP.lerp(C_WATER_BOTTOM, t)


func _draw() -> void:
	if font == null:
		return
	if not transparent_outside:
		draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	# Water, a little darker toward the bottom.
	var water_rows := sand_row() - 1
	for r in water_rows:
		draw_rect(Rect2(origin + Vector2(cell.x, (r + 1) * cell.y), Vector2((cols - 2) * cell.x, cell.y)),
			_water_color(r + 1))

	# Drifting specks in the water.
	for m in motes:
		_put(m.pos.x, m.pos.y, ".", Color(0.6, 0.8, 1.0, 0.12))

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
			_put(x, sand_row() - 1 - k, ch, C_WEED.lerp(C_WEED_TIP, float(k) / max(1, h)))

	# Castle.
	if has_castle:
		var cx: float = floor(cols * 0.62)
		for k in CASTLE.size():
			_put(cx, sand_row() - CASTLE.size() + k, CASTLE[k], C_CASTLE)
		_put(cx + 3, sand_row() - CASTLE.size(), ">" if int(time * 2.0) % 2 == 0 else "}", Color("b85a5a"))

	# Auto-feeder hanging at the surface.
	if feeder_level > 0:
		_put(_feeder_x(), 1, "[::]", C_FEEDER)

	for fd in foods:
		var fk: Dictionary = Data.FOODS[fd.kind]
		_put(fd.pos.x, fd.pos.y, fk.glyph, fk.color)

	for b in bubbles:
		var prog: float = 1.0 - (b.pos.y - 2.0) / max(1.0, floor_y() - 2.0)
		var ch := "." if prog < 0.3 else ("o" if prog < 0.75 else "O")
		_put(b.pos.x, b.pos.y, ch, C_BUBBLE)

	for s in snails:
		_put(s.x, floor_y(), SNAIL_RIGHT if s.dir > 0 else SNAIL_LEFT, C_SNAIL)

	# Coins: a pile grows as more coins land on it; color shows its value.
	for c in coins:
		if c.landed and c.life < 15.0 and fmod(time, 0.5) < 0.2:
			continue
		var n: int = c.count
		var glyph := "$" if n <= 1 else ("$$" if n <= 3 else "<$>")
		var v: float = c.value
		var col := C_COPPER
		if v >= 1000.0:
			col = C_GEM
		elif v >= 100.0:
			col = C_GOLD
		elif v >= 10.0:
			col = C_SILVER
		_put(c.pos.x - (glyph.length() - 1) * 0.5, c.pos.y, glyph, col)

	# Big fish swim behind small ones.
	var order := fishes.duplicate()
	order.sort_custom(func(a, b): return a.w * a.h > b.w * b.h)
	for f: Fish in order:
		if f.dead or not _is_cleaner(f):
			_draw_fish(f)



func _draw_dirt_layer() -> void:
	if font == null or not dirt_enabled or dirt.level <= 0.0005:
		return
	_ci = _dirt_layer
	_draw_dirt()
	_ci = self


func _draw_top() -> void:
	if font == null:
		return
	_ci = _top_layer
	_draw_overlay()
	_ci = self


# Above the grime.
func _draw_overlay() -> void:
	for fl in flashes:
		var k: float = fl.life / float(fl.get("max", 0.5))
		var c: Vector2 = origin + (fl.pos as Vector2) * cell
		var size: float = fl.get("size", 4.0)
		var r := cell.y * (size * 0.35 + size * (1.0 - k))
		_ci.draw_circle(c, r, Color(1, 1, 1, 0.12 * k))
		_ci.draw_circle(c, r * 0.6, Color(1, 1, 1, 0.25 * k))
		_ci.draw_circle(c, r * 0.3, Color(1, 1, 1, 0.5 * k))
	for s in sparks:
		var col: Color
		if s.get("rainbow", false):
			col = Color.from_hsv(fmod(float(s.hue) + time * 0.4, 1.0), 0.5, 1.0)
		else:
			col = s.color
		col.a = clampf(s.life / minf(0.5, float(s.get("max", 0.5))), 0.0, 1.0)
		_put(s.pos.x, s.pos.y, s.glyph, col)
	for r in rockets:
		_put(r.pos.x, r.pos.y, "^", Color.from_hsv(r.hue, 0.35, 1.0))
	# Algae eaters cling to the glass, in front of the grime they graze.
	for f: Fish in fishes:
		if not f.dead and _is_cleaner(f):
			_draw_fish(f)

	# Revive countdowns stay readable through the grime.
	for f: Fish in fishes:
		if f.dead and not f.skeleton:
			var left := int(ceil(f.revive_left))
			var label := "x_x %d:%02d" % [left / 60, left % 60]
			var lx := clampf(f.pos.x, 1.0, cols - 1.0 - label.length())
			var ly := maxf(1.0, f.pos.y - 1.0 + sin(time * 1.2 + f.phase) * 0.15)
			_ci.draw_rect(Rect2(origin + Vector2(lx, ly) * cell, Vector2(label.length(), 1) * cell), Color(0.03, 0.05, 0.08, 0.7))
			_put(lx, ly, label, Color("ff8a8a"))

	for p in popups:
		var a: float = clamp(p.life / 0.6, 0.0, 1.0)
		var text := String(p.text)
		var x0: float = p.pos.x - text.length() * 0.5
		if p.get("rainbow", false):
			for i in text.length():
				var rc := Color.from_hsv(fmod(i * 0.08 + time * 0.7, 1.0), 0.45, 1.0, a)
				_put(x0 + i, p.pos.y + sin(time * 8.0 + i * 0.7) * 0.15, text[i], rc)
		else:
			var col: Color = p.color
			col.a = a
			_put(x0, p.pos.y, text, col)


# Grime on the glass: a murky tint that hides what's behind it, with
# denser characters where it's thicker.
func _draw_dirt() -> void:
	var water_rows := sand_row() - 1
	var rid := _ci.get_canvas_item()
	_cache_glyphs()
	# The tint is one small image, a pixel per cell, stretched over the glass
	# (one quad for the GPU instead of thousands of rectangles). The glyphs
	# come after it, all from the same font texture, so they batch too.
	var iw := cols - 2
	if _tint_img == null or _tint_img.get_width() != iw or _tint_img.get_height() != water_rows:
		_tint_img = Image.create(iw, water_rows, false, Image.FORMAT_RGBA8)
		_tint_tex = null
	_tint_img.fill(Color(0, 0, 0, 0))
	var marks := []
	for y in range(1, sand_row()):
		for x in range(1, cols - 1):
			var v := dirt.sample((x - 0.5) / float(cols - 2), (y - 0.5) / float(water_rows))
			if v < 0.06:
				continue
			var col := C_ALGAE.lerp(C_GRIME, clampf(v * 1.2 - 0.2, 0.0, 1.0))
			var tint := col
			tint.a = clampf(pow(v, 1.6) * 0.9, 0.0, 0.88)
			_tint_img.set_pixel(x - 1, y - 1, tint)
			# Irregular ASCII grime, thicker characters where it's thicker.
			# Light film is just a tint; characters only where grime is visible.
			if v >= 0.22:
				marks.append(Vector3(x, y, v))
	if _tint_tex == null:
		_tint_tex = ImageTexture.create_from_image(_tint_img)
	else:
		_tint_tex.update(_tint_img)
	var p0 := (origin + cell).floor()
	var p1 := (origin + Vector2(cols - 1, sand_row()) * cell).floor()
	_ci.draw_texture_rect(_tint_tex, Rect2(p0, p1 - p0), false)
	for m: Vector3 in marks:
		var x := int(m.x)
		var y := int(m.y)
		var v := m.z
		var col := C_ALGAE.lerp(C_GRIME, clampf(v * 1.2 - 0.2, 0.0, 1.0))
		var tier: String = GRIME[mini(int(v * GRIME.size()), GRIME.size() - 1)]
		var ch := tier[absi((x * 73856093) ^ (y * 19349663)) % tier.length()]
		var gc := col.lightened(0.12)
		gc.a = clampf(0.22 + v * 0.45, 0.0, 0.7)
		var g: Array = _glyphs.get(ch, [])
		if g.is_empty():
			_put(x, y, ch, gc)
		else:
			# Straight from the font's glyph texture: far cheaper than draw_char.
			var at := (origin + Vector2(x * cell.x, y * cell.y + ascent)).round() + (g[2] as Vector2)
			RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(at, g[3]), g[0], g[1], gc)


# Where each grime character sits in the font's glyph textures.
func _cache_glyphs() -> void:
	var key := Vector2i(font.get_instance_id(), font_size)
	if key == _glyphs_for:
		return
	_glyphs_for = key
	_glyphs.clear()
	var ts := TextServerManager.get_primary_interface()
	var sz := Vector2i(font_size, 0)
	var rids := font.get_rids()
	if rids.is_empty():
		return
	var fr: RID = rids[0]
	for tier in GRIME:
		for ch in tier:
			if ch == " " or _glyphs.has(ch):
				continue
			var gi := ts.font_get_glyph_index(fr, font_size, ch.unicode_at(0), 0)
			if gi == 0:
				continue
			ts.font_render_glyph(fr, sz, gi)
			if ts.font_get_glyph_texture_idx(fr, sz, gi) < 0:
				continue
			var tex := ts.font_get_glyph_texture_rid(fr, sz, gi)
			if not tex.is_valid():
				continue
			_glyphs[ch] = [tex, ts.font_get_glyph_uv_rect(fr, sz, gi),
				ts.font_get_glyph_offset(fr, sz, gi), ts.font_get_glyph_size(fr, sz, gi)]


func _draw_fish(f: Fish) -> void:
	var sp: Dictionary = Data.SPECIES[f.species]
	var spr_data: Dictionary = _sprites[f.species]
	var mope := mood(f)
	if mope != "" and _mood_sprites.has(f.species):
		spr_data = _mood_sprites[f.species][mope]
	var frames: Array = spr_data.r if f.facing > 0 else spr_data.l
	var spr: Array = frames[int(f.anim) % frames.size()]
	var mask: Array = spr_data.mr if f.facing > 0 else spr_data.ml
	if f.dead:
		_draw_dead(f, spr, mask)
		return

	var body: Color = sp.color
	var accent: Color = sp.get("accent", body)
	if f.super_time > 0.0:
		# Super happy: colors slowly cycle through the rainbow.
		var hue := fmod(time * 0.35 + f.phase, 1.0)
		body = Color.from_hsv(hue, 0.45, 1.0)
		accent = Color.from_hsv(fmod(hue + 0.12, 1.0), 0.65, 1.0)
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
		if f.sick:
			c = c.lerp(C_SICK, 0.4)
		if f == hovered:
			c = c.lightened(0.15)
		palette[key] = c

	var bob := sin(time * 2.0 + f.phase) * 0.12
	if f.super_time > 0.0:
		bob -= absf(sin(time * 5.0 + f.phase)) * 0.45   # happy little hops
	var blinking := f.blink > 0.0 or f.hunger >= 1.0

	if f == hovered:
		var pad := Vector2(cell.x * 0.6, cell.y * 0.35)
		var r := Rect2(origin + Vector2(f.pos.x * cell.x, (f.pos.y + bob) * cell.y) - pad,
			Vector2(f.w * cell.x, f.h * cell.y) + pad * 2.0)
		var oc: Color = body
		oc.a = 0.45
		_ci.draw_rect(r, oc, false, 1.0)

	for k in spr.size():
		var row: String = spr[k]
		var mrow: String = mask[k]
		var y := f.pos.y + k + bob
		# Paint water behind this row so the fish hides whatever swims behind it.
		var first := row.length() - row.lstrip(" ").length()
		var last := row.rstrip(" ").length()
		if last > first:
			_ci.draw_rect(Rect2(origin + Vector2((f.pos.x + first) * cell.x, y * cell.y),
				Vector2((last - first) * cell.x, cell.y)), _water_color(y))
		var base := origin + Vector2(f.pos.x * cell.x, y * cell.y + ascent)
		for i in row.length():
			var ch := row[i]
			if ch == " ":
				continue
			var m := mrow[i]
			if m == "e" and blinking:
				ch = "-"
			_ci.draw_char(font, base + Vector2(i * cell.x, 0).round(), ch, font_size, palette.get(m, palette[" "]))

	# Hunger / starving marker above the head.
	var head_x := f.pos.x + (f.w - 1 if f.facing > 0 else 0)
	var lonely := Data.food_of(f.species) == "pat"
	if f.super_time > 0.0:
		var hx := clampf(head_x - (2 if f.facing > 0 else 0), 1.0, cols - 4.0)
		_put(hx, f.pos.y - 1 + bob, "^-^", Color("fff3a0"))
	elif f.overload > 0 and time - f.last_pat < 3.0:
		# Charging up: five hearts fill as you keep patting, pulsing faster.
		var fill := float(f.overload) / Data.OVERLOAD_PATS
		var mx := clampf(f.pos.x + f.w * 0.5 - 2.5, 1.0, cols - 6.0)
		var pulse := 0.75 + 0.25 * sin(time * (6.0 + 14.0 * fill))
		for i in 5:
			var on := fill * 5.0 > i
			var hc := Color("ff8fc8") if on else Color("6a5068")
			if on:
				hc = hc.lerp(Color("ffffff"), fill * 0.5 * pulse)
			_put(mx + i, f.pos.y - 1 + bob, "\u2665", hc)
	elif lonely and f.hunger > 0.7 and not f.sick:
		# A lonely Dawa sulks: ... then :( when it stops making coins.
		var mark := ":(" if f.hunger >= 1.0 else "..."
		var mx := clampf(head_x - (mark.length() - 1 if f.facing > 0 else 0), 1.0, cols - 1.0 - mark.length())
		_put(mx, f.pos.y - 1 + bob, mark, Color("ff8fc8") if f.hunger < 1.0 else Color("ff5c5c"))
	elif f.hunger >= 1.0:
		_put(head_x, f.pos.y - 1 + bob, "!", Color("ff5c5c"))
	elif f.sick:
		_put(head_x, f.pos.y - 1 + bob, "~", C_SICK)
	elif f.hunger > 0.7:
		_put(head_x, f.pos.y - 1 + bob, "?", Color("ffcf5c"))
	if f == hovered and f.level > 0:
		_put(f.pos.x, f.pos.y + spr.size() + bob, "*".repeat(f.level), Color("9dff9d"))


# Belly-up and grey with x eyes, or just bones once it's too late.
func _draw_dead(f: Fish, spr: Array, mask: Array) -> void:
	var bob := sin(time * 1.2 + f.phase) * 0.15
	if f == hovered:
		var pad := Vector2(cell.x * 0.6, cell.y * 0.35)
		_ci.draw_rect(Rect2(origin + Vector2(f.pos.x * cell.x, (f.pos.y + bob) * cell.y) - pad,
			Vector2(f.w * cell.x, f.h * cell.y) + pad * 2.0), Color(C_DEAD, 0.5), false, 1.0)
	if f.skeleton:
		var bones := ">" + "-}".repeat(maxi(1, (f.w - 3) / 2)) + "x>"
		if f.facing < 0:
			bones = String(_mirror([bones])[0])
		_put(f.pos.x, f.pos.y + floorf((f.h - 1) * 0.5) + bob, bones, C_BONE)
		return
	var n := spr.size()
	for k in n:
		# Upside down: draw the rows bottom to top.
		var row: String = spr[n - 1 - k]
		var mrow: String = mask[n - 1 - k]
		var y := f.pos.y + k + bob
		var base := origin + Vector2(f.pos.x * cell.x, y * cell.y + ascent)
		for i in row.length():
			var ch := row[i]
			if ch == " ":
				continue
			if mrow[i] == "e":
				ch = "x"
			_ci.draw_char(font, base + Vector2(i * cell.x, 0).round(), ch, font_size,
				C_DEAD.lightened(0.15) if f == hovered else C_DEAD)
