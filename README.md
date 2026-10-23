# ChatScrub

A World of Warcraft addon that hides public chat lines that match your keywords or look like gold/boost spam. Hidden lines go to a review log so you can catch false positives.

- **Filters:** channels (Trade, General, LFG, Services…), say, yell, whispers, emotes.
- **Never filters:** your own messages, friends, guildmates, players you allow, or guild/party/raid/instance chat.
- **Clients:** one `.toc` lists Retail 12.1.x, MoP Classic, Classic Era/Anniversary, and the 1.60 "_forever_" client.
- **Catches:** your keywords (with `*` wildcards or `~` Lua patterns), eight built-in spam rules you can switch one by one (guild recruitment is off by default), look-alike spellings (g0ld, c4rry, g o l d, b.o.o.s.t), German/French/Spanish spam, repeated lines, and blocked players.
- **Also:** watch words that highlight a line and play a sound, a searchable log window, import/export of your lists, a right-click "Block" on names in chat, optional raid-icon removal, hiding other players' loot, and hiding chat bubbles of hidden lines.
- **Saved variables:** `ChatScrubDB` (lists, log, counts, switches) per account; `ChatScrubCharDB` per character, used when a character has its own switches.
- **Language:** the options pages, windows and menu are in English, German, French and Spanish. Slash command replies are English only.

## Install

Copy the inner `ChatScrub/` folder (the one holding `ChatScrub.toc`) into your client's AddOns folder:

| Client | Folder |
|---|---|
| Retail | `/Applications/World of Warcraft/_retail_/Interface/AddOns/` |
| MoP Classic | `/Applications/World of Warcraft/_classic_/Interface/AddOns/` |
| Classic Era / Anniversary | `/Applications/World of Warcraft/_classic_era_/Interface/AddOns/` |

The result should be `.../Interface/AddOns/ChatScrub/ChatScrub.toc`. If the `.toc` ends up one folder deeper, the game won't see the addon.

While developing, a symlink saves copying after every edit:

```bash
ln -s "$HOME/Local Documents/AI-Projects/ChatScrub/ChatScrub" "/Applications/World of Warcraft/_retail_/Interface/AddOns/ChatScrub"
```

## Use

`/scrub` shows status and every command. `/scrub options` opens the settings (Options → AddOns → ChatScrub), which has four pages: the main page (switches and keywords), **Rules**, **Players** (blocked, allowed, allowed phrases, watch words) and **Extras**.

**Keywords**
- `/scrub add <phrase>`, `/scrub remove <phrase or number>`, `/scrub list` (shows how many lines each keyword hid)
- Keywords are plain text, not case-sensitive, and match anywhere in a line ("run" also hides "running"). `*` matches anything (`wts*carry`). A keyword starting with `~` is a Lua pattern (`~lf %d dps`).
- `/scrub try <phrase>` adds a keyword on trial: for 24 hours its matches go to the log but stay visible, then it starts hiding them.
- `/scrub watch <phrase>` highlights lines containing it and plays a sound (at most every 5 seconds). `/scrub watch` lists them, `/scrub unwatch <phrase or number>` removes one, `/scrub sound on|off` mutes it.

**Players**
- `/scrub block <name> [note]` hides everything that player says. `/scrub unblock <name>`, `/scrub blocked`.
- `/scrub allow <name> [days] [note]` never hides that player, optionally for a number of days. `/scrub unallow <name>`, `/scrub allowed`.
- `/scrub allowphrase <text>` never hides lines containing it; `/scrub unallowphrase <text or number>`.
- A name without a realm matches that name on every realm.
- Right-click a name in chat for **Block** and **Never hide this player** (on clients with the new menu system).
- **Auto-block:** after 3 spam-rule hits from one player, everything they say is hidden until you log out. `/scrub autoblock on|off|<hits>`.

**Rules and switches**
- `/scrub rules` lists the built-in rules with their on/off state and hit counts; `/scrub rule <number or name> on|off`.
- `/scrub spam on|off`, `/scrub on|off`, `/scrub repeats on|off|<minutes>` (default 5).
- `/scrub icons on|off` removes raid target icons from public lines. `/scrub loot on|off` hides other players' loot messages. `/scrub bubbles on|off` hides the say/yell bubble of a hidden line (open world only; the game blocks this in instances).
- `/scrub char on|off` gives this character its own copy of the switches. Keywords and player lists stay shared.

**Log and sharing**
- `/scrub log` opens the log window: search box, newest first, mouse wheel to scroll. **Show** prints a hidden line in chat; **Allow** stops hiding its sender. `/scrub log <n>` prints the last n lines instead. `/scrub clearlog` empties it.
- `/scrub export` shows your lists as text to copy; `/scrub import` takes that text back (adds entries, never removes).
- `/scrub test <text>` says whether a line would be hidden.
- `/scrub minimap` shows or hides the minimap button.

**Minimap button:** left-click opens the options, right-click turns filtering on/off (the icon goes grey when off), and dragging moves it around the minimap. Hover for on/off status and counts. The position is saved.

## Test in game

1. Log in. If ChatScrub is missing from the AddOns list on the character screen, check the folder depth (see Install).
2. Type `/scrub`. The status line should read "filtering on, spam rules on, repeats on (5 min), 0 keywords", followed by the command list.
3. `/scrub test WTS mythic+ carry 300k` should say "would hide it (spam: sells a boost/carry)". `/scrub test WTS [Linen Cloth] 5g` should say "would show it". `/scrub test w t s c4rry 300k` should also hide.
4. To check live filtering, add a word you can trigger yourself: `/scrub add pineapple`. Your own messages are never hidden, so have a non-guild, non-friend player say "pineapple" in /say, or wait for one in Trade. The line shouldn't appear. Then `/scrub log` should open the log window with it.
5. `/reload`, then run `/scrub list`. The keyword should still be there, with its hit count.
6. Watch Trade for a few minutes: players who post the same line every minute should show once. The counts on the main options page should climb.
7. Open each options page (main, Rules, Players, Extras). Turn a rule off on Rules, then `/scrub rules` should show it off.
8. Right-click a player's name in Trade. The menu should end with a ChatScrub section with Block and Never hide this player. Block them, then `/scrub blocked` should list them.
9. `/scrub watch lf` and wait for an "LF..." line in Trade: it should show with a gold `[lf]` tag and a sound.
10. `/scrub export`: a window with your lists should open, already selected for copying.
11. Hover the minimap button (lower left of the minimap) for the status tooltip, drag it somewhere else, `/reload`, and check that it stays put. `/scrub minimap` twice should hide and then show it.
12. If an addon error shows (BugGrabber/BugSack is installed on Retail), copy it into a note for fixing.

## Icon

`art/icon.svg` is the source. `art/icon-512.png` is for the CurseForge project page, and `ChatScrub/Media/Icon.tga` (64×64) is what the game loads for the AddOns list and the minimap button. To regenerate the TGA after editing the SVG:

```bash
rsvg-convert -w 64 -h 64 art/icon.svg | magick - -alpha on -depth 8 -compress None -define tga:image-origin=TopLeft TGA:ChatScrub/Media/Icon.tga
```

WoW only picks up new texture files after a full game restart, not `/reload`.

## Tests

```bash
luajit tests/run_tests.lua
```

(`lua tests/run_tests.lua` works too.)

The tests run the spam rules against sample spam (English, German, French, Spanish, look-alike spellings) and against normal chat that must stay visible. They cover keywords with wildcards, patterns and trials, and per-rule switches. With stubbed WoW API calls they cover the filter itself:
- deduping across chat windows, the repeat filter, trusted senders and secret values
- blocking, allowing with expiry, allowed phrases and auto-block
- watch words with sound throttling, raid-icon removal, loot and chat bubbles
- per-character switches, hit counts, import/export and the right-click menu
- the slash commands, the log cap and search, and the minimap button

The tests don't cover what the game actually draws: how the panels and windows look, whether the menu items appear, or how chat bubbles behave. Use "Test in game" for those.
