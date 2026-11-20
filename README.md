# IMMUNE

IMMUNE is a single-player, turn-based strategy game on a 3D hex board. You control the blue T cells and play against pink bacteria. Each side wins by eliminating every opposing cell.

## Run the game

The project was tested with Godot 4.7.2 and uses the Compatibility renderer.

1. Clone the repository with `git clone https://github.com/kitretsu101/IMMUNE.git`.
2. In Godot's Project Manager, choose **Import** and select `project.godot`.
3. Open the project and press **F5** to play.

## How to play

- **Move.** Select a T cell, choose **Move**, then click a highlighted hex. A cell can move up to four hexes, depending on its individual range. It can cross empty hexes and capture an opponent by landing on its hex.
- **Clone.** Select a T cell, choose **Clone**, then click a green hex next to it. The parent stays in place and creates one copy. During clonal evolution, one trait on the copy rolls −1, 0, or +1 within its allowed range. T cells can vary in movement range. For bacteria, either movement range or infectibility can vary.
- **Capture.** A T cell consumes the bacterium it lands on. A bacterium consumes the T cell it lands on and can also consume adjacent T cells. Its infectibility sets the maximum number consumed in that capture, including the T cell it lands on. Hover over a bacterium on your turn to see its stats.

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

The bacteria use two-ply minimax. The AI evaluates each legal bacterial action against the strongest T-cell reply and accounts for the probability of each clonal evolution outcome.

## Asset credits

See [asset credits](assets/CREDITS.md) for model sources and licenses.
