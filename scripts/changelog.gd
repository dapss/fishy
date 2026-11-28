# What changed in each version, newest first. Shown once after an update
# ("What's new") and any time from the help card. Keep lines short: they
# have to read well in a Tiny window too.
extends RefCounted

const ENTRIES := [
	{
		"version": "0.5.0",
		"notes": [
			"A longer game: fishy is paced like an idle game now. The first fish still come quickly, but the later ones take hours, then days, to save up for. Each extra fish of a kind costs a bit more than the last.",
			"Two new fish: the Betta, with long rippling fins, and the Stingray, which glides low over the sand.",
			"The Shark is the top fish now, after the Jellyfish. One guppy keeps a shark full for longer.",
			"New upgrade, Guppy hatchery: hatches little guppy fry for your sharks to hunt, even while the game is closed.",
			"While you're away, a Dawa gets lonely but keeps making half its coins instead of stopping.",
			"Keys 1-9 and 0 buy fish.",
		],
	},
	{
		"version": "0.4.3",
		"notes": [
			"Happiness overload takes much longer now (about 20 seconds of patting a happy Dawa), with hearts above it that fill up as you go. After a minute of super happy, it rests for 5 minutes.",
			"And it's a much bigger party: a flash, a ring of light, fireworks, rainbow confetti over the whole tank, and a sparkly rainbow trail while it's super happy.",
			"Patting reaches a Dawa even when another fish swims in front of it.",
		],
	},
	{
		"version": "0.4.2",
		"notes": [
			"Fixed: patting a fully happy Dawa into a happiness overload now works.",
			"Algae eaters are smarter: they head for the thickest grime nearby, graze with their mouth so they reach the edges of the glass too, and several of them spread out over different patches.",
		],
	},
	{
		"version": "0.4.1",
		"notes": [
			"A lonely Dawa droops: its head curves down, more the lonelier it gets. A pat perks it up.",
			"Happiness overload: keep patting a fully happy Dawa and it bursts with joy. Super happy Dawas drop coins twice as often for a minute.",
			"Algae eaters graze properly: they crawl along a patch of grime eating it, instead of swimming past it and starving. With dirt turned off they never go hungry.",
		],
	},
	{
		"version": "0.4.0",
		"notes": [
			"Food! Each fish eats only its own: flakes are free, pellets, shrimp and plankton come from the shop. The auto-feeder uses your stock, even while you're away.",
			"The Dawa doesn't eat anymore: pat it (move the mouse back and forth over it) when it's lonely.",
			"Treats: Gourmet (double XP) and Golden flakes (x1.5 coins). New upgrade: Food hopper stores more food.",
			"New fish: the Jellyfish, after the Shark. It pulses up and drifts down instead of swimming.",
			"Algae eaters are fish now (key 8): they eat only grime, grazing it off the glass. Your old ones moved in.",
			"Sharks don't eat pellets anymore: they hunt guppies. Name a guppy to keep it safe.",
			"New upgrade: Big sponge. Wider strokes, scrubs harder, needs rinsing less often.",
			"Dirty tanks no longer slow the game down.",
			"The sponge outline keeps up with the mouse.",
		],
	},
	{
		"version": "0.3.0",
		"notes": [
			"Dirty tanks! Grime slowly builds up on the glass.",
			"Press W (or [ clean ]) and scrub with the left button held. Slow strokes clean best; right-click rinses the sponge.",
			"Dirty water earns less, makes fish sick ( ~ ) and costs them levels. Left fully covered, fish start to die.",
			"Fish Medicine (shop) revives a dead fish within 5 minutes, or cures a sick one. Or flush it.",
			"New upgrades: Algae eater, Filter and UV lamp slow the grime down.",
			"Scrub the tank spotless for +25% coins for 3 minutes.",
			"Smaller, tidier shop in small windows.",
			"Don't want grime? Turn it (or fish deaths) off in settings.",
		],
	},
	{
		"version": "0.2.0",
		"notes": [
			"fishy updates itself: it tells you when a new version is out and asks first.",
			"Installer with a Start menu entry.",
			"Fish list (L), Shift-click to buy as many as you can afford, F feeds every hungry fish.",
			"Start with Windows, save backups, export / import, and a stats screen.",
		],
	},
]


# "0.10.0" > "0.9.3": compare number by number.
static func newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


# Notes for every version after `since` (all of them if since is "").
static func text_since(since: String, limit := 3) -> String:
	var parts := []
	for e in ENTRIES:
		if since != "" and not newer(e.version, since):
			break
		var lines := ["v%s" % e.version]
		for n in e.notes:
			lines.append("- " + n)
		parts.append("\n".join(lines))
		if parts.size() >= limit:
			break
	return "\n\n".join(parts)
