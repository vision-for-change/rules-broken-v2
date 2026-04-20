# SYSTEM//BREACH
### Systems-Driven Stealth Game — Godot 4.6

---

## HOW TO OPEN
1. Extract zip anywhere
2. Open **Godot 4.6**
3. Import → select `project.godot`
4. Press **F5**

---

## CONTROLS
| Key | Action |
|-----|--------|
| Arrow Keys / WASD | Move |
| E / F | Interact with objects |
| Tab | Toggle hacked client panel |
| ` (backtick) | Toggle system log |
| Escape | Back to menu |

---

## GAME SYSTEMS ARCHITECTURE

### 1. EventBus (autoloads/EventBus.gd)
Zero-coupling signal hub. All systems communicate through signals here.
No node holds a direct reference to another system node.

### 2. RuleManager (autoloads/RuleManager.gd)
The heart of the game. Rules are Dictionary data structures with:
- `priority` (int 0-100) — determines conflict resolution
- `applies_to` (tags) — which entities are subject to this rule
- `blocks` / `allows` (action types) — what the rule permits/denies
- `severity` — soft/hard/critical
- `conflicts` — which other rules this one fights with

Conflict resolution: if a rule ALLOWS and another BLOCKS the same action,
the higher-priority rule wins. This is how loopholes emerge.

### 3. ActionBus (autoloads/ActionBus.gd)
Every interaction goes through `ActionBus.submit(type, tags, context)`.
Returns `{ allowed, reason, loophole, blocking_rule }`.
This is the single choke point that makes the system auditable.

Action types: MOVE, INTERACT, ACCESS, ALERT, BYPASS, DELETE, OVERWRITE

### 4. EntityRegistry (autoloads/EntityRegistry.gd)
Every game object registers here with:
- `type` (player/watchdog/terminal/sign)
- `tags` (dynamic array — rules match against these)
- `state` (current state machine state)
- `metadata` (arbitrary key/value store)

Tags are the connective tissue between entities and rules.

### 5. RuleDefinitions (autoloads/RuleDefinitions.gd)
Static data library of all possible rules. Levels pick which to activate.
Add new rules here — never hardcode rule logic in entity scripts.

---

## EMERGENT LOOPHOLES

The system produces real loopholes from rule interactions:

### Loophole 1: Priority Override (Level 1)
- `no_running` (priority 50) blocks MOVE for tagged "running"
- `permit_run` (priority 65) allows MOVE for tagged "authorized"
- If player gains "authorized" tag, `permit_run` beats `no_running`
- The system logs this as an exploit, not a cheat

### Loophole 2: Sign Inversion (Level 4)
- Destroying the `no_running` sign grants `permit_run` rule
- This is configured in the sign's `grants_rule_id` field
- One action creates a new permission from its own destruction

### Loophole 3: Watchdog Rule-Block
- Watchdogs submit ALERT through ActionBus too
- `watchdog_no_alert` blocks the ALERT action type for "enforcer" tags
- Create this rule state → watchdogs literally cannot alert

### Loophole 4: Identity Spoof (Level 4)
- Terminal command SPOOF_IDENTITY removes "agent" tag, adds "administrator"
- `permit_bypass` applies to "administrator" with priority 90
- Bypasses `restricted_zone` (priority 75) via priority win

### Loophole 5: Integrity Lockdown Cascade
- Exploit too many rules → integrity drops → `integrity_lockdown` fires
- This is a TRAP — the system fights back

---

## FREE ASSETS

### Sprites (drop into assets/sprites/)
**Kenney Tiny Dungeon** — https://kenney.nl/assets/tiny-dungeon
- 16x16 top-down characters — use rogue for player, knight for watchdog

### Audio SFX (generate at https://sfxr.me, save as .wav to assets/audio/sfx/)
| Filename | Preset |
|----------|--------|
| footstep.wav | Coin/Pickup (very short) |
| denied.wav | Hit/Hurt |
| exploit.wav | Powerup |
| sign_break.wav | Explosion (short) |
| terminal_access.wav | Blip/Select |
| level_complete.wav | Powerup (rising) |
| caught.wav | Hit/Hurt (dramatic) |
| lockdown.wav | Explosion |

### Music (drop as .ogg into assets/audio/music/)
| Filename | Source |
|----------|--------|
| music_stable.ogg | OpenGameArt: "stealth loop cc0" |
| music_unstable.ogg | OpenGameArt: "tense ambient loop" |
| music_critical.ogg | OpenGameArt: "danger loop" |
| music_alert.ogg | OpenGameArt: "chase music cc0" |

All from https://opengameart.org — search the terms above, filter CC0.

---

## ADDING NEW RULES

Edit `autoloads/RuleDefinitions.gd`, add to the RULES dictionary:
```gdscript
"my_new_rule": {
    "id": "my_new_rule",
    "priority": 55,
    "applies_to": ["player"],   # tags to match
    "blocks": ["INTERACT"],     # action types blocked
    "allows": [],
    "conditions": {},
    "severity": "hard",
    "conflicts": ["permit_access"],
    "source": "system",
    "display": "NO INTERACTION"
}
```
Then reference it in a level's `initial_rules` array or sign's `rule_id`.

---

## ADDING NEW LEVELS

1. Create `scenes/levels/Level5.tscn`
2. Set root script to `BaseLevel.gd`
3. Set `level_number = 5`
4. Populate `initial_rules` array with rule IDs from RuleDefinitions
5. Place Player, Watchdog(s), Signs, Terminals, Exit instances
6. The system handles everything else

---

## PROJECT STRUCTURE
```
SYSTEM//BREACH/
├── autoloads/
│   ├── EventBus.gd          # Signal hub
│   ├── RuleManager.gd       # Rule engine + validation pipeline
│   ├── ActionBus.gd         # Unified action dispatch
│   ├── EntityRegistry.gd    # Entity + tag tracking
│   ├── RuleDefinitions.gd   # Rule data library
│   ├── AudioManager.gd      # Context music + SFX
│   ├── ScreenFX.gd          # Juice + glitch effects
│   └── InputSetup.gd        # Runtime input mapping
├── scenes/
│   ├── player/Player.tscn   # Player (submits all actions to ActionBus)
│   ├── enemy/Watchdog.tscn  # AI (also submits ALERT through ActionBus!)
│   ├── objects/
│   │   ├── RuleSign.tscn    # Destroyable rule source
│   │   ├── Terminal.tscn    # Rule injection interface
│   │   └── Exit.tscn        # Exit (validated via ActionBus)
│   ├── levels/
│   │   ├── BaseLevel.gd     # Level orchestrator
│   │   └── Level1-4.tscn    # 4 playable sectors
│   └── ui/
│       ├── HUD.tscn         # Live rule inspector + system log
│       ├── MainMenu.tscn
│       ├── GameOver.tscn
│       └── WinScreen.tscn
└── assets/
    ├── audio/music/         # ← drop .ogg files here
    └── audio/sfx/           # ← drop .wav files here
```
