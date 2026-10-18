# GryphonMail

A World of Warcraft: Forever addon that extends the default mailbox.

Target client: WoW Forever (`## Interface: 16001`). Forever uses the Mainline
(retail) UI and API, so Mainline documentation applies, not Classic Era.

## Installation

Copy (or symlink) the `GryphonMail` folder into the Forever client's AddOns folder:

```
World of Warcraft\<forever client folder>\Interface\AddOns\GryphonMail
```

## Structure

```
GryphonMail/
├── GryphonMail.toc        # Addon manifest, defines load order
├── docs/
│   └── addon-description.md  # Description text for CurseForge / WoWInterface (not shipped)
├── Locales/
│   ├── enUS.lua           # Base locale (fallback, all keys)
│   └── deDE.lua           # German translation
├── Core/
│   ├── Init.lua           # Namespace, module registry, event dispatcher
│   ├── Util.lua           # Print/Debug helpers, defaults handling
│   ├── Names.lua          # Forever character names ("First Surname"): build and compare
│   └── Main.lua           # Bootstrap: saved variables, module lifecycle, slash commands
└── Modules/
    ├── Characters.lua     # Remembers the account's own characters (saved on login)
    ├── Contacts.lua       # Cached friends, guild members and recent allies
    ├── MailFilters.lua    # Search box with own-character suggestions and filter presets, for inbox and log
    ├── InboxView.lua      # Shared inbox filtering: redraws rows, paging, "Open All"
    ├── InboxSearch.lua    # Inbox search box (sender/subject)
    ├── InboxFilter.lua    # Inbox filter dropdown (own characters, friends, recent allies, guild, unread, read, AH, gold, C.O.D.)
    ├── MailLog.lua        # Records collected and sent mail per character, "Open All" summary
    ├── MailLogFrame.lua   # Third mail frame tab "Log" with search box and filters (as inbox, but from/to)
    └── SendMailRecipients.lua # Recipient dropdown next to the "To" field of "Send Mail"
```

## Adding a module

1. Create `Modules/MyModule.lua`:

   ```lua
   local _, ns = ...
   local MyModule = ns:RegisterModule("MyModule")

   function MyModule:OnInitialize() end -- saved variables available
   function MyModule:OnEnable() end     -- PLAYER_LOGIN
   ```

2. Add it to `GryphonMail.toc` above `Core\Main.lua`.

## Localization

All strings live in `Locales/`. Add new keys to `enUS.lua` first; other locales
only override what they translate. Missing keys fall back to English.

## Development

Lint with [luacheck](https://github.com/lunarmodules/luacheck). Place `luacheck.exe` in `.tools/`
(ignored by git) and run from the repo root:

```
./.tools/luacheck.exe .
```

## Slash commands

- `/gryphonmail` – help
- `/gryphonmail version` – show version
- `/gryphonmail chars` – list known own characters
- `/gryphonmail chars remove <number|name>` – forget a character (e.g. deleted or renamed)
- `/gryphonmail log` – show log settings
- `/gryphonmail log days <1-365>` – keep log entries for that many days (default 30)
- `/gryphonmail log clear` – clear the log of the current character
- `/gryphonmail debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.
