# IMMUNE

IMMUNE is a single-player, turn-based strategy game on a 3D hex board. You control the blue T cells and defend seven gold human cells in the center. You win by eliminating all pink bacteria. The bacteria win by infecting all seven human cells.

## Run the game

The project was tested with Godot 4.7.2 and uses the Compatibility renderer.

1. Clone the repository with `git clone https://github.com/kitretsu101/IMMUNE.git`.
2. In Godot's Project Manager, choose **Import** and select `project.godot`.
3. Open the project and press **F5** to play.

## How to play

- **Move.** Select a T cell, choose **Move**, then click a highlighted hex. A cell can move up to four hexes, depending on its individual range, and can cross only empty hexes. Human cells stay on their starting tiles until infected and block T-cell movement.
- **Clone.** Select a T cell, choose **Clone**, then click a green hex next to it. The parent stays in place and creates one copy. During clonal evolution, one trait on the copy rolls −1, 0, or +1 within its allowed range. T cells can vary in movement range. For bacteria, either movement range or infectibility can vary.
- **Capture and infect.** A T cell consumes the bacterium it lands on. A bacterium can consume a T cell that stands in its way. When a bacterium lands on a human cell, its infectibility sets how many human cells it can infect, including the one it lands on and any adjacent human cells. Infected human cells are removed from the board. Hover over a bacterium on your turn to see its stats.

Each side takes one action per turn. A side with no legal action passes. The game draws if both sides pass consecutively.

## Controls

| Input | Action |
| --- | --- |
| Left-click | Select a T cell or choose a highlighted destination |
| `M` / `C` | Switch to Move / Clone |
| Right-drag | Pan the camera |
| Middle-drag | Orbit the camera |
| Scroll | Zoom |
| `R` | Restart the match |

## Bacterial AI

The bacteria use two-ply minimax. The AI rewards infecting human cells and moving closer to those still healthy. It checks whether T cells can capture bacteria in response and accounts for the probability of each clonal evolution outcome.

## Asset credits

See [asset credits](assets/CREDITS.md) for model sources and licenses.
