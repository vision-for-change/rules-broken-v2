## EventBus.gd
## Global signal hub. All systems communicate through here.
## No direct node references needed between systems.
extends Node

# ─── Rule System Events ───────────────────────────────────────────
signal rule_registered(rule: Dictionary)
signal rule_removed(rule_id: String)
signal rule_conflict_detected(rule_a: String, rule_b: String)
signal rule_overridden(winner: String, loser: String)

# ─── Action System Events ─────────────────────────────────────────
signal action_attempted(action: Dictionary)
signal action_approved(action: Dictionary)
signal action_denied(action: Dictionary, reason: String)
signal action_exploited(action: Dictionary, loophole: String)

# ─── Entity Events ────────────────────────────────────────────────
signal entity_registered(entity_id: String, entity_data: Dictionary)
signal entity_removed(entity_id: String)
signal entity_state_changed(entity_id: String, old_state: String, new_state: String)
signal entity_tag_changed(entity_id: String, tag: String, added: bool)

# ─── AI/Watchdog Events ───────────────────────────────────────────
signal watchdog_state_changed(watchdog_id: String, old_state: String, new_state: String)
signal watchdog_alert(watchdog_id: String, target_id: String, reason: String)
signal watchdog_blocked(watchdog_id: String, rule_id: String)

# ─── System Integrity Events ──────────────────────────────────────
signal integrity_changed(new_value: float, delta: float)
signal system_unstable()
signal system_critical()
signal system_stable()

# ─── World Events ─────────────────────────────────────────────────
signal terminal_accessed(terminal_id: String)
signal door_state_changed(door_id: String, is_open: bool)
signal loophole_discovered(loophole_id: String, description: String)
signal enemy_defeated(enemy_id: String)
signal player_health_changed(current_health: int, max_health: int)
signal level_complete()
signal player_caught(catcher_id: String)

# ─── UI Events ────────────────────────────────────────────────────
signal log_event(message: String, severity: String)  # severity: info/warn/error/exploit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Convenience: emit a log event with a formatted message
func log(msg: String, severity: String = "info") -> void:
	log_event.emit(msg, severity)
