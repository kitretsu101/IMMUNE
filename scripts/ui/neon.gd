class_name Neon
extends RefCounted
## The IMMUNE colour system. One place for every colour so panels, tiles and organisms agree.

const BACKGROUND := Color("#040918")
const PANEL := Color(0.02, 0.04, 0.11, 0.88)
const PANEL_SOLID := Color("#060D22")
const PANEL_RAISED := Color(0.035, 0.06, 0.15, 0.92)
const BORDER := Color(0.45, 0.55, 0.8, 0.22)
const BORDER_STRONG := Color(0.18, 0.88, 1.0, 0.75)
const TEXT := Color("#B9C6E4")
const TEXT_MUTED := Color("#6E7FA6")
const TEXT_DIM := Color("#3F4E72")

const CYAN := Color("#2DE1FF")
const PURPLE := Color("#A56BFF")
const GREEN := Color("#3DFF8A")
const RED := Color("#FF3D5E")
const ORANGE := Color("#FF8A3D")
const YELLOW := Color("#FFE24D")
const MAGENTA := Color("#FF4FD8")
const GREY := Color("#6B7385")
const TEAL := Color("#0F6B72")

const BACTERIA := Color("#39FF88")
const IMMUNE := Color("#28E6FF")
const TISSUE_HEALTHY := Color("#0C4A55")
const TISSUE_INFECTED := Color("#FF2D4F")
const TISSUE_DAMAGED := Color("#B5551A")
const TISSUE_DESTROYED := Color("#3A3F4A")
const NUTRIENT := YELLOW
const CHEMICAL := PURPLE
const BIOFILM := Color("#D93FD0")

const ANTIGEN_HUES := [0.40, 0.29, 0.22, 0.47]


static func team_color(team: int) -> Color:
	return IMMUNE if team == Sim.IMMUNE else BACTERIA


static func antigen_color(antigen: int) -> Color:
	return Color.from_hsv(ANTIGEN_HUES[antigen % 4], 0.78, 1.0)


static func severity_color(severity: String) -> Color:
	match severity:
		"critical": return RED
		"important": return ORANGE
		"notable": return CYAN
	return TEXT_MUTED


static func category_color(category: String) -> Color:
	match category:
		"Movement": return CYAN
		"Infection": return RED
		"Reproduction": return GREEN
		"Combat": return ORANGE
		"Death": return MAGENTA
		"Evolution": return PURPLE
		"Environment": return YELLOW
	return TEXT_MUTED
