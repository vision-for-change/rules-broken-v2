## EntityRegistry.gd
## Tracks every game entity as a data record.
## Entities are NOT node references — they're data. Nodes register/unregister.
## Rules apply to entities by matching tags dynamically.
extends Node

## Entity record schema:
## {
##   id:       String
##   type:     String        "player" | "watchdog" | "terminal" | "door" | "sign"
##   tags:     Array[String] dynamic, rule-checked tags
##   state:    String        current state machine state
##   node:     Node          weak reference to actual scene node
##   metadata: Dictionary    arbitrary key-value store for context
## }

var _entities: Dictionary = {}  # entity_id -> record

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ─── Registration ─────────────────────────────────────────────────

func register(entity_id: String, entity_type: String, node: Node, initial_tags: Array = [], metadata: Dictionary = {}) -> void:
	var record = {
		"id":       entity_id,
		"type":     entity_type,
		"tags":     initial_tags.duplicate(),
		"state":    "idle",
		"node":     node,
		"metadata": metadata.duplicate()
	}
	_entities[entity_id] = record
	EventBus.entity_registered.emit(entity_id, record)

func unregister(entity_id: String) -> void:
	if _entities.has(entity_id):
		_entities.erase(entity_id)
		EventBus.entity_removed.emit(entity_id)

# ─── Tag Management ───────────────────────────────────────────────

func add_tag(entity_id: String, tag: String) -> void:
	var rec = _entities.get(entity_id)
	if rec == null or tag in rec["tags"]:
		return
	rec["tags"].append(tag)
	EventBus.entity_tag_changed.emit(entity_id, tag, true)

func remove_tag(entity_id: String, tag: String) -> void:
	var rec = _entities.get(entity_id)
	if rec == null:
		return
	rec["tags"].erase(tag)
	EventBus.entity_tag_changed.emit(entity_id, tag, false)

func has_tag(entity_id: String, tag: String) -> bool:
	var rec = _entities.get(entity_id)
	if rec == null:
		return false
	return tag in rec["tags"]

func get_tags(entity_id: String) -> Array:
	var rec = _entities.get(entity_id)
	return rec["tags"].duplicate() if rec != null else []

# ─── State Management ─────────────────────────────────────────────

func set_state(entity_id: String, new_state: String) -> void:
	var rec = _entities.get(entity_id)
	if rec == null:
		return
	var old_state = rec["state"]
	if old_state == new_state:
		return
	rec["state"] = new_state
	EventBus.entity_state_changed.emit(entity_id, old_state, new_state)

func get_state(entity_id: String) -> String:
	return _entities.get(entity_id, {}).get("state", "")

# ─── Metadata ─────────────────────────────────────────────────────

func set_entity_meta(entity_id: String, key: String, value: Variant) -> void:
	var rec = _entities.get(entity_id)
	if rec != null:
		rec["metadata"][key] = value

func get_entity_meta(entity_id: String, key: String, default: Variant = null) -> Variant:
	return _entities.get(entity_id, {}).get("metadata", {}).get(key, default)

# ─── Query ────────────────────────────────────────────────────────

func get_entity(entity_id: String) -> Dictionary:
	return _entities.get(entity_id, {})

func get_entity_node(entity_id: String) -> Node:
	var rec = _entities.get(entity_id)
	if rec == null:
		return null
	return rec["node"] if is_instance_valid(rec["node"]) else null

func get_entities_with_tag(tag: String) -> Array:
	var result = []
	for rec in _entities.values():
		if tag in rec["tags"]:
			result.append(rec)
	return result

func get_entities_of_type(entity_type: String) -> Array:
	var result = []
	for rec in _entities.values():
		if rec["type"] == entity_type:
			result.append(rec)
	return result

func get_all_entities() -> Array:
	return _entities.values().duplicate()

func clear_all() -> void:
	_entities.clear()
