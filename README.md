# GryphonMail

A World of Warcraft addon that extends the default mailbox.

## Features

- **Inbox search:** filters mail by sender, subject or attached item as you type, and suggests own
  characters.
- **Filter presets:** own characters, friends, recent allies, guild, unread, read, auction house,
  gold and C.O.D. They work together with the search box.
- **Open Filtered:** while a search or filter is active, "Open All" only opens the matching mail
  (still skipping C.O.D. and GM mail).
- **Recipient dropdown:** next to the "To" field of "Send Mail", lists own characters that can
  receive mail from the current one, guild members and recent allies.
- **Mail log:** a "Log" tab with collected, sent, returned and deleted mail, including gold and
  items, with the same search and filters as the inbox. Stored per character.
- **Chat summary:** after "Open All" / "Open Filtered", what was collected.

The full description for CurseForge is in [docs/addon-description.md](docs/addon-description.md).

## Supported clients

| Client      | Interface | Status                                 |
| ----------- | --------- | -------------------------------------- |
| Forever     | 16001     | Supported                              |
| Anniversary | 20506     | Supported                              |
| Classic Era | 11509     | Supported, less tested (see [#24][])   |
| MoP Classic | 50504     | Supported, less tested                 |
| Retail      | 120105    | Supported, less tested (see [#24][])   |

One package works on all clients. Forever and Retail use the Mainline UI and API, Classic Era,
Anniversary and MoP Classic the Classic UI. Client differences are handled in `Core/Compat.lua`.

Known differences:

- Outside Forever, characters are told apart by realm: characters on other realms are shown as
  "Name-Realm", and own characters are only offered as recipients on the same realm (Retail: also
  on connected realms) and faction.
- The recent allies filter and submenu only appear where the client has that system enabled.

[#24]: https://github.com/Clausi/gryphonMail/issues/24

## Installation

Install it from [CurseForge](https://www.curseforge.com/projects/1750287) or
[Wago Addons](https://addons.wago.io/addons/gryphonmail), or copy (or symlink) the `GryphonMail` folder into the client's AddOns folder:

```
World of Warcraft\<client folder>\Interface\AddOns\GryphonMail
```

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` to a new version section and bump
   `## Version` in `GryphonMail.toc`, then merge that into `main`.
2. Tag the merge commit on `main` and push the tag:

   ```
   git tag v0.7.0
   git push origin v0.7.0
   ```

3. The `Release` workflow runs luacheck, builds the package with the
   [BigWigs packager](https://github.com/BigWigsMods/packager) and uploads it to CurseForge (project
   ID from `X-Curse-Project-ID` in the TOC), Wago Addons (`X-Wago-ID`) and as a GitHub release.
   Game versions come from `## Interface`. It needs the repository secrets `CF_API_KEY` (a
   CurseForge API token) and `WAGO_API_TOKEN` (a Wago Addons API key).

## Structure

```
GryphonMail/
├── .github/workflows/
│   ├── luacheck.yml       # luacheck on pushes to main and on pull requests
│   └── release.yml        # Builds and uploads a release on version tags (BigWigs packager)
├── .pkgmeta               # Packager config: changelog and files left out of the package
├── GryphonMail.toc        # Addon manifest, defines load order
├── LICENSE                # MIT license
├── docs/
│   └── addon-description.md  # Description text for CurseForge / Wago / WoWInterface (not shipped)
├── Locales/
│   ├── enUS.lua           # Base locale (fallback, all keys)
│   ├── deDE.lua           # German translation
│   └── frFR.lua           # French translation
├── Core/
│   ├── Init.lua           # Namespace, module registry, event dispatcher
│   ├── Compat.lua         # Client differences (Forever, Classic Era, Anniversary, MoP Classic, Retail) detected from the APIs
│   ├── Util.lua           # Print/Debug helpers, debug memory output, on-demand dropdown menus, defaults
│   ├── Names.lua          # Character names per client ("First Surname" / "Name-Realm"): build, compare, show
│   └── Main.lua           # Bootstrap: saved variables, module lifecycle, slash commands
└── Modules/
    ├── Characters.lua     # Remembers the account's own characters (saved on login)
    ├── Contacts.lua       # Cached friends, guild members and recent allies
    ├── MailFilters.lua    # Search box with own-character suggestions and filter presets, for inbox and log
    ├── InboxView.lua      # Shared inbox filtering: redraws rows, paging, "Open All"
    ├── InboxSearch.lua    # Inbox search box (sender/subject/item)
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
- `/gryphonmail chars` – list known own characters, mail targets of the current one marked with a
  mailbox icon
- `/gryphonmail chars remove <number|name>` – forget a character (e.g. deleted or renamed)
- `/gryphonmail log` – show log settings
- `/gryphonmail log days <1-365>` – keep log entries for that many days (default 30)
- `/gryphonmail log clear` – clear the log of the current character
- `/gryphonmail notify on|off` – automatic messages (login, summary after "Open All", hints) of the
  current character, default on
- `/gryphonmail debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.

## License

[MIT](LICENSE)
