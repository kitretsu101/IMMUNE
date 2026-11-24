extends Node
## Signal hub. Nodes announce what happened here and never reach into each other.

## Every simulation event (see Ev). Presentation, audio and logging all listen to this one signal.
signal sim_event(event: Dictionary)
signal decision_made(decision: Decision)
signal round_changed(round_number: int)
signal side_changed(side: int)
signal state_changed
signal status_changed(status: String)
signal speed_changed(speed: float)
signal organism_selected(org_id: int)
signal organism_hovered(org_id: int)
signal view_mode_changed(mode: int)
signal notify(text: String, severity: String)
signal game_over(result: Dictionary)
signal request_log_window(visible: bool)
signal request_menu
signal match_loaded
signal infection_level(level: float)
signal settings_changed

enum View { NORMAL, INFECTION, NUTRIENTS, IMMUNE, EVOLUTION }
const VIEW_NAMES := ["Normal", "Infection", "Nutrients", "Immune", "Evolution"]
