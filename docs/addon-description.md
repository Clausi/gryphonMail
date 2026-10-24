# GryphonMail

**A smarter mailbox for World of Warcraft: Forever, Classic Era, Anniversary, MoP Classic and Retail.**

GryphonMail extends the default mailbox instead of replacing it. Everything stays where you know it, with a few tools that save you time on every visit.

## Features

### Search your inbox
- Search box in the inbox that filters mail by **sender, subject or attached item** as you type
- Suggests your **own characters** while typing, matching first name or surname
- Page through the results just like the normal inbox

### Predefined filters
Show only the mail you care about with one click:
- **My Characters** (mail from your alts)
- **Friends**
- **Recent Allies** (characters from the *Recent Allies* tab of your friends list, where the game has it)
- **Guild**
- **Unread** / **Read**
- **Auction House**
- **Gold**
- **C.O.D.**

Filters work together with the search box, e.g. *Guild* + "ore".

### Open only what you filtered
While a search or filter is active, **Open All** becomes **Open Filtered** and only collects the mail you see. C.O.D. and GM mail are still skipped, just like Blizzard's button.

### Pick a recipient
A small dropdown next to the **To** field of *Send Mail* lists:
- Your **own characters** of the same faction and realm (Forever: ruleset PvE, PvP, RP; Retail: also connected realms)
- Your **guild members** and **recent allies** (where the game has them) in submenus, class colored. Long lists are split into name ranges, e.g. *Abby - Fiona*.

Pick one and the name is filled in.

### Mail log
A new **Log** tab next to *Inbox* and *Send Mail* lists everything you collected, sent, returned and deleted:
- Sender, subject, date, gold and items for each mail, including the C.O.D. amount you paid
- **Sent mail** with recipient, gold, items and the C.O.D. amount you asked for
- **Deleted** and **returned mail**, including the gold and items it still contained
- The same **search box and filters** as the inbox, with **From** / **To** / **Returned** / **Deleted** instead of Unread / Read
- Item details in the tooltip
- Stored per character, kept for 30 days (configurable)
- Only counts what actually arrived in your bags, and only mail that was actually sent

### Summary in chat
After *Open All* / *Open Filtered* you get a short summary, e.g.
`GryphonMail: Collected 25 items and 12g 50s.`

## Slash commands

| Command | Description |
|---|---|
| `/gryphonmail` | Show all commands |
| `/gryphonmail chars` | List your known characters, with a mailbox icon for those you can send mail to |
| `/gryphonmail chars remove <number or name>` | Forget a character (deleted or renamed) |
| `/gryphonmail log` | Show log settings |
| `/gryphonmail log days <1-365>` | Keep log entries for that many days |
| `/gryphonmail log clear` | Clear the log of the current character |
| `/gryphonmail chat on\|off` | Turn the automatic chat messages (login, summary, hints) of this character on or off |

## Good to know
- One download for **Forever**, **Classic Era**, **Anniversary**, **MoP Classic** and **Retail**.
- Outside Forever, characters on other realms are shown as *Name-Realm*.
- Your characters are remembered when you log in with them once while the addon is active.
- Languages: English, German, French.

## Feedback & source code

Found a bug or have an idea? Please open an issue on GitHub:
**[github.com/Clausi/gryphonMail/issues](https://github.com/Clausi/gryphonMail/issues)**

Source code and changelog: [github.com/Clausi/gryphonMail](https://github.com/Clausi/gryphonMail)

Also available on [CurseForge](https://www.curseforge.com/projects/1750287) and [Wago Addons](https://addons.wago.io/addons/gryphonmail).
