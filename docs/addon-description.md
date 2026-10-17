# GryphonMail

**A smarter mailbox for World of Warcraft: Forever.**

GryphonMail extends the default mailbox instead of replacing it. Everything stays where you know it, with a few tools that save you time on every visit.

## Features

### Search your inbox
- Search box in the inbox that filters mail by **sender or subject** as you type
- Suggests your **own characters** while typing, matching first name or surname
- Page through the results just like the normal inbox

### Predefined filters
Show only the mail you care about with one click:
- **My Characters** (mail from your alts)
- **Friends**
- **Guild**
- **Unread** / **Read**
- **Auction House**
- **Gold**
- **C.O.D.**

Filters work together with the search box, e.g. *Guild* + "ore".

### Open only what you filtered
While a search or filter is active, **Open All** becomes **Open Filtered** and only collects the mail you see. C.O.D. and GM mail are still skipped, just like Blizzard's button.

### Send to your alts
A small dropdown next to the **To** field of *Send Mail* lists your own characters of the same faction and ruleset (PvE, PvP, RP). Pick one and the name is filled in.

### Mail log
A new **Log** tab next to *Inbox* and *Send Mail* lists everything you collected:
- Sender, subject, date, gold and items for each mail, including the C.O.D. amount you paid
- Item details in the tooltip
- Stored per character, kept for 30 days (configurable)
- Only counts what actually arrived in your bags

### Summary in chat
After *Open All* / *Open Filtered* you get a short summary, e.g.
`GryphonMail: Collected 25 items and 12g 50s.`

## Slash commands

| Command | Description |
|---|---|
| `/gryphonmail` | Show all commands |
| `/gryphonmail chars` | List your known characters |
| `/gryphonmail chars remove <number or name>` | Forget a character (deleted or renamed) |
| `/gryphonmail log` | Show log settings |
| `/gryphonmail log days <1-365>` | Keep log entries for that many days |
| `/gryphonmail log clear` | Clear the log of the current character |

## Good to know
- Made for **World of Warcraft: Forever** (Interface 16001).
- Your characters are remembered when you log in with them once while the addon is active.
- Languages: English, German.

## Feedback & source code

Found a bug or have an idea? Please open an issue on GitHub:
**[github.com/Clausi/gryphonMail/issues](https://github.com/Clausi/gryphonMail/issues)**

Source code and changelog: [github.com/Clausi/gryphonMail](https://github.com/Clausi/gryphonMail)
