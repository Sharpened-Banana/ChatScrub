# Changelog

## 1.3.1 (2026-10-23)

- Adds the CurseForge project ID so addon managers can match installs to the project page. No changes in the game.

## 1.3.0 (2026-10-22): first CurseForge release

Supports Retail 12.1.x and the 1.60 client.

**Matching**
- Catches look-alike spellings: c4rry, go1d, b3st, and spaced or dotted letters like "g o l d" and "b.o.o.s.t".
- Keywords can use `*` as a wildcard (`wts*carry`), or start with `~` to be a Lua pattern.
- `/scrub try <phrase>` adds a keyword on trial: for 24 hours its matches are logged but stay visible, then it starts hiding them.
- Spam rules also cover German, French and Spanish spam.
- New guild-recruitment rule, off by default.

**Rules**
- Each built-in rule can be turned on or off on the new Rules page or with `/scrub rule <number> on|off`.
- Every rule and keyword counts how many lines it has hidden (`/scrub rules`, `/scrub list`).

**Players**
- `/scrub block <name>` hides everything a player says. `/scrub allow <name> [days]` never hides them.
- `/scrub allowphrase <text>` never hides lines containing that text.
- Right-click a name in chat for Block and Never hide this player.
- Players caught by the spam rules 3 times are hidden until you log out (`/scrub autoblock`).

**Other**
- Watch words highlight a line and play a sound (`/scrub watch <phrase>`).
- Log window with search: Show puts a hidden line back in chat, Allow stops hiding its sender (`/scrub log`).
- Import and export your lists as text (`/scrub export`, `/scrub import`).
- Optional: remove raid-target icons from public chat, hide other players' loot, hide the chat bubble of a hidden line.
- A character can have its own switches while the lists stay shared (`/scrub char on`).
- Options split into four pages: main, Rules, Players and Extras.
- Options pages, windows and menu are translated into German, French and Spanish.
- New icon.

## 1.2.0 (2026-10-22)

- Repeat filter: a line the same player already posted in the same channel within 5 minutes is hidden (`/scrub repeats`). Whispers aren't affected.
- Hovering "Use built-in spam rules" lists what each rule catches.

## 1.1.0 (2026-10-22)

- Minimap button: left-click for options, right-click to turn filtering on or off, drag to move.

## 1.0.0 (2026-10-21)

- Hides public chat that matches your keywords or the built-in gold/boost spam rules.
- Never hides your own lines, friends, guildmates, or group chat.
- Keeps a log of the last 50 hidden lines with the rule that caught each one.
- Options panel and `/scrub` commands.
