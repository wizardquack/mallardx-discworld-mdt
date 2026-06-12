# Mallard Discworld MDT

A [Mallard](https://mallard.vnsf.xyz) plugin for [Discworld MUD](https://discworld.starturtle.net/lpc/) that turns the `room.writtenmap` GMCP frame into a scored "Nearby" panel.

Functional equivalent of Quow Cow Bar's MDT module and tt_dw's `/mdt` —
ported to Mallard.

## What it does

Each time you move, Discworld sends a GMCP `room.writtenmap` payload listing who and what is visible in adjacent rooms (the same data you'd see by typing `map door text`). This plugin parses it and renders a sortable, scored panel:

```
  N   [5]  Sgt Detritus, 2 watchmen
  NE  [3]  3 bystanders, beggar
  2E  [2]  Carrot
  S   [1]  cat, 2 ravens
```

Rooms are sorted by score; the panel hides rooms below a threshold (configurable).

## Commands

| Command | Effect |
|---|---|
| `mdt` | Focus the Nearby panel |
| `mdt help` | Command list |
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

## Storage

Match lists are stored per-character, keyed by `char.info.name`. Until your character logs in, edits land in a `_default` bucket shared across alts.

## Development

```sh
luarocks install busted  # one-time
busted                    # run unit tests
```

Spec lives at `docs/superpowers/specs/2026-06-12-mdt-v0.1-design.md`
(gitignored — keep your local copy in sync with intent).
