# Alters Forever

A light alt manager for World of Warcraft: Forever. I wanted to know what my
other characters were carrying without logging into each of them, so I wrote
this.

Every character you log in with gets remembered: level and experience, gold,
rested XP, zone, time played, and what it has in its bags, bank, mail and on
the auction house. Hover any item and the tooltip tells you who has it and
where. The bank, mail and auction house are read when you open them, so visit
each once per character.

`/alts` (or the minimap button) opens the window.

The Characters tab lists everyone with their gold and rested XP, and the
rested amount keeps going up while a character is logged out, the same way the
game does it. Click a character to open its page, which works like the
in-game character window. The icons next to the name switch between items,
talents, legacy trees, reputation, skills, PvE/PvP, currency, attributes and
the numbers from the game's statistics window. Talents and legacy trees show
the points each character has spent, and PvE/PvP starts with the instances and
world bosses it is saved to. Items are shown bag by bag, each bag under its own
divider with its name and how full it is, slot for slot as it is in the game,
empty slots included. They can be filtered by bags, bank, mail, equipped or
auction. Equipped gear is laid out like the paper doll.

The Guild tab shows the guild bank tab by tab, slot for slot as it is in the
game, with its gold. It is read when you open the guild bank with any
character in the guild, and item tooltips and Search count it too.

Professions shows the ranks of every character side by side. Click one to see
its recipes, coloured by how likely they are to give a skill-up, with their
materials and how many of them that character has. You can search recipes by
name or by material. Recipe items in tooltips say who already knows them, who
can learn them and who still needs more skill.

Mail lists every letter of every character, the one that expires first at the
top: who sent it, what it carries, its gold or cash on delivery and when it
expires. Mail you send or return to your own characters, and auctions that sold
or ended, show up as expected letters (marked with ~) until that character opens
its mailbox. A red letter next to a name means mail about to expire, a blue one
new mail.

Cooldowns collects profession cooldowns (transmutes, mooncloth and the like)
from all your characters and tells you in chat when one is ready.

Columns can be sorted by clicking their header. Characters you don't want to
see can be hidden with a right click, without deleting anything. Shift-right
click writes a note. The buttons under the list show only this realm or this
faction.

Options, "Tabs, sections and filters", hides tabs you don't use, changes their
order and hides sections of the character page.

By default the window uses the Forever look: dark glass with bronze lines and
gold highlights. The Blizzard theme gives it the game's own frames and buttons,
and there are seven colour themes too. Size and opacity can be changed, and
every colour lives in `Themes.lua` if you want to make your own.

## Commands

| Command | What it does |
| --- | --- |
| `/alts` | Open or close the window |
| `/alts tooltip` | Turn the item tooltip lines on or off |
| `/alts button` | Show or hide the minimap button |
| `/alts theme horde` | Change the colours (`forever`, `blizzard`, `green`, `blue`, `purple`, `grey`, `classic`, `alliance`, `horde`) |
| `/alts scale 1.2` | Window size, from 0.6 to 1.6 |
| `/alts mail` | Open the Mail tab |
| `/alts customize` | Tabs, sections, filters and mail options |

`/af` and `/alters` work the same as `/alts`.

## Languages

English, Spanish, German, French, Italian, Portuguese, Russian, Korean, and
Simplified and Traditional Chinese.

## Installation

Put the `AltersForever` folder in `World of Warcraft\_classic_beta_\Interface\AddOns\`
and restart the game. Made for Forever 1.60.1 (`Interface: 16001`).

## Development

Run `tests/check.sh` before a commit. It needs `lua5.1`, `luac5.1` and
`luacheck` (on Ubuntu: `sudo apt install lua5.1 lua-check`). It does three
things:

- compiles every file with Lua 5.1, which has the same limits as the game:
  200 locals in the main chunk and 60 upvalues in each function. The main
  file is close to the first limit, so new code goes into tables such as
  `mailbox`, `custom` or `guildBank` instead of new top-level locals, or
  into its own file. `Mail.lua` and `Customize.lua` load after the main file
  and get its helpers from `ns.af`, and `db`, `me` and `window` from `ns`;
- runs luacheck with `.luacheckrc`. An unknown global is usually a typo or a
  local used before its definition. Add a WoW API name to the list only when
  the code needs it;
- runs `tests/harness.lua`, which loads the addon against a mocked game API
  and goes through login, the mailbox, sent mail, auctions and every tab.

The harness does not replace a test in the game.

## License

MIT
