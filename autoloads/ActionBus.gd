## ActionBus.gd
## All gameplay interactions are submitted here as abstract action requests.
## The pipeline: submit → validate → dispatch → react
extends Node

# ─── Action Types (string constants) ─────────────────────────────
const MOVE      = "MOVE"
const INTERACT  = "INTERACT"
const DELETE    = "DELETE"
const BYPASS    = "BYPASS"
const ALERT     = "ALERT"
const ACCESS    = "ACCESS"
const TRANSMIT  = "TRANSMIT"
const OVERWRITE = "OVERWRITE"

## Action schema:
## {
##   type:       String        action type constant
##   actor_id:   String        entity performing action
##   actor_tags: Array         tags of the performing entity
##   target_id:  String        entity being acted on (optional)
##   context:    Dictionary    extra data (position, direction, etc.)
##   timestamp:  int           auto-filled
## }

var _action_history: Array[Dictionary] = []
const HISTORY_MAX = 50

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Primary entry point for ALL gameplay interactions
func submit(action_type: String, actor_tags: Array, context: Dictionary = {}) -> Dictionary:
	var action = {
		"type":       action_type,
		"actor_tags": actor_tags,
		"actor_id":   context.get("actor_id", "unknown"),
		"target_id":  context.get("target_id", ""),
		"context":    context,
		"timestamp":  Time.get_ticks_msec()
	}

	EventBus.action_attempted.emit(action)

	# Run through RuleManager validation pipeline
	var result = RuleManager.validate_action(action_type, actor_tags, context)

	action["result"] = result
	_record(action)

	if result["allowed"]:
		EventBus.action_approved.emit(action)
		if result["loophole"] != "":
			EventBus.loophole_discovered.emit(
				"%s_%d" % [action_type, Time.get_ticks_msec()],
				result["loophole"]
			)
	else:
		EventBus.action_denied.emit(action, result["reason"])
		AudioManager.play_sfx("denied")
		EventBus.log("DENIED: %s — %s" % [action_type, result["reason"]], "warn")

	return result

## Check without actually submitting (used for AI preview checks)
func preview(action_type: String, actor_tags: Array, context: Dictionary = {}) -> Dictionary:
	return RuleManager.validate_action(action_type, actor_tags, context)

func get_history() -> Array:
	return _action_history.duplicate()

func _record(action: Dictionary) -> void:
	_action_history.push_back(action)
	if _action_history.size() > HISTORY_MAX:
		_action_history.pop_front()
