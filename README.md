# Mallard Discworld MDT

A [Mallard](https://mallard.vnsf.xyz) plugin for [Discworld MUD](https://discworld.starturtle.net/lpc/) that turns the `room.writtenmap` GMCP frame into a scored "Nearby" panel.

## What it does

Each time you move, Discworld sends a GMCP `room.writtenmap` payload listing who and what is visible in adjacent rooms (the same data you'd see by typing `map door text`). This plugin parses it and renders a sortable, scored panel:

```
  N   [5]  Sgt Detritus, 2 watchmen
  NE  [3]  3 bystanders, beggar
  2E  [2]  Carrot
  S   [1]  cat, 2 ravens
```

Rooms are sorted by score; the panel hides rooms below a threshold (configurable).

## Radar panel

A second panel, **Radar**, shows the same rooms as a 5x5 map of the ground
around you, with your own square in the middle:

```
  .    .    .    .    .
  .   2wm  .    .    .
  .    .    @   3bg  .
  .    .   6pg  .    .
  .    .    .    .    .
```

Each room's direction is summed into a square — "one north and one east" and
"one northeast" land on the same cell and merge. Hovering a square shows its
full contents; the squares themselves show as much as the panel allows, so
resizing the panel shows more.

Backgrounds shade by the square's own score, on fixed bands (1, 2-3, 4-6,
7-10, 11+) running deep blue through violet and magenta to burnt orange, so
the same room always looks the same colour as you move. The busiest square in
view is outlined. The count in the corner ramps green through red, and the
eight rooms one step away sit on a lighter ground than the ring beyond them.

Rooms with no compass square — up, down, shipboard directions (fore/aft/port/
starboard), and anything more than two rooms out — are listed underneath the
grid in the usual scored rows rather than being dropped.

Both panels are driven by the same pushes, so you can dock either one, or
both at once, and place them wherever your layout wants them.

## Commands

| Command | Effect |
|---|---|
| `mdt` | Show command list |
| `mdt help` | Show command list |
| `mdt list [pattern]` | Show match list, optionally filtered |
| `mdt add <pattern> [score] [colour]` | Add a match |
| `mdt remove <pattern>\|<n>` | Remove by pattern text or 1-based index |
| `mdt clear` | Wipe match list (this character only) |

Patterns are case-insensitive substrings by default. Wrap a pattern in `/.../` for Lua-pattern matching:

```
mdt add watchman 3 red
mdt add /^(sgt|cpt) %a+/ 5 yellow
```

Colours: `red`, `yellow`, `green`, `cyan`, `blue`, `magenta`, `white`, `grey`, plus `bold-` variants.

## Settings

- **Default score per entity** — applied to entities matching no entry (default: 1).
- **Hide rooms scoring below** — threshold for omitting rooms from the panel (default: 0).
- **Max rooms shown in panel** — caps the visible rows (default: 20).
- **Radar panel shading** — shade squares by score, use one colour for every
  occupied room, or no background colour at all.
- **Radar colour — score 1 / 2-3 / 4-6 / 7-10 / 11+** — one hex colour per
  band. Left blank, a band follows the current theme: saturated darks under a
  dark theme, tints of the same hues under a light one. A value overrides that
  band in every theme; anything that isn't a hex colour is treated as blank.
  The score 1 colour doubles as the fill for the "one colour for every occupied
  room" mode — that mode means "something is here, never mind how much", which
  is what the bottom band already says.

## Storage

Match lists are stored per-character, keyed by `char.info.name`.

## Development

```sh
luarocks install busted  # one-time
busted                    # run unit tests
```

Spec lives at `docs/superpowers/specs/2026-06-12-mdt-v0.1-design.md`
(gitignored — keep your local copy in sync with intent).

## Credit

Many thanks to Quow and Oki, whose work on similar plugins was
invaluable in designing and building this one.
