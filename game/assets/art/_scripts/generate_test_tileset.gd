extends SceneTree
## M1.1 test-art generator (T-003). Draws the first real 16x16-unit tiles and
## the hero sprite programmatically so the LDtk pipeline (T-004/T-011) and the
## M1.4 scaling check (T-020) have genuine pixel art to work with before
## Aseprite is installed.
##
## Grid unit decision (M1.1, 2026-07-06): art is authored at 16x16 pixels per
## tile and rendered at 4x, matching RoomGrid.TILE = 64 at the 1280x720 design
## reference. GBA-style unit per /BLUEPRINT.md -> Visual Language.
##
## This is a deterministic stopgap for the Aseprite pipeline, not a replacement:
## once Aseprite lands these become .aseprite sources exported by
## export_sheets.lua (same output paths/sizes, so nothing downstream changes).
##
## Run: Godot --headless --path . --script assets/art/_scripts/generate_test_tileset.gd
## Outputs:
##   assets/art/tilesets/test_tiles.png  (80x16: grass, tree, path, cave floor, cave wall)
##   assets/art/sprites/test_hero.png    (16x16, transparent background)

const TILE := 16

# Bright, readable GBA-fantasy palette (Visual Language: bright greens, tans,
# blues, soft shadows).
const GRASS := Color(0.36, 0.72, 0.28)
const GRASS_DARK := Color(0.29, 0.61, 0.22)
const GRASS_LIGHT := Color(0.55, 0.85, 0.38)
const CANOPY := Color(0.15, 0.44, 0.20)
const CANOPY_LIGHT := Color(0.24, 0.58, 0.26)
const CANOPY_OUTLINE := Color(0.07, 0.22, 0.10)
const TRUNK := Color(0.45, 0.29, 0.12)
const TRUNK_DARK := Color(0.32, 0.20, 0.08)
const PATH := Color(0.82, 0.70, 0.45)
const PATH_DARK := Color(0.71, 0.59, 0.36)
const PATH_LIGHT := Color(0.90, 0.80, 0.55)
const CAVE_FLOOR := Color(0.45, 0.42, 0.47)
const CAVE_FLOOR_DARK := Color(0.38, 0.35, 0.40)
const CAVE_WALL := Color(0.23, 0.20, 0.27)
const CAVE_WALL_DARK := Color(0.16, 0.14, 0.19)
const CAVE_WALL_LIGHT := Color(0.32, 0.29, 0.36)

## Hero: chunky silhouette, oversized head, dark outline (Visual Language:
## identity from silhouette and color, not fine detail). 16 rows x 16 chars.
const HERO_ROWS: Array[String] = [
	"................",
	".....OOOOOO.....",
	"....OHHHHHHO....",
	"...OHHHHHHHHO...",
	"...OHSSSSSSHO...",
	"...OSSWSSWSSO...",
	"...OSSSSSSSSO...",
	"....OSSSSSSO....",
	"....OOOOOOOO....",
	"...OTTTTTTTTO...",
	"..OTTTTTTTTTTO..",
	"..OTTTTTTTTTTO..",
	"...OTTTTTTTTO...",
	"....OLLOOLLO....",
	"....OLLO.OLLO...",
	"....OOO..OOO....",
]
const HERO_PALETTE := {
	"O": Color(0.10, 0.08, 0.12),
	"H": Color(0.55, 0.33, 0.14),
	"S": Color(0.96, 0.80, 0.62),
	"W": Color(0.12, 0.12, 0.20),
	"T": Color(0.20, 0.42, 0.85),
	"L": Color(0.25, 0.22, 0.35),
}


func _init() -> void:
	var failures := 0
	failures += _save(_make_tiles(), "res://assets/art/tilesets/test_tiles.png")
	failures += _save(_make_hero(), "res://assets/art/sprites/test_hero.png")
	if failures == 0:
		print("TEST ART: PASS (tilesets/test_tiles.png, sprites/test_hero.png)")
		quit(0)
	else:
		print("TEST ART: FAIL (%d file(s) not written)" % failures)
		quit(1)


func _save(img: Image, path: String) -> int:
	var err := img.save_png(path)
	if err != OK:
		push_error("failed to save %s (error %d)" % [path, err])
		return 1
	print("  wrote ", path)
	return 0


func _make_tiles() -> Image:
	var img := Image.create_empty(TILE * 5, TILE, false, Image.FORMAT_RGBA8)
	_draw_grass(img, 0)
	_draw_grass(img, 1)   # tree sits on a grass base so field edges tile clean
	_draw_tree(img, 1)
	_draw_speckled(img, 2, PATH, PATH_DARK, PATH_LIGHT, 21)
	_draw_speckled(img, 3, CAVE_FLOOR, CAVE_FLOOR_DARK, CAVE_FLOOR, 22)
	_draw_cave_wall(img, 4)
	return img


## Deterministic speckle fill - fixed seeds keep every regeneration identical.
func _draw_speckled(img: Image, slot: int, base: Color, dark: Color,
		light: Color, seed_val: int) -> void:
	var ox := slot * TILE
	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, y, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in 10:
		img.set_pixel(ox + rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), dark)
	for i in 6:
		img.set_pixel(ox + rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), light)


func _draw_grass(img: Image, slot: int) -> void:
	_draw_speckled(img, slot, GRASS, GRASS_DARK, GRASS_LIGHT, 20)


func _draw_tree(img: Image, slot: int) -> void:
	var ox := slot * TILE
	# Trunk first (canopy overlaps its top).
	for y in range(10, 16):
		for x in range(6, 10):
			var c := TRUNK_DARK if (x == 6 or x == 9 or y == 15) else TRUNK
			img.set_pixel(ox + x, y, c)
	# Canopy: chunky disc with outline and an upper-left highlight.
	var center := Vector2(7.5, 5.5)
	for y in TILE:
		for x in TILE:
			var d := Vector2(x, y).distance_to(center)
			if d <= 5.4:
				var c := CANOPY
				if Vector2(x, y).distance_to(Vector2(5.5, 3.5)) <= 2.2:
					c = CANOPY_LIGHT
				img.set_pixel(ox + x, y, c)
			elif d <= 6.4:
				img.set_pixel(ox + x, y, CANOPY_OUTLINE)


func _draw_cave_wall(img: Image, slot: int) -> void:
	var ox := slot * TILE
	for y in TILE:
		for x in TILE:
			var c := CAVE_WALL
			# Brick courses: mortar line every 4 rows, joints offset per course.
			if y % 4 == 3:
				c = CAVE_WALL_DARK
			elif (x + (y / 4) * 4) % 8 == 7:
				c = CAVE_WALL_DARK
			elif y % 4 == 0:
				c = CAVE_WALL_LIGHT   # top edge of each course catches light
			img.set_pixel(ox + x, y, c)


func _make_hero() -> Image:
	var img := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	assert(HERO_ROWS.size() == TILE, "hero map must be 16 rows")
	for y in HERO_ROWS.size():
		var row := HERO_ROWS[y]
		assert(row.length() == TILE, "hero row %d must be 16 chars" % y)
		for x in row.length():
			var ch := row[x]
			if ch != ".":
				assert(HERO_PALETTE.has(ch), "unknown hero pixel '%s'" % ch)
				img.set_pixel(x, y, HERO_PALETTE[ch])
	return img
