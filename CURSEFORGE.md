# CurseForge project page

Text to paste into the CurseForge project settings. Everything under "Description" goes in the description field (CurseForge accepts Markdown). The screenshot list at the end is for you, not the page.

## Project settings

- **Name:** ChatScrub
- **Summary:** Hides gold sellers, boost ads and anything else you don't want to see in Trade, General and public chat.
- **Category:** Chat & Communication (secondary: Miscellaneous)
- **License:** MIT
- **Icon:** `art/icon-512.png`
- **Game versions to tick on upload:** Retail 12.1.x and 1.60

## Description

**ChatScrub hides the spam in public chat so you can read the rest.**

Gold sellers, boost ads, website links and the same "WTS" line every 30 seconds: ChatScrub takes them out of Trade, General, LFG, say, yell, whispers and emotes. Your own lines, friends, guildmates and group chat are never touched.

Nothing disappears for good. Every hidden line goes to a log you can search, so if something you wanted gets caught, one click puts it back.

### What it catches

- **Gold and boost spam** with built-in rules, including spam written as c4rry, g0ld, "g o l d" or b.o.o.s.t, and German, French and Spanish ads. Each rule can be switched off by itself.
- **Your own keywords.** Plain words, `*` wildcards (`wts*carry`), or Lua patterns for advanced users. Try a keyword for 24 hours first: matches are logged but stay visible until you're sure.
- **Repeated lines.** If someone posts the same thing again within 5 minutes, you see it once.
- **Players you block.** Right-click a name in chat and choose Block. Players who keep tripping the spam rules are hidden until you log out.
- **Guild recruitment ads**, if you want them gone (off by default).

### What it doesn't hide

- Anyone on your friends list or in your guild
- Players you allow (for good, or for a few days)
- Lines containing phrases you allow, like the item you're shopping for
- Guild, party, raid and instance chat

### Also

- **Watch words:** highlight lines that mention something you care about ("LF tank", your name) and play a sound.
- **Log window:** search hidden lines by player, channel, text or rule. Show puts a line back in chat; Allow stops hiding that player.
- **Counts:** see how many lines each rule and keyword has hidden.
- **Clean-ups:** optionally remove raid-target icons, hide other players' loot messages, and hide the chat bubbles of hidden lines.
- **Import/export** your lists as text to share them or move them between accounts.
- **Per-character switches** if one character wants different settings.
- **Minimap button:** left-click for options, right-click to turn filtering on or off.
- No library dependencies.

### Commands

`/scrub` shows everything. The ones you'll use most:

| Command | What it does |
|---|---|
| `/scrub options` | Open the settings |
| `/scrub add <phrase>` | Hide lines containing it |
| `/scrub block <name>` | Hide everything a player says |
| `/scrub log` | Open the hidden-lines log |
| `/scrub test <text>` | Check whether a line would be hidden |
| `/scrub on` / `/scrub off` | Turn filtering on or off |

### Notes

- **Mythic+, PvP and boss fights (Retail):** the game doesn't let addons read chat during these, so ChatScrub lets those lines through rather than risk errors.
- **Chat bubbles** can only be hidden in the open world; the game blocks it in dungeons and raids.
- **Translations:** the German, French and Spanish text hasn't been checked by native speakers yet. Corrections are welcome in the comments.

## Screenshots to take

CurseForge shows these in a gallery; 3–5 is plenty. Take them at a normal UI scale, crop to the relevant part, and give each a one-line caption.

1. **Before/after Trade chat.** A busy Trade channel with `/scrub off`, then the same stretch with `/scrub on`. Caption: "Trade chat with and without ChatScrub."
2. **The log window** (`/scrub log`) with a dozen hidden lines and their reasons. Hover a row so the tooltip shows. Caption: "Every hidden line is logged with the rule that caught it."
3. **The Rules page** (Options → AddOns → ChatScrub → Rules) after some play, so the counts are non-zero. Caption: "Switch each rule on or off and see what it has caught."
4. **The right-click menu** on a name in Trade, showing the ChatScrub section. Caption: "Block a spammer from the chat menu."
5. **A watch word hit**, such as `/scrub watch lf tank`, with the gold tag visible in chat. Caption: "Watch words highlight what you're looking for."

Blur or crop other players' names if you'd rather not show them.
