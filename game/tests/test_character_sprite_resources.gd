extends "res://tests/gd_test.gd"
## Future T-056 acceptance contract. Register this suite in run_tests.gd only
## after all four *_complete.tres resources exist; the current local package
## contains source studies and one unwired Buddy atlas, not four runtime kits.
## Contract for gameplay-complete party SpriteFrames resources. Every class
## exposes the same names so exploration/combat code stays data-driven.

const CHARACTER_RESOURCES := {
	"paladin": "res://data/sprites/paladin_complete.tres",
	"wizard": "res://data/sprites/wizard_complete.tres",
	"druid": "res://data/sprites/druid_complete.tres",
	"rogue": "res://data/sprites/rogue_complete.tres",
}

const LOOPING_ANIMATIONS := {
	&"idle_n": 4.0,
	&"idle_e": 4.0,
	&"idle_s": 4.0,
	&"walk_n": 8.0,
	&"walk_e": 8.0,
	&"walk_s": 8.0,
	&"combat_idle": 4.0,
}

const ONE_SHOT_ANIMATIONS := {
	&"attack": 8.0,
	&"ability": 8.0,
	&"defend": 8.0,
	&"hurt": 8.0,
	&"ko": 6.0,
}


func test_complete_character_sprite_contract() -> void:
	for character: String in CHARACTER_RESOURCES:
		var path: String = CHARACTER_RESOURCES[character]
		ok(ResourceLoader.exists(path), "%s SpriteFrames resource exists" % character)
		var frames: SpriteFrames = load(path)
		not_null(frames, "%s SpriteFrames resource loads" % character)
		if frames == null:
			continue
		_check_animations(character, frames, LOOPING_ANIMATIONS, true)
		_check_animations(character, frames, ONE_SHOT_ANIMATIONS, false)


func _check_animations(character: String, frames: SpriteFrames,
		expected: Dictionary, should_loop: bool) -> void:
	for animation: StringName in expected:
		ok(frames.has_animation(animation), "%s has %s" % [character, animation])
		if not frames.has_animation(animation):
			continue
		eq(frames.get_frame_count(animation), 4,
				"%s %s has four frames" % [character, animation])
		eq(frames.get_animation_loop(animation), should_loop,
				"%s %s loop contract" % [character, animation])
		eq(frames.get_animation_speed(animation), expected[animation],
				"%s %s speed contract" % [character, animation])
		for index in frames.get_frame_count(animation):
			not_null(frames.get_frame_texture(animation, index),
					"%s %s frame %d has a texture" % [character, animation, index])
