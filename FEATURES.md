# Feature ideas

From a look at chat-filter addons on CurseForge on 2026-10-22. ChatScrub already has keywords, built-in spam rules, a log that names the matching rule, `/scrub test`, 0-for-o matching, a friend/guild/group whitelist, safe handling of 12.x secret values, and a minimap button. Everything from that survey is now built except what is listed under Skipped.

## Done in 1.3.0 (2026-10-22)

All of the ideas from the survey except the low-level whisper filter (see below):

1. Repeat-message filter (1.2.0)
2. Per-rule hit counts: `/scrub list`, `/scrub rules`, the Rules page, the rules tooltip
3. Per-rule on/off: Rules page, `/scrub rule <n> on|off`
4. Block a player: `/scrub block`, right-click menu
5. Auto-block repeat spammers for the session: `/scrub autoblock`
6. Look-alike matching: 1/3/4/5/7 and 0 swaps, spaced or dotted letters
7. Log window with search, Show and Allow
8. Allowlist for players (with note and expiry) and phrases
9. Watch words with marker and sound
10. Wildcard (`*`) and Lua-pattern (`~`) keywords
11. Import/export as text
12. Guild recruitment rule (off by default)
14. Chat bubbles of hidden lines (open world only)
15. Trial keywords: `/scrub try`
16. Per-character switches: `/scrub char`
17. German, French and Spanish: interface text and spam patterns
18. Raid icon removal and hiding other players' loot

## Skipped

13. **Low-level whisper filter.** Addons can't read a whisperer's level. `/who` lookups need a key press since patch 8.2.5, and the remaining trick (briefly adding each whisperer as a friend, as BadBoy_Levels does) changes your friends list. Not worth that.
18 (part). **Addon chatter.** Too vague to filter safely: other addons' messages arrive mostly in party/raid chat, which ChatScrub never touches.

## Still unverified in game

- How the four options pages lay out on each client.
- The right-click menu on Classic Era and MoP Classic (it needs the newer Menu API; without it only the slash commands work).
- Hiding chat bubbles, and loot hiding on Classic clients (whether loot lines name the looter there).
- The German, French and Spanish text needs a check by native speakers.

## Not worth it

- **Group Finder listing filters:** addons can't read listing titles or descriptions any more (LFGSpamFilter works around this only by banning leaders).
- **Auto-reporting spammers:** since 11.0 addons can barely use the report window, and automating reports risks breaking Blizzard's rules.
- **Learning rules from "spam / not spam" clicks:** CleanChat Sentinel does this, but it's a lot of code for a small addon, and per-rule hit counts plus the allowlist cover most of the benefit.

## Retail 12.x note

During Mythic+, PvP and boss fights, chat arrives as secret values that addons can't read. ChatScrub already lets those lines through. One report says `ChatFrame_AddMessageEventFilter` can cause "Action Blocked" errors in 12.x; it's unconfirmed, but if those errors appear in testing, check this first.
