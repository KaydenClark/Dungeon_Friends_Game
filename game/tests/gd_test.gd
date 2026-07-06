extends Node
## Tiny assertion base class for the headless unit suites (see
## /RUNBOOK.md -> Test Coverage Policy). There is no GUT/third-party framework
## yet; this is the smallest thing that gives real red/green on pure logic
## without pulling an addon into game/addons/. Each suite `extends` this file
## and defines `test_*` methods; tests/run_tests.gd discovers and runs them.
##
## Assertions record a pass or a labelled failure; they never abort the run, so
## one broken expectation doesn't hide the rest. The runner reads `checks` and
## `failures` after each suite.

var checks := 0
var failures: Array[String] = []
## Set by the runner before each test so failure messages carry their origin.
var _ctx := "?"


func set_context(ctx: String) -> void:
	_ctx = ctx


func _pass() -> void:
	checks += 1


func _fail(msg: String) -> void:
	checks += 1
	var line := "%s: %s" % [_ctx, msg]
	failures.append(line)
	print("    CHECK FAILED: ", line)


func ok(cond: bool, msg: String) -> void:
	if cond:
		_pass()
	else:
		_fail(msg)


func not_ok(cond: bool, msg: String) -> void:
	ok(not cond, msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_pass()
	else:
		_fail("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func ne(actual: Variant, unexpected: Variant, msg: String) -> void:
	if actual != unexpected:
		_pass()
	else:
		_fail("%s (should not equal %s)" % [msg, str(unexpected)])


func is_null(value: Variant, msg: String) -> void:
	ok(value == null, msg)


func not_null(value: Variant, msg: String) -> void:
	ok(value != null, msg)
