## Terminal.gd
## Players can access terminals to inject/override rules,
## change their own tags, or read system state.
## Key mechanic: terminals let the player manipulate the rule engine directly.
extends StaticBody2D

@export var terminal_id       := "terminal_01"
@export var terminal_commands : Array[String] = []  # available commands
@export var requires_tag      := ""  # player must have this tag to access

var entity_id := ""
var _accessed := false

@onready var body_rect: ColorRect  = $BodyRect
@onready var glow_rect: ColorRect  = $GlowRect
@onready var label: Label          = $Label

const COMMAND_DEFS := {
	"GRANT_ACCESS": {
		"desc": "Grants 'authorized' tag to agent",
		"action": "grant_tag",
		"tag": "authorized"
	},
	"DISABLE_WATCHDOG": {
		"desc": "Tags watchdogs as 'disabled'",
		"action": "tag_entities",
		"target_type": "watchdog",
		"tag": "disabled"
	},
	"INJECT_PERMIT": {
		"desc": "Injects a BYPASS rule (priority 90)",
		"action": "inject_rule",
		"rule": "permit_bypass"
	},
	"CORRUPT_RULESET": {
		"desc": "Removes all soft rules",
		"action": "purge_soft_rules"
	},
	"SPOOF_IDENTITY": {
		"desc": "Adds 'authorized' and removes 'agent' tag",
		"action": "spoof"
	}
}

func _ready() -> void:
	entity_id = terminal_id
	EntityRegistry.register(entity_id, "terminal", self,
		["terminal", "interactable"],
		{"commands": terminal_commands}
	)
	label.text = "[TERMINAL]"
	_animate_idle()

func on_player_interact(action_result: Dictionary) -> void:
	# Check access requirement
	if requires_tag != "" and not EntityRegistry.has_tag("player", requires_tag):
		EventBus.log("ACCESS DENIED: terminal requires tag [%s]" % requires_tag, "warn")
		AudioManager.play_sfx("denied")
		ScreenFX.flash_screen(Color(1, 0.2, 0.1, 0.3), 0.2)
		return

	EventBus.terminal_accessed.emit(terminal_id)
	EventBus.log("TERMINAL ACCESSED: %s" % terminal_id, "info")
	AudioManager.play_sfx("terminal_access")
	ScreenFX.flash_screen(Color(0.1, 0.8, 0.4, 0.25), 0.3)

	# Execute all available commands
	for cmd_name in terminal_commands:
		_execute_command(cmd_name)

func _execute_command(cmd_name: String) -> void:
	var cmd = COMMAND_DEFS.get(cmd_name, {})
	if cmd.is_empty():
		return

	EventBus.log("EXEC: %s — %s" % [cmd_name, cmd["desc"]], "info")

	match cmd["action"]:
		"grant_tag":
			EntityRegistry.add_tag("player", cmd["tag"])
			EventBus.log("TAG GRANTED: player +[%s]" % cmd["tag"], "exploit")

		"tag_entities":
			var entities = EntityRegistry.get_entities_of_type(cmd["target_type"])
			for e in entities:
				EntityRegistry.add_tag(e["id"], cmd["tag"])
				var node = EntityRegistry.get_node(e["id"])
				if node and node.has_method("stun"):
					node.stun(8.0)
			EventBus.log("WATCHDOGS DISABLED via terminal", "exploit")

		"inject_rule":
			var rule = RuleDefinitions.get_rule(cmd["rule"])
			if not rule.is_empty():
				RuleManager.register_rule(rule)

		"purge_soft_rules":
			for rule in RuleManager.get_all_rules():
				if rule.get("severity") == "soft":
					RuleManager.remove_rule(rule["id"])
			EventBus.log("SOFT RULES PURGED", "exploit")

		"spoof":
			EntityRegistry.add_tag("player", "authorized")
			EntityRegistry.remove_tag("player", "agent")
			EntityRegistry.add_tag("player", "administrator")
			EventBus.log("IDENTITY SPOOFED: player is now [administrator]", "exploit")

	ScreenFX.exploit_flash()

func get_interact_hint() -> String:
	return "ACCESS TERMINAL"

func _animate_idle() -> void:
	var t = create_tween().set_loops()
	t.tween_property(glow_rect, "modulate:a", 0.45, 0.65)
	t.tween_property(glow_rect, "modulate:a", 1.0, 0.65)
