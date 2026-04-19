## RuleDefinitions.gd
## Static data library of all possible rules in the game.
## Rules are requested by ID — never hardcoded into level scripts.
## This is the "rulebook" the entire system runs on.
extends Node

## All rules defined here as data. Levels pick which to activate.
const RULES := {

	# ── Movement Restrictions ──────────────────────────────────────
	"no_running": {
		"id": "no_running", "priority": 50,
		"applies_to": ["player", "agent"],
		"blocks": ["MOVE"],
		"allows": [],
		"conditions": {"tag_has": "running"},
		"severity": "hard",
		"conflicts": ["permit_run"],
		"source": "system",
		"display": "NO RUNNING"
	},
	"no_move": {
		"id": "no_move", "priority": 70,
		"applies_to": ["player", "agent"],
		"blocks": ["MOVE"],
		"allows": [],
		"conditions": {},
		"severity": "hard",
		"conflicts": ["permit_move"],
		"source": "system",
		"display": "NO MOVEMENT"
	},

	# ── Access Restrictions ───────────────────────────────────────
	"no_access": {
		"id": "no_access", "priority": 60,
		"applies_to": ["agent"],
		"blocks": ["ACCESS", "INTERACT"],
		"allows": [],
		"conditions": {},
		"severity": "hard",
		"conflicts": ["permit_access"],
		"source": "system",
		"display": "NO ACCESS"
	},
	"restricted_zone": {
		"id": "restricted_zone", "priority": 75,
		"applies_to": ["agent"],
		"blocks": ["MOVE", "ACCESS"],
		"allows": [],
		"conditions": {},
		"severity": "critical",
		"conflicts": ["permit_bypass"],
		"source": "system",
		"display": "RESTRICTED ZONE"
	},

	# ── Watchdog Restrictions (exploitable!) ─────────────────────
	"watchdog_no_alert": {
		"id": "watchdog_no_alert", "priority": 80,
		"applies_to": ["enforcer", "watchdog"],
		"blocks": ["ALERT"],
		"allows": [],
		"conditions": {},
		"severity": "hard",
		"conflicts": ["watchdog_enforce"],
		"source": "system",
		"display": "ALERT SUSPENDED"
	},
	"watchdog_enforce": {
		"id": "watchdog_enforce", "priority": 60,
		"applies_to": ["enforcer", "watchdog"],
		"blocks": [],
		"allows": ["ALERT"],
		"conditions": {},
		"severity": "hard",
		"conflicts": ["watchdog_no_alert"],
		"source": "system",
		"display": "ENFORCE PROTOCOL"
	},

	# ── Permission Escalation (loophole enablers) ─────────────────
	"permit_run": {
		"id": "permit_run", "priority": 65,
		"applies_to": ["authorized", "administrator"],
		"blocks": [],
		"allows": ["MOVE"],
		"conditions": {},
		"severity": "soft",
		"conflicts": ["no_running"],
		"source": "player",
		"display": "AUTHORIZED MOVEMENT"
	},
	"permit_access": {
		"id": "permit_access", "priority": 70,
		"applies_to": ["authorized"],
		"blocks": [],
		"allows": ["ACCESS", "INTERACT"],
		"conditions": {},
		"severity": "soft",
		"conflicts": ["no_access"],
		"source": "player",
		"display": "ACCESS GRANTED"
	},
	"permit_bypass": {
		"id": "permit_bypass", "priority": 90,
		"applies_to": ["administrator"],
		"blocks": [],
		"allows": ["BYPASS", "ACCESS", "MOVE", "INTERACT", "OVERWRITE"],
		"conditions": {},
		"severity": "soft",
		"conflicts": ["restricted_zone", "no_access"],
		"source": "player",
		"display": "BYPASS ACTIVE"
	},

	# ── Meta rules (high-level system state) ─────────────────────
	"integrity_lockdown": {
		"id": "integrity_lockdown", "priority": 100,
		"applies_to": ["*"],
		"blocks": ["BYPASS", "DELETE", "OVERWRITE"],
		"allows": [],
		"conditions": {},
		"severity": "critical",
		"conflicts": ["permit_bypass"],
		"source": "system",
		"display": "SYSTEM LOCKDOWN"
	},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_rule(rule_id: String) -> Dictionary:
	return RULES.get(rule_id, {})

func get_all_ids() -> Array:
	return RULES.keys()
