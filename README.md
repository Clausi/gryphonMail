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
    ├── InboxView.lua      # Shared inbox filtering: redraws rows, paging, "Open All"
    └── InboxSearch.lua    # Search box that filters the inbox by sender or subject
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
- `/gryphonmail debug` – toggle debug output

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.
