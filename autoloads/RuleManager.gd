## RuleManager.gd
## Central rule engine. Rules are data structures processed through
## a validation pipeline. Supports priority, conflicts, overrides, tags.
extends Node

# ─── Rule Schema ──────────────────────────────────────────────────
## Rule: {
##   id:          String         unique identifier
##   priority:    int            higher = wins conflicts (0-100)
##   applies_to:  Array[String]  entity tags this rule targets
##   blocks:      Array[String]  action types this rule blocks
##   allows:      Array[String]  action types this rule explicitly permits
##   conditions:  Dictionary     {tag: must_have, state: must_be_in}
##   severity:    String         "soft" | "hard" | "critical"
##   conflicts:   Array[String]  rule IDs this rule conflicts with
##   source:      String         who created this rule (system, player, ai)
## }

const SEVERITY_SOFT     = "soft"
const SEVERITY_HARD     = "hard"
const SEVERITY_CRITICAL = "critical"

var _rules: Dictionary = {}
var _conflict_log: Array[Dictionary] = []
const MAX_SYSTEM_INTEGRITY := 9.0
var system_integrity: float = MAX_SYSTEM_INTEGRITY
const HACK_DRAIN_PER_SECOND := 0.4

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if system_integrity <= 0.0:
		return

# ─── Public API ───────────────────────────────────────────────────

func register_rule(rule: Dictionary) -> bool:
	if not _validate_rule_schema(rule):
		push_error("RuleManager: Invalid rule schema for id=%s" % rule.get("id", "UNKNOWN"))
		return false

	var id = rule["id"]
	_rules[id] = rule
	_check_new_conflicts(id)
	EventBus.rule_registered.emit(rule)
	EventBus.log("RULE ADDED: [%s] p=%d sev=%s" % [id, rule["priority"], rule["severity"]], "info")
	return true

func remove_rule(rule_id: String) -> void:
	if not _rules.has(rule_id):
		return
	_rules.erase(rule_id)
	EventBus.rule_removed.emit(rule_id)
	EventBus.log("RULE REMOVED: [%s]" % rule_id, "warn")
	_recalculate_integrity()

func get_rule(rule_id: String) -> Dictionary:
	return _rules.get(rule_id, {})

func get_all_rules() -> Array:
	return _rules.values()

func get_active_rule_ids() -> Array:
	return _rules.keys()

func is_rule_active(rule_id: String) -> bool:
	return _rules.has(rule_id)

func validate_action(action_type: String, actor_tags: Array, context: Dictionary = {}) -> Dictionary:
	var result = { "allowed": true, "reason": "", "loophole": "", "blocking_rule": "" }

	var applicable = _get_applicable_rules(action_type, actor_tags, context)

	if applicable.is_empty():
		return result

	applicable.sort_custom(func(a, b): return a["priority"] > b["priority"])

	var highest_allow = _find_highest_allow(applicable, action_type)
	var highest_block = _find_highest_block(applicable, action_type)

	if highest_allow != null and highest_block != null:
		if highest_allow["priority"] > highest_block["priority"]:
			var loophole_desc = "Rule [%s] overrides [%s] for action %s" % [
				highest_allow["id"], highest_block["id"], action_type
			]
			result["loophole"] = loophole_desc
			result["allowed"] = true
			_adjust_integrity(-0.05)
			EventBus.action_exploited.emit({"type": action_type, "tags": actor_tags}, loophole_desc)
			EventBus.log("LOOPHOLE: %s" % loophole_desc, "exploit")
		else:
			result["allowed"] = false
			result["reason"] = "Rule [%s] blocks %s" % [highest_block["id"], action_type]
			result["blocking_rule"] = highest_block["id"]
	elif highest_block != null:
		result["allowed"] = false
		result["reason"] = "Rule [%s] blocks %s (sev=%s)" % [
			highest_block["id"], action_type, highest_block["severity"]
		]
		result["blocking_rule"] = highest_block["id"]
		if highest_block["severity"] == SEVERITY_CRITICAL:
			_adjust_integrity(-0.15)

	return result

func check_conflict(rule_id_a: String, rule_id_b: String) -> bool:
	var a = _rules.get(rule_id_a, {})
	var b = _rules.get(rule_id_b, {})
	if a.is_empty() or b.is_empty():
		return false
	for act in a.get("blocks", []):
		if act in b.get("allows", []):
			return true
	for act in b.get("blocks", []):
		if act in a.get("allows", []):
			return true
	return false

func get_integrity() -> float:
	return system_integrity

func get_max_integrity() -> float:
	return MAX_SYSTEM_INTEGRITY

func get_integrity_ratio() -> float:
	if MAX_SYSTEM_INTEGRITY <= 0.0:
		return 0.0
	return system_integrity / MAX_SYSTEM_INTEGRITY

func apply_integrity_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _is_player_invincible():
		return
	_adjust_integrity(-amount)

func apply_integrity_heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_adjust_integrity(amount)

# ─── Private ──────────────────────────────────────────────────────

func _validate_rule_schema(rule: Dictionary) -> bool:
	for required in ["id", "priority", "applies_to", "blocks", "allows", "severity"]:
		if not rule.has(required):
			return false
	return true

func _get_applicable_rules(action_type: String, actor_tags: Array, context: Dictionary) -> Array:
	var result = []
	for rule in _rules.values():
		var tag_match = false
		for tag in rule.get("applies_to", []):
			if tag == "*" or tag in actor_tags:
				tag_match = true
				break
		if not tag_match:
			continue

		if not _check_conditions(rule.get("conditions", {}), actor_tags, context):
			continue

		var affects = (action_type in rule.get("blocks", [])) or (action_type in rule.get("allows", []))
		if not affects:
			continue

		result.append(rule)
	return result

func _check_conditions(conditions: Dictionary, actor_tags: Array, context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("tag_has"):
		if not conditions["tag_has"] in actor_tags:
			return false
	if conditions.has("tag_lacks"):
		if conditions["tag_lacks"] in actor_tags:
			return false
	if conditions.has("context_key"):
		var ck = conditions["context_key"]
		if not context.get(ck["key"]) == ck["value"]:
			return false
	return true

func _find_highest_allow(rules: Array, action_type: String) -> Dictionary:
	for r in rules:
		if action_type in r.get("allows", []):
			return r
	return {}

func _find_highest_block(rules: Array, action_type: String) -> Dictionary:
	for r in rules:
		if action_type in r.get("blocks", []):
			return r
	return {}

func _check_new_conflicts(new_id: String) -> void:
	for existing_id in _rules.keys():
		if existing_id == new_id:
			continue
		if check_conflict(new_id, existing_id):
			_conflict_log.append({"a": new_id, "b": existing_id, "time": Time.get_ticks_msec()})
			EventBus.rule_conflict_detected.emit(new_id, existing_id)
			EventBus.log("CONFLICT DETECTED: [%s] vs [%s]" % [new_id, existing_id], "warn")
			_adjust_integrity(-0.08)

var _death_triggered := false

func _adjust_integrity(delta: float) -> void:
	if _death_triggered:
		return
	if delta < 0.0 and _is_player_invincible():
		return

	var old = system_integrity
	system_integrity = clampf(system_integrity + delta, 0.0, MAX_SYSTEM_INTEGRITY)

	print("INTEGRITY:", system_integrity, " | delta:", delta)

	EventBus.integrity_changed.emit(system_integrity, delta)

	var critical_threshold := MAX_SYSTEM_INTEGRITY * 0.25
	var unstable_threshold := MAX_SYSTEM_INTEGRITY * 0.5

	# Emit warnings when crossing thresholds
	if system_integrity < critical_threshold and old >= critical_threshold:
		EventBus.system_critical.emit()
		EventBus.log("!! SYSTEM CRITICAL — integrity below 25%", "error")
	elif system_integrity < unstable_threshold and old >= unstable_threshold:
		EventBus.system_unstable.emit()
		EventBus.log("! SYSTEM UNSTABLE — integrity below 50%", "warn")

	# Integrity still drives warnings and lockdowns, but it should not
	# instantly kill the player while their actual health is still high.


func _recalculate_integrity() -> void:
	_adjust_integrity(0.1)

func clear_rules() -> void:
	_rules.clear()
	_conflict_log.clear()
	_death_triggered = false
	system_integrity = MAX_SYSTEM_INTEGRITY
	EventBus.integrity_changed.emit(system_integrity, 0.0)

func _count_active_player_hacks() -> int:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return 0
	var player = players[0]
	if player == null or not player.has_method("get_hacked_client_modes"):
		return 0
	var modes: Dictionary = player.get_hacked_client_modes()
	var count := 0
	for enabled in modes.values():
		if bool(enabled):
			count += 1
	return count

func _is_player_invincible() -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var player = players[0]
	if player == null:
		return false
	if player.has_method("is_hack_invincible"):
		return bool(player.call("is_hack_invincible"))
	if player.has_method("get_hacked_client_modes"):
		var modes: Dictionary = player.get_hacked_client_modes()
		return bool(modes.get("invincible", false))
	return false
