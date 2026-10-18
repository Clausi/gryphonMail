# GryphonMail

A World of Warcraft addon that extends the default mailbox.

## Supported clients

| Client      | Interface | Status                    |
| ----------- | --------- | ------------------------- |
| Forever     | 16001     | Supported                 |
| Classic Era | 11509     | In progress (see [#24][]) |
| Anniversary | 20506     | In progress (see [#24][]) |
| Retail      | 120105    | In progress (see [#24][]) |

Forever uses the Mainline (retail) UI and API, while Classic Era and Anniversary use the Classic UI.
Client differences are handled in `Core/Compat.lua`.

Known differences:

- Classic Era and Anniversary: "Open All" always opens all mail, also while a search or filter is
  active. Blizzard's button there offers no way to skip single mails.

[#24]: https://github.com/Clausi/gryphonMail/issues/24

## Installation

Copy (or symlink) the `GryphonMail` folder into the client's AddOns folder:

```
World of Warcraft\<client folder>\Interface\AddOns\GryphonMail
```

## Structure

```
GryphonMail/
├── GryphonMail.toc        # Addon manifest, defines load order
├── LICENSE                # MIT license (not shipped)
├── docs/
│   └── addon-description.md  # Description text for CurseForge / WoWInterface (not shipped)
├── Locales/
│   ├── enUS.lua           # Base locale (fallback, all keys)
│   └── deDE.lua           # German translation
├── Core/
│   ├── Init.lua           # Namespace, module registry, event dispatcher
│   ├── Compat.lua         # Client differences (Forever, Classic Era, Anniversary, Retail) detected from the APIs
│   ├── Util.lua           # Print/Debug helpers, debug memory output, on-demand dropdown menus, defaults
│   ├── Names.lua          # Forever character names ("First Surname"): build and compare
│   └── Main.lua           # Bootstrap: saved variables, module lifecycle, slash commands
└── Modules/
    ├── Characters.lua     # Remembers the account's own characters (saved on login)
    ├── Contacts.lua       # Cached friends, guild members and recent allies
    ├── MailFilters.lua    # Search box with own-character suggestions and filter presets, for inbox and log
    ├── InboxView.lua      # Shared inbox filtering: redraws rows, paging, "Open All"
    ├── InboxSearch.lua    # Inbox search box (sender/subject)
    ├── InboxFilter.lua    # Inbox filter dropdown (own characters, friends, recent allies, guild, unread, read, AH, gold, C.O.D.)
    ├── MailLog.lua        # Records collected, sent, returned and deleted mail per character, "Open All" summary
    ├── MailLogFrame.lua   # Third mail frame tab "Log" with search box and filters (as inbox, but from/to/returned/deleted)
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
- `/gryphonmail chat on|off` – automatic chat messages (login, summary after "Open All", hints) of the
  current character, default on
- `/gryphonmail debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.

## License

[MIT](LICENSE)
