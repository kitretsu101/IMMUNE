# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

<!-- Note: IMMUNE is a native desktop Godot 4.7 game (Compatibility renderer), not a website. `web` is the closest schema value; no iOS/Android design language applies. -->

## Stack

Godot 4.7.2 (GDScript), 3D hex board, Compatibility renderer. Existing codebase; stack is settled.

## Users

Casual strategy players on desktop, in short sessions of single-player, turn-based play. They learn rules from the README and in-game cues.

## Product Purpose

IMMUNE is a single-player, turn-based strategy game on a 3D hex board. The player commands blue T cells defending seven gold human cells at the center. They win by eliminating all pink bacteria; the bacteria win by infecting all seven human cells.

## Positioning

An immune-system defense game where cloning T cells triggers clonal evolution: a copy's trait rolls -1, 0, or +1, so the player's army mutates as it grows. Bacteria answer with two-ply minimax AI.

## Operating Context

One action per side per turn; a side with no legal action passes, and consecutive passes draw. Controls: left-click select/move, `M`/`C` switch Move/Clone, right-drag pan, middle-drag orbit, scroll zoom, `R` restart. Hovering a bacterium on the player's turn shows its stats.

## Capabilities and Constraints

- Move up to four hexes (per-cell range) across empty hexes only; human cells block movement until infected.
- Clone onto an adjacent hex; trait variation within allowed ranges (T cells: movement range; bacteria: movement range or infectibility).
- Infection removes human cells; infectibility sets how many (landing cell plus adjacent human cells).
- Model assets credited in assets/CREDITS.md.

## Evidence on Hand

README.md, assets/CREDITS.md, existing 3D scenes and neon tile visuals in scenes/. No user testimonials or metrics exist; do not fabricate.

## Product Principles

- Rules must be legible at a glance: the player always knows what a click will do.
- Clear sides: blue T cells, gold human cells, pink bacteria stay distinguishable.
- Evolution is the hook; surface the stats that make clonal variation meaningful.
- Short sessions: quick turns, easy restart.
